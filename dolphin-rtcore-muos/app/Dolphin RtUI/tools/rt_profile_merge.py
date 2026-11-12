#!/usr/bin/env python3
"""Build Dolphin's global runtime INIs from canonical Rt:Core profile layers.

GameSettings are intentionally not merged here. They are projected separately
to Config/GameSettings/<GameID>.ini so Dolphin applies one native per-game file.
"""

import argparse
from pathlib import Path
import re

INI_SECTION_RE = re.compile(r'^\s*\[([^\]]+)\]\s*$')
INI_KV_RE = re.compile(r'^\s*([^=;#][^=]*?)\s*=\s*(.*?)\s*$')


def parse_ini(text):
    order, sections, current = [], {}, None
    for raw in text.splitlines():
        section = INI_SECTION_RE.match(raw)
        if section:
            current = section.group(1).strip()
            if current not in sections:
                order.append(current)
                sections[current] = []
            continue
        item = INI_KV_RE.match(raw)
        if item and current is not None:
            sections[current].append((item.group(1).strip(), item.group(2)))
    return order, sections


def flatten(order, sections):
    result = {}
    for section in order:
        for key, value in sections[section]:
            result[(section, key)] = value
    return result


def merge_into(order, flat, text):
    incoming_order, incoming_sections = parse_ini(text)
    for section in incoming_order:
        if section not in order:
            order.append(section)
        for key, value in incoming_sections[section]:
            flat[(section, key)] = value


def write_ini(path, order, flat):
    section_keys = {section: [] for section in order}
    seen = set()
    for section in order:
        for (candidate_section, key), value in flat.items():
            pair = (candidate_section, key)
            if candidate_section == section and pair not in seen:
                section_keys[section].append((key, value))
                seen.add(pair)

    output = []
    for section in order:
        if not section_keys[section]:
            continue
        output.append(f'[{section}]')
        for key, value in section_keys[section]:
            output.append(f'{key} = {value}')
        output.append('')
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(output), encoding='utf-8')


def read_requires_base(profile_dir):
    """Read [Runtime] RequiresBase from profile metadata, if present."""
    metadata = Path(profile_dir) / 'rtprofile_data.ini'
    if not metadata.is_file():
        return ''

    current_section = ''
    for raw in metadata.read_text(encoding='utf-8', errors='replace').splitlines():
        section = INI_SECTION_RE.match(raw)
        if section:
            current_section = section.group(1).strip()
            continue
        if current_section != 'Runtime':
            continue
        item = INI_KV_RE.match(raw)
        if item and item.group(1).strip() == 'RequiresBase':
            return item.group(2).strip()
    return ''


def resolve_profile_layers(default_dir, profile_dir):
    """Resolve Default -> family/required parents -> selected profile/tier."""
    default_path = Path(default_dir).resolve()
    profiles_root = default_path.parent
    layers, seen = [], set()

    def add(candidate):
        candidate = Path(candidate)
        if not candidate.is_dir():
            return
        resolved = candidate.resolve()
        if resolved == default_path or resolved in seen:
            return
        seen.add(resolved)

        try:
            relative = resolved.relative_to(profiles_root)
        except ValueError:
            relative = None

        # A family tier such as RtPrime/std inherits its parent family first.
        if relative is not None and len(relative.parts) > 1:
            parent = resolved.parent
            if parent != profiles_root and parent != default_path:
                add(parent)

        required = read_requires_base(resolved)
        if required and required != 'Default':
            required_path = profiles_root / required
            if required_path.is_dir():
                add(required_path)

        layers.append(resolved)

    add(profile_dir)
    return layers


def merge_profile_layers(default_dir, profile_dir):
    """Build Dolphin.ini/GFX.ini from the canonical profile hierarchy."""
    default_path = Path(default_dir)
    state = {}

    for filename in ('Dolphin.ini', 'GFX.ini'):
        source = default_path / filename
        if source.is_file():
            order, sections = parse_ini(source.read_text(encoding='utf-8', errors='replace'))
            state[filename] = (order, flatten(order, sections))
        else:
            state[filename] = ([], {})

    for layer in resolve_profile_layers(default_path, profile_dir):
        for filename in ('Dolphin.ini', 'GFX.ini'):
            source = layer / filename
            if source.is_file():
                merge_into(
                    state[filename][0],
                    state[filename][1],
                    source.read_text(encoding='utf-8', errors='replace'),
                )
    return state


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--default-dir', required=True)
    parser.add_argument('--profile-dir', required=True)
    parser.add_argument('--out-dir', required=True)
    parser.add_argument('--game-id', default='', help='diagnostic label only; GameSettings are projected separately')
    args = parser.parse_args()

    default_dir = Path(args.default_dir)
    profile_dir = Path(args.profile_dir)
    output_dir = Path(args.out_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    state = merge_profile_layers(default_dir, profile_dir)
    for filename in ('Dolphin.ini', 'GFX.ini'):
        write_ini(output_dir / filename, state[filename][0], state[filename][1])

    layers = resolve_profile_layers(default_dir, profile_dir)
    print(f'merged profiles: default={default_dir} layers={layers} game={args.game_id or "global"} -> {output_dir}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
