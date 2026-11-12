# Testing and verification

This guide describes the **current repository layout** and the checks used for Dolphin Rt:Core. It replaces the legacy `frontend/` and `dev.sh` instructions.

## 1. Repository checks

Run from the repository root:

```sh
git diff --check
git status --short
python3 -m unittest tests/test_compat_site.py -v
```

The CI workflow also runs repository-tooling checks for shell syntax, Python compilation, muOS registration, Dolphin runtime contracts, packaging manifests and platform package dry-runs.

## 2. Rt:UI Lua checks

The active muOS LÖVE application is:

```text
dolphin-rtcore-muos/app/Dolphin RtUI/
```

Compile every Lua file with LuaJIT:

```sh
find dolphin-rtcore-muos/app -name '*.lua' -print0 \
  | xargs -0 -n1 luajit -bl >/dev/null
```

Run the focused NEXUS and frontend tests used by CI:

```sh
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
bash tests/test_muos_ui.sh
bash tests/test_ui_action_registration.sh
```

Some Lua tests expect the Rt:UI directory as their working directory. If a test cannot resolve its modules from the repository root, run it from the application directory using the relative path shown by the CI workflow.

## 3. LÖVE screen smoke test and screenshots

Install LÖVE and Xvfb on a Linux host, then run:

```sh
cd "dolphin-rtcore-muos/app/Dolphin RtUI"
SDL_AUDIODRIVER=dummy xvfb-run -a love . --smoke
```

The smoke test writes `data/logs/smoke.txt`; a successful run must report `0 FAIL`.

Capture every registered screen from the repository root:

```sh
bash tools/capture-ui.sh --all --out-dir /tmp/rtcore-screens
```

For UI changes, inspect focus, clipping, text legibility, contrast and safe areas at the logical 640×480 layout. CI additionally captures the frontend at 640×480, 720×480 and 720×720. Captures are automated evidence, not a substitute for human review.

## 4. Shell and package checks

Use the interpreter declared by each script:

```sh
bash -n path/to/bash-script.sh
sh -n path/to/posix-script.sh
```

Build and verify a muOS Andromeda update archive:

```sh
bash dolphin-rtcore-muos/tools/build-muxupd.sh dist
bash dolphin-rtcore-muos/tools/verify-muxupd.sh dist/*.muxupd
```

The verifier fetches the muOS 2606.0 Andromeda verification functions from the upstream tagged source and therefore requires network access. Do not treat a local archive build alone as proof that installation works on a device.

## 5. Device verification

A successful CI run, LÖVE smoke test, screenshot capture, package dry-run or archive verification does **not** prove that the package works on a physical handheld.

Before marking a hardware target as verified, record at minimum:

- Exact device and SoC.
- Firmware name and version.
- Package filename, version and SHA-256.
- Install or upgrade path used.
- Frontend boot, input mapping, rendering and audio results.
- Game launch and clean exit.
- Reboot and persistence checks.
- Logs and known limitations.

For the RG35XX H / H700, explicitly test the 640×480 panel, physical controls, Dolphin launch/return path, GameCube and Wii input, font rendering, memory behavior and clean shutdown.

## 6. Reporting test results

Every report must distinguish:

- **Passed:** the exact command or procedure completed successfully.
- **Failed:** the exact check failed; include the failing job/step and relevant log excerpt.
- **Not run:** the check was not executed.
- **Not applicable:** explain why it does not apply.
- **Hardware unverified:** no physical-device result exists for the exact binary/package.

Never convert a skipped check, CI dry-run or desktop result into a hardware pass.
