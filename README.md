# Renegade X for GameServerApp on Windows

Ready-to-use Windows container and GameServerApp blueprint for hosting Renegade X dedicated servers.

Renegade X is Totem Arts' free tactical first-person shooter and real-time strategy hybrid inspired by Command & Conquer: Renegade. Players fight as GDI or Nod, purchase infantry and vehicles, defend their base, destroy enemy structures, and coordinate across large combined-arms battlefields. The game also includes Defense Survival, a cooperative wave mode that is well suited to private groups and community events.

This project packages a tested Renegade X `1.0.1022` headless runtime, persistent configuration, optional map downloads, logs, and GameServerApp controls into a Windows Server 2022 container.

## Project Information

- Container and blueprint author: **TwistedBobRoss**
- Game developer: **Totem Arts**
- Project type: unofficial community hosting integration
- Host operating system: Windows Server 2022 with Windows containers
- Primary image: `ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-core20-ltsc2022-r11`
- Raw blueprint: [renegade-x-gsa-windows.json](https://raw.githubusercontent.com/TwistedBobRoss/Renegade-X-GSA-Windows/main/blueprints/renegade-x-gsa-windows.json)
- Repository: [TwistedBobRoss/Renegade-X-GSA-Windows](https://github.com/TwistedBobRoss/Renegade-X-GSA-Windows)
- Release notes: [CHANGELOG.md](CHANGELOG.md)

Renegade X remains the property of Totem Arts. This repository does not claim ownership of the game or its assets.

## What This Provides

- Prebuilt Windows Server 2022 container
- GameServerApp blueprint with automatic port allocation
- Tested 20-map core runtime
- Three optional map packs containing 27 additional maps
- Standard Command & Conquer and Defense Survival launch profiles
- Editable GSA configuration boxes
- Persistent server files, configs, custom content, payload cache, and logs
- Public master-server listing support
- Reliable container-based GSA monitoring
- Optional Renegade X web statistics service
- Bot count, difficulty, and behavior controls
- Map voting and rotation controls
- Custom maps, packages, mutators, and HTTP redirect support
- Automatic recovery download when the baked runtime is unavailable
- FTP payload preloading for installations with slow first-start downloads

## Requirements

- Windows Server 2022 or another host compatible with LTSC 2022 Windows containers
- GameServerApp Dediconnect installed and connected
- Docker configured to run Windows containers
- Enough disk space for the Windows image, persistent runtime, maps, and Docker layers
- Public UDP ports when hosting an internet server

The full image includes a 20-map core runtime. The first pull can take time because Windows container layers are large even though the running server uses comparatively little memory.

## GameServerApp Installation

Download the published blueprint from the GameServerApp Marketplace. For manual import or review, use:

```text
https://raw.githubusercontent.com/TwistedBobRoss/Renegade-X-GSA-Windows/main/blueprints/renegade-x-gsa-windows.json
```

Create a server from the blueprint, choose its slot limit, review the settings, and install it. GSA assigns the game, peer, reserved query, and optional web ports automatically.

Use **Container** monitoring in the GSA blueprint. It reliably reports whether the server process is running, but it does not display player counts or player names. Source Query and RCON integration for Renegade X in GSA container environments remain under development.

### Recommended First Test

```text
Starting Map = CNC-Field
Game Class Override = Normal / map prefix
Map Cycle Class = Standard CnC
List Server = On
Fixed Map Rotation = Off
Disable Bots = Off
Enable Steam = On
Enable Web Server = Off
Maximum players = 40 or fewer for CNC-Field
```

The Renegade X engine supports a maximum of 64 players. Individual maps may have lower practical or configured limits. The container clamps a larger GSA slot setting to 64 before launch.

### Marathon CnC Preset

For a no-time-limit CnC server, use:

```text
Starting Map = CNC-Field
Game Class Override = Normal / map prefix
Map Cycle Class = Standard CnC
Marathon Mode = On
```

`Marathon Mode` forces `TimeLimit=0` and `CnCModeTimeLimit=0`, disables building revival, and enables vehicle airdrops. Leave it off for timed All Out War style matches where overtime, sudden death, and building revival are intended.

### Defense Survival Preset

```text
Starting Map = DEF-DarkNight
Game Class Override = Survival
Map Cycle Class = Survival
Map Rotation = DEF-DarkNight,DEF-HillSide
List Server = On
Disable Bots = Off
Minimum Net Players = 1
Wait For Net Players = Off
```

Survival mode uses:

```text
RenX_Coop.Rx_Game_Survival
```

Its wave and frustration settings are stored in `UDKSurvival.ini` after the runtime creates or copies that file.

## Updating An Existing Server

Changing only an editable INI value normally requires a server restart.

Changing the image tag, Docker environment variables, mounts, or blueprint directory types requires GSA to recreate or reinstall the container. The persistent mount must remain:

```text
\renx-data
```

Do not wipe `renx-data` unless you intentionally want to remove the server runtime, configs, maps, downloads, and logs.

## Public Server Listing

To appear in the Renegade X server browser:

- Enable the GSA option that exposes the server publicly.
- Set `List Server` to `On`.
- Keep `bListed=true` in `UDKRenegadeX.ini`.
- Keep Steam enabled unless you are deliberately operating a private test.
- Allow the GSA-assigned UDP game, peer, and query ports through Windows Firewall and any upstream firewall or router.
- Allow outbound TCP `21337` to `devbot-rx.totemarts.services`; Renegade X uses this fixed remote service port for public-list registration. It is not a server listening port and is not allocated by GSA.
- Wait for the map to finish loading before checking the list.

The public listing name comes from:

```ini
[Engine.GameReplicationInfo]
ServerName={gameserver.list_name}
```

`ServerName` in `UDKWeb.ini` labels the optional web service. It does not control master-server registration.

## Container Images

Primary 20-map image:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-core20-ltsc2022-r11
```

Bootstrap-only recovery image:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r11
```

The primary image is recommended for GSA. It seeds the runtime into persistent storage and avoids downloading the core payload during a normal first start.

## Persistent Storage

The blueprint mounts:

```text
Host:      {container.home_root}/renx-data
Container: C:\renx-data
```

Important paths:

```text
C:\renx-data\ServerFiles                       Installed Renegade X runtime
C:\renx-data\Config                            Persistent editable runtime INIs
C:\renx-data\CustomContent                     Custom maps, packages, and configs
C:\renx-data\CustomContent\_Downloaded         URL-downloaded optional content
C:\renx-data\CustomContent\_Required           URL-downloaded required content
C:\renx-data\CustomContent\_OptionalMaps       Optional map-pack archives
C:\renx-data\PayloadCache                      Reassembled and extracted payload cache
C:\renx-data\PayloadCache\Downloads            FTP-preload location for split payloads
C:\renx-data\Logs                              Persistent game logs
C:\renx-data\Logs\RenegadeXServer.log          Main Renegade X log
```

The Logs directory is registered with GSA as a log source, so `RenegadeXServer.log` appears beside the Docker container log on the server Logs page. The launcher creates this file before starting UDK and mirrors new game-log lines into the live Docker log, allowing both views to update while the server is running.

For public-list troubleshooting, look for:

```text
Public listing endpoint reachable: devbot-rx.totemarts.services:21337
Game engine initialized
MAP Loaded
```

## Ports

GSA assigns ports automatically from these blueprint port types:

| Purpose | Protocol | Container default | GSA variable |
| --- | --- | ---: | --- |
| Game | UDP | `7777` | `{gameserver.game_port}` |
| Peer/raw | UDP | `7778` | `{gameserver.raw_port}` |
| Reserved query compatibility | UDP | `27015` | `{gameserver.query_port}` |
| Optional web service | TCP | `6969` | `{gameserver.other_port}` |

Keep the assigned query port exposed because the game configuration and online subsystem expect it. The web port is unnecessary when `Enable Web Server` is off.

## Included Maps

The core image contains 18 playable maps and two required frontend maps:

```text
CNC-Canyon
CNC-Complex
CNC-Field
CNC-GoldRush
CNC-Islands
CNC-LakeSide
CNC-Mesa
CNC-Oasis
CNC-Under
CNC-Volcano
CNC-Walls
CNC-Whiteout
CNC-Xmountain
DEF-DarkNight
DEF-HillSide
TDM-Caves
TDM-Deck
TDM-UndergroundNetwork
RenX-FrontEndMap
RenX-MenuMap
```

### Optional Map Pack 1

Approximately 616 MiB:

```text
CNC-City
CNC-Crash_Site
CNC-Daybreak
CNC-Desolation
CNC-Forest_Winter
CNC-HeXmountain
CNC-Mines
CNC-Reservoir_Winter
CNC-Tomb
```

### Optional Map Pack 2

Approximately 648 MiB:

```text
CNC-CliffSide
CNC-DarkSide
CNC-Eyes
CNC-Field_2025
CNC-Forest
CNC-Hourglass
CNC-LakeSide_Winter
CNC-Outposts
CNC-Reservoir
```

### Optional Map Pack 3

Approximately 637 MiB:

```text
CNC-Arctic_Stronghold
CNC-Field_Winter
CNC-Field_X
CNC-Snow
CNC-Steppe
CNC-Toxicity
CNC-Tunnels
CNC-Uphill
CNC-Walls_Winter
```

Each pack can be enabled independently. Downloads are cached. Turning a pack off later does not delete files already installed.

## Custom Maps And Mutators

Upload custom content through FTP into:

```text
\renx-data\CustomContent
```

Supported loose files:

```text
.udk  Map
.u    Script package or mutator
.upk  Content package
.ini  Configuration
.int  Localization
.zip  Structured content archive
```

Startup sync rules:

```text
CustomContent\CookedPC\*  -> UDKGame\CookedPC
CustomContent\Maps\*      -> UDKGame\CookedPC\Maps\RenX
CustomContent\Config\*    -> UDKGame\Config
Loose *.udk               -> UDKGame\CookedPC\Maps\RenX
Loose *.u and *.upk       -> UDKGame\CookedPC
Loose *.ini               -> UDKGame\Config
Loose *.int               -> UDKGame\Localization\INT
```

Enter comma-separated mutator classes in the GSA `Mutators` field:

```text
PackageName.MutatorClass,OtherPackage.OtherMutator
```

Public clients may need matching packages. Use channel downloading or an HTTP redirect:

```ini
[IpDrv.TcpNetDriver]
AllowDownloads=true

[IpDrv.HTTPDownload]
RedirectToURL=https://your-content-host.example/
UseCompression=false
```

Keep the redirect files synchronized with the packages installed on the server.

## Configuration Precedence

At startup the wrapper:

1. Installs or validates the persistent runtime.
2. Initializes persistent runtime INIs under `C:\renx-data\Config`.
3. Applies GSA parameters to those INIs.
4. Copies persistent configs into `ServerFiles\UDKGame\Config`.
5. Reinforces managed identity and match settings in both runtime and default config files.
6. Installs optional maps and custom content.
7. Launches `Binaries\Win64\UDK.com`.

Values controlled by GSA parameters are written again at every start. To make an advanced manual change persistent, do not edit a line that a GSA parameter intentionally manages unless you also change the corresponding parameter.

## GameServerApp Parameter Reference

### Launch And Rotation

| Parameter | Default | Purpose |
| --- | --- | --- |
| Starting Map | `CNC-Field` | Initial map name without `.udk`. |
| Game Class Override | Normal / map prefix | Lets the map prefix choose the class, or explicitly launches Survival. |
| Map Cycle Class | Standard CnC | Writes `Rx_Game` or `Rx_Game_Survival` into the generated map cycle. |
| Map Rotation | Core CNC rotation | Comma-separated map names used to generate `GameSpecificMapCycles`. |
| Mutators | blank | Comma-separated mutator class names appended to the launch URL. |
| Extra Launch Args | blank | Raw advanced UDK command-line arguments. |
| Multihome IP | blank | Adds `-MULTIHOME=address` when binding to a specific local address. |

### Installation And Content

| Parameter | Default | Purpose |
| --- | --- | --- |
| Server Payload URLs | Core release parts | Recovery URLs for the core runtime. |
| Refresh Server Payload | Off | Forces payload redownload and runtime replacement on the next start. |
| Install Optional Map Pack 1 | Off | Installs optional map pack 1. |
| Install Optional Map Pack 2 | Off | Installs optional map pack 2. |
| Install Optional Map Pack 3 | Off | Installs optional map pack 3. |
| Optional Map Pack 1 URL | Published release | Public archive URL for pack 1. |
| Optional Map Pack 2 URL | Published release | Public archive URL for pack 2. |
| Optional Map Pack 3 URL | Published release | Public archive URL for pack 3. |
| Required Content URLs | blank | Semicolon-separated content that must be installed before launch. |
| Custom Content URLs | blank | Semicolon-separated optional content downloads. |
| Refresh Content Downloads | Off | Redownloads configured custom content on the next start. |

### Identity And Access

| Parameter | Default | Purpose |
| --- | --- | --- |
| GSA server name | GSA list name | Writes the public server name into `UDKGame.ini` and `UDKWeb.ini`. |
| Admin Password | blank | Writes `AdminPassword`. |
| Server Password | blank | Writes `GamePassword`; blank means no join password. |
| Moderator Password | blank | Writes `ModPassword`. |
| Message Of The Day | blank | Writes `MessageOfTheDay`. |
| List Server | On | Writes `bListed=true`. GSA's public exposure toggle must also be enabled. |
| Require Steam | Off | Writes `bRequireSteam`. |
| Steam Auth Admins | Off | Writes `bSteamAuthAdmins`. |
| Broadcast Admin Identity | Off | Writes `bBroadcastAdminIdentity`. |

### Match And Voting

| Parameter | Default | Purpose |
| --- | --- | --- |
| Maximum players | GSA slot limit | Writes `MaxPlayers`; do not exceed 64. |
| Max Spectators | `2` | Reserved spectator capacity. |
| Initial Credits | `0` | Player starting credits where supported. |
| Marathon Mode | Off | Forces `TimeLimit=0`, `CnCModeTimeLimit=0`, `bBuildingsRevive=false`, and `bEnableAirdrops=true`. |
| Overall Time Limit | `50` | Generic Renegade X `TimeLimit` in minutes. Set `0` to disable it when not using Marathon Mode. |
| CnC Time Limit | `30` | CnC match limit in minutes. Marathon Mode forces this to `0`. |
| DM Time Limit | `20` | Deathmatch limit in minutes. |
| Buildings Revive | On | Allows destroyed buildings to revive. Marathon Mode forces this off. |
| Enable Airdrops | Off | Enables vehicle airdrops. Marathon Mode forces this on. |
| Team Mode | Random shuffle/scramble | Team organization behavior. See numeric values below. |
| Fixed Map Rotation | Off | Enforces the map cycle instead of normal map voting. |
| Map Vote Size | `5` | Maximum choices in the map vote. |
| Recent Maps Excluded | `2` | Number of recently played maps removed from the vote. |
| Spawn Crates | On | Enables crate spawning. |
| Players Must Be Ready | Off | Requires players to ready before match start. |
| Force Respawn | On | Automatically respawns players. |
| Admins Can Pause | Off | Allows administrators to pause. |
| Restart Wait Seconds | `30` | In-game map transition delay, not a GSA scheduled restart. |


### Bots

| Parameter | Default | Purpose |
| --- | --- | --- |
| Disable Bots | Off | Writes `bBotsDisabled`. |
| GDI Bot Count | blank | Launch URL `GDIBotCount`. |
| NOD Bot Count | blank | Launch URL `NODBotCount`. |
| GDI Bot Difficulty | Normal | Bot difficulty value written for GDI. |
| NOD Bot Difficulty | Normal | Bot difficulty value written for Nod. |
| GDI Attack Percent | Balanced | GDI attacking behavior value. |
| NOD Attack Percent | Balanced | Nod attacking behavior value. |

### Network And Downloads

| Parameter | Default | Purpose |
| --- | --- | --- |
| Allow Downloads | On | Allows Unreal channel downloads. |
| HTTP Redirect URL | Totem Arts content service | Fast-download base URL; use a trailing slash. |
| Redirect Uses Compression | Off | Enables compressed redirect packages only when the redirect supports them. |
| Download Timeout | `30` | HTTP download connection timeout in seconds. |
| Max Client Rate | `15000` | Per-client network rate. |
| Max Internet Client Rate | `10000` | Internet client network rate. |
| Server Tick Rate | `30` | Maximum server network tick rate. |
| Enable Steam | On | Enables the Steam online subsystem. |
| Use VAC | Off | Enables VAC where supported. |

### Startup Waiting

| Parameter | Default | Purpose |
| --- | --- | --- |
| Wait For Net Players | Off | Waits for the configured minimum before starting. |
| Minimum Net Players | `1` | Minimum players used by the wait behavior. |
| Net Wait Seconds | `15` | Startup or travel wait duration. |
| Client Processing Timeout | `30` | Client loading/travel timeout. |

### Optional Web Service

| Parameter | Default | Purpose |
| --- | --- | --- |
| Enable Web Server | Off | Enables the optional HTTP statistics service. |
| Web Max Connections | `32` | Maximum simultaneous web connections. |
| Web Port | GSA assigned | Uses `{gameserver.other_port}`. |

## Team Mode Values

The shipped Renegade X `TeamMode` values are:

```text
0 = Static teams
1 = Swap teams
2 = Random swap
3 = Shuffle
4 = Traditional assignment as players connect
5 = Unrestricted traditional; players may change teams
6 = Random shuffle/scramble
```

Standard Renegade X defaults to `6`. Defense Survival defaults to `3`.

## Editable Configuration Files

The GSA configuration template directly exposes:

```text
\renx-data\Config\UDKGame.ini
\renx-data\Config\UDKEngine.ini
\renx-data\Config\UDKRenegadeX.ini
\renx-data\Config\UDKWeb.ini
```

The persistent runtime also contains advanced files under:

```text
\renx-data\ServerFiles\UDKGame\Config
```

Important advanced files include:

```text
UDKMapList.ini
UDKSurvival.ini
UDKPurchaseSystem.ini
UDKRenegadeXAISetup.ini
UDKFPSMonitor.ini
UDKStatAPI.ini
CNC-*.ini
DEF-*.ini
TDM-*.ini
```

## Complete Server Setting Reference

This reference covers every server-relevant setting shipped in the Renegade X `1.0.1022` configuration used by this project. The distribution also contains client controls, graphics, editor, UI, audio, and key-binding settings. Those are intentionally excluded because they do not provide useful dedicated-server behavior.

### `UDKGame.ini`: Core Server Identity And Limits

Section: `[Engine.GameInfo]`

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `DefaultGameType` | `RenX_Game.Rx_Game` | Default game class. |
| `DefaultGame` | `RenX_Game.Rx_Game` | Default game implementation. |
| `DefaultServerGame` | `RenX_Game.Rx_Game` | Dedicated-server default class. |
| `PlayerControllerClassName` | `RenX_Game.Rx_Controller` | Renegade X player controller. |
| `GameDifficulty` | `1.0` | General game difficulty baseline. |
| `MaxPlayers` | `64` | Absolute player limit. |
| `MaxSpectators` | `0` | Spectator limit. |
| `MaxTimeMargin` | `1.0` | Advanced engine timing margin. |
| `TimeMarginSlack` | `1.2` | Advanced timing tolerance. |
| `MinTimeMargin` | `-0.5` | Minimum timing margin. |
| `GoreLevel` | `6` | Gore/content level. |
| `bKickLiveIdlers` | `false` | Enables UT live-idler kicking. |
| `MaxIdleTime` | `300` | Idle timeout in seconds when engine idler kicking is used. |
| `TotalNetBandwidth` | `3584000` | Total dynamic bandwidth pool. |
| `MaxDynamicBandwidth` | `56000` | Maximum dynamic bandwidth allocation. |
| `MinDynamicBandwidth` | `4000` | Minimum dynamic bandwidth allocation. |
| `DefaultMapPrefixes` | multiple | Maps prefixes to game classes: CNC, DEF, TDM, CQ, and others. |

Section: `[Engine.GameReplicationInfo]`

| Setting | Shipped default | Purpose |
| --- | --- | --- |
| `ServerName` | `Renegade X Server` | Public server name. |
| `MessageOfTheDay` | welcome message | Lobby/server MOTD. |

Section: `[Engine.AccessControl]`

| Setting | Typical value | Purpose |
| --- | --- | --- |
| `AdminPassword` | blank | Administrator authentication password. |
| `GamePassword` | blank | Password required to join the server. |
| `IPPolicies` | `ACCEPT;*` | Unreal IP allow/deny policy list. |

### `UDKGame.ini`: UT Match Framework

Section: `[UTGame.UTGame]`

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `bForceRespawn` | `true` | Automatically respawns players. |
| `BotRatio` | `1.0` | UT bot population ratio. |
| `GoalScore` | `25` | Generic mode score goal. |
| `bTournament` | `false` | Tournament-style match behavior. |
| `bPlayersMustBeReady` | `false` | Requires ready status. |
| `NetWait` | `15` | Startup/network wait duration. |
| `ClientProcessingTimeout` | `30` | Client loading/travel timeout. |
| `RestartWait` | `30` | Map transition delay. |
| `MinNetPlayers` | `1` | Minimum players before start when waiting is enabled. |
| `bWaitForNetPlayers` | `true` | Enables minimum-player waiting. |
| `LateEntryLives` | `1` | Lives given to late entrants in limited-life modes. |
| `TimeLimit` | `20` | Generic time limit. |
| `GameDifficulty` | `5.0` | UT framework difficulty. |
| `EndTimeDelay` | `4.0` | End-of-match delay. |
| `GameSpecificMapCycles` | multiple | Map cycles for CnC, Survival, TDM, and other game classes. |
| `bLogGameplayEvents` | `false` | Enables gameplay-event logging. |

Section: `[UTGame.UTTeamGame]`

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `GoalScore` | `60` | Team-mode goal score. |
| `bPlayersBalanceTeams` | `true` | Uses UT team balancing. |
| `bWeaponStay` | `true` | Weapon pickup persistence behavior. |
| `MaxLives` | `0` | `0` means unlimited lives. |

### `UDKEngine.ini`: Ports, Bandwidth, Downloads, And Steam

Section: `[URL]`

| Setting | Shipped default | Purpose |
| --- | --- | --- |
| `MapExt` | `udk` | Map extension. |
| `AdditionalMapExt` | `mobile` | Additional map extension. |
| `Map` | `RenX-MenuMap.udk` | Default engine map. |
| `LocalMap` | map value | Local/default map. |
| `TransitionMap` | transition map | Seamless-travel transition map. |
| `EXEName` | executable name | Runtime executable identity. |
| `DebugEXEName` | debug executable | Debug executable identity. |
| `Port` | GSA game port | Main UDP game port when present in the runtime file. |
| `PeerPort` | GSA raw port | Peer/raw UDP port when present. |

Section: `[Engine.Player]`

| Setting | Purpose |
| --- | --- |
| `ConfiguredInternetSpeed` | Client internet bandwidth assumption. |
| `ConfiguredLanSpeed` | Client LAN bandwidth assumption. |

Section: `[IpDrv.TcpNetDriver]`

| Setting | Blueprint default | Purpose |
| --- | ---: | --- |
| `AllowDownloads` | `true` | Permits Unreal channel downloads. |
| `MaxClientRate` | `15000` | Maximum per-client data rate. |
| `MaxInternetClientRate` | `10000` | Maximum internet-client data rate. |
| `NetServerMaxTickRate` | `30` | Maximum network tick rate. |

Section: `[IpDrv.HTTPDownload]`

| Setting | Blueprint default | Purpose |
| --- | --- | --- |
| `ConnectionTimeout` | `30` | Redirect connection timeout. |
| `ProxyServerPort` | `0` | Optional HTTP proxy port. |
| `ProxyServerHost` | blank | Optional HTTP proxy host. |
| `RedirectToURL` | Totem Arts content URL | Fast-download root URL. |
| `UseCompression` | `false` | Uses compressed redirect packages when supported. |

Section: `[OnlineSubsystemSteamworks.OnlineSubsystemSteamworks]`

| Setting | Shipped default | Purpose |
| --- | --- | --- |
| `bEnableSteam` | `true` | Enables Steam online services. |
| `QueryPort` | `27015` | Reserved UDP query/Steam compatibility port. |
| `bUseVAC` | `true` in distribution | Enables VAC where supported; blueprint defaults off. |
| `bRelaunchInSteam` | `false` | Prevents dedicated server relaunch through Steam. |
| `RelaunchAppId` | `0` | Steam relaunch application ID. |
| `GameDir` | `unrealtest` | Steam game directory identifier used by UDK. |
| `GameVersion` | `1.0.0.0` | Online subsystem version string. |
| `Region` | `255` | Region filter; `255` means unrestricted. |
| `CurrentNotificationPosition` | `8` | Steam notification position. |
| `ResetStats` | `0` | Steam stat reset switch. |
| `bFilterEngineBuild` | `false` | Engine-build filtering behavior. |
| `VOIPVolumeMultiplier` | `4.0` | Voice volume multiplier. |
| `ServerBrowserTimeout` | `10` | Browser query timeout. |
| `InviteTimeout` | `10` | Invite timeout. |

### `UDKRenegadeX.ini`: Standard CnC Match Settings

Section: `[RenX_Game.Rx_Game]`

#### Match Flow And Victory

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `NetWait` | `2` | RenX startup wait. |
| `TeamMode` | `6` | Team organization mode. |
| `InitialCredits` | `200` | Starting credits. |
| `TimeLimit` | `50` | Overall match time limit. |
| `CnCModeTimeLimit` | `50` | CnC-specific limit; `0` disables it. |
| `DMModeTimeLimit` | `15` | Deathmatch limit. |
| `bBuildingsRevive` | `true` | Allows destroyed buildings to revive. |
| `BuildingReviveTime` | `600` | Seconds before a building can revive. |
| `bStructuresAutoRevive` | `false` | Automatically revives structures; otherwise MCT interaction may be required. |
| `bEnableAirdrops` | `false` | Enables vehicle airdrops; recommended by the shipped comments for marathon play. |
| `bTeamScoreIsBuildingDamage` | `true` | Uses building damage for team score. |
| `bWasTeamScoreIsBuildingDamage` | `false` | Internal previous-state value; normally leave unchanged. |
| `bEnableOverTime` | `true` | Enables overtime at the limit. |
| `bWasOverTimeEnabled` | `false` | Internal previous-state value. |
| `OverTimeTimeLimit` | `1200` | Overtime duration in seconds. |
| `SuddenDeathTimeLimit` | `600` | Sudden-death duration in seconds. |
| `PointsToWinBy` | `15000` | Required score lead; buildings are described as worth 10000. |
| `bSurrenderAtTimeLimit` | `true` | Uses surrender/end behavior at the time limit. |
| `SuddenDeath_DmgMult` | `3.0` | Sudden-death damage multiplier. |
| `GoalScore` | `60` | Generic goal score used by applicable modes. |
| `MaxLives` | `0` | Unlimited lives when `0`. |

#### Surrender, Voting, And Rotation

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `SurrenderLength` | `120` | Surrender countdown in seconds. |
| `SurrenderDisabledTime` | `600` | Time before surrender voting is available. |
| `ChangeMapDisabledTime` | `600` | Time before change-map voting is available. |
| `bAdminsStartMapVote` | `false` | Controls administrator map-vote initiation behavior. |
| `bShowOtherGameTypes` | `true` | Includes non-CnC maps such as TDM and Defense in selection. |
| `RecentMapsToExclude` | `5` | Recent maps removed from voting. |
| `MaxMapVoteSize` | `5` | Maximum map-vote choices. |
| `MapVoteTime` | `35` | Voting duration in seconds. |
| `bFixedMapRotation` | `false` | Uses fixed rotation rather than normal voting. |
| `bBotVotesDisabled` | `false` | Prevents bots from affecting votes when enabled. |
| `bRemoveVariantMapsInVoteList` | `true` | Removes map variants from the vote list. |

#### Vehicles, Commanders, And Economy

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `VehicleLimit` | `20` | General vehicle limit. |
| `bUsePedestal` | `true` | Enables the endgame pedestal mechanic. |
| `MinPlayersForNukes` | `0` | Minimum players required for superweapon access. |
| `bEnableCommanders` | `true` | Enables commanders. |
| `bUseStaticCommanders` | `false` | Keeps commander assignments static when enabled. |
| `InitialCP` | `600` | Initial command points. |
| `Max_CP` | `3000` | Maximum command points. |
| `bAllowPowerUpDrop` | `true` | Allows power-up drops. |
| `DonationsDisabledTime` | `180` | Seconds before donations become available. |
| `bReserveVehiclesToBuyer` | `true` | Reserves purchased vehicles for their buyer. |
| `SpawnCrates` | `true` | Enables crate spawning. |
| `CrateRespawnAfterPickup` | `30` | Crate respawn delay. |

#### Listing, Bots, Chat, And Join Behavior

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `bListed` | `true` | Allows public master-list registration. |
| `bBotsDisabled` | `false` | Globally disables bots. |
| `bUnlockCheatingBots` | `true` | Unlocks advanced/cheating bot choices. |
| `bFillSpaceWithBots` | `true` | Fills available population with bots. |
| `bIsCompetitive` | `false` | Enables competitive-mode behavior. |
| `bWaitForNetPlayers` | `true` | Waits for minimum player count. |
| `MinNetPlayers` | `40` | Minimum count when waiting is enabled. |
| `bAllowPrivateMessaging` | `true` | Enables private messages. |
| `bPrivateMessageTeamOnly` | `false` | Restricts private messages to teammates. |
| `bAllowNonTeamChat` | `false` | Allows global/non-team chat when enabled. |
| `ClientProcessingTimeout` | `30` | Client travel/loading timeout. |
| `LateEntryLives` | `1` | Lives for late entrants in limited-life modes. |

#### Lifecycle, Warmup, AFK, And Diagnostics

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `MaxServerUptime` | `500000` | Forces an in-game restart after this many seconds. GSA scheduled restarts are still recommended. |
| `RTC_DisableTime` | `0` | Disables request-team-change behavior for an initial period. |
| `GameplayEventsWriterClassName` | RenX writer | Gameplay-event writer class. |
| `TeamMmrAnnouncementInterval` | `0` | Team MMR announcement interval; `0` disables announcements. |
| `bHostsAuthenticationService` | `false` | Hosts the RenX authentication service when enabled. |
| `bForceMidGameMenuAtStart` | `false` | Forces the mid-game menu at match start. |
| `bLogGameplayEvents` | `false` | Enables gameplay-event logs. |
| `bWarmupRound` | `false` | Enables a warmup round. |
| `WarmupTime` | `0` | Warmup duration. |
| `ResetTimeDelay` | `0` | Reset delay. |
| `bIsStandbyCheckingEnabled` | `false` | Enables Unreal standby/network-health detection. |
| `StandbyRxCheatTime` | `0` | Advanced receive-standby threshold. |
| `StandbyTxCheatTime` | `0` | Advanced transmit-standby threshold. |
| `BadPingThreshold` | `0` | Advanced bad-ping threshold. |
| `PercentMissingForRxStandby` | `0` | Missing receive-packet percentage threshold. |
| `PercentMissingForTxStandby` | `0` | Missing transmit-packet percentage threshold. |
| `PercentForBadPing` | `0` | Percentage threshold for bad ping. |
| `JoinInProgressStandbyWaitTime` | `0` | Standby delay for joining players. |
| `bAutoKickAFKEnabled` | `false` | Enables RenX AFK kicking. |
| `AutoKickAFKMinimumServerFullSeconds` | `60` | Requires the server to remain full this long before AFK kicks. |
| `AutoKickAFKMinimumCurrentAFKSeconds` | `120` | Minimum continuous AFK time. |
| `AutoKickAFKMinimumTotalAFKSeconds` | `300` | Minimum total AFK time during the match. |
| `FirstMinuteThreshold` | `300` | Early-match activity threshold. |
| `FirstMinuteMaxIdleTime` | `90` | Early-match maximum idle time. |

#### Bounty System

`BountyRankList` may be repeated:

```ini
BountyRankList=(RankName="Assassin",Threshold=10,CreditsBase=300,CreditsMult=75,VPBase=10,VPMult=0.5)
```

Fields:

| Field | Purpose |
| --- | --- |
| `RankName` | Display name. |
| `Threshold` | Kill/bounty threshold. |
| `CreditsBase` | Base credit reward. |
| `CreditsMult` | Credit multiplier. |
| `VPBase` | Base veterancy-point reward. |
| `VPMult` | Veterancy-point multiplier. |
| `BountyPermaspotRank` | Rank index at which permanent spotting begins. |

#### Map Population Limits

`MapsWithPlayerNumLimits` may be repeated:

```ini
MapsWithPlayerNumLimits=(MapName="CNC-Field",MapMinPlayers=0,MapMaxPlayers=20)
```

This controls whether a map is eligible for voting at the current population. It does not change the server's global slot limit.

#### Relevancy And Version

| Setting | Shipped default | Purpose |
| --- | --- | --- |
| `bVehiclesAlwaysRelevant` | `true` | Keeps vehicles network-relevant. |
| `bInfantryAlwaysRelevant` | `true` | Keeps infantry network-relevant. |
| `GameVersion` | `Release 1.0.1022` | Game version advertised by the server; do not change casually. |
| `GameVersionNumber` | `17209` | Numeric compatibility version; do not change. |

#### Auto-Balance

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `bAutoBalancerEnabled` | `false` | Enables RenX auto-balance. |
| `bAutoBalanceForced` | `false` | Forces balancing rather than relying on volunteers. |
| `AutobalanceThreshold` | `2` | Team-size difference that triggers balancing. |
| `AutoBalanceCreditReward` | `700` | Credit reward for balancing. |
| `TimeTillFirstAutoBalance` | `600` | Delay before first balance attempt. |
| `AutoBalanceMaximumRewardTime` | `1800` | Maximum reward window. |
| `AutoBalanceCooldown` | `120` | Cooldown between balance attempts. |
| `AutoBalanceVpReward` | `10` | Veterancy-point reward. |
| `bMercyImportantGameObject` | `true` | Uses important-object state in mercy/balance logic. |
| `bMercyScoreThreshold` | `100` | Mercy score threshold. |
| `bMercyPreviouslyBalanced` | `true` | Considers previous balancing in mercy logic. |
| `AutoBalanceDuration` | `30` | Balance action duration. |
| `bAutoBalanceRewardVp` | `false` | Enables VP reward for balancing. |

### `UDKRenegadeX.ini`: Access And Public Services

Section: `[RenX_Game.Rx_AccessControl]`

| Setting | Blueprint default | Purpose |
| --- | ---: | --- |
| `bRequireSteam` | `false` | Requires Steam-authenticated players. |
| `bSteamAutoAuthAdmins` | distribution setting | Automatically authenticates configured Steam admins where supported. |
| `bSteamAuthAdmins` | `false` | Enables Steam administrator authentication. |
| `bBroadcastAdminIdentity` | `false` | Announces administrator identity. |
| `ModPassword` | blank | Moderator password where supported. |

Section: `[RenX_Game.Rx_ServerListQueryHandler]`

| Setting | Shipped value | Purpose |
| --- | --- | --- |
| `MasterServerURL` | `https://serverlist-rx.totemarts.services/servers.jsp` | Official public server list. |

Section: `[RenX_Game.Rx_VersionQueryHandler]`

| Setting | Shipped value | Purpose |
| --- | --- | --- |
| `MasterVersionURL` | Totem Arts version endpoint | Version/compatibility service. |

Do not replace the master endpoints unless operating a deliberate private ecosystem.

### `UDKSurvival.ini`: Defense Survival

Section: `[RenX_Coop.Rx_Game_Survival]`

#### Common Survival Match Settings

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `MinNetPlayers` | `40` | Minimum players when network waiting is enabled. |
| `NetWait` | `30` | Startup wait. |
| `bWaitForNetPlayers` | `true` | Waits for minimum players. |
| `bAllowPowerUpDrop` | `true` | Allows dropped power-ups. |
| `DonationsDisabledTime` | `180` | Donation lockout. |
| `InitialCredits` | `200` | Starting credits. |
| `SpawnCrates` | `true` | Enables crates. |
| `CrateRespawnAfterPickup` | `30` | Crate respawn time. |
| `bIsCompetitive` | `false` | Competitive behavior. |
| `bReserveVehiclesToBuyer` | `true` | Reserves purchased vehicles. |
| `TimeLimit` | `0` | Survival time limit; `0` disables it. |
| `DMModeTimeLimit` | `12` | Deathmatch-derived timing value used by applicable behavior. |
| `bFixedMapRotation` | `false` | Fixed rotation. |
| `RecentMapsToExclude` | `0` | Recent maps excluded. |
| `MaxMapVoteSize` | `5` | Vote choices. |
| `TeamMode` | `3` | Shuffle. |
| `bAllowPrivateMessaging` | `true` | Private messages. |
| `bPrivateMessageTeamOnly` | `false` | Team-only private messages. |
| `bListed` | `true` | Public listing. |
| `bBotVotesDisabled` | `false` | Bot voting behavior. |
| `SurrenderLength` | `300` | Surrender countdown. |
| `SurrenderDisabledTime` | `600` | Initial surrender lockout. |
| `RTC_DisableTime` | `0` | Team-change request lockout. |
| `GameplayEventsWriterClassName` | RenX writer | Event writer. |
| `bUsePedestal` | `false` | Endgame pedestal behavior. |
| `bEnableCommanders` | `true` | Commanders. |
| `bUseStaticCommanders` | `false` | Static commanders. |
| `InitialCP` | `600` | Initial command points. |
| `Max_CP` | `3000` | Maximum command points. |
| `bVehiclesAlwaysRelevant` | `true` | Vehicle network relevancy. |
| `bInfantryAlwaysRelevant` | `true` | Infantry network relevancy. |

#### Wave Settings

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `TimeBeforeCountdown` | `10` | Delay before wave countdown. |
| `WaveGraceTime` | `15` | Grace time between wave phases. |
| `MaximumEnemy` | `40` | Maximum active enemy count. |
| `BaseWaveCreditsReward` | `100` | Base credits multiplied by wave and bonus. |
| `BaseWaveCPReward` | `100` | Base command points for qualifying wave clears. |
| `BaseWaveVPReward` | `5` | Base veterancy points for qualifying wave clears. |

#### Frustration Mechanic

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `bEnableFrustration` | `true` | Enables adaptive frustration/difficulty behavior. |
| `FrustrationVentInterval` | `10` | Seconds between vent attempts. |
| `FrustrationCoolOffTimer` | `30` | Cool-off duration after venting. |
| `FrustrationFailureChance` | `0.7` | Probability a vent attempt fails. |
| `FrustrationBuildUpStartWave` | `4` | Wave where passive buildup begins. |
| `FrustrationBuildUpMult` | `0.5` | Wave-scaled buildup multiplier. |
| `FrustrationBuildDownMult` | `5` | Cool-off reduction multiplier. |
| `FrustrationInfKillIncrement` | `1` | Increase when enemy infantry dies. |
| `FrustrationVehKillIncrement` | `5` | Increase when enemy vehicles die. |
| `FrustrationPlayerKillDecrement` | `8` | Reduction when a player dies. |
| `FrustrationWaveClearIncrement` | `25` | Increase for strong wave clears. |
| `FrustrationWaveClearDecrement` | `75` | Reduction for weaker survival results. |

### `UDKMapList.ini`: Game Profiles And Rotation

Section: `[RenX_Game.Rx_MapListManager]`

```ini
GameProfiles=(GameClass="RenX_Game.Rx_Game",GameName="Command & Conquer",bIsTeamGame=true,MapListName="CNCMapList",Options="",Mutators="",ExcludedMuts="")
GameProfiles=(GameClass="RenX_Coop.Rx_Game_Survival",GameName="Defense Survival",bIsTeamGame=true,MapListName="DEFMapList",Options="",Mutators="",ExcludedMuts="")
```

Game profile fields:

| Field | Purpose |
| --- | --- |
| `GameClass` | Unreal game class. |
| `GameName` | Display name. |
| `bIsTeamGame` | Team-game behavior. |
| `MapListName` | Section containing maps. |
| `Options` | Additional URL options. |
| `Mutators` | Mutators for this profile. |
| `ExcludedMuts` | Mutators excluded from this profile. |

Optional manager settings present as comments in the shipped file:

```text
AutoStripOptions
AutoEmptyOptions
MapReplayLimit
PlayIndex
```

Map-list entries repeat:

```ini
[CNCMapList Rx_MapList]
Maps=(Map="CNC-Field")

[DEFMapList Rx_MapList]
Maps=(Map="DEF-DarkNight")
```

### `UDKWeb.ini`: Optional Web Statistics Service

Section: `[RenX_Game.Rx_WebServer]`

| Setting | Blueprint value | Purpose |
| --- | --- | --- |
| `ServerName` | `{gameserver.list_name}` | Web-service display/server name. |
| `Applicationss` | `RenX_Game.Rx_WebApplication_Stats` | Web application class. The doubled `s` is the shipped RenX key. |
| `ApplicationPathss` | `/ServerInfo` | URL path. The doubled `s` is the shipped RenX key. |
| `bEnabled` | `false` | Enables the web service. |
| `ListenPort` | `{gameserver.other_port}` | GSA-assigned TCP port. |
| `MaxConnections` | `32` | Maximum connections. |
| `DefaultApplication` | `1` | Default application index. |
| `ExpirationSeconds` | `86400` | Session/data expiration time. |

### `UDKPurchaseSystem.ini`: Prices And Airdrops

Section: `[RenX_Game.Rx_PurchaseSystem]`

| Setting | Purpose |
| --- | --- |
| `AirdropCooldownTime` | Vehicle airdrop cooldown; shipped value `470`. |
| `GDIVehiclePrices[0..6]` | Humvee, APC, MRLS, Medium Tank, Mammoth Tank, Chinook, Orca. |
| `NodVehiclePrices[0..7]` | Buggy, APC, Artillery, Flame Tank, Light Tank, Stealth Tank, Chinook, Apache. |
| `GDIItemPrices[0..7]` | Ion beacon, airstrike, repair tool, ammo kit, mechanical kit, motion sensor, MG sentry, AT sentry. |
| `NodItemPrices[0..7]` | Nuke beacon, airstrike, repair tool, ammo kit, mechanical kit, motion sensor, MG sentry, AT sentry. |
| `GDIWeaponPrices[0..6]` | Heavy pistol, carbine, two Tiberium rifles, EMP grenade, AT mine, smoke grenade. |
| `NodWeaponPrices[0..6]` | Heavy pistol, carbine, two Tiberium rifles, EMP grenade, AT mine, smoke grenade. |

Preserve array indexes when changing prices because each index maps to a specific purchase item.

Shipped price arrays:

```text
GDIVehiclePrices = 350, 500, 450, 800, 1500, 700, 900
NodVehiclePrices = 300, 500, 450, 800, 600, 900, 700, 900
GDIItemPrices    = 1000, 800, 200, 150, 150, 200, 300, 300
NodItemPrices    = 1000, 800, 200, 150, 150, 200, 300, 300
GDIWeaponPrices  = 100, 250, 400, 400, 300, 250, 100
NodWeaponPrices  = 100, 250, 400, 400, 300, 250, 100
```

### `UDKRenegadeXAISetup.ini`: AI Behavior

Section: `[RenX_Game.Rx_TeamAI]`

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `RushFailureChancePercentage` | `-1` | Rush failure/chance behavior; `-1` uses built-in behavior. |
| `bCheetozBotzEnabled` | `true` | Enables the advanced RenX bot behavior. |
| `bQuietBots` | `false` | Suppresses bot chatter when enabled. |

### `UDKFPSMonitor.ini`: Performance Logging

Section: `[RenX_Game.Rx_FPSMonitor]`

| Setting | Shipped default | Purpose |
| --- | ---: | --- |
| `LogFrequency` | `60` | Seconds between FPS log summaries. |
| `PreviousCapturesToLog` | `6` | Number of previous samples included. |
| `CaptureFrequency` | `10` | Seconds between FPS samples. |

### `UDKStatAPI.ini`: External Statistics

Section: `[RenX_Game.Rx_StatAPI]`

| Setting | Shipped default | Purpose |
| --- | --- | --- |
| `StatAPIURL` | Renegade X server stats endpoint | Destination for statistics. |
| `APIUpdateInterval` | `300` | Update interval in seconds. |
| `bPostToAPI` | `true` | Enables posting statistics. |

Only point this at a service you control or explicitly trust.

### Per-Map INI Settings

Each `CNC-*.ini`, `DEF-*.ini`, or `TDM-*.ini` file contains a section such as:

```ini
[CNC-Field Rx_UIDataProvider_MapInfo]
```

Available keys:

| Setting | Purpose |
| --- | --- |
| `MapName` | Package/map name. |
| `FriendlyName` | Human-readable name. |
| `PreviewImageMarkup` | UI preview asset. |
| `Size` | Small, medium, or large metadata. |
| `Style` | Symmetrical/asymmetrical metadata. |
| `NumPlayers` | Suggested player count. |
| `MinNumPlayers` | Suggested minimum player count. |
| `AirVehicles` | Air-vehicle availability metadata. |
| `TechBuildings` | Number of tech buildings. |
| `BaseDefences` | Base-defense metadata. |
| `MineLimit` | Map mine limit. |
| `VehicleLimit` | Map vehicle limit. |
| `LastGDIBotItemPosition` | GDI bot menu/default position. |
| `LastGDITacticStyleItemPosition` | GDI tactic menu/default position. |
| `GDIAttackingValue` | GDI attack behavior. |
| `GDIBotValue` | GDI bot count/default. |
| `LastNodBotItemPosition` | Nod bot menu/default position. |
| `LastNodTacticStyleItemPosition` | Nod tactic menu/default position. |
| `NodAttackingValue` | Nod attack behavior. |
| `NodBotValue` | Nod bot count/default. |
| `LastStartingTeamItemPosition` | Starting-team selection. |
| `StartingCreditsValue` | Map/skirmish starting credits. |
| `LastTimeLimitItemPosition` | Time-limit menu/default position. |
| `LastMineLimitItemPosition` | Mine-limit menu/default position. |
| `LastVehicleLimitItemPosition` | Vehicle-limit menu/default position. |
| `bFriendlyFire` | Friendly fire. |
| `bCanRepairBuildings` | Building repair behavior. |
| `bBaseDestruction` | Base destruction victory behavior. |
| `bEndGamePedistal` | Pedestal endgame behavior; spelling matches the shipped key. |
| `bTimeLimitExpiry` | Time-limit expiration behavior. |

### Firestorm/Tiberian Sun Settings Included In The Distribution

The shipped `UDKRenegadeX.ini` also contains Firestorm/Tiberian Sun sections. They do not control normal Renegade X CnC or Defense Survival servers.

Sections:

```text
[TibSun_Game.TS_Game]
[TibSun_Game.TS_Game_Conquest]
```

Available settings:

```text
bAutoBalancerEnabled
bAutoBalanceForced
AutobalanceThreshold
AutoBalanceCreditReward
TimeTillFirstAutoBalance
AutoBalanceMaximumRewardTime
AutoBalanceCooldown
AutoBalanceVpReward
bMercyImportantGameObject
bMercyScoreThreshold
bMercyPreviouslyBalanced
AutoBalanceDuration
bAutoBalanceRewardVp
GameModeVoteList[0..1]
MaxServerUptime
SuddenDeathCountDown
bSuddenDeathEnabled
bSuddenDeathResetOnMajorityLost
TicketCycle
BaseTicketGoal
OutpostInitialBuildTimer
OutpostRebuildTimer
PowerPlantTicketSpeedIncreaseTime
bTiersEnabled
bTiersForced
```

## Container Environment Variables

GSA supplies these automatically:

```text
RENX_SERVER_NAME
RENX_MAP
RENX_GAME_CLASS
RENX_MAP_CYCLE_CLASS
RENX_MAP_ROTATION
RENX_MUTATORS
RENX_MAX_PLAYERS
RENX_GAME_PORT
RENX_PEER_PORT
RENX_QUERY_PORT
RENX_WEB_PORT
RENX_ADMIN_PASSWORD
RENX_SERVER_PASSWORD
RENX_MOTD
RENX_LISTED
RENX_FIXED_MAP_ROTATION
RENX_BOTS_DISABLED
RENX_GDI_BOTS
RENX_NOD_BOTS
RENX_GDI_BOT_DIFFICULTY
RENX_NOD_BOT_DIFFICULTY
RENX_GDI_ATTACK_PERCENT
RENX_NOD_ATTACK_PERCENT
RENX_ALLOW_DOWNLOADS
RENX_REDIRECT_URL
RENX_REDIRECT_USE_COMPRESSION
RENX_SERVER_PAYLOAD_URLS
RENX_REFRESH_SERVER_PAYLOAD
RENX_INSTALL_OPTIONAL_MAP_PACK_1
RENX_INSTALL_OPTIONAL_MAP_PACK_2
RENX_INSTALL_OPTIONAL_MAP_PACK_3
RENX_OPTIONAL_MAP_PACK_1_URL
RENX_OPTIONAL_MAP_PACK_2_URL
RENX_OPTIONAL_MAP_PACK_3_URL
RENX_REQUIRED_CONTENT_URLS
RENX_CONTENT_URLS
RENX_REFRESH_CONTENT_DOWNLOADS
RENX_WEB_ENABLED
RENX_WEB_MAX_CONNECTIONS
RENX_NET_WAIT
RENX_MIN_NET_PLAYERS
RENX_WAIT_FOR_NET_PLAYERS
RENX_FORCE_RESPAWN
RENX_PLAYERS_MUST_BE_READY
RENX_RESTART_WAIT
RENX_INITIAL_CREDITS
RENX_MARATHON_MODE
RENX_TIME_LIMIT
RENX_CNC_TIME_LIMIT
RENX_DM_TIME_LIMIT
RENX_BUILDINGS_REVIVE
RENX_ENABLE_AIRDROPS
RENX_TEAM_MODE
RENX_MAX_MAP_VOTE_SIZE
RENX_RECENT_MAPS_TO_EXCLUDE
RENX_SPAWN_CRATES
RENX_MAX_CLIENT_RATE
RENX_MAX_INTERNET_CLIENT_RATE
RENX_SERVER_TICK_RATE
RENX_MULTIHOME
RENX_EXTRA_ARGS
```

Internal/maintainer variables:

```text
RENX_ROOT
RENX_DATA_ROOT
RENX_BOOTSTRAP_ROOT
RENX_SEED_ROOT
RENX_LOG_FILE
```

## Direct Docker Example

```powershell
docker run -d --name renx-test `
  -p 7777:7777/udp `
  -p 7778:7778/udp `
  -p 27015:27015/udp `
  -v C:\renx-test\data:C:\renx-data `
  -e RENX_SERVER_NAME="Twisted Renegade X" `
  -e RENX_MAP="CNC-Field" `
  -e RENX_MAX_PLAYERS="40" `
  -e RENX_GAME_PORT="7777" `
  -e RENX_PEER_PORT="7778" `
  -e RENX_QUERY_PORT="27015" `
  -e RENX_LISTED="true" `
  -e RENX_TEAM_MODE="6" `
  ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-core20-ltsc2022-r11
```

## Troubleshooting

### First Pull Or Installation Takes A Long Time

- The image contains Windows Server layers and the 20-map Renegade X runtime, so the first pull is large.
- Leave the installation running while Docker is downloading and extracting layers.
- Confirm the host has enough free disk space for the image, Docker's layer cache, and `renx-data`.
- Later installs are normally faster because Docker reuses cached layers.

### Installation Fails Immediately

- Confirm the host is running Windows Server 2022 with Docker set to Windows containers.
- Confirm the blueprint image is `ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-core20-ltsc2022-r11`.
- Reinstall the server after changing the image tag, Docker environment variables, mounts, or port definitions.
- Check the Docker container log for an image pull, mount, or Windows container compatibility error.

### Server Is Not In The Public List

- Enable GSA's public exposure toggle.
- Set `List Server` to On.
- Confirm the server reached a loaded map instead of stopping at wrapper startup output.
- Confirm the game, peer, and query UDP ports are reachable.
- Allow outbound TCP `21337` to `devbot-rx.totemarts.services`.
- Check `RenegadeXServer.log` for bind, Steam, socket, or online-subsystem errors.

### GSA Monitoring Does Not Show Players

- Use `Container` monitoring. This is the supported monitoring type for the current blueprint.
- Container monitoring reports whether the server process is running, but it cannot show player count or player names.
- Keep recovery enabled only after container monitoring has correctly recognized a healthy test start.

### GSA Says The Server Crashed Or Offline

- Confirm the blueprint is using `Container` monitoring.
- Confirm the container process remains alive.
- Open the game log from the GSA Logs page.
- Check that `UDK.com` exists under `ServerFiles\Binaries\Win64`.
- Look for `Game engine initialized` or `MAP Loaded` in `RenegadeXServer.log`.
- If the game is running but monitoring was changed recently, restore `Container` monitoring and restart the container.

### Game Log Does Not Appear In GSA

- Confirm the blueprint includes `\renx-data\Logs` as a directory with type `logs`.
- Confirm `C:\renx-data\Logs\RenegadeXServer.log` exists inside the container.
- Restart the container after updating the blueprint's directory definitions.
- The same live game output is also mirrored into the Docker container log.

### Server Starts On The Wrong Map Or Mode

- Use map names without `.udk`.
- Normal CnC should use `CNC-*` maps.
- Survival should use `DEF-*`, `RenX_Coop.Rx_Game_Survival`, and `Rx_Game_Survival`.
- Confirm the map is installed in `UDKGame\CookedPC\Maps\RenX`.

### Server Name Is Missing Words Or Contains Quotes

- Use the `r11` image or newer.
- Set the name through the normal GSA game-server list name field.
- Restart or recreate the container after changing from an older image.
- The orange server-list prefix used by some communities is assigned by the Renegade X master-list service and is not controlled by `ServerName`.

### Optional Map Download Repeats

- Confirm the archive remains in `CustomContent\_OptionalMaps`.
- Keep `Refresh Content Downloads` off after a successful installation.
- Turning a pack off does not uninstall it.

### Config Changes Do Not Stick

- Check whether a GSA parameter controls the same key.
- Edit the persistent file under `C:\renx-data\Config`, not only the runtime copy.
- Recreate the container after changing image tags or Docker environment variables.
- Do not wipe the persistent mount during routine updates.

### Marathon Mode Still Ends The Match

- Use image `1.0.1022-core20-ltsc2022-r11` or newer.
- Set `Marathon Mode` to On, then fully stop/start or reinstall the container so GSA passes the updated environment values.
- Confirm `\renx-data\Config\UDKRenegadeX.ini` and `\renx-data\ServerFiles\UDKGame\Config\DefaultRenegadeX.ini` contain `TimeLimit=0` and `CnCModeTimeLimit=0`.
- Leave `Marathon Mode` off for timed matches; the normal time-limit, building revive, and airdrop fields remain adjustable.

### Server Stops After A Configuration Change

- Remove unsupported raw launch arguments from `Extra Launch Args`.
- Confirm numeric fields contain numbers and boolean settings use the provided GSA toggles.
- Confirm the selected map exists and is appropriate for the selected game class.
- Review the last lines of both the container log and `RenegadeXServer.log`.
- Restore the last known working value and restart before making additional changes.

### Players Cannot Join

- Confirm the game and peer ports are exposed as UDP and assigned by GSA.
- Check Windows Firewall and upstream NAT/firewall rules.
- Confirm the server is not password protected unexpectedly.
- Confirm clients have the same custom maps, packages, and mutators or can download them through the configured redirect.

## Repository Files

```text
blueprints/renegade-x-gsa-windows.json  GameServerApp blueprint
Dockerfile.full                         Core 20 Windows image definition
Dockerfile                              Bootstrap image definition
Start.ps1                               Runtime installer and startup wrapper
LaunchRenegadeXServer.bat               Dedicated-server launcher
scripts/                                Payload and release maintenance tools
maps/                                   Core and optional map manifests
.github/workflows/                      Container build workflows
```

Normal server owners do not need to build the image. Use the published blueprint and pinned GHCR image.

## Sources And Credits

- [Totem Arts](https://totemarts.games/)
- [TotemArts/Renegade-X source and configuration](https://github.com/TotemArts/Renegade-X)
- [Totem Arts forums](https://forums.totemarts.games/)
- [GameServerApp blueprint documentation](https://docs.gameserverapp.com/dashboard/blueprints/create_and_manage_blueprints/)

Renegade X is created by Totem Arts. This GameServerApp integration, container wrapper, documentation, and automated build workflow are maintained by TwistedBobRoss.
