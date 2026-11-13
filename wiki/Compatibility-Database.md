# Compatibility Atlas

The **Dolphin Rt:Core Compatibility Atlas** is the community's GameCube and Wii test browser. It combines the live compatibility catalogue with device/firmware distribution, core/profile references, testing guidance and contribution tools.

## Browse games

1. Select **GameCube** or **Wii**.
2. Search by title, Game ID, notes, tester, device, firmware or profile.
3. Filter by region, boot result, exact rating, handheld or muOS release.
4. Sort by rating, recency, title or test count.
5. Open a title to inspect its individual report history before applying settings.

The Share action preserves console and supported filters in the URL. Favourites are stored locally in the browser and are not uploaded.

## Environment explorer

The **Devices & muOS firmware** section counts actual reports by normalized handheld and firmware label. Missing environment information is counted separately and never assigned to a likely device or firmware.

The **Rt:Core builds & profiles** section reports the observed build and profile vocabulary. Legacy, prerelease and development builds are not interchangeable with published releases. A combined profile test remains a multi-profile result.

## Understanding compatibility

A card summarizes multiple observations. Open the details to compare each tester's device, muOS version, Rt:Core build, profile, Game ID, region, FPS range, boot state, playability and notes.

The score is not a universal guarantee. A result is tied to the hardware, firmware, game region/revision, core build and profile that were tested. Boot and playability are separate fields.

## Submit a test

Use the Atlas **Submit a test report** form. It prepares a GitHub issue for review; the browser does not write to the data file. The report records game identity, rating, FPS, device, firmware, Rt:Core version, profile and observations. You can explicitly mark unknown environment data instead of guessing.

Maintainers validate and merge accepted reports into `dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json`. The same importer also accepts the structured GitHub issue form.

## GameSettings and resources

The GameSettings browser reads `dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json`. Inspect the target game, region, author, notes and INI content before using a community file. Back up your own configuration first.

## Privacy and safety

Do not submit ROMs, BIOS files, firmware images, copyrighted game files, serial numbers, pairing tokens or private logs. Share only configuration text and evidence you are entitled to distribute.

## Site operations

Local preview, Pages deployment, offline/PWA behavior, source endpoints and automated checks are documented in [[Compatibility-Site]]. Data field names and naming conventions are documented in [[Compatibility-Data-Model]].
