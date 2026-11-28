# Roadmap — Dolphin Rt:Core

## M0 — Preserve platform separation
- [x] Keep muOS, KNULLI and ROCKNIX packages in separate directories and build paths.
- [x] Verify KNULLI/ROCKNIX archives include a matching AArch64 binary and required GameCube Sys resources.
- [x] Keep Rt:Stream handheld UI and PC portal under the shared product boundary.
- [x] Extend packaging regression tests to reject cross-platform package-root leakage.

## M1 — muOS Andromeda quality
- [ ] Keep controller mappings, UI screens, profiles and launcher hand-off synchronized.
- [ ] Continue bounded asynchronous library scans and cover/cache verification.
- [ ] Verify package manifests, rollback and user-owned settings migration.
- [ ] Test at 640×480 on physical RG35XX H hardware.

## M2 — KNULLI and ROCKNIX
- [ ] Validate each OS's actual launcher, emulator category registration and storage paths.
- [ ] Keep ROCKNIX experimental until its own H700 hardware matrix passes.
- [ ] Verify separate package roots, Sys payload, checksums and install/rollback behavior.

## M3 — Rt:Stream
- [ ] Keep the handheld streaming library, profiles and PC portal protocol compatible.
- [ ] Test LAN discovery, pairing, credentials and reconnect behavior.
- [ ] Validate desktop browser layouts and offline/PWA behavior separately from handheld UI.

## M4 — Release readiness
- [ ] Rebuild native binaries with recorded upstream commit, patch set and toolchain.
- [ ] Run all host CI, screenshot packs and package verifiers.
- [ ] Record physical-device evidence per OS and hardware revision before changing support status.

## Acceptance
No cross-platform files leak between KNULLI/ROCKNIX packages; AArch64 and Sys resource gates pass; muOS UI tests pass; Rt:Stream protocol tests pass; hardware-only claims have device evidence. ROMs, BIOS and copyrighted assets are never included.

## Release target
Continue the current muOS release line while KNULLI/ROCKNIX and Rt:Stream advance independently under the same Core repository. Do not promote experimental platform support without its own qualification.
