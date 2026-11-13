# Testing and verification

This guide describes the current repository layout and the checks used for Dolphin Rt:Core. It replaces the retired \`frontend/\` and \`dev.sh\` instructions.

## 1. Repository checks

Run from the repository root:

\`\`\`sh
git diff --check
git status --short --branch
python3 -m unittest tests/test_repo_tools.py tests/test_compat_site.py tests/test_rtstream_web_portal.py -v
\`\`\`

The CI workflow also compiles selected Python modules, syntax-checks selected shell helpers, validates AArch64 ELF contracts, tests muOS registration/runtime behavior, verifies the Dolphin Sys tree and MUXUPD manifest, tests the experimental Qt 6 package and performs Knulli/ROCKNIX packaging dry-runs.

## 2. Rt:UI Lua checks

The active muOS LÖVE application is:

\`\`\`text
dolphin-rtcore-muos/app/Dolphin RtUI/
\`\`\`

Compile every Lua file:

\`\`\`sh
find dolphin-rtcore-muos/app -name '*.lua' -print0 | xargs -0 -n1 luajit -bl >/dev/null
\`\`\`

Run the focused CI tests from the repository root:

\`\`\`sh
luajit tests/test_nexus.lua
luajit tests/test_stream_lib.lua
luajit tests/test_stream_settings_nexus.lua
luajit tests/test_stream_config_persistence.lua
luajit tests/test_diagnostics_nexus.lua
luajit tests/test_hotkeys_nexus.lua
luajit tests/test_cheats_screen_nexus.lua
luajit tests/test_game_nexus.lua
luajit tests/test_keymap_nexus.lua
luajit tests/test_controller_profiles_nexus.lua
luajit tests/test_compat_nexus.lua
luajit tests/test_cheatdb_nexus.lua
luajit tests/test_app_input_andromeda.lua
luajit tests/test_boot_initializer_async.lua
luajit tests/test_gameset_loader.lua
luajit tests/test_gamesettings_deployer.lua
luajit tests/test_cheats_downloader.lua
luajit tests/test_boot_screen_auto_proceed.lua
luajit tests/test_library_boot_scan_handoff.lua
luajit tests/test_controller_map_input.lua
bash tests/test_muos_controller_profiles.sh
bash tests/test_hotkeys_runtime.sh
bash tests/test_ui_action_registration.sh
luajit tests/test_compat_layout.lua
bash tests/test_rom_paths.sh
\`\`\`

A test should be run from the working directory specified by the CI workflow if it relies on relative Lua module paths. Do not omit a failing test from the command list to make a local run appear green.

## 3. LÖVE smoke test and screen captures

Install LÖVE and Xvfb, then run from the Rt:UI application directory:

\`\`\`sh
cd "dolphin-rtcore-muos/app/Dolphin RtUI"
SDL_AUDIODRIVER=dummy xvfb-run -a love . --smoke
\`\`\`

The smoke test must create \`data/logs/smoke.txt\` and report \`0 FAIL\`.

CI additionally captures every registered screen at:
- 640×480
- 720×480
- 720×720

For a UI change, inspect the generated images for clipping, overlap, text legibility, contrast, selection/focus state and safe areas. Automated screenshot capture is not a substitute for human visual review.

## 4. Shell, archive and platform checks

Use the interpreter that the script declares:

\`\`\`sh
bash -n path/to/bash-script.sh
sh -n path/to/posix-script.sh
\`\`\`

A complete muOS update build requires a validated AArch64 Dolphin executable and a matching Sys tree:

\`\`\`sh
DOLPHIN_BIN=/path/to/aarch64/dolphin \\
DOLPHIN_SYS_DIR=/path/to/matching/Sys \\
DOLPHIN_LIB_DIR=/path/to/matching/lib \\
  bash dolphin-rtcore-muos/tools/build-muxupd.sh dist
bash dolphin-rtcore-muos/tools/verify-muxupd.sh dist/*.muxupd
\`\`\`

The UI-only validation archive is intentionally incomplete: it must not contain the Dolphin executable and must never be described or distributed as a full installable package.

The MUXUPD verifier uses the muOS Andromeda verification functions from upstream and requires network access. Do not treat archive creation alone as proof that installation works on a device.

## 5. PC Companion checks

The current PC-side source is under \`pc-stream/\`. The local web Companion runs on loopback and uses the existing Rt:Stream core. Run the static/unit checks through repository CI:

\`\`\`sh
python3 -m unittest tests/test_rtstream_web_portal.py -v
python3 -m py_compile pc-stream/usr/lib/spdw-stream-portal/web_portal.py
\`\`\`

These checks do not verify Sunshine/Moonlight streaming or SFTP against a physical handheld. For SFTP, the target must have a working SSH/SFTP service, a trusted host key, the correct username/port and an existing configured ROM path. Record separately the results of connection, browse, upload, download, resume, overwrite and delete tests.

## 6. Physical-device verification

A successful CI run, LÖVE smoke test, screenshot capture, package dry-run, AArch64 build or archive verification does **not** prove that a package works on a physical handheld.

Before marking a hardware target verified, record:
- Exact device and SoC.
- Firmware name and version.
- Package filename, version and SHA-256.
- Install or upgrade path used.
- Frontend boot, controls, display and audio results.
- Game launch and clean exit.
- Reboot and settings-persistence checks.
- Logs and known limitations.

For the RG35XX H / H700, explicitly test the 640×480 panel, all physical buttons/axes/hats, Dolphin launch and return, GameCube/Wii input, fonts, memory behavior and clean shutdown.

## 7. Reporting test results

Use these states precisely:
- **Passed:** the exact command or procedure completed successfully.
- **Failed:** the exact check failed; include the failing job/step and log excerpt.
- **Not run:** the check was not executed.
- **Not applicable:** explain why it does not apply.
- **Hardware unverified:** no physical-device result exists for the exact binary/package.

Never convert a skipped check, CI dry-run or desktop result into a hardware pass.
