# Renegade X GSA Windows Container

Unofficial GameServerApp blueprint and Windows container wrapper for hosting Renegade X dedicated servers.

Renegade X is a free tactical shooter from Totem Arts inspired by Command & Conquer: Renegade. This project is intended to make community server hosting easier through GameServerApp, Windows containers, and a repeatable GitHub Actions build flow.

## Current Status

This is a first-pass package based on inspection of `renegade_x_Release_1.0.1022_3.zip`.

Known server-relevant files found in the release:

- `Binaries\Win64\UDK.exe`
- `UDKGame\Config\DefaultGame.ini`
- `UDKGame\Config\DefaultEngine.ini`
- `UDKGame\Config\DefaultMapList.ini`
- `UDKGame\Config\DefaultRenegadeX.ini`
- `UDKGame\Config\DefaultWeb.ini`

The launch wrapper uses the standard UDK dedicated server pattern:

```text
UDK.exe server CNC-Field?Game=RenX_Game.Rx_Game?MaxPlayers=40?Port=7777 -log=RenegadeXServer.log -unattended
```

RCON and Steam/Source-style query support still need live testing before marketplace copy should promise an RCON console or query monitoring.

## Image

Planned image name:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r1
```

This is a Windows container image intended for Windows Server 2022 / LTSC 2022 Windows container hosts.

## Why Payload Release Assets

Do not commit Renegade X server files directly into the repository. The release is too large for normal GitHub source control and contains files over normal GitHub file-size limits.

Recommended flow:

1. Use `scripts\Prepare-RenXPayload.ps1` locally to extract a server-focused payload from the official Renegade X release zip.
2. Upload the generated `renx-server-payload.zip.*` parts to a GitHub Release.
3. Run the GitHub Actions workflow.
4. The workflow downloads the payload parts, reconstructs the zip, extracts it into the Docker build context, builds the Windows image, and pushes it to GHCR.
5. GSA users install the blueprint and only pull the finished GHCR image.

## Prepare Payload

From PowerShell:

```powershell
.\scripts\Prepare-RenXPayload.ps1 `
  -SourceZip "C:\Users\imgon\Downloads\renegade_x_Release_1.0.1022_3.zip" `
  -OutputDir ".\payload-parts"
```

Default trimming excludes:

- `Binaries\Win32`
- `Binaries\InstallData`
- `UDKGame\Movies`
- `PreviewVids`

Those are likely unnecessary for a headless server image. If testing shows a missing dependency, rerun the script with:

```powershell
-IncludeMovies
-IncludePreviewVideos
-IncludeWin32
```

Upload these generated assets to a GitHub Release, for example tag:

```text
renx-payload-1.0.1022
```

Assets to upload:

```text
renx-server-payload.zip.001
renx-server-payload.zip.002
...
renx-server-payload-manifest.json
```

## Build Image

Run the `Build Renegade X Windows Image` workflow manually and provide:

```text
payload_release_tag = renx-payload-1.0.1022
image_tag = 1.0.1022-ltsc2022-r1
```

If the GitHub-hosted Windows runner runs out of disk space, use a self-hosted Windows Server 2022 runner with Docker configured for Windows containers.

## GameServerApp Setup

Use:

```text
blueprints/renegade-x-gsa-windows.json
```

The first version uses container monitoring because it is the safest known baseline. Query and RCON can be added after live testing confirms the correct GSA implementation type.

The blueprint mounts persistent data at:

```text
\renx-data
```

Inside the container this is:

```text
C:\renx-data
```

On first startup, `Start.ps1` seeds editable config files into:

```text
C:\renx-data\Config
```

Then it applies GSA environment values and copies those configs into the game install before launching.

Logs are written to:

```text
C:\renx-data\Logs
```

## Ports

Observed/default ports:

```text
7777/UDP  = game
7778/UDP  = peer/raw
27015/UDP = Steam/query
37015/TCP = proposed RCON test port
6969/TCP  = Renegade X web server, if used
```

## GSA Parameters

The blueprint currently uses text parameters because the public dropdown JSON schema was not available during drafting. These are good candidates to convert to dropdowns in the GSA editor:

```text
Starting Map
Game Class
Max Players / slot presets
```

Recommended starting values:

```text
Starting Map = CNC-Field
Game Class = RenX_Game.Rx_Game
Max Players = 40
Admin Password = blank for first test
Server Password = blank for public access
Extra Launch Args = blank
```

Survival test:

```text
Starting Map = DEF-DarkNight
Game Class = RenX_Coop.Rx_Game_Survival
```

## Maps Found In The Release

Command & Conquer:

```text
CNC-Arctic_Stronghold
CNC-Canyon
CNC-City
CNC-CliffSide
CNC-Complex
CNC-Crash_Site
CNC-DarkSide
CNC-Daybreak
CNC-Desolation
CNC-Eyes
CNC-Field
CNC-Field_2025
CNC-Field_Winter
CNC-Field_X
CNC-Forest
CNC-Forest_Winter
CNC-GoldRush
CNC-HeXmountain
CNC-Hourglass
CNC-Islands
CNC-LakeSide
CNC-LakeSide_Winter
CNC-Mesa
CNC-Mines
CNC-Oasis
CNC-Outposts
CNC-Reservoir
CNC-Reservoir_Winter
CNC-Snow
CNC-Steppe
CNC-Tomb
CNC-Toxicity
CNC-Tunnels
CNC-Under
CNC-Uphill
CNC-Volcano
CNC-Walls
CNC-Walls_Winter
CNC-Whiteout
CNC-Xmountain
```

Defense Survival:

```text
DEF-DarkNight
DEF-HillSide
```

Team Deathmatch:

```text
TDM-Caves
TDM-Deck
TDM-UndergroundNetwork
```

## Docker Run Example

After the image is published:

```powershell
docker run -d --name renx-test `
  -p 7777:7777/udp `
  -p 7778:7778/udp `
  -p 27015:27015/udp `
  -p 37015:37015/tcp `
  -v C:\renx-test\data:C:\renx-data `
  -e RENX_SERVER_NAME="Renegade X Test Server" `
  -e RENX_MAP="CNC-Field" `
  -e RENX_GAME_CLASS="RenX_Game.Rx_Game" `
  -e RENX_MAX_PLAYERS="40" `
  -e RENX_GAME_PORT="7777" `
  -e RENX_PEER_PORT="7778" `
  -e RENX_QUERY_PORT="27015" `
  -e RENX_RCON_PORT="37015" `
  ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r1
```

## Credits

Renegade X is created by Totem Arts. This project is an unofficial community hosting wrapper by TwistedBobRoss.
