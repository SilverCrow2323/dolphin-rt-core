# Frequently Asked Questions

## Why are GameCube and Wii missing from Content Explorer?

Run the registration check and inspect its result:

```sh
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh status
```

If missing or stale, open **Settings > System > Repair GameCube/Wii registration**. Startup also runs `ensure` automatically. See [[muOS-Registration]].

## Why does a game show different results from another device?

The H700 handhelds, firmware versions, game revisions and Dolphin profiles are not identical. Compare the exact device, muOS version, Game ID, region and Rt:Core profile. See [[Compatibility-Database]].

## Does a rating of 5 mean full speed on every handheld?

No. It means a tester observed an excellent result on the stated setup. Read the underlying report before applying it to another setup. See [[Rating-Guide]].

## Does submitting a test report immediately change the database?

No. The form prepares a GitHub issue. A maintainer reviews it and updates the tracked JSON source. See [[Reporting-a-Test]].

## Is the Compatibility Database website deployed?

The HTML application is tracked in the repository. A public GitHub Pages URL exists only after the repository owner enables Pages. See [[Compatibility-Site]].

## Can I use the current Andromeda package on Jacaranda?

Do not infer that from the registration detector. The root README lists the supported package for each muOS line. The current v12 release is documented for Andromeda; Jacaranda has its separate legacy release line. See [[Platform-Support]].

## Does Rt:Stream emulate on the handheld?

No. Dolphin runs on the PC; Sunshine streams video and Moonlight decodes it on the handheld. See [[Rt-Stream]].

## Should I delete Sys/GameSettings or Sys/Load/GraphicMods?

No. They contain official Dolphin resources. Keep them intact; use Rt:UI's GameSettings and Mod Vault interfaces for game-specific changes. See [[Graphics-Mods]].

## Does “All Games” activate a graphics mod for every title?

No. It means the mod's marker matches every Game ID. The mod remains disabled until you enable it in that game's Mod Vault. Dolphin stores the enabled state in the per-game profile under Config/GraphicMods. See [[Graphics-Mods]].

## What does the M key show?

M expands the Rt:UI header into the scrollable Rt:System Status Center. It shows Wi-Fi/battery telemetry, Rt:Stream portal and Sunshine health, local database state, GameSettings deployment, library status, background operations and notification history. See [[Rt-System-Status-Center]].
