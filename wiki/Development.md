# Development

## Host tools

Install only the tools needed by the component you are changing. A typical Linux environment uses Git, Python 3, Bash, LuaJIT, LÖVE 11.5 and Xvfb/Mesa for headless frontend work. Pillow is optional for image contact sheets. The PC portal has its own Python/Tk dependencies; follow `portal/README.md`.

## Clone and orient yourself

```sh
git clone https://github.com/SilverCrow2323/dolphin-rt-core.git
cd dolphin-rt-core
git status --short --branch
```

Before editing, read the target platform's README, changelog and build scripts. Avoid treating `Core_History/` as the current implementation.

## Frontend

```sh
cd "dolphin-rtcore-muos/app/Dolphin RtUI"
love . --screen=library
```

The logical UI canvas is 640×480. For repeatable captures from repository root use:

```sh
bash tools/capture-ui.sh --all
```

## Tests

From the repository root, run the checks relevant to the changed component:

```sh
bash -n tools/capture-ui.sh tools/publish-wiki.sh
python3 -m unittest tests/test_repo_tools.py tests/test_compat_site.py -v
bash tests/test_ports_dryrun.sh
```

The GitHub Actions workflow also checks Lua syntax, the frontend stream library, portal tests, package building and archive integrity. Read the workflow to see the exact current matrix.

## Safe development data

- Use temporary HOME/data directories and synthetic ROM metadata.
- Never point destructive tests at a real SD card or a user's Dolphin directory.
- Never commit local settings, logs, pairing credentials or machine-specific paths.
- Test shell scripts with the exact shell available on the target firmware.
