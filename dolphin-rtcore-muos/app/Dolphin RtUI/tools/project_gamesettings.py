#!/usr/bin/env python3
"""Build Dolphin's runtime GameSettings/<GameID>.ini projection.

The editable GameINI is sourced from Workshop. Rt:UI's cheat manager may have
already added generated [Rt] Gecko/ActionReplay blocks to the previous runtime
file; preserve only those tagged blocks while replacing all ordinary settings
with the newly selected Workshop preset.
"""

from pathlib import Path
import re
import sys

SECTION_RE = re.compile(r"^\s*\[([^\]]+)\]\s*$")
MANAGED_SECTIONS = (
    "Gecko",
    "Gecko_Enabled",
    "ActionReplay",
    "ActionReplay_Enabled",
)
CODE_SECTIONS = {"Gecko", "ActionReplay"}
TAG = "$[Rt] "


def split_managed(text: str) -> tuple[list[str], dict[str, list[list[str]]]]:
    """Remove Rt-owned cheat blocks while returning them grouped by section."""
    output: list[str] = []
    managed: dict[str, list[list[str]]] = {name: [] for name in MANAGED_SECTIONS}
    lines = text.splitlines()
    section = ""
    index = 0

    while index < len(lines):
        line = lines[index]
        section_match = SECTION_RE.match(line)
        if section_match:
            section = section_match.group(1).strip()
            output.append(line)
            index += 1
            continue

        if section in MANAGED_SECTIONS and line.startswith("$"):
            if line.startswith(TAG):
                block = [line]
                index += 1
                if section in CODE_SECTIONS:
                    while index < len(lines):
                        next_line = lines[index]
                        if SECTION_RE.match(next_line) or next_line.startswith("$"):
                            break
                        block.append(next_line)
                        index += 1
                managed[section].append(block)
                continue
        output.append(line)
        index += 1

    return output, managed


def append_section_blocks(lines: list[str], section: str, blocks: list[list[str]]) -> None:
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

    end = len(lines)
    for i in range(start + 1, len(lines)):
        if SECTION_RE.match(lines[i]):
            end = i
            break

    payload = [line for block in blocks for line in block]
    # Preserve a single blank separator before the next INI section.
    insert_at = end
    while insert_at > start + 1 and lines[insert_at - 1] == "":
        insert_at -= 1
    lines[insert_at:insert_at] = payload
    if end < len(lines) and (not lines[end] or lines[end] != ""):
        lines.insert(insert_at + len(payload), "")


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: project_gamesettings.py SOURCE.ini PREVIOUS_RUNTIME.ini OUTPUT.tmp", file=sys.stderr)
        return 2

    source = Path(sys.argv[1])
    previous = Path(sys.argv[2])
    output = Path(sys.argv[3])

    if not source.is_file():
        print(f"source GameINI not found: {source}", file=sys.stderr)
        return 1

    source_lines, _ = split_managed(source.read_text(encoding="utf-8", errors="replace"))
    previous_text = previous.read_text(encoding="utf-8", errors="replace") if previous.is_file() else ""
    _, previous_managed = split_managed(previous_text)

    for section in MANAGED_SECTIONS:
        append_section_blocks(source_lines, section, previous_managed[section])

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(source_lines).rstrip("\n") + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
