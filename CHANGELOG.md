# Changelog

All notable changes to the Renegade X GameServerApp Windows blueprint are tracked here.

## 1.5.3 - 2026-07-07

### Fixed

- Restored the host-facing GSA voting and surrender controls that were missing from the blueprint.
- Reconnected vote settings to the existing mode-profile environment variables used by the `r11` image.

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
