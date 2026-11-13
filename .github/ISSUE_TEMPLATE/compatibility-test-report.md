---
name: Compatibility test report
about: Submit a reproducible GameCube or Wii test for the community compatibility database
title: "[Test Report] "
labels: ["test-report"]
assignees: []
---

> Use this template for one exact game release and one exact device / firmware / Rt:Core setup. A report is evidence from a single test session, not a universal compatibility guarantee.

## Game identity

- **Game title:**
- **Game ID (six characters):**
- **System:** GameCube / Wii
- **Region:** PAL / NTSC / NTSC-J
- **Disc revision / game patch (if known):**

## Test environment

- **Tester / credit:**
- **Device model:**
- **Device / board revision:**
- **Firmware and exact version:**
- **Dolphin Rt:Core release:**
- **Dolphin build / commit (if known):**
- **Core profile:**
- **Graphics backend:**
- **Test date (YYYY-MM-DD):**

## Test conditions

- **Gameplay duration (minutes):**
- **Area, scene or repeatable test scenario:**
- **Game image format (metadata only; do not attach the image):**

## Observed result

- **Overall rating (0–5):**
- **Boot result:** YES / CRASH / NO
- **Playability:** YES / YES WITH ISSUES / NO
- **Minimum FPS (measured in gameplay):**
- **Maximum FPS (measured in gameplay):**
- **Audio:** Not tested / Clean / Minor issues / Major issues
- **Graphics:** Not tested / Clean / Minor issues / Major issues
- **Input / controls:** Not tested / Clean / Minor issues / Major issues
- **Stability:** Not tested / Clean / Minor issues / Major issues

## Reproduction notes

Describe the exact scene, steps, slowdowns, glitches, audio defects, input issues, crashes, workarounds and whether the result was repeatable. Write "Not tested" rather than guessing.

## Optional settings and evidence

- **GameSettings / profile changes:**
- **Public resource URL:**
- **Screenshot / short video URL:**

## Machine-readable report (preferred)

Paste the JSON payload produced by the Compatibility Database form below. Keep one report per test session; do not merge separate devices, regions, firmware versions or profiles into a synthetic result.

    {
      "game_info": {
        "game_id": "",
        "system": "",
        "game": "",
        "region": ""
      },
      "test_review": {
        "rating": 0,
        "fps": "N/A",
        "boot": "NO",
        "playable": "NO",
        "fps_min": 0,
        "fps_max": 0
      },
      "test_details": {
        "rtcore_version": "",
        "dolphin_version": "",
        "core_profile": "",
        "graphics_backend": "Not recorded",
        "test_duration_minutes": null,
        "test_scene": "",
        "audio": "Not tested",
        "graphics": "Not tested",
        "input": "Not tested",
        "stability": "Not tested",
        "considerations": ""
      },
      "test_environment": {
        "tester": "",
        "device": "",
        "device_revision": "",
        "muos_version": ""
      },
      "custom_settings": [],
      "attachments": []
    }

## Privacy and copyright check

- [ ] I have not attached ROMs, BIOS files, firmware images, copyrighted game files or pirated content.
- [ ] Screenshots, clips and logs contain no serial numbers, MAC addresses, pairing tokens, passwords or other private identifiers.
- [ ] I have included only evidence relevant to this report.
- [ ] I understand that maintainers review submissions before adding them to the canonical database.
