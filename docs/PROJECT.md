# Project: Dolphin Rt:Core

## Purpose
Maintain the shared Dolphin handheld/desktop ecosystem and its platform integrations, including the muOS Andromeda frontend, KNULLI and ROCKNIX packages, Rt:Stream portal and historical release sources.

## Users and use cases
- H700 handheld owners running muOS, KNULLI or ROCKNIX.
- Desktop users of the Rt:Stream portal and companion tools.
- Maintainers packaging Dolphin binaries, shared Sys resources, UI assets and platform-specific launchers.

## Scope and boundaries
This repository owns Dolphin Rt:Core integration, frontend, packaging, Rt:Stream components and compatibility tooling. The muOS frontend is the current primary handheld implementation; KNULLI and ROCKNIX retain separate package roots and release status. Rt:Stream includes the handheld streaming UI and PC portal; it is not a separate emulator core.

Out of scope: redistributing game ROMs, BIOS or copyrighted artwork; treating experimental ROCKNIX support as stable without evidence; and copying historical code into current platform directories without a reviewed dependency.

## Targets
- muOS Andromeda on H700 handhelds, including RG35XX H.
- KNULLI and ROCKNIX as separately packaged integrations.
- Linux/Windows desktop portal and developer tooling.
- LÖVE/LuaJIT handheld UI, shell scripts, Python/Node tooling and native AArch64 Dolphin builds.

## Architecture
- Platform packages: dolphin-rtcore-muos/, dolphin-rtcore-k/ and dolphin-rtcore-r/.
- Shared UI/data/assets and controller/profile logic.
- Rt:Stream handheld screens, protocol, profiles and PC portal.
- Native build/patch pipeline and AArch64 ELF validation.
- Compatibility site, screenshot studio, release and packaging tests.
- Core_History/ preserves historical releases and is not the default source for new behavior.

## Dependencies and integration
Dolphin upstream, LÖVE 11.5/LuaJIT, SDL2, platform-specific muOS/KNULLI/ROCKNIX launch contracts, AArch64 toolchains and desktop portal dependencies. Every platform must declare its own install paths and support state.

## Safety and quality
Keep package roots isolated, verify ELF architecture and shared Sys resources, avoid ROM/BIOS/game-data commits, bound background scans and preserve controller accessibility. CI/emulator screenshots are not physical hardware qualification. Documentation must state platform status and exact test scope.

## Verified baseline
The repository already has platform-specific build/package tests, a broad muOS UI test suite, Rt:Stream portal tests and screenshot tooling. The existing docs/PROJECT_MAP.md describes code locations; docs/ROADMAP.md defines the next staged integration work.
