# Compatibility Data Model

The Compatibility Database and the LÖVE Rt:UI frontend read the same schema v2 compatibility database. The website reads the bundled Rt:UI JSON; the handheld boot updater also serves a root JSON copy into the runtime data directory. These two tracked copies must remain byte-identical.

## Source files

- dolphin-rtcore-muos/app/Dolphin RtUI/data/games_data.json — canonical bundled database and website source.
- data/games_data.json — runtime download endpoint used by the handheld boot initializer.
- dolphin-rtcore-muos/app/Dolphin RtUI/data/gamesettings.json — GameSettings and shared resources.

Do not update one compatibility database copy without updating the other. tools/normalize_games_data.py verifies parity in --check mode and writes both with --write.

## Schema v2

The root contains:

| Field | Meaning |
|---|---|
| version | Existing dataset revision field retained for older consumers |
| schema_version | Data contract version; currently 2 |
| last_update | Date of the latest imported report, not the schema migration date |
| catalogs | Canonical device, muOS, Rt:Core and core-profile labels |
| games | Grouped game identities and their independent reports |

Each game group contains game_info and entries. The canonical identity is the tuple Game ID + system + region. The game title is canonical display text but does not replace the Game ID. If two entries carry different Game IDs, they belong to different groups even when the title is identical.

## Report structure

| Object | Fields | Meaning |
|---|---|---|
| game_info | game_id, system, game, region, optional revision | Exact title and release identity |
| test_review | rating, fps, boot, playable, fps_min, fps_max, optional date | Observed outcome and actual gameplay performance |
| test_details | rtcore_version, core_profile, considerations, optional Dolphin build, backend, duration, scene and subsystem states | Runtime and test conditions |
| test_environment | tester, device, muos_version, optional device_revision and date | Tester, hardware and firmware actually used |
| cover_art | URL or empty string | Optional artwork reference |
| custom_settings | list | Optional per-game configuration |
| attachments | list | Optional public evidence links |

Optional detail fields include dolphin_version, graphics_backend, test_duration_minutes, test_scene, audio, graphics, input and stability. Subsystem values are Not tested, Clean, Minor issues or Major issues. Do not report a subsystem as clean unless it was checked.

Ratings range from 0 to 5. Boot is YES, NO or CRASH. Playability is YES, YES WITH ISSUES or NO. When FPS was not measured, use fps=N/A and set the numeric bounds to zero. A known FPS range must be measured in actual gameplay, not in menus or the boot animation.

## Canonical catalogues

The catalogs object contains unique arrays for devices, muos_versions, rtcore_versions and core_profiles. Use the exact canonical spelling in new entries. Custom values are accepted only when the tester records an actual value not yet listed. Empty firmware is retained as not recorded; a generic Jacaranda label without a version remains muOS Jacaranda (version not specified), not 2601.1 by assumption. Unknown hardware is Unspecified, not a guessed handheld.

Known alias normalization includes RG35XX H spelling variants, RG34XX SP spelling variants, firmware naming variants, Rt:Core prerelease capitalization and profile capitalization. It does not combine different releases or distinct test configurations.

## Data integrity rules

- Preserve every independent test session and original tester attribution.
- Group only by Game ID + system + region.
- Keep regions and systems separate.
- Keep different devices, firmware builds, Rt:Core versions and profiles as separate entries.
- Do not infer missing FPS, firmware, device or Dolphin build metadata.
- Keep rating, boot and playability values consistent with the Rating Guide.
- Never store ROMs, BIOS, firmware images, copyrighted game files, private logs or personal device identifiers.

## Normalization and validation

Run:

~~~sh
python3 tools/normalize_games_data.py --check
python3 -m unittest tests/test_compat_site.py -v
~~~

The normalizer is idempotent and verifies that both tracked copies match the same canonical content. To intentionally migrate known aliases or repair group identity / copy drift, review the diff and then run:

~~~sh
python3 tools/normalize_games_data.py --write
~~~

The website report form reads catalogues from this same JSON and prepares a GitHub issue. Maintainers review and validate the issue before importing a report. See [[Reporting-a-Test]], [[Rating-Guide]] and [[Compatibility-Site]].
