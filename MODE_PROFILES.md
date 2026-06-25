# Granular Mode Profiles

This branch adds a separate GameServerApp blueprint:

```text
blueprints/renegade-x-gsa-windows-mode-profiles.json
```

It is designed for one dedicated mode per server and applies its selected profile every time the container starts.

## Mode selection

| GSA profile | Engine game class | Suitable maps |
| --- | --- | --- |
| Command & Conquer | `RenX_Game.Rx_Game` | `CNC-*` |
| All Out War (CnC profile) | `RenX_Game.Rx_Game` | `CNC-*` |
| Defense Survival | `RenX_Coop.Rx_Game_Survival` | `DEF-DarkNight`, `DEF-HillSide` |

All Out War is deliberately implemented as a CnC-class rules preset. Totem Arts' shipped map profile configuration exposes CnC and Defense Survival game classes; it does not expose a distinct `AOW` game class. The AOW preset therefore changes CnC-compatible rules, rather than pretending a separate engine class exists.

Do not mix `DEF-*` maps with CnC/AOW maps in one rotation.

## What is mode-specific

### Defense Survival

The profile applies settings under:

```ini
[RenX_Coop.Rx_Game_Survival]
```

in `UDKSurvival.ini`, including player-start behavior, economy, commanders, wave timing, concurrent-enemy cap, wave rewards, and the adaptive Frustration mechanic.

### CnC and AOW

The profiles apply settings under:

```ini
[RenX_Game.Rx_Game]
```

in `UDKRenegadeX.ini`, including credits, timers, team organization, crates, power-up drops, donations, vehicle limits, commander CP, building revival, airdrops, overtime, sudden death, surrender, and bot filling.

The AOW profile defaults airdrops and bot filling to on. The individual controls remain editable, so a host can change either behavior.

## Granular voting controls

The profile handler applies these values to the active mode's INI section:

| GSA setting | INI key | Effect |
| --- | --- | --- |
| Force Fixed Rotation | `bFixedMapRotation` | Bypasses normal map voting and follows the listed rotation. |
| Map Vote Choices | `MaxMapVoteSize` | Maximum maps offered in a vote. |
| Recently Played Maps Excluded | `RecentMapsToExclude` | Keeps recent maps out of the next vote. |
| Map Vote Duration Seconds | `MapVoteTime` | Length of the voting period. |
| Change Map Vote Lockout Seconds | `ChangeMapDisabledTime` | Initial time before change-map voting is available. |
| Admins Can Start Map Votes | `bAdminsStartMapVote` | Lets admins begin map votes where supported. |
| Ignore Bot Votes | `bBotVotesDisabled` | Prevents bots from influencing votes. |
| Remove Map Variants From Vote | `bRemoveVariantMapsInVoteList` | Removes variant duplicates where the game supports the key. |

## Recommended initial presets

### Public Survival

```text
Server Mode Profile: Defense Survival
Starting Map: DEF-DarkNight
Map Cycle Class: Survival
Map Rotation: DEF-DarkNight,DEF-HillSide
Minimum Players: 1
Wait For Minimum Players: Off
Maximum Active Enemies: 40
Enable Adaptive Frustration: On
Force Fixed Rotation: Off
Ignore Bot Votes: On
```

### Standard CnC

```text
Server Mode Profile: Command & Conquer
Starting Map: CNC-Field
Map Cycle Class: CnC / AOW
Map Rotation: CNC-Field,CNC-Walls,CNC-GoldRush
Enable Vehicle Airdrops: Off
Fill Empty Slots With Bots: Off
Force Fixed Rotation: Off
```

### Casual AOW-style CnC

```text
Server Mode Profile: All Out War (CnC profile)
Starting Map: CNC-Field
Map Cycle Class: CnC / AOW
Map Rotation: CNC-Field,CNC-Walls,CNC-GoldRush
Enable Vehicle Airdrops: On
Fill Empty Slots With Bots: On
Force Fixed Rotation: Off
```

## Deployment note

The new profile script is copied into the container image by the Dockerfile. Build and publish a new image tag before importing the mode-profile blueprint into GSA. Existing server installations should be recreated or moved to that new tag so their bootstrap environment includes `ApplyModeProfile.ps1`.
