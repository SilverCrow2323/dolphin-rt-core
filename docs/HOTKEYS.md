# Hotkeys

Dolphin Rt:UI supports two mutually exclusive hotkey paths. The active path is
selected by \`[Hotkeys1] Device\` in the profile's \`Hotkeys.ini\`.

## Keyboard mode (bundled Default)

The bundled profile uses:

\`\`\`ini
[Hotkeys1]
Device = Keyboard
\`\`\`

In this mode, Dolphin receives keyboard keys and \`gptokeyb2\` translates the
handheld buttons to those keys using
\`workshop/hotkeys/Default/ext-dolphin.gptk\`. The default modifier is SELECT:

| Handheld combo | Emulated key |
|---|---|
| SELECT + L1 / R1 | F1 / F2 |
| SELECT + L2 / R2 | F3 / F4 |
| SELECT + A / B | F5 / F6 |
| SELECT + D-pad Up / Down | F7 / F8 |
| SELECT + D-pad Left / Right | F9 / F10 |
| SELECT + X / Y | F11 / F12 |
| SELECT + MENU | Escape |

The launcher starts \`gptokeyb2\` only in this keyboard mode.

## Native SDL pad mode

For direct Dolphin controller input, the profile uses:

\`\`\`ini
[Hotkeys1]
Device = SDL/0/muOS-Keys
Keys/Save State Slot 1 = \`Button 11\`
\`\`\`

The Hotkey Designer in \`ui/screens/hotkeys.lua\` writes Dolphin button
expressions from \`core/app_input.lua\`'s muOS Andromeda map. For the H700,
the important indices are A=1, B=0, L1=4, R1=5, SELECT=6, START=7,
MENU=8, L2=9, L3=11 and R2=12. Button 10 is the physical Volume Up key.

In native SDL mode, the launcher does **not** start \`gptokeyb2\`; Dolphin
handles the bindings directly. This prevents keyboard-injection hotkeys from
running alongside native SDL hotkeys. D-pad directions are hats rather than
\`Button N\` inputs and cannot be saved as native button expressions by the
current designer.

## Safe Exit

The muOS overlay exit watcher handles START + SELECT independently of
\`Hotkeys.ini\`. It is a process-exit safety path, not the Dolphin
\`Keys/Exit\` binding edited in the Hotkey Designer.

## Editing

1. Open the Hotkeys editor and select a profile.
2. Choose Keyboard or Pad with L1/R1.
3. In Pad mode, press A on an action and then press the desired button combo.
4. Hold the combo briefly to commit; the editor warns about unsupported
   D-pad or unmapped inputs.
5. Press START to save. B returns to the profile list; unsaved changes prompt
   before leaving.
