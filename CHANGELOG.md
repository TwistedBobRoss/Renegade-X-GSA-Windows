# Changelog

All notable changes to the Renegade X GameServerApp Windows blueprint are tracked here.

## 1.7.3 - 2026-09-14

### Changed

- Pinned the GSA blueprint image to the exact tested `1.2.1109-core20-ltsc2022-r3` compatibility tag instead of the rolling `stable-core20-ltsc2022` tag.
- Added an explicit `stable` default for the runtime update channel dropdown.
- Added a build input for producing RenX 1.2 compatibility images from the last working `1.0.1022-core20-ltsc2022-r12` base.

### Fixed

- Restored the last working GSA-facing host mount and registered directory layout under `\renx-data`.
- Moved editable GSA INI templates back to `\renx-data\Config` so the installer has default config files in a persistent path that exists before the Renegade X runtime is seeded.

## 1.7.2 - 2026-09-14

### Fixed

- Restored a small default GSA config template for install/access/content/update basics, while keeping map voting and rotation INI-first.
- Reconnected the startup map, Admin/RCON password, listing, content, runtime update, payload, and optional-map values to explicit config-template fields so GSA has defaults to render during install.

## 1.7.1 - 2026-09-14

### Fixed

- Moved the GSA-exposed INI files back under `\renx-data\ServerFiles\UDKGame\Config` so the installer sees a conventional server-files config path.
- Imported newer GSA-written INIs into persistent config before seed install or runtime auto-update, preventing map/vote config from being overwritten during startup.
- Bumped the full-image rebuild default to `1.2.1109-core20-ltsc2022-r2` while keeping the blueprint on the rolling `stable-core20-ltsc2022` tag.

## 1.7.0 - 2026-09-14

### Changed

- Updated the packaged Totem Arts runtime to Renegade X `Release 1.2.1109` / `18038`.
- Updated the release manifest, workflow defaults, and payload URLs for the `renx-core20-1.2.1109-r1` release assets.
- Simplified the GSA blueprint to use normal editable INI files with zero custom config-parameter fields.
- Kept only essential Docker environment values in the blueprint: server identity, slots, ports, RCON password, payload fallback URLs, and restart-time auto-update settings.

### Fixed

- Reduced the blueprint install surface so GSA no longer has to render and validate dozens of config-template tabs before installing a server.
- Made common gameplay settings prefer persistent INI values after install, matching the INI-first map voting behavior.
- Made the full-image workflow retry each payload chunk download and verify recorded size/hash before assembling the runtime zip.

## 1.6.0 - 2026-09-14

### Changed

- Made map voting and rotation INI-first so edited `UDKGame.ini`, `UDKMapList.ini`, `UDKRenegadeX.ini`, and `UDKSurvival.ini` values are preserved across restarts.
- Added normal `GameSpecificMapCycles` entries to the GSA blueprint's `UDKGame.ini` template and aligned the default recent-map vote exclusion with RenX 1.1.
- Kept runtime auto-update enabled by default so the container checks the release manifest each time it starts.

### Fixed

- Preserved repeated `GameSpecificMapCycles` entries instead of replacing every map cycle with one generated line.
- Synced the active map cycle into `UDKMapList.ini` so map travel and the voting list stay aligned.
- Preserved Survival game-class selection through the final launcher handoff instead of clearing it when no separate mode-profile field was present.
- Prevented the mode-profile helper from overwriting INI-sourced vote settings after startup.

## 1.5.4 - 2026-07-10

### Changed

- Updated the published GSA blueprint image tag to `1.0.1022-core20-ltsc2022-r12`.
- Updated bootstrap and full-image build workflow defaults to `r12`.

### Fixed

- Startup now applies the host-facing GSA voting and surrender controls into both runtime and default Renegade X config files.

## 1.5.3 - 2026-07-07

### Fixed

- Restored the host-facing GSA voting and surrender controls that were missing from the blueprint.
- Reconnected vote settings to the existing mode-profile environment variables used by the `r11` image.
- Renamed the map-vote count control to `Number Of Maps Available In Vote` so hosts can identify it more easily.

## 1.5.2 - 2026-07-07

### Changed

- Updated the primary Core 20 image and blueprint to `1.0.1022-core20-ltsc2022-r11`.
- Updated bootstrap and full-image build workflow defaults to `r11`.
- Restored the visible `CnC Marathon` blueprint section for Marathon Mode and related controls.

### Fixed

- Reinforced Marathon timing in both runtime and default Renegade X config files so server listings no longer fall back to 50 minutes.
- Preserved non-Marathon time-limit behavior by using `RENX_TIME_LIMIT` for generic `TimeLimit` and `RENX_CNC_TIME_LIMIT` for `CnCModeTimeLimit`.
- Fixed `ApplyModeProfile.ps1` INI update handling and added a full-image smoke test that verifies Marathon `0/0` timing before publish.

## 1.5.1 - 2026-07-03

### Added

- Added `Marathon Mode` to the GameServerApp blueprint.
- Added GSA controls for the generic Renegade X `TimeLimit`, building revival, and vehicle airdrops.

### Changed

- Updated the primary image reference and GitHub Actions defaults to `1.0.1022-core20-ltsc2022-r8`.
- Corrected the `Team Mode` dropdown to use Renegade X numeric `TeamMode` values.
- Documented restart behavior for marathon settings and existing persistent server data.

### Fixed

- Marathon mode now writes both `TimeLimit=0` and `CnCModeTimeLimit=0` instead of only changing the CnC-specific timer.
- Marathon mode now applies the shipped Renegade X recommendations to disable building revival and enable vehicle airdrops.

## 1.5.0 - 2026-06-27

### Added

- Published Windows Server 2022 container support for Renegade X dedicated hosting.
- GameServerApp blueprint with automatic port allocation and editable configuration boxes.
- Verified `Container` monitoring guidance for GameServerApp.
- Persistent server files, config files, logs, and custom content mounts.
- Public master-list support and optional web statistics service.
- Core runtime packaging with 20 maps and optional packaging with 27 additional maps.
- FTP payload preloading guidance for slower first-start installs.
- Expanded README documentation and troubleshooting guidance.

### Changed

- Clarified that source query and RCON monitoring for Renegade X in GSA container environments remain under development.
- Documented the current image tag and blueprint import workflow.
- Added clearer setup notes for map voting, map limits, and server startup behavior.

### Fixed

- Full GameServerApp server names with spaces are handled correctly in the `r7` image line.
- Documentation now distinguishes between verified container monitoring and unverified player-count monitoring paths.

### Notes

- Renegade X remains the property of Totem Arts.
- This is an unofficial community hosting integration maintained by TwistedBobRoss.
