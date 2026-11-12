# Hotkeys and Safe Exit

## Input modes

Rt:Core has two distinct hotkey paths. They must not run at the same time:

- **Keyboard:** Dolphin receives keyboard events injected by `gptokeyb2`. Rt:Core starts it only when the selected `Hotkeys.ini` contains `Device = Keyboard`.
- **SDL / Pad:** Dolphin receives button expressions such as `(\`Button 9\` & \`Button 1\`)` directly through SDL. `gptokeyb2` is not started in this mode.

`START` and `SELECT` are not remapped as a global modifier in the bundled keyboard profile. This keeps them available to games.

## Bundled keyboard profile

The Default `ext-dolphin.gptk` uses the native gptokeyb2 state-machine format: holding L2 enters the `rt_hotkeys` layer, and the selected button emits a function key. The old pseudo-syntax `l2+a = F1` is not valid gptokeyb2 configuration and silently left hotkeys inactive.

| Action | Default keyboard combo | Dolphin key |
|---|---|---|
| Save State 1 | L2 + A | F1 |
| Load State 1 | L2 + B | F2 |
| Save State 2 | L2 + X | F3 |
| Load State 2 | L2 + Y | F4 |
| Save State 3 | L2 + L1 | F5 |
| Load State 3 | L2 + R1 | F6 |
| Toggle Pause | L2 + Up | F7 |
| Fast Forward | L2 + Down | F8 |
| Frame Limit − / + | L2 + Left / Right | F9 / F10 |
| Screenshot | L2 + R2 | F11 |
| Reset | Unbound by default (configure in RtUI) | — |
Safe Exit is not a Dolphin keyboard hotkey: the Safe Exit watcher reads MENU / M (or the user-recorded combo) directly from the raw controller stream.

The launchers start gptokeyb2 before Dolphin opens the controller and do **not** pass a positional process name. In gptokeyb2, that first argument becomes the process target for the START + hotkey kill action (the default hotkey is BACK / SELECT). The legacy `-1` flag is ignored by current gptokeyb2; omitting the process name is what disables the kill action. Rt:Core Safe Exit remains the only game-exit handler.

The hotkey designer can change the combo and emitted key. The table above describes the shipped Default keyboard profile, not a restriction on user profiles.

## Safe Exit

Safe Exit is a separate raw-button watcher, not Dolphin's ordinary `Hotkeys.ini` exit action.

- Default: **MENU / M only** (RG35XX H joydev button index 8).
- RTUI → Settings → Safe Exit records a single MENU button or a combination of 2–4 buttons.
- The selected raw joydev button indices are saved in `data/safe_exit.conf` and shared by RTUI and the muOS Content Explorer launcher.
- The watcher requests graceful termination first and uses a forced termination only as a fallback.

The default no longer uses START+SELECT, and START is not used by the default L2 hotkey layer. The watcher reads button events and does not synthesize input or remap gameplay buttons. A custom combination should avoid buttons needed by the current game.

## Troubleshooting

1. Confirm the selected profile is not Disabled.
2. Confirm the launcher calls `gptokeyb2 -c <profile>` without a positional `dolphin` argument; passing a process name enables the START + SELECT kill action.
3. Check that the Default `.gptk` contains `[controls]`, `l2 = hold_state rt_hotkeys`, and `[controls:rt_hotkeys]`; plain `l2+a = f1` lines are not valid gptokeyb2 FSM syntax.
4. For keyboard mode, check that `Device = Keyboard` is in the copied `Config/Hotkeys.ini` and that `lib/gptokeyb2` is executable.
4. For pad mode, confirm `Device` is an SDL device, then make sure `gptokeyb2` is not running for that session.
5. Check `data/logs/gptokeyb2_*.log` or `data/logs/gptokeyb2-content-explorer.log` and the Safe Exit watcher log.
6. If START or SELECT is still intercepted, test with the Default profile and inspect other installed remappers or muOS-level hotkeys before changing Dolphin's own mappings.

Physical-device validation is required to confirm the button numbering on a particular controller/firmware combination.
