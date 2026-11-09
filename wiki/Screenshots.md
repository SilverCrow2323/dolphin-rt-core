# Screenshots

The muOS LÖVE frontend has an opt-in screenshot hook in `core/devshot.lua`. It is inert unless `DOLPHINUI_SHOT` is set.

From the repository root:

```sh
bash tools/capture-ui.sh library
bash tools/capture-ui.sh --screen triage --pads "R1,A,DOWN" --output /tmp/triage.png
bash tools/capture-ui.sh --screens "boot,library,settings,triage"
bash tools/capture-ui.sh --all
```

Requires LÖVE 11.5 and either an X11 display or `xvfb-run`. The `--all` option iterates the screens registered by the frontend and continues after individual failures.

Inspect images manually. A successful process only proves a PNG was written; it does not prove the correct state rendered. For handheld changes, include separately labelled real-device evidence where possible.

Generated captures are written below `artifacts/`, which is ignored by Git. Do not commit screenshots of personal ROM lists, usernames, tokens or other private data.
