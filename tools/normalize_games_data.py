#!/usr/bin/env python3
"""Canonicalize the shared Dolphin Rt:Core compatibility database.

The bundled Rt:UI JSON is the editable source; data/games_data.json is the
runtime download endpoint used by the handheld boot updater. Both copies are
required and must remain byte-identical.

Run with --check in CI. Use --write only when intentionally migrating the
tracked source data. The migration is idempotent and preserves every
individual report while grouping by Game ID + system + region.
"""
from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA_PATH = ROOT / "dolphin-rtcore-muos" / "app" / "Dolphin RtUI" / "data" / "games_data.json"
RUNTIME_PATH = ROOT / "data" / "games_data.json"

DEVICE_ALIASES = {
    "unknown device": "Unspecified",
    "unknown": "Unspecified",
    "anbernic rg35xx h": "Anbernic RG35XX H",
    "rg35xx h": "Anbernic RG35XX H",
    "rg 35xx h": "Anbernic RG35XX H",
    "rg35xxh": "Anbernic RG35XX H",
    "rg-34xx sp": "Anbernic RG34XX SP",
    "rg34xx sp": "Anbernic RG34XX SP",
}
MUOS_ALIASES = {
    "funky jacaranda": "muOS 2601.1 Jacaranda",
    "funky jakaranda": "muOS 2601.1 Jacaranda",
    "jacaranda": "muOS Jacaranda (version not specified)",
    "2601.1 funky jacaranda": "muOS 2601.1 Jacaranda",
    "2601.0 jacaranda": "muOS 2601.0 Jacaranda",
    "2508.3 golden goose": "muOS 2508.3 Golden Goose",
}
RTCORE_ALIASES = {
    "unknown": "Unspecified",
    "v10.6 (pre release)": "v10.6 (prerelease)",
    "v11.0.00 (prerelease)": "v11.0.0 (prerelease)",
    "v11.0.0 'frontendone' (prerelease)": "v11.0.0 (FrontendONE prerelease)",
    "v11.0.00-dev": "v11.0.0 (development)",
    "v11.0.0-dev": "v11.0.0 (development)",
    "v11.0.0 (current)": "v11.0.0",
    "v11.5.00-ii 'bash arsenal'": "v11.5.00-II (Bash Arsenal)",
    "v11.5.00 'comfort zone' (prerelease)": "v11.5.00 (Comfort Zone prerelease)",
    "v11.5.00-iii frontendone": "v11.5.00-III (FrontendONE)",
}
PROFILE_ALIASES = {
    "standard": "Standard",
    "speedhack / default": "SpeedHack + Default (multiple profiles)",
    "speedhack / default (both tested)": "SpeedHack + Default (both tested)",
    "all profiles (tested multiple)": "All profiles (multiple tested)",
    "black screen fix, compatibility, default": "Black Screen Fix + Compatibility + Default",
    "speedhacks, performance, ultra": "SpeedHack + Performance + Ultra",
}
REGION_ALIASES = {
    "ntsc / usa": "NTSC",
    "ntsc / jpn": "NTSC-J",
    "jpn": "NTSC-J",
}
SYSTEM_ALIASES = {
    "gc": "GC",
    "gamecube": "GC",
    "game cube": "GC",
    "nintendo gamecube": "GC",
    "wii": "Wii",
    "nintendo wii": "Wii",
}
TITLE_ALIASES = {
    "need for speed - most wanted": "Need for Speed: Most Wanted",
}

CATALOGS = {
    "devices": [
        "Anbernic RG35XX H",
        "Anbernic RG34XX SP",
        "Anbernic RG40XX H",
        "Anbernic RG CubeXX",
        "RG4xxxx",
        "Unspecified",
    ],
    "muos_versions": [
        "muOS 2606.0 Andromeda",
        "muOS Jacaranda (version not specified)",
        "muOS 2601.1 Jacaranda",
        "muOS 2601.0 Jacaranda",
        "muOS 2508.3 Golden Goose",
        "muOS 2508.2 Silly Goose",
        "muOS 2508.1 Canada Goose",
        "muOS 2508.0 Goose",
        "muOS 2502.0 Pixie",
    ],
    "rtcore_versions": [
        "12.0.0 Kanzentai",
        "v11.5.00-III (FrontendONE)",
        "v11.5.00-II (Bash Arsenal)",
        "v11.5.00 (Comfort Zone prerelease)",
        "v11.0.0",
        "v11.0.0 (prerelease)",
        "v11.0.0 (FrontendONE prerelease)",
        "v11.0.0 (development)",
        "v10.6 (prerelease)",
        "v10.5.300",
        "v10.5.3",
        "v10.5-124",
        "Legacy",
        "Unspecified",
    ],
    "core_profiles": [
        "Default",
        "Performance",
        "Compatibility",
        "SpeedHack",
        "Black Screen Fix",
        "Ultra",
        "SpeedUp 1",
        "SpeedUp 2",
        "All profiles",
        "All profiles (multiple tested)",
        "SpeedHack + Default (multiple profiles)",
        "SpeedHack + Default (both tested)",
        "Black Screen Fix + Compatibility + Default",
        "SpeedHack + Performance + Ultra",
        "Various profiles",
    ],
}


