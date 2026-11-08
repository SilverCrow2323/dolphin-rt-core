# Screenshots

The muOS frontend has an opt-in screenshot hook in `core/devshot.lua`. From the repository root:

```sh
tools/capture-ui.sh library
tools/capture-ui.sh --screen triage --pads "R1,A,DOWN" --output /tmp/triage.png
tools/capture-ui.sh --screens "boot,library,settings,triage" --out-dir artifacts/screenshots
```

Requires LÖVE 11.5 and either an X11 display or `xvfb-run`. Screen names must match registered frontend screen names. Inspect the PNGs manually; a successful process does not prove the correct screen rendered.

For handheld changes, include a separately labelled real-device capture where possible. Never claim an Xvfb image is hardware evidence.
