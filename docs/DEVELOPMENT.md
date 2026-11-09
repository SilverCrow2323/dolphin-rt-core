# Development setup

## Host tools

Install the tools required by the component you are changing. Typical Linux tools:

- Git, Python 3 and Bash.
- LuaJIT / Lua compiler for Lua syntax checks.
- LÖVE 11.5 for frontend execution.
- Xvfb and Mesa software rendering for headless visual checks.
- Pillow (optional) for contact sheets and richer image metadata.
- GitHub CLI (`gh`) only if you intend to publish the Wiki using the helper.

Do not assume every platform package can be built on every host. Follow the platform-local README and build scripts.

## Clone and inspect

```sh
git clone https://github.com/SilverCrow2323/dolphin-rt-core.git
cd dolphin-rt-core
git status --short --branch
```

Before editing, identify the target deliverable and read its README, changelog and build/test scripts. Avoid making changes directly in the historical archive unless the task is explicitly archival.

## Frontend development

```sh
cd "dolphin-rtcore-muos/app/Dolphin RtUI"
love . --screen=library
```

Use the repository's existing LÖVE version and runtime environment. The app has a logical 640×480 canvas; alternate physical resolutions are letterboxed by the frontend. For reproducible screenshots see [SCREENSHOTS.md](SCREENSHOTS.md).

The existing `core/devshot.lua` hook supports:

```sh
DOLPHINUI_SHOT=/tmp/library.png:2.0 love . --screen=library
DOLPHINUI_SHOT=/tmp/triage.png:2.0 DOLPHINUI_SHOT_PADS="R1,A,DOWN" love . --screen=triage
```

The hook is opt-in and should remain inert during normal device use.

## Safe development data

- Use temporary HOME/data directories and synthetic ROM metadata in tests.
- Never point destructive tests at a real SD card or a user's Dolphin directory.
- Do not commit generated screenshots, logs, local settings, pairing credentials or machine-specific paths.
- Keep shell scripts compatible with BusyBox/POSIX where they run on handheld firmware.
