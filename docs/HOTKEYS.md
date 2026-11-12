# Hotkeys and Safe Exit

> [!IMPORTANT]
> Keep three input-numbering layers separate: Linux `EV_KEY`, joydev `/dev/input/js1`, and Dolphin's SDL `Button n` tokens. They are not interchangeable. See [Controller input reference](CONTROLLER_INPUT.md).

## Input modes

Rt:Core has two distinct hotkey paths. They must not run at the same time:

- **Keyboard:** Dolphin receives keyboard events injected by `gptokeyb2`. Rt:Core starts it only when the selected `Hotkeys.ini` contains `Device = SDL/0/Keyboard Mouse`.
- **SDL / Pad:** Dolphin receives button expressions such as `(`Button 9` & `Button 1`)` directly through SDL. `gptokeyb2` is not started in this mode.

`START` and `SELECT` are not global modifiers in the bundled keyboard profile, so games retain those controls.

The Hotkey Designer reads legacy `[Hotkeys1]` / `Keys/...` profiles and translates known actions; saving writes the Dolphin 2606 `[Hotkeys]` schema. Pad profiles use `Device = SDL/0/muOS-Keys`; virtual-keyboard profiles use `Device = SDL/0/Keyboard Mouse`.

## Bundled keyboard profile

The Default `ext-dolphin.gptk` uses the native gptokeyb2 state-machine format: holding L2 enters the `rt_hotkeys` layer, and the selected button emits a function key. The old pseudo-syntax `l2+a = F1` is not valid gptokeyb2 configuration.

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

The hotkey designer can change the combo and emitted key. The table describes the shipped Default keyboard profile, not a restriction on user profiles.

The launchers start gptokeyb2 before Dolphin opens the controller and do **not** pass a positional process name. In gptokeyb2, that first argument becomes the process target for the START + configured hotkey kill action (the default hotkey is BACK / SELECT). Omitting the process name disables that built-in kill action; Rt:Core Safe Exit remains the game-exit handler.

## Safe Exit

Safe Exit is a separate joydev watcher. It is not Dolphin's ordinary `Hotkeys.ini` exit action.

<details>
<summary><strong>Default combination and raw joydev numbers</strong></summary>

- Default: **START + SELECT**.
- On the documented RG35XX H `js1` sequence: **SELECT = 8**, **START = 9**.
- The watcher default is `8,9` in `data/safe_exit.conf`.
- A single-button exit is allowed only for **MENU / M**, which is joydev index **10** in this sequence.
- The RTUI editor records a single MENU button or a combination of 2–4 buttons. The selected indices are shared with the muOS Content Explorer launcher.

The watcher requests graceful termination first and uses forced termination only as a fallback. It does not synthesize keyboard events or remap gameplay buttons.

</details>

The RTUI launcher and Content Explorer launcher both prefer `/dev/input/js1`, then `js0`, then another available `js*` character device. A matching name in `/proc` is not enough: the node must be a usable character device. If none is available, Safe Exit is disabled and the launcher log records the reason.

## Troubleshooting

1. Confirm the selected hotkey profile is not Disabled.
2. Confirm the launcher calls `gptokeyb2 -c <profile>` without a positional `dolphin` argument.
3. Check that the Default `.gptk` contains `[controls]`, `l2 = hold_state rt_hotkeys`, and `[controls:rt_hotkeys]`; plain `l2+a = f1` lines are not valid gptokeyb2 FSM syntax.
4. For keyboard mode, check that `Device = SDL/0/Keyboard Mouse` is in the copied `Config/Hotkeys.ini` and that `lib/gptokeyb2` is executable.
5. For pad mode, confirm `Device = SDL/0/muOS-Keys` and that gptokeyb2 is not running for that session.
6. Check `data/logs/gptokeyb2_*.log`, `data/logs/gptokeyb2-content-explorer.log`, the launch log and the Safe Exit watcher log.
7. If START or SELECT is intercepted, test with the Default profile and inspect other installed remappers or muOS-level hotkeys before changing Dolphin's own mappings.

Physical-device validation is required for each firmware/controller combination. CI verifies syntax and the launch contract; it cannot certify the physical button stream.
