# Full project audit

**Status:** in progress  
**Baseline:** `main` at `2bff55e2f80530216885e3759a2bd551c1f18dde`  
**Audit branch:** `quality/full-project-audit`  
**Started:** 2026-11-12

This is the working audit record for the repository, Rt:UI application and project website. Findings are evidence-based and are separated from proposed work. A clean CI run is not treated as proof of physical-device compatibility.

## Executive assessment

The repository already contains substantial engineering infrastructure: multiple platform integrations, a pinned Dolphin build pipeline, a LÖVE frontend, a PC portal, compatibility data, package tooling, screenshots and a GitHub Wiki source tree.

The main risk is now **consistency across this large surface area**. The active product, historical implementations, platform-specific packaging, documentation and website need clear boundaries and matching quality gates. The first priority is not to add another major feature; it is to make existing behavior auditable and repeatable.

## Repository map

| Area | Current location | Audit focus |
|---|---|---|
| muOS package and Rt:UI | `dolphin-rtcore-muos/` | Launcher, app lifecycle, settings, update/install, runtime contracts |
| Knulli integration | `dolphin-rtcore-k/` | Platform-specific paths, package parity and device evidence |
| ROCKNIX integration | `dolphin-rtcore-r/` | Experimental status, Wayland assumptions and hardware evidence |
| Dolphin build | `dolphin-build/` | Pinned source, patch reproducibility, architecture and artifacts |
| PC streaming portal | `portal/` | Tests, packaging, protocol and security boundaries |
| Website | root `index.html`, `sw.js`, `manifest.json` | Compatibility data UX, accessibility, PWA and product-site strategy |
| Documentation | `docs/` and `wiki/` | Current-vs-legacy accuracy, navigation, practical guides |
| Historical archive | `Core_History/` | Ensure old code is not accidentally treated as active implementation |

The active muOS LÖVE application is `dolphin-rtcore-muos/app/Dolphin RtUI/`. The project map and root README identify this as the current frontend location.

## Confirmed findings

### F-001 — Duplicate NEXUS action registration

**Severity:** low  
**Area:** Rt:UI startup  
**Evidence:** `ui/init.lua` registered the `compat_list` and `keymap` screen actions twice. `core/nexus.lua` explicitly rejects a second registration of the same action ID with `action already registered`. The UI startup wrapper logs rejected registrations.

**Impact:** duplicate startup work and misleading error-level log entries despite the screen actions already being registered.

**Action taken on this branch:** removed the two repeated registration blocks and added `tests/test_ui_action_registration.sh`, wired into CI to prevent duplicate screen registration declarations.

### F-002 — Testing guide described a legacy frontend layout

**Severity:** medium  
**Area:** Documentation  
**Evidence:** the previous `docs/TESTING.md` described `frontend/`, `dev.sh`, and log paths that do not match the current documented application location. The active application is under `dolphin-rtcore-muos/app/Dolphin RtUI/`; CI uses LuaJIT, LÖVE smoke tests, screenshot capture and package verification.

**Impact:** contributors could follow commands for an obsolete layout and misunderstand which checks actually run.

**Action taken on this branch:** replaced the guide with current repository-root commands, current app paths, CI-aligned tests and explicit hardware-verification rules.

### F-003 — Hardware validation is intentionally outside CI

**Severity:** release gate  
**Area:** Platform support  
**Evidence:** root README and quality/release documentation explicitly distinguish CI, Xvfb, dry-run and ELF checks from physical-device verification.

**Impact:** passing CI cannot establish a working H700 boot, controller mapping, rendering, audio, game launch or clean exit.

**Required action:** maintain per-device evidence with firmware, exact package hash, install path, launch/exit results and logs before changing support claims.

### F-004 — Root website is currently the compatibility database

**Severity:** product strategy  
**Area:** Website  
**Evidence:** root `index.html` title and metadata identify the page as “Dolphin Rt:Core · Compatibility Database”. It is not yet a complete product landing/documentation/download experience.

**Impact:** the website roadmap needs a clear separation between the compatibility application and the official product presentation, without discarding the existing database.

**Required action:** design the official site information architecture around the existing compatibility database as a first-class section or application.

### F-005 — CI has broad automated checks, but coverage is not equivalent to release certification

**Severity:** medium  
**Area:** CI / quality  
**Evidence:** the workflow covers portal tests on Python 3.10/3.12, muOS Lua checks, LÖVE smoke and screenshots at 640×480, 720×480 and 720×720, repository tooling, package dry-runs and artifacts.

**Gaps to close:** explicit shell lint execution, install/upgrade/uninstall lifecycle tests against disposable fixtures, package reproducibility checks, and a documented physical-device test matrix.

### F-006 — muOS archive verification depends on fetching upstream verification scripts

**Severity:** medium  
**Area:** Packaging / CI reliability  
**Evidence:** `dolphin-rtcore-muos/tools/verify-muxupd.sh` downloads muOS Andromeda verification functions at runtime from the upstream tagged source.

**Impact:** the check requires network access and depends on upstream availability and tag integrity.

**Required action:** assess pinning the exact upstream commit/checksum or maintaining a small, clearly licensed fixture/contract test while retaining a periodic upstream compatibility check.

## Work queue

### P0 — Release confidence

- [ ] Complete the audit of install, upgrade, rollback and uninstall paths.
- [ ] Verify all package manifests and ensure generated archives contain no runtime secrets, logs or local state.
- [ ] Add disposable-fixture lifecycle tests.
- [ ] Build the exact H700 package and complete a physical RG35XX H validation pass.
- [ ] Review every known issue against current code and current CI evidence.

### P1 — Application quality

- [ ] Audit startup and shutdown error handling; identify swallowed failures and missing user-facing outcomes.
- [ ] Audit controller input routing, key mapping and focus behavior across every screen.
- [ ] Audit filesystem scans, subprocesses, network timeouts and background operation cancellation.
- [ ] Audit settings ownership and persistence to prevent duplicate sources of truth.
- [ ] Review all screens at the supported logical and physical resolutions.

### P1 — Website and documentation

- [ ] Define the official website architecture without replacing the compatibility database.
- [ ] Reconcile documentation indexes and remove stale references to retired paths and tools.
- [ ] Make release, platform support and hardware evidence data-driven where practical.
- [ ] Add accessibility, keyboard/controller navigation and offline PWA checks.

### P2 — Maintainability and ecosystem

- [ ] Map module dependencies and ownership.
- [ ] Identify dead code, duplicate implementations and archive leakage.
- [ ] Define platform contracts shared by muOS, Knulli and ROCKNIX.
- [ ] Review third-party licenses, provenance and asset inventory.
- [ ] Separate stable, experimental and developer-only capabilities visibly.

## Rules for this audit

1. Findings must cite a file, test, workflow or reproducible observation.
2. Do not delete historical material solely because it looks old.
3. Do not refactor large subsystems without a testable behavior contract.
4. Do not report desktop/CI success as hardware success.
5. Keep the PR #84 branch and this quality branch independent.
6. Keep PRs draft until their own tests and review criteria are satisfied.

## Next audit slices

1. Installer, updater, rollback and uninstall lifecycle.
2. Rt:UI startup, shutdown, error handling and action registry.
3. Input mapping and screen navigation.
4. Settings and filesystem ownership.
5. Website/PWA behavior and documentation consistency.
