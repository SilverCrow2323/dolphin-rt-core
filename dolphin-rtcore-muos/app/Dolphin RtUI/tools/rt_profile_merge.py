#!/usr/bin/env python3
"""Layer Rt:Core profiles and the selected per-game GameSettings into runtime INIs.

Canonical sources:
  workshop/rtcoreprofile/Default/
  workshop/rtcoreprofile/<family>[/<tier>]/
  workshop/gamesettings/<GAMEID>/rtgameset_data.ini -> ActiveConfig

The generated Config/ files are disposable runtime projections. Source profiles
and GameSettings are never modified by this tool.
"""

import argparse
import re
import sys
from pathlib import Path

INI_SECTION_RE = re.compile(r'^\s*\[([^\]]+)\]\s*$')
INI_KV_RE = re.compile(r'^\s*([^=;#][^=]*?)\s*=\s*(.*?)\s*$')

GS_SECTION_MAP = {
    'Core': ('Dolphin.ini', 'Core'),
    'DSP': ('Dolphin.ini', 'DSP'),
    'Interface': ('Dolphin.ini', 'Interface'),
    'General': ('Dolphin.ini', 'General'),
    'Network': ('Dolphin.ini', 'Network'),
    'Video_Settings': ('GFX.ini', 'Settings'),
    'Video_Enhancements': ('GFX.ini', 'Enhancements'),
    'Video_Hacks': ('GFX.ini', 'Hacks'),
    'Video_Hardware': ('GFX.ini', 'Hardware'),
    'Settings': ('GFX.ini', 'Settings'),
    'Enhancements': ('GFX.ini', 'Enhancements'),
    'Hacks': ('GFX.ini', 'Hacks'),
    'Hardware': ('GFX.ini', 'Hardware'),
}


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


def split_gamesettings(text):
    order, sections = parse_ini(text)
    dolphin_lines, gfx_lines, unknown = [], [], []
    for section in order:
        target = GS_SECTION_MAP.get(section)
        if not target:
            unknown.append(section)
            continue
        target_file, target_section = target
        bucket = dolphin_lines if target_file == 'Dolphin.ini' else gfx_lines
        bucket.append(f'[{target_section}]')
        for key, value in sections[section]:
            bucket.append(f'{key} = {value}')
        bucket.append('')
    return '\n'.join(dolphin_lines), '\n'.join(gfx_lines), unknown


def _safe_ini_filename(value):
    if not value or Path(value).name != value or value in {'.', '..'} or '..' in value:
        return False
    return value.lower().endswith('.ini')


def find_gameset_file(workshop_dir, game_id):
    if not workshop_dir or not game_id:
        return None

    workshop_dir = Path(workshop_dir)
    base = workshop_dir / 'gamesettings' / game_id
    if not base.is_dir():
        return None

    metadata = base / 'rtgameset_data.ini'
    if not metadata.is_file():
        return None

    active = ''
    in_game_settings = False
    for line in metadata.read_text(encoding='utf-8', errors='replace').splitlines():
        section = INI_SECTION_RE.match(line)
        if section:
            in_game_settings = section.group(1).strip() == 'GameSettings'
            continue
        if not in_game_settings:
            continue
        item = re.match(r'^\s*ActiveConfig\s*=\s*(.*?)\s*$', line)
        if item:
            active = item.group(1).strip()
            break

    if not _safe_ini_filename(active):
        return None

    candidate = base / active
    try:
        if candidate.is_file() and candidate.resolve().parent == base.resolve():
            return candidate
    except OSError:
        return None
    return None


def read_requires_base(profile_dir):
    """Read [Runtime] RequiresBase from a profile's metadata, if present."""
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

        # RtPrime/std inherits RtPrime before applying the tier patch.
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
    """Create Dolphin.ini/GFX.ini state from Default and inherited overlays."""
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
    parser.add_argument('--game-id', default='')
    parser.add_argument('--gs-file', default='')
    parser.add_argument('--workshop', default='')
    args = parser.parse_args()

    default_dir = Path(args.default_dir)
    profile_dir = Path(args.profile_dir)
    output_dir = Path(args.out_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    state = merge_profile_layers(default_dir, profile_dir)

    gameset_file = None
    if args.gs_file and args.workshop and args.game_id:
        explicit = Path(args.gs_file)
        expected_dir = (Path(args.workshop) / 'gamesettings' / args.game_id).resolve()
        try:
            if (
                explicit.is_file()
                and explicit.suffix.lower() == '.ini'
                and explicit.resolve().parent == expected_dir
            ):
                gameset_file = explicit
        except OSError:
            gameset_file = None

    if gameset_file is None and args.workshop and args.game_id:
        gameset_file = find_gameset_file(Path(args.workshop), args.game_id)

    if gameset_file:
        dolphin_text, gfx_text, unknown = split_gamesettings(
            gameset_file.read_text(encoding='utf-8', errors='replace')
        )
        if dolphin_text.strip():
            merge_into(state['Dolphin.ini'][0], state['Dolphin.ini'][1], dolphin_text)
        if gfx_text.strip():
            merge_into(state['GFX.ini'][0], state['GFX.ini'][1], gfx_text)
        if unknown:
            print(f'warning: unknown GameSettings sections skipped: {unknown}', file=sys.stderr)

    for filename in ('Dolphin.ini', 'GFX.ini'):
        write_ini(output_dir / filename, state[filename][0], state[filename][1])

    layers = resolve_profile_layers(default_dir, profile_dir)
    print(f'merged: default={default_dir} layers={layers} gs={gameset_file} -> {output_dir}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
