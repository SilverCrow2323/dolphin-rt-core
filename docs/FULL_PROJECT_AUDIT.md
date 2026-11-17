# Dolphin Rt:Core — full project audit

**Status:** active, evidence-based audit  
**Baseline:** \`main\` at the current project portal / Rt:Stream / Rt:UI integration  
**Last reviewed:** 2026-11-13

This document records verified repository-level findings, separates completed work from outstanding checks, and keeps CI evidence distinct from physical-device certification. Update it when a relevant PR is merged or when a finding is disproved.

## Executive assessment

The repository now has a more coherent product surface: the root site is the official Dolphin Rt:Core portal, the compatibility database remains available as its own application, Rt:Stream has a browser-based PC Companion, and muOS Rt:UI has broader boot, input, library and diagnostics coverage.

The next quality priority is **release confidence and integration consistency**, not another parallel implementation. Keep one active implementation for each feature, test the packaged result, and do not describe CI or an ARM64 build as a successful handheld installation.

## Current repository map

| Area | Active location | Review focus |
|---|---|---|
| muOS package and Rt:UI | \`dolphin-rtcore-muos/\` | Launcher, app lifecycle, input, settings, update/install and runtime contracts |
| Dolphin build | \`dolphin-build/\` | Pinned upstream source, patch reproducibility, architecture and runtime dependencies |
| Rt:Stream PC Companion | \`pc-stream/\` | Local web control plane, Sunshine, library sync, SFTP and desktop packaging |
| Official project website | \`index.html\`, \`manifest.json\`, \`sw.js\` | Product information, releases, PWA and offline behavior |
| Compatibility application | \`compatibility.html\`, \`data/games_data.json\` | Search, reports, schema, data validation and intake |
| Knulli integration | \`dolphin-rtcore-k/\` | Platform-specific paths, package parity and device evidence |
| ROCKNIX integration | \`dolphin-rtcore-r/\` | Experimental status, Wayland assumptions and device evidence |
| Documentation | \`docs/\` and \`wiki/\` | Current-vs-legacy accuracy and practical guides |
| Historical archive | \`Core_History/\` | Ensure archived code is not mistaken for the active implementation |

The active muOS LÖVE application is \`dolphin-rtcore-muos/app/Dolphin RtUI/\`. The current PC Companion is under \`pc-stream/\`; older portal material should be treated as historical unless a specific workflow still references it.

## Confirmed findings

### F-001 — Duplicate NEXUS screen-action registration

**Status:** resolved in the current mainline integration  
**Area:** Rt:UI startup

The same screen-action registration blocks for Compatibility List and Keymap previously appeared more than once in \`ui/init.lua\`. The registry rejects duplicate action identifiers. The current integration removes the duplicated blocks and includes \`tests/test_ui_action_registration.sh\` in CI.

**Regression gate:** keep one registration owner per screen and retain the duplicate-registration test whenever the screen manifest or NEXUS bootstrap changes.

### F-002 — Testing instructions described a retired frontend layout

**Status:** documentation correction in this audit work  
**Area:** contributor documentation

The older \`docs/TESTING.md\` described \`frontend/\` and \`dev.sh\`, which do not match the active application path. The replacement guide uses the current repository layout and the checks actually wired into GitHub Actions.

**Regression gate:** update the guide in the same change that adds or removes a required CI command.

### F-003 — CI success is not physical-device certification

**Status:** open release gate  
**Area:** platform support

CI covers source contracts, Lua compilation and tests, LÖVE smoke/screenshot checks, portal tests, package checks and selected platform dry-runs. These checks cannot prove a package boots on a real RG35XX H, that physical controls behave correctly, or that a particular game has acceptable audio, video and frame pacing.

**Required evidence for a hardware claim:** device and SoC, exact firmware, package filename and SHA-256, install/upgrade path, boot result, input map, screen/audio behavior, game launch/exit, reboot/persistence result and relevant logs.

### F-004 — Official website and compatibility app needed separate routes

**Status:** resolved by the official project portal integration  
**Area:** website architecture

The root site is now the Dolphin Rt:Core Project Portal. The existing compatibility database is preserved as \`compatibility.html\`, rather than being discarded or conflated with the product homepage.

**Regression gate:** keep both routes published and precached by the PWA; test direct navigation and offline fallback for the compatibility route as well as the root portal.

### F-005 — Automated coverage is broad but bounded

**Status:** ongoing  
**Area:** CI / quality

The current workflow includes:
- Python portal lint/tests under Python 3.10 and 3.12, with GUI tests under Xvfb.
- Portal package builds for the supported desktop packaging outputs.
- Repository tooling: shell syntax for selected helpers, Python compilation, native-build workflow triggers, ELF validation, muOS registration/runtime contracts, system-resource packaging tests, Qt 6 experimental packaging checks, Knulli/ROCKNIX packaging dry-runs and repository/web/PC-Companion unit tests.
- muOS Andromeda Lua compilation and focused NEXUS, input, startup, GameSettings, hotkey, controller and compatibility tests.
- An explicitly labelled UI-only MUXUPD for source/installer validation. It is not a full installable Dolphin package and must never be presented as one.
- LÖVE smoke tests and screen captures at 640×480, 720×480 and 720×720.

**Remaining work:** disposable-fixture install/upgrade/rollback/uninstall lifecycle coverage, repeatable package builds, dependency/licence provenance review and a maintained physical-device test matrix.

### F-006 — muOS archive verification depends on upstream verification code

**Status:** open reliability item  
**Area:** packaging / CI

\`dolphin-rtcore-muos/tools/verify-muxupd.sh\` obtains muOS Andromeda verification functions from the upstream tagged source at runtime. This introduces a network dependency and makes the verification path sensitive to upstream availability and tag provenance.

**Required action:** evaluate pinning the exact upstream commit and validating its checksum, while retaining a deliberate compatibility update process. Do not silently replace the upstream checks with a weaker local approximation.

### F-007 — Rt:Stream has three distinct transport channels

**Status:** architecture established; hardware validation open  
**Area:** PC Companion and handheld integration

The PC Companion keeps these channels separate:
1. Sunshine/Moonlight for game video and controller input.
2. The existing HTTP library service for the handheld's manifest and cover-art sync.
3. Optional OpenSSH SFTP for explicit remote ROM file management.

The browser control plane binds to loopback. SFTP uses strict host-key checking and existing SSH keys/agent; it does not store passwords or private keys. LAN/Tailscale discovery only checks known neighbors and online peers, not a subnet sweep.

**Hardware gate:** SFTP must be tested with the actual firmware's SSH service, account, host key, port and ROM directory. Discovery of a candidate is not proof that SFTP is enabled or authenticated.

### F-008 — Atomic MUXUPD publication needs to remain a release invariant

**Status:** being integrated and validated  
**Area:** packaging

The atomic publisher builds to a temporary archive beside the destination, verifies the ZIP and integrity manifest, and only then replaces the published package. Regression tests simulate a failed ZIP process and a corrupt archive returned with exit status zero. The old valid archive must remain byte-for-byte unchanged in both cases.

**Regression gate:** never publish a MUXUPD before ZIP integrity and \`manifest.sha256\` checks pass.

## Prioritized work queue

### P0 — Release confidence
- [ ] Complete a disposable-fixture lifecycle test for install, upgrade, rollback and uninstall.
- [ ] Verify generated packages contain no local settings, logs, runtime stream state, credentials or temporary files.
- [ ] Pin and provenance-check the upstream muOS archive-verification code.
- [ ] Build the exact H700 full package and record physical RG35XX H results.
- [ ] Review release notes against the exact artifacts and current CI state.

### P1 — Rt:UI quality
- [ ] Audit startup/shutdown error handling and user-facing outcomes.
- [ ] Validate physical button/axis/hat behavior against the Andromeda mapping.
- [ ] Audit filesystem scans, subprocess timeouts and background-operation cancellation.
- [ ] Review settings ownership and persistence for duplicate sources of truth.
- [ ] Inspect screen captures for clipping, overlap, focus and legibility at supported resolutions.

### P1 — Rt:Stream PC Companion
- [ ] Validate Sunshine start/stop/restart and Moonlight pairing on a real PC/handheld pair.
- [ ] Test LAN and Tailscale peer discovery on networks with multiple candidate devices.
- [ ] Exercise SFTP upload, download, resume, overwrite, folder browsing and explicit deletion with a real muOS SFTP service.
- [ ] Ensure the desktop package contains the web backend and static assets, and that upgrades retain the legacy fallback.
- [ ] Add end-to-end transfer integrity/checksum reporting after confirming device-side capabilities.

### P1 — Website and documentation
- [ ] Keep the project portal and compatibility application as distinct first-class routes.
- [ ] Make release/platform support statements evidence-based and distinguish planned, built and device-tested states.
- [ ] Keep the PWA cache/fallback routes aligned with the site architecture.
- [ ] Use the GitHub Wiki as the practical FAQ, how-to and quick-reference layer; keep deeper implementation notes in \`docs/\`.

### P2 — Maintainability
- [ ] Map module dependencies and ownership.
- [ ] Identify dead code and duplicate active implementations; preserve historical archive material unless proven safe to remove.
- [ ] Define shared platform contracts for muOS, Knulli and ROCKNIX.
- [ ] Review third-party licensing, provenance and asset inventory.
- [ ] Keep stable, experimental and developer-only features visibly separate.

## Audit rules

1. Every finding must cite a file, test, workflow or reproducible observation.
2. Do not delete historical material solely because it looks old.
3. Do not refactor a major subsystem without a testable behavior contract.
4. Do not describe desktop/CI success as hardware success.
5. Do not publish a full update package without a matching validated Dolphin binary and Sys tree.
6. Update this audit when a listed issue is fixed, disproved or superseded.
