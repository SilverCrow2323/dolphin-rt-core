#!/usr/bin/env python3
"""rt_profile_merge.py - runtime merge helper for DolphinRtFinalCut launch.

Merges Default <- Profile <- GameSettings into a throw-away Config dir.
Source files are never modified.

GameSettings section names are remapped:
  [Video_Settings]     -> GFX.ini [Settings]
  [Video_Enhancements] -> GFX.ini [Enhancements]
  [Video_Hacks]        -> GFX.ini [Hacks]
  [Video_Hardware]     -> GFX.ini [Hardware]
  [Core] [DSP] [Interface] stay as-is in Dolphin.ini
"""

import argparse, re, sys
from pathlib import Path

INI_SECTION_RE = re.compile(r'^\s*\[([^\]]+)\]\s*$')
INI_KV_RE      = re.compile(r'^\s*([^=;#][^=]*?)\s*=\s*(.*?)\s*$')

def parse_ini(text):
    order, sections, cur = [], {}, None
    for raw in text.splitlines():
        m = INI_SECTION_RE.match(raw)
        if m:
            cur = m.group(1).strip()
            if cur not in sections:
                order.append(cur); sections[cur] = []
            continue
        m = INI_KV_RE.match(raw)
        if m and cur is not None:
            sections[cur].append((m.group(1).strip(), m.group(2)))
    return order, sections

def flatten(order, sections):
    flat = {}
    for sec in order:
        for k, v in sections[sec]:
            flat[(sec, k)] = v
    return flat

def merge_into(order, flat, text):
    o_order, o_sections = parse_ini(text)
    for sec in o_order:
        if sec not in order:
            order.append(sec)
        for k, v in o_sections[sec]:
            flat[(sec, k)] = v

def write_ini(path, order, flat):
    sec_keys = {sec: [] for sec in order}
    seen = set()
    for sec in order:
        for (s, k), v in flat.items():
            if s == sec and (s, k) not in seen:
                sec_keys[sec].append((k, v)); seen.add((s, k))
    out = []
    for sec in order:
        if not sec_keys[sec]: continue
        out.append(f'[{sec}]')
        for k, v in sec_keys[sec]:
            out.append(f'{k} = {v}')
        out.append('')
    path.write_text('\n'.join(out), encoding='utf-8')

GS_SECTION_MAP = {
    'Core':               ('Dolphin.ini', 'Core'),
    'DSP':                ('Dolphin.ini', 'DSP'),
    'Interface':          ('Dolphin.ini', 'Interface'),
    'General':            ('Dolphin.ini', 'General'),
    'Network':            ('Dolphin.ini', 'Network'),
    'Video_Settings':     ('GFX.ini', 'Settings'),
    'Video_Enhancements': ('GFX.ini', 'Enhancements'),
    'Video_Hacks':        ('GFX.ini', 'Hacks'),
    'Video_Hardware':     ('GFX.ini', 'Hardware'),
    'Settings':           ('GFX.ini', 'Settings'),
    'Enhancements':       ('GFX.ini', 'Enhancements'),
    'Hacks':              ('GFX.ini', 'Hacks'),
    'Hardware':           ('GFX.ini', 'Hardware'),
}

def split_gamesettings(text):
    order, sections = parse_ini(text)
    dol, gfx, unknown = [], [], []
    for sec in order:
        target = GS_SECTION_MAP.get(sec)
        if not target:
            unknown.append(sec); continue
        tgt_file, tgt_sec = target
        bucket = dol if tgt_file == 'Dolphin.ini' else gfx
        bucket.append(f'[{tgt_sec}]')
        for k, v in sections[sec]:
            bucket.append(f'{k} = {v}')
        bucket.append('')
    return '\n'.join(dol), '\n'.join(gfx), unknown

