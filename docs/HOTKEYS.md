# Hotkeys

## 1. Format

`Config/Hotkeys.ini`:

```ini
[Hotkeys1]
Device = SDL/0/muOS-Keys
Keys/Exit = `Button 9` & `Button 7`
Keys/Save State Slot 1 = `Button 9` & `Button 1`
Keys/Load State Slot 1 = `Button 9` & `Button 0`
...
```

Expressions are Dolphin syntax: backtick-wrapped button tokens
joined by `&`. `hotkey_editor.lua` builds and parses these.

## 2. Bundled profile

`workshop/hotkeys/Default/Hotkeys.ini`:

| Action | Binding |
|---|---|
| Exit | SELECT + START |
| Save State 1 | SELECT + A |
| Load State 1 | SELECT + B |
| Toggle Pause | SELECT + X |
| Fast Forward | SELECT + Y |
| Reset | SELECT + L1 |

## 3. Live Menu override

When Live Menu is enabled, `launch.sh` swaps in
`scripts/livemenu/Hotkeys.internal.ini` before starting Dolphin.
The user's file is preserved as `Hotkeys.ini.user`. The frontend
re-applies the chosen hotkey profile on every launch, so no state
is lost.

## 4. Editor

`workshop_hotkey_edit.lua` binds one action at a time:

1. Navigate to the row, [A] to start capture.
2. Press one or more buttons. Release to commit.
3. Commit fires 1.5 s after the last button or on [Enter].
4. [X] clears the binding, [Y] resets the file to Default.

Capture mode is global: `State.capture_mode = true` while
capturing, so main.lua routes raw pad events directly.

## 5. Native exit

Comfort Zone ships a native hotkey: **START + SELECT**. This sends
SIGTERM directly to Dolphin, clean process termination, no memory
card corruption. It is independent of the Hotkeys.ini bindings.
