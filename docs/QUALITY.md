# Quality gates

Run checks relevant to the changed component. Do not claim a full test pass if only a subset was executed.

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

- Compile changed Lua files with the project's supported LuaJIT compiler.
- Run the frontend smoke test where dependencies are available.
- Capture affected screens with `bash tools/capture-ui.sh --all`.
- Inspect focus visibility, clipping, contrast, missing icons and safe areas at 640×480.
- Test on target hardware before describing a change as hardware-verified.

## Shell and Python

- Run `bash -n` or `sh -n` according to the script's declared interpreter.
- Run the component's unit tests and package verification scripts.
- Test destructive or install operations only against disposable fixtures.

## Platform status

The root README is the source of truth for support status. A dry-run, emulator or Xvfb result does not establish physical-device support.