def find_gameset_file(workshop_dir, game_id):
    if not workshop_dir or not game_id:
        return None
    base = workshop_dir / 'gamesettings' / game_id
    if not base.is_dir():
        gs_root = workshop_dir / 'gamesettings'
        if gs_root.is_dir():
            for sub in gs_root.iterdir():
                cand = sub / game_id
                if cand.is_dir():
                    base = cand; break
    if not base.is_dir():
        return None
    meta = base / 'rtgameset_data.ini'
    active = ''
    if meta.is_file():
        in_section = False
        for line in meta.read_text(encoding='utf-8', errors='replace').splitlines():
            section = INI_SECTION_RE.match(line)
            if section:
                in_section = section.group(1).strip() == 'GameSettings'
                continue
            if not in_section:
                continue
            m = re.match(r'^\s*ActiveConfig\s*=\s*(.*?)\s*


def read_requires_base(profile_dir):
    """Return [Runtime] RequiresBase from a profile's metadata, if present."""
    meta = Path(profile_dir) / 'rtprofile_data.ini'
    if not meta.is_file():
        return ''
    section = ''
    for raw in meta.read_text(encoding='utf-8', errors='replace').splitlines():
        match = INI_SECTION_RE.match(raw)
        if match:
            section = match.group(1).strip()
            continue
        if section != 'Runtime':
            continue
        match = INI_KV_RE.match(raw)
        if match and match.group(1).strip() == 'RequiresBase':
            return match.group(2).strip()
    return ''


def resolve_profile_layers(default_dir, profile_dir):
    """Return parent/family/profile overlays in application order.

    Default is always the immutable base. A nested tier (RtPrime/std) first
    receives its family folder (RtPrime), then its own tier patch. Metadata
    RequiresBase can add further ancestors without cycles.
    """
    default_path = Path(default_dir).resolve()
    profiles_root = default_path.parent
    layers = []
    seen = set()

    def add(path):
        path = Path(path)
        if not path.is_dir():
            return
        resolved = path.resolve()
        if resolved == default_path or resolved in seen:
            return
        seen.add(resolved)

        try:
            relative = resolved.relative_to(profiles_root)
        except ValueError:
            relative = None
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
    """Build Dolphin.ini/GFX.ini state from Default plus profile ancestry."""
    state = {}
    default_path = Path(default_dir)
    for fname in ('Dolphin.ini', 'GFX.ini'):
        source = default_path / fname
        if source.is_file():
            order, sections = parse_ini(source.read_text(encoding='utf-8', errors='replace'))
            state[fname] = (order, flatten(order, sections))
        else:
            state[fname] = ([], {})

    for layer_dir in resolve_profile_layers(default_path, profile_dir):
        for fname in ('Dolphin.ini', 'GFX.ini'):
            source = layer_dir / fname
            if source.is_file():
                merge_into(state[fname][0], state[fname][1],
                           source.read_text(encoding='utf-8', errors='replace'))
    return state

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--default-dir', required=True)
    ap.add_argument('--profile-dir', required=True)
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--game-id', default='')
    ap.add_argument('--gs-file', default='')
    ap.add_argument('--workshop', default='')
    args = ap.parse_args()

    default_dir, profile_dir = Path(args.default_dir), Path(args.profile_dir)
    out_dir = Path(args.out_dir); out_dir.mkdir(parents=True, exist_ok=True)

    state = merge_profile_layers(default_dir, profile_dir)

    gs_file = None
    if args.gs_file:
        p = Path(args.gs_file)
        if p.is_file() and args.workshop and args.game_id and p.suffix.lower() == '.ini':
            try:
                expected_dir = (Path(args.workshop) / 'gamesettings' / args.game_id).resolve()
                if p.resolve().parent == expected_dir:
                    gs_file = p
            except OSError:
                gs_file = None
    if gs_file is None and args.workshop and args.game_id:
        gs_file = find_gameset_file(Path(args.workshop), args.game_id)
    if gs_file:
        dol_text, gfx_text, unknown = split_gamesettings(
            gs_file.read_text(encoding='utf-8', errors='replace'))
        if dol_text.strip(): merge_into(state['Dolphin.ini'][0], state['Dolphin.ini'][1], dol_text)
        if gfx_text.strip(): merge_into(state['GFX.ini'][0], state['GFX.ini'][1], gfx_text)
        if unknown:
            print(f'warning: unknown GameSettings sections skipped: {unknown}', file=sys.stderr)

    for fname in ('Dolphin.ini', 'GFX.ini'):
        write_ini(out_dir / fname, state[fname][0], state[fname][1])

    layers = resolve_profile_layers(default_dir, profile_dir)
    print(f'merged: default={default_dir} layers={layers} gs={gs_file} -> {out_dir}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
, line)
            if m:
                active = m.group(1).strip()
                break
    # ActiveConfig must be a plain INI filename contained in this GameID folder.
    if not active or Path(active).name != active or active in {'.', '..'} or '..' in active:
        return None
    p = base / active
    try:
        if p.is_file() and p.resolve().parent == base.resolve() and p.suffix.lower() == '.ini':
            return p
    except OSError:
        pass
    return None


def read_requires_base(profile_dir):
    """Return [Runtime] RequiresBase from a profile's metadata, if present."""
    meta = Path(profile_dir) / 'rtprofile_data.ini'
    if not meta.is_file():
        return ''
    section = ''
    for raw in meta.read_text(encoding='utf-8', errors='replace').splitlines():
        match = INI_SECTION_RE.match(raw)
        if match:
            section = match.group(1).strip()
            continue
        if section != 'Runtime':
            continue
        match = INI_KV_RE.match(raw)
        if match and match.group(1).strip() == 'RequiresBase':
            return match.group(2).strip()
    return ''


def resolve_profile_layers(default_dir, profile_dir):
    """Return parent/family/profile overlays in application order.

    Default is always the immutable base. A nested tier (RtPrime/std) first
    receives its family folder (RtPrime), then its own tier patch. Metadata
    RequiresBase can add further ancestors without cycles.
    """
    default_path = Path(default_dir).resolve()
    profiles_root = default_path.parent
    layers = []
    seen = set()

    def add(path):
        path = Path(path)
        if not path.is_dir():
            return
        resolved = path.resolve()
        if resolved == default_path or resolved in seen:
            return
        seen.add(resolved)

        try:
            relative = resolved.relative_to(profiles_root)
        except ValueError:
            relative = None
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
    """Build Dolphin.ini/GFX.ini state from Default plus profile ancestry."""
    state = {}
    default_path = Path(default_dir)
    for fname in ('Dolphin.ini', 'GFX.ini'):
        source = default_path / fname
        if source.is_file():
            order, sections = parse_ini(source.read_text(encoding='utf-8', errors='replace'))
            state[fname] = (order, flatten(order, sections))
        else:
            state[fname] = ([], {})

    for layer_dir in resolve_profile_layers(default_path, profile_dir):
        for fname in ('Dolphin.ini', 'GFX.ini'):
            source = layer_dir / fname
            if source.is_file():
                merge_into(state[fname][0], state[fname][1],
                           source.read_text(encoding='utf-8', errors='replace'))
    return state

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--default-dir', required=True)
    ap.add_argument('--profile-dir', required=True)
    ap.add_argument('--out-dir', required=True)
    ap.add_argument('--game-id', default='')
    ap.add_argument('--gs-file', default='')
    ap.add_argument('--workshop', default='')
    args = ap.parse_args()

    default_dir, profile_dir = Path(args.default_dir), Path(args.profile_dir)
    out_dir = Path(args.out_dir); out_dir.mkdir(parents=True, exist_ok=True)

    state = merge_profile_layers(default_dir, profile_dir)

    gs_file = None
    if args.gs_file:
        p = Path(args.gs_file)
        if p.is_file(): gs_file = p
    if gs_file is None and args.workshop and args.game_id:
        gs_file = find_gameset_file(Path(args.workshop), args.game_id)
    if gs_file:
        dol_text, gfx_text, unknown = split_gamesettings(
            gs_file.read_text(encoding='utf-8', errors='replace'))
        if dol_text.strip(): merge_into(state['Dolphin.ini'][0], state['Dolphin.ini'][1], dol_text)
        if gfx_text.strip(): merge_into(state['GFX.ini'][0], state['GFX.ini'][1], gfx_text)
        if unknown:
            print(f'warning: unknown GameSettings sections skipped: {unknown}', file=sys.stderr)

    for fname in ('Dolphin.ini', 'GFX.ini'):
        write_ini(out_dir / fname, state[fname][0], state[fname][1])

    layers = resolve_profile_layers(default_dir, profile_dir)
    print(f'merged: default={default_dir} layers={layers} gs={gs_file} -> {out_dir}')
    return 0

if __name__ == '__main__':
    sys.exit(main())