def canonical(value: Any, aliases: dict[str, str]) -> str:
    text = str(value or "").strip()
    return aliases.get(text.casefold(), text)


def normalize_document(document: dict[str, Any]) -> dict[str, Any]:
    if not isinstance(document.get("games"), list):
        raise ValueError("games_data.json must contain a games array")

    grouped: OrderedDict[tuple[str, str, str], dict[str, Any]] = OrderedDict()
    for old_group in document["games"]:
        base = old_group.get("game_info") or {}
        entries = old_group.get("entries") or []
        if not entries:
            info = dict(base)
            identity = normalize_game_info(info)
            key = (identity["game_id"], identity["system"], identity["region"])
            grouped.setdefault(key, {**{k: v for k, v in old_group.items() if k not in {"game_info", "entries"}},
                                     "game_info": identity, "entries": []})
            continue

        for report in entries:
            info = {**base, **(report.get("game_info") or {})}
            identity = normalize_game_info(info)
            key = (identity["game_id"], identity["system"], identity["region"])
            if key not in grouped:
                extras = {k: v for k, v in old_group.items() if k not in {"game_info", "entries"}}
                grouped[key] = {**extras, "game_info": identity, "entries": []}
            target = grouped[key]
            # Preserve extra per-report game metadata, but make identity fields exact.
            report_info = dict(report.get("game_info") or {})
            report_info.update(target["game_info"])
            report["game_info"] = report_info

            details = report.setdefault("test_details", {})
            details["rtcore_version"] = canonical(details.get("rtcore_version"), RTCORE_ALIASES)
            details["core_profile"] = canonical(details.get("core_profile"), PROFILE_ALIASES)

            environment = report.setdefault("test_environment", {})
            environment["device"] = canonical(environment.get("device"), DEVICE_ALIASES)
            # Empty firmware values mean "not recorded"; never infer a release.
            environment["muos_version"] = canonical(environment.get("muos_version"), MUOS_ALIASES)
            target["entries"].append(report)

    document["schema_version"] = 2
    document["catalogs"] = CATALOGS
    document["games"] = list(grouped.values())
    return document


def normalize_game_info(info: dict[str, Any]) -> dict[str, Any]:
    result = dict(info)
    result["game_id"] = str(result.get("game_id") or "").strip().upper()
    result["system"] = canonical(result.get("system"), SYSTEM_ALIASES)
    result["region"] = canonical(result.get("region"), REGION_ALIASES)
    result["game"] = canonical(result.get("game"), TITLE_ALIASES)
    return result


def render(document: dict[str, Any]) -> str:
    return json.dumps(document, ensure_ascii=False, indent=2) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="fail if the tracked data needs normalization (default)")
    mode.add_argument("--write", action="store_true", help="write the normalized data to the source file")
    args = parser.parse_args()

    original = DATA_PATH.read_text(encoding="utf-8")
    runtime_original = RUNTIME_PATH.read_text(encoding="utf-8")
    document = json.loads(original)
    normalized = render(normalize_document(document))
    if args.write:
        DATA_PATH.write_text(normalized, encoding="utf-8")
        RUNTIME_PATH.write_text(normalized, encoding="utf-8")
        print("Normalized both canonical and runtime-served games_data.json copies")
        return 0
    errors = []
    if original != normalized:
        errors.append("canonical Rt:UI data is not normalized")
    if runtime_original != normalized:
        errors.append("runtime-served data/games_data.json is stale or differs from Rt:UI data")
    if errors:
        print("; ".join(errors) + "; run: python3 tools/normalize_games_data.py --write")
        return 1
    reports = sum(len(group.get("entries", [])) for group in document["games"])
    print(f"Canonical compatibility data: {len(document['games'])} games / {reports} reports (both copies match)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
