# Quality gates

Run checks relevant to the changed component. Do not claim a full test pass if only a subset was executed.

## Repository hygiene

```sh
git diff --check
git status --short
```

## muOS frontend

- Compile changed Lua files with the project's supported LuaJIT/Lua compiler.
- Run the frontend smoke test where its dependencies are available.
- Capture the changed screens using [the screenshot workflow](SCREENSHOTS.md).
- Inspect screenshots for clipping, focus visibility, contrast, missing icons and safe-area issues at 640×480.
- Test on target hardware before describing the change as hardware-verified.

## Shell and Python

- Run `bash -n` or `sh -n` according to the script's declared interpreter.
- Run the component's unit tests and package verification scripts.
- Test destructive or install operations only against disposable fixtures.

## Platform status

The root README is the source of truth for support status. In particular, do not promote an experimental port to supported based only on syntax checks or dry-run tests.
