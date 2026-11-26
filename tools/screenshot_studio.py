#!/usr/bin/env python3
"""Generate a release-ready Rt:UI screenshot pack from the real LÖVE frontend.

The existing tools/capture-ui.sh performs actual rendering and navigation.
This wrapper captures all registered screens (or a selected set), validates
PNG signatures and dimensions, and writes gallery/release-note snippets plus
a provenance manifest. It uses only the Python standard library.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import struct
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from urllib.parse import quote

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / "tools" / "capture-ui.sh"
CORE_VERSION_FILE = ROOT / "dolphin-rtcore-muos" / "VERSION"
UI_VERSION_FILE = ROOT / "dolphin-rtcore-muos" / "app" / "Dolphin RtUI" / "version.lua"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
FEATURED = ("library", "triage", "settings", "compat_list", "diagnostics")
LABELS = {
    "boot": "Boot / Startup",
    "library": "Game Library",
    "mods": "Mod Vault",
    "cheatdb": "Cheat Database",
    "game": "Game Details",
    "cheats": "Cheats",
    "hotkeys": "Hotkeys",
    "settings": "Settings",
    "rt_editor": "Rt:Core Editor",
    "folders": "ROM Folders",
    "about": "About Rt:UI",
    "diagnostics": "Diagnostics",
    "controller_map": "Controller Mapping",
    "controller_profiles": "Controller Profiles",
    "triage": "Environment Triage",
    "rt_profiles": "Rt:Core Profiles",
    "gameset_browser": "GameSettings Browser",
    "keymap": "Keymap",
    "gameset_explorer": "GameSettings Explorer",
    "compat_list": "Compatibility List",
    "stream_library": "Rt:Stream Library",
    "stream_settings": "Rt:Stream Settings",
}


def run(command: list[str], *, env: dict[str, str] | None = None) -> str:
    result = subprocess.run(command, cwd=ROOT, env=env, check=False, capture_output=True, text=True)
    if result.returncode:
        detail = (result.stderr or result.stdout).strip()
        raise RuntimeError(f"Command failed ({result.returncode}): {' '.join(command)}\n{detail}")
    return result.stdout.strip()


def discover_screens() -> list[str]:
    if not CAPTURE.is_file():
        raise RuntimeError(f"Screenshot engine not found: {CAPTURE}")
    names = run(["bash", str(CAPTURE), "--list"]).splitlines()
    names = [name.strip() for name in names if name.strip()]
    if not names:
        raise RuntimeError("The frontend has no registered screens to capture.")
    return names


def parse_resolutions(value: str) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    seen: set[tuple[int, int]] = set()
    for raw in value.split(","):
        item = raw.strip().lower()
        match = re.fullmatch(r"(\d{3,4})x(\d{3,4})", item)
        if not match:
            raise ValueError(f"Invalid resolution '{raw}'. Use WIDTHxHEIGHT, e.g. 640x480.")
        width, height = map(int, match.groups())
        if not (320 <= width <= 3840 and 240 <= height <= 2160):
            raise ValueError(f"Resolution outside supported bounds: {item}")
        size = (width, height)
        if size not in seen:
            result.append(size)
            seen.add(size)
    if not result:
        raise ValueError("At least one resolution is required.")
    return result


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as stream:
        header = stream.read(24)
    if len(header) < 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ValueError(f"Not a valid PNG (missing signature/IHDR): {path}")
    return struct.unpack(">II", header[16:24])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_name(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]", "_", value)


def human_label(screen: str) -> str:
    return LABELS.get(screen, screen.replace("_", " ").title())


def read_versions() -> tuple[str, str, str]:
    core = CORE_VERSION_FILE.read_text(encoding="utf-8").strip() if CORE_VERSION_FILE.is_file() else "unknown"
    ui = "unknown"
    codename = ""
    if UI_VERSION_FILE.is_file():
        source = UI_VERSION_FILE.read_text(encoding="utf-8")
        version_match = re.search(r'\bstring\s*=\s*["\']([^"\']+)', source)
        codename_match = re.search(r'\bcodename\s*=\s*["\']([^"\']+)', source)
        if version_match:
            ui = version_match.group(1)
        if codename_match:
            codename = codename_match.group(1)
    return core, ui, codename


def git_value(*args: str) -> str | None:
    try:
        value = subprocess.run(["git", *args], cwd=ROOT, check=False, capture_output=True, text=True)
        return value.stdout.strip() if value.returncode == 0 and value.stdout.strip() else None
    except OSError:
        return None


def repository_slug() -> str | None:
    remote = git_value("remote", "get-url", "origin")
    if not remote:
        return None
    match = re.search(r"github\.com[:/]([^/]+/[^/.]+?)(?:\.git)?$", remote)
    return match.group(1) if match else None


def relative_to_root(path: Path) -> str | None:
    try:
        return path.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return None


def build_gallery(core: str, ui: str, codename: str, screens: list[str],
                  resolutions: list[tuple[int, int]], generated: str,
                  commit: str | None, capture_host: str) -> str:
    lines = [
        f"# Rt:UI {ui} {codename} — Screenshot Gallery".rstrip(),
        "",
        f"**Dolphin Rt:Core:** {core}  ",
        f"**Generated:** {generated}  ",
        f"**Source commit:** `{commit or 'unknown'}`  ",
        f"**Capture:** LÖVE frontend on {capture_host}; rendered UI evidence, not a device photograph or hardware-certification claim.",
        "",
        "> Review every image before publishing. Remove captures containing personal ROM names, paths, usernames, network details or other private data.",
        "",
        "## Screens",
        "",
        "| Screen | Captured sizes |",
        "|---|---|",
    ]
    sizes = ", ".join(f"{w}×{h}" for w, h in resolutions)
    for screen in screens:
        lines.append(f"| {human_label(screen)} (`{screen}`) | {sizes} |")
    for width, height in resolutions:
        lines.extend(["", f"## {width}×{height}", ""])
        for screen in screens:
            rel = f"{width}x{height}/{safe_name(screen)}.png"
            lines.extend([
                f"### {human_label(screen)}",
                "",
                f"![{human_label(screen)} — Rt:UI {ui}]({rel})",
                "",
            ])
    return "\n".join(lines).rstrip() + "\n"


def build_readme_snippet(gallery_url: str, raw_base: str | None, records: list[dict]) -> str:
    lines = [
        "## Rt:UI — Interface Gallery",
        "",
        f"Explore Rt:UI in the [complete screenshot gallery]({gallery_url}).",
        "",
    ]
    available = {record["screen"] for record in records if record["resolution"] == "640x480"}
    featured = [name for name in FEATURED if name in available]
    if raw_base and featured:
        lines.append("| " + " | ".join(human_label(name) for name in featured) + " |")
        lines.append("|" + "|".join("---" for _ in featured) + "|")
        lines.append("| " + " | ".join(
            f'<img src="{raw_base}/640x480/{safe_name(name)}.png" alt="{human_label(name)}" width="220">'
            for name in featured
        ) + " |")
        lines.append("")
    else:
        lines.extend(["The generated GALLERY.md contains the full screen collection and all captured resolutions.", ""])
    return "\n".join(lines).rstrip() + "\n"


def build_release_snippet(gallery_url: str, raw_base: str | None, records: list[dict]) -> str:
    lines = [
        "## Interface tour",
        "",
        f"Explore the [Rt:UI screenshot gallery]({gallery_url}) for the complete interface tour.",
        "",
    ]
    available = {record["screen"] for record in records if record["resolution"] == "640x480"}
    featured = [name for name in ("library", "triage", "settings") if name in available]
    if raw_base:
        for screen in featured:
            lines.extend([
                f"### {human_label(screen)}",
                "",
                f"![{human_label(screen)} — Rt:UI]({raw_base}/640x480/{safe_name(screen)}.png)",
                "",
            ])
    return "\n".join(lines).rstrip() + "\n"


def verify_pack(out_dir: Path) -> int:
    """Verify a completed screenshot pack independently of the capture process."""
    if out_dir.is_symlink() or not out_dir.is_dir():
        raise ValueError("Screenshot pack directory is missing or is a symlink")
    manifest_path = out_dir / "manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError("Screenshot pack manifest is missing or unsafe")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"Cannot read screenshot manifest: {exc}") from exc
    if not isinstance(manifest, dict) or manifest.get("schema") != 1:
        raise ValueError("Unsupported screenshot manifest schema")
    screens = manifest.get("screens")
    resolutions = manifest.get("resolutions")
    records = manifest.get("images")
    if (not isinstance(screens, list) or not screens or
            not isinstance(resolutions, list) or not resolutions or
            not isinstance(records, list)):
        raise ValueError("Screenshot manifest has an incomplete capture matrix")
    if len(set(screens)) != len(screens) or len(set(resolutions)) != len(resolutions):
        raise ValueError("Screenshot manifest contains duplicate screens or resolutions")
    expected = {
        f"{resolution}/{safe_name(screen)}.png"
        for screen in screens for resolution in resolutions
    }
    if len(expected) != len(screens) * len(resolutions) or len(records) != len(expected):
        raise ValueError("Screenshot manifest image count does not match the capture matrix")
    seen = set()
    for record in records:
        if not isinstance(record, dict):
            raise ValueError("Screenshot image record must be an object")
        relative = record.get("path")
        if not isinstance(relative, str) or "\\\\" in relative or "\\x00" in relative:
            raise ValueError(f"Unsafe screenshot path: {relative!r}")
        path = PurePosixPath(relative)
        if path.is_absolute() or any(part in ("", ".", "..") for part in path.parts):
            raise ValueError(f"Unsafe screenshot path: {relative!r}")
        normalized = path.as_posix()
        if normalized not in expected or normalized in seen:
            raise ValueError(f"Unexpected or duplicate screenshot path: {normalized}")
        seen.add(normalized)
        candidate = out_dir.joinpath(*path.parts)
        current = out_dir
        for part in path.parts:
            current = current / part
            if current.is_symlink():
                raise ValueError(f"Screenshot path contains a symlink: {normalized}")
        if not candidate.is_file():
            raise ValueError(f"Screenshot is missing: {normalized}")
        resolution = record.get("resolution")
        try:
            expected_width, expected_height = map(int, resolution.split("x"))
        except (AttributeError, ValueError):
            raise ValueError(f"Invalid screenshot resolution in record: {normalized}")
        if resolution not in resolutions or normalized != f"{resolution}/{safe_name(record.get('screen', ''))}.png":
            raise ValueError(f"Screenshot record identity mismatch: {normalized}")
        actual = png_dimensions(candidate)
        if actual != (expected_width, expected_height):
            raise ValueError(f"Screenshot dimensions mismatch: {normalized}: {actual}")
        if record.get("width") != expected_width or record.get("height") != expected_height:
            raise ValueError(f"Manifest dimensions mismatch: {normalized}")
        if candidate.stat().st_size != record.get("bytes") or sha256(candidate) != record.get("sha256"):
            raise ValueError(f"Screenshot fingerprint mismatch: {normalized}")
    if seen != expected:
        raise ValueError("Screenshot manifest is missing one or more screen/resolution combinations")
    for name in ("GALLERY.md", "README_GALLERY_SNIPPET.md", "RELEASE_NOTES_SNIPPET.md"):
        path = out_dir / name
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"Screenshot pack companion file is missing or unsafe: {name}")
    return len(records)


def previous_generated_paths(out_dir: Path) -> list[Path]:
    manifest_path = out_dir / "manifest.json"
    if not manifest_path.is_file():
        return []
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    paths = []
    for item in manifest.get("images", []):
        rel = item.get("path")
        if not isinstance(rel, str):
            continue
        candidate = (out_dir / rel).resolve()
        try:
            candidate.relative_to(out_dir.resolve())
        except ValueError:
            continue
        paths.append(candidate)
    return paths


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Capture Rt:UI screens and generate a gallery, README block and release-note snippet."
    )
    parser.add_argument("--list", action="store_true", help="List registered screen IDs and exit (no LÖVE needed).")
    parser.add_argument("--screens", help="Comma-separated screen IDs. Default: every registered screen.")
    parser.add_argument("--resolutions", default="640x480,720x480,720x720",
                        help="Comma-separated sizes (default: 640x480,720x480,720x720).")
    parser.add_argument("--out-dir", help="Output directory. Default: screenshots/releases/<auto-detected version>.")
    parser.add_argument("--delay", type=float, default=1.0, help="Seconds to let each screen settle before capture (default: 1.0).")
    parser.add_argument("--pads", default="", help='Logical gamepad presses before every capture, e.g. "R1,A".')
    parser.add_argument("--ref", help="Git ref for GitHub image URLs (default: current branch).")
    parser.add_argument("--image-base-url", help="Override the raw-image base URL in generated snippets.")
    parser.add_argument("--dry-run", action="store_true", help="Show the capture plan without launching LÖVE or writing files.")
    parser.add_argument("--verify-pack", action="store_true", help="Verify an existing screenshot pack at --out-dir without capturing.")
    args = parser.parse_args(argv)

    try:
        if args.verify_pack:
            if not args.out_dir:
                raise ValueError("--verify-pack requires --out-dir")
            verify_dir = Path(args.out_dir).expanduser()
            if not verify_dir.is_absolute():
                verify_dir = ROOT / verify_dir
            count = verify_pack(verify_dir)
            print(f"Screenshot pack verified: {count} images")
            return 0
        registered = discover_screens()
        if args.list:
            print("\n".join(registered))
            return 0
        if args.delay < 0:
            raise ValueError("--delay must be non-negative")
        resolutions = parse_resolutions(args.resolutions)
        if args.screens:
            screens = [item.strip() for item in args.screens.split(",") if item.strip()]
            unknown = [name for name in screens if name not in registered]
            if unknown:
                raise ValueError("Unknown screen ID(s): " + ", ".join(unknown) + ". Use --list to see registered screens.")
            screens = list(dict.fromkeys(screens))
        else:
            screens = registered
        if not screens:
            raise ValueError("No screens selected.")

        core, ui, codename = read_versions()
        slug = re.sub(r"[^a-zA-Z0-9.-]+", "-", codename.lower()).strip("-") or "frontend"
        default_name = f"v{core}-rtui-{ui}-{slug}"
        out_dir = Path(args.out_dir).expanduser() if args.out_dir else ROOT / "screenshots" / "releases" / default_name
        if not out_dir.is_absolute():
            out_dir = ROOT / out_dir
        out_dir = out_dir.resolve()

        capture_host = "existing X11 display" if os.environ.get("DISPLAY") else "Xvfb (headless virtual display)"
        commit = git_value("rev-parse", "HEAD")
        ref = args.ref or git_value("branch", "--show-current") or "main"
        repo = repository_slug()
        out_rel = relative_to_root(out_dir)
        raw_base = args.image_base_url.rstrip("/") if args.image_base_url else None
        if not raw_base and repo and out_rel:
            raw_base = f"https://raw.githubusercontent.com/{repo}/{quote(ref, safe='/-._')}/{quote(out_rel, safe='/')}"
        gallery_url = (
            f"https://github.com/{repo}/blob/{quote(ref, safe='/-._')}/{quote(out_rel + '/GALLERY.md', safe='/')}"
            if repo and out_rel else "GALLERY.md"
        )

        plan = {
            "screens": screens,
            "resolutions": [f"{w}x{h}" for w, h in resolutions],
            "output": str(out_dir),
            "total_images": len(screens) * len(resolutions),
            "capture_host": capture_host,
        }
        print(json.dumps(plan, indent=2))
        if args.dry_run:
            return 0

        out_dir.mkdir(parents=True, exist_ok=True)
        # Remove only prior generated images listed by our manifest. Never
        # recursively clean an output directory or unrelated user files.
        for old_file in previous_generated_paths(out_dir):
            try:
                old_file.unlink(missing_ok=True)
            except OSError as exc:
                raise RuntimeError(f"Cannot remove previous generated image {old_file}: {exc}") from exc

        records: list[dict] = []
        for width, height in resolutions:
            resolution = f"{width}x{height}"
            resolution_dir = out_dir / resolution
            resolution_dir.mkdir(parents=True, exist_ok=True)
            env = os.environ.copy()
            env["DOLPHINUI_RES"] = resolution
            command = [
                "bash", str(CAPTURE), "--screens", ",".join(screens),
                "--delay", str(args.delay), "--out-dir", str(resolution_dir),
            ]
            if args.pads:
                command.extend(["--pads", args.pads])
            print(f"\n== Capture {resolution}: {len(screens)} screens ==", flush=True)
            run(command, env=env)
            for screen in screens:
                image_path = resolution_dir / f"{safe_name(screen)}.png"
                if not image_path.is_file() or image_path.stat().st_size <= 24:
                    raise RuntimeError(f"Capture missing or empty: {image_path}")
                actual = png_dimensions(image_path)
                if actual != (width, height):
                    raise RuntimeError(f"Wrong image dimensions for {image_path}: {actual}, expected {(width, height)}")
                records.append({
                    "screen": screen,
                    "label": human_label(screen),
                    "resolution": resolution,
                    "path": image_path.relative_to(out_dir).as_posix(),
                    "bytes": image_path.stat().st_size,
                    "sha256": sha256(image_path),
                    "width": width,
                    "height": height,
                })
                print(f"  OK {image_path.relative_to(out_dir)}")

        generated = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        manifest = {
            "schema": 1,
            "generated_utc": generated,
            "project": "Dolphin Rt:Core",
            "core_version": core,
            "rtui_version": ui,
            "codename": codename,
            "source_commit": commit,
            "source_ref": ref,
            "capture_host": capture_host,
            "host_platform": platform.platform(),
            "screens": screens,
            "resolutions": [f"{w}x{h}" for w, h in resolutions],
            "images": records,
        }
        (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        (out_dir / "GALLERY.md").write_text(
            build_gallery(core, ui, codename, screens, resolutions, generated, commit, capture_host),
            encoding="utf-8",
        )
        (out_dir / "README_GALLERY_SNIPPET.md").write_text(
            build_readme_snippet(gallery_url, raw_base, records), encoding="utf-8"
        )
        (out_dir / "RELEASE_NOTES_SNIPPET.md").write_text(
            build_release_snippet(gallery_url, raw_base, records), encoding="utf-8"
        )
        print(f"\nDone: {len(records)} PNGs validated.")
        print(f"Gallery: {out_dir / 'GALLERY.md'}")
        print(f"README block: {out_dir / 'README_GALLERY_SNIPPET.md'}")
        print(f"Release-note block: {out_dir / 'RELEASE_NOTES_SNIPPET.md'}")
        print("Review screenshots for personal data and visual glitches before publishing.")
        return 0
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"screenshot-studio: ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
