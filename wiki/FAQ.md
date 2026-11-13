# Frequently Asked Questions

## Why are GameCube and Wii missing from Content Explorer?

Run the registration check and inspect its result:

```sh
sh /opt/muos/share/emulator/dolphin/RtSys/manifest_tool.sh status
```

If missing or stale, run `ensure` or open Rt:UI **Settings → System → Repair GameCube/Wii registration**. See [[muOS-Registration]].

## Why does a game show different results from another device?

The H700 handhelds, firmware versions, game revisions and Dolphin profiles are not identical. Compare the exact device, muOS version, Game ID, region and Rt:Core profile. See [[Compatibility-Database]].

## Which controller profile should I start with?\n\nStart with **Default** for the GameCube or Wii controller family you are using. Change one profile at a time and compare the exact device and firmware. See [[Controls-and-Profiles]].\n\n## Does a rating of 5 mean full speed on every handheld?

No. It means a tester observed an excellent result on the stated setup. Read the underlying report before applying it to another setup. See [[Rating-Guide]].

## Does submitting a test report immediately change the database?

No. The form prepares a GitHub issue. A maintainer reviews it and updates the tracked JSON source. See [[Reporting-a-Test]].

## Is the Compatibility Database website deployed?

The HTML application is tracked in the repository. A public GitHub Pages URL exists only after the repository owner enables Pages. See [[Compatibility-Site]].

## Can I use the current Andromeda package on Jacaranda?

Do not infer that from the registration detector. The root README lists the supported package for each muOS line. The current v12 release is documented for Andromeda; Jacaranda has its separate legacy release line. See [[Platform-Support]].

## Does Rt:Stream emulate on the handheld?

No. Dolphin runs on the PC; Sunshine streams video and Moonlight decodes it on the handheld. See [[Rt-Stream]].
