# Quality Gates

Run the checks relevant to the changed component. Never claim full validation when only one subset was executed.

## Repository hygiene

```sh
git diff --check
git status --short
```

## Website and data

```sh
python3 -m unittest tests/test_compat_site.py -v
```

Verify JSON endpoints, local PWA icons, inline JavaScript syntax and desktop/mobile layouts. Test offline behavior after a successful online load.

## muOS frontend

- Compile changed Lua files with the supported LuaJIT compiler.
- Run the frontend screen smoke test when dependencies are available.
- Capture affected screens with `bash tools/capture-ui.sh --all`.
- Inspect focus, clipping, contrast, missing icons and safe areas at 640×480.
- Test on target hardware before describing a change as device-verified.

## Shell, Python and portal

- Run `bash -n` / `sh -n` for the target shell.
- Run Python unit tests and `make lint` / `make test` in `portal/` when applicable.
- Test installers against disposable filesystem fixtures.
- Verify produced package contents and checksums.

## Platform status

The root README is the source of truth for support status. A dry-run, emulator or Xvfb result does not establish hardware support.
