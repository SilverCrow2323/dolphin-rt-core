#!/usr/bin/env python3
"""Build Dolphin's runtime GameSettings/<GameID>.ini projection.

The selected editable GameINI comes from Workshop. Existing per-game Gecko and
ActionReplay blocks are retained across preset changes because Rt:UI's cheat
manager writes generated codes to this user-root file and intentionally leaves
hand-written codes alone. Non-cheat runtime settings are replaced by Workshop.
"""

from pathlib import Path
import re
import sys

SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*$")
CHEAT_SECTIONS = {
    "Gecko",
    "Gecko_Enabled",
    "ActionReplay",
    "ActionReplay_Enabled",
}
MULTILINE_SECTIONS = {"Gecko", "ActionReplay"}


def cheat_blocks(text: str) -> dict[str, list[list[str]]]:
    """Extract named cheat blocks while preserving their code continuation rows."""
    result = {section: [] for section in CHEAT_SECTIONS}
    lines = text.splitlines()
    section = ""
    index = 0

    while index < len(lines):
        line = lines[index]
        section_match = SECTION_RE.match(line)
        if section_match:
            section = section_match.group(1).strip()
            index += 1
            continue

        if section in CHEAT_SECTIONS and line.startswith("$"):
            block = [line]
            index += 1
            if section in MULTILINE_SECTIONS:
                while index < len(lines):
                    next_line = lines[index]
                    if SECTION_RE.match(next_line) or next_line.startswith("$"):
                        break
                    block.append(next_line)
                    index += 1
            result[section].append(block)
            continue

        index += 1

    return result


def append_missing_blocks(lines: list[str], section: str, blocks: list[list[str]]) -> None:
    if not blocks:
        return

    start = next(
        (i for i, line in enumerate(lines) if line.strip() == f"[{section}]"),
        None,
    )
    if start is None:
        if lines and lines[-1].strip():
            lines.append("")
        lines.append(f"[{section}]")
        start = len(lines) - 1

    existing_names = set()
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if SECTION_RE.match(lines[i]):
            end = i
            break
        if lines[i].startswith("$"):
            existing_names.add(lines[i])

    missing = [block for block in blocks if block and block[0] not in existing_names]
    if not missing:
        return

    payload = [line for block in missing for line in block]
    insert_at = end
    while insert_at > start + 1 and lines[insert_at - 1] == "":
        insert_at -= 1
    lines[insert_at:insert_at] = payload
    if insert_at + len(payload) < len(lines) and lines[insert_at + len(payload)] != "":
        lines.insert(insert_at + len(payload), "")


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: project_gamesettings.py SOURCE.ini PREVIOUS_RUNTIME.ini OUTPUT.tmp", file=sys.stderr)
        return 2

    source_arg = sys.argv[1]
    previous = Path(sys.argv[2])
    output = Path(sys.argv[3])

    if source_arg == "-":
        source_text = ""
    else:
        source = Path(source_arg)
        if not source.is_file():
            print(f"source GameINI not found: {source}", file=sys.stderr)
            return 1
        source_text = source.read_text(encoding="utf-8", errors="replace")

    previous_text = previous.read_text(encoding="utf-8", errors="replace") if previous.is_file() else ""
    source_blocks = cheat_blocks(source_text)
    previous_blocks = cheat_blocks(previous_text)
    output_lines = source_text.splitlines()

    for section in ("Gecko", "Gecko_Enabled", "ActionReplay", "ActionReplay_Enabled"):
        append_missing_blocks(output_lines, section, previous_blocks[section])

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(output_lines).rstrip("\n") + ("\n" if output_lines else ""), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
