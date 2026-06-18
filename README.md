# Renegade X GSA Windows Container

Unofficial GameServerApp blueprint and Windows container wrapper for hosting Renegade X dedicated servers.

Renegade X is a free tactical shooter from Totem Arts inspired by Command & Conquer: Renegade. This project is intended to make community server hosting easier through GameServerApp, Windows containers, and a repeatable GitHub Actions build flow.

## Hosting Model

Renegade X uses the Unreal Development Kit server pattern. A dedicated server is launched from the Renegade X game distribution with the Win64 UDK binary:

```text
Binaries\Win64\UDK.exe server CNC-Field?maxplayers=40 -port=7777
```

The Totem Arts wiki documents server settings in runtime config files such as:

```text
UDKGame\Config\UDKGame.ini
UDKGame\Config\UDKEngine.ini
UDKGame\Config\UDKRenegadeX.ini
UDKGame\Config\UDKWeb.ini
```

This wrapper seeds those runtime files from the bundled defaults on first boot, stores editable copies under `C:\renx-data\Config`, applies GSA parameters, then copies them back into the game install before launch.

## Core 20 Hosting Model

There does not appear to be a separate tiny dedicated-server-only package. Current community tooling and forum examples still launch `UDK.exe server` from a Renegade X install folder.

The primary GSA image contains a tested core runtime with 20 map files. On first start, it copies that runtime into the persistent GSA mount:

```text
C:\renx-data\ServerFiles
```

The core contains 18 playable maps plus the two required frontend/menu maps:

```text
CNC: Canyon, Complex, Field, GoldRush, Islands, LakeSide, Mesa, Oasis,
     Under, Volcano, Walls, Whiteout, Xmountain
DEF: DarkNight, HillSide
TDM: Caves, Deck, UndergroundNetwork
System: RenX-FrontEndMap, RenX-MenuMap
```

This includes all five maps shipped specifically for DEF/co-op and TDM, plus a practical CnC rotation covering small and large player counts. The other 27 playable CnC maps are available as three optional nine-map packs.

The runtime payload URLs remain as a recovery path. A safe server-focused payload keeps:

- `Binaries\Win64`
- `UDKGame\Config`
- `UDKGame\CookedPC`
- root and support files needed by the UDK build

The default payload script removes likely client-only pieces:

- `Binaries\Win32`
- `Binaries\InstallData`
- `UDKGame\Movies`
- `PreviewVids`

Do not blindly remove all shared `UDKGame\CookedPC` packages. Even headless UDK servers may load packages referenced by maps, actors, weapons, vehicles, and mutators. The better approach is to host a small tested runtime zip plus required map/content packs and let the container download them on install/startup.

## Image

Primary core image:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-core20-ltsc2022-r2
```

This is a Windows container image intended for Windows Server 2022 / LTSC 2022 Windows container hosts.

The smaller bootstrap-only image remains available as:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r5
```

## Build Images

Run `Build Renegade X Core 20 Windows Image` to build the primary image:

```text
payload_release = renx-core20-1.0.1022-r1
image_tag = 1.0.1022-core20-ltsc2022-r2
```

The workflow downloads the verified core payload release, reconstructs it, validates all 20 map files, and bakes the runtime into the Windows image.

## Runtime Payload URLs

In the GSA blueprint, set `Server Payload URLs` to a direct public URL for the Renegade X server runtime zip, or to split zip parts:

```text
https://example.com/renx-server-payload.zip
```

or:

```text
https://example.com/renx-server-payload.zip.001
https://example.com/renx-server-payload.zip.002
https://example.com/renx-server-payload.zip.003
```

The helper script `scripts\Publish-RenXPayloadAndBuild.ps1` can upload split payload parts to a GitHub Release and print URLs in this format.

The full image normally copies its baked seed into:

```text
C:\renx-data\ServerFiles
```

If that seed is unavailable, `Start.ps1` falls back to the configured split payload URLs. Set `Refresh Server Payload` to true only when you intentionally want to replace the persistent runtime from those URLs.

## Optional Map Packs

The remaining 27 playable maps are divided into three balanced downloads. Each pack may be enabled independently in the GSA blueprint.

Pack 1, approximately 616 MiB:

```text
City, Crash Site, Daybreak, Desolation, Forest Winter, HeXmountain,
Mines, Reservoir Winter, Tomb
```

Pack 2, approximately 648 MiB:

```text
CliffSide, DarkSide, Eyes, Field 2025, Forest, Hourglass,
LakeSide Winter, Outposts, Reservoir
```

Pack 3, approximately 637 MiB:

```text
Arctic Stronghold, Field Winter, Field X, Snow, Steppe,
Toxicity, Tunnels, Uphill, Walls Winter
```

Enable none, any one, any two, or all three packs. Enabled packs download and install during startup. Downloads are cached under `CustomContent\_OptionalMaps`, so later starts reuse them. Turning a switch off does not delete a pack already installed; remove its cached folder and map files manually if intentional removal is required.

## Optional FTP Payload Preload

The blueprint creates this persistent folder during GSA installation and exposes it through FTP:

```text
\renx-data\PayloadCache\Downloads
```

You may preload the release assets before starting the server. This is optional and can avoid a long first-start download or a GSA startup timeout.

1. Install the server from the GSA blueprint, but do not start it yet.
2. Download all numbered payload parts from the release linked by `Server Payload URLs`.
3. Upload the files by FTP into `\renx-data\PayloadCache\Downloads`.
4. Keep every filename unchanged, including `.zip.001`, `.zip.002`, and the remaining numbered suffixes.
5. Return to GSA and start the server normally.

The core recovery release requires:

```text
renx-core20-payload.zip.001
renx-core20-payload.zip.002
renx-core20-payload.zip.003
renx-core20-payload.zip.004
```

The manifest file is useful for checksum reference but is not required by the runtime installer. On startup, the container finds the preloaded parts, skips their GitHub downloads, joins them into one zip, extracts the runtime, validates `UDK.exe`, configuration folders, and maps, then launches Renegade X.

Do not rename the parts, extract them manually, or upload the large combined zip alongside the numbered files. If a part is missing, the container downloads only the missing filename from its configured URL. If an FTP upload was interrupted, replace that incomplete part before starting.

## Required Content URLs

Use `Required Content URLs` for map packs or packages that must be installed before launch. Zip files may contain full folder structure such as:

```text
UDKGame\CookedPC\Maps\RenX\CNC-Field.udk
UDKGame\CookedPC\RenX\...
UDKGame\Config\...
```

Loose `.udk`, `.u`, `.upk`, `.ini`, and `.int` files are also supported. Optional content can go in `Custom Content URLs`.

## GameServerApp Setup

Use:

```text
blueprints/renegade-x-gsa-windows.json
```

The first version uses container monitoring because it is the safest known baseline. Query and the GSA RCON command panel should not be promised until live testing confirms the correct GSA implementation type. The server-side RCON port is still configured by this blueprint.

The blueprint mounts persistent data at:

```text
\renx-data
```

Inside the container this is:

```text
C:\renx-data
```

Useful persistent folders:

```text
C:\renx-data\ServerFiles
C:\renx-data\PayloadCache
C:\renx-data\PayloadCache\Downloads
C:\renx-data\Config
C:\renx-data\CustomContent
C:\renx-data\CustomContent\_OptionalMaps
C:\renx-data\Logs
```

## Ports

Observed/default ports:

```text
7777/UDP  = game
7778/UDP  = peer/raw
27015/UDP = Steam/query
37015/TCP = RCON default test port
6969/TCP  = Renegade X web server, if exposed separately
```

Renegade X documents `RconPort=-1` as meaning RCON runs on the game port. This blueprint instead reserves a separate GSA `rcon` port and writes that allocated port into `UDKRenegadeX.ini`. If you want the game-port behavior, change `RENX_RCON_PORT` to `-1` in your forked blueprint or container environment.

## Custom Maps And Mods

Renegade X clients download loaded packages from the server or from an HTTP redirect. The Wiki describes two download paths:

- Channel downloading, controlled by `AllowDownloads=True` under `[IpDrv.TcpNetDriver]`.
- HTTP downloading, controlled by `RedirectToURL` and `UseCompression` under `[IpDrv.HTTPDownload]`.

HTTP redirect is the practical path for public custom content. The redirect webserver must serve files from the root path, include a trailing slash in the URL, and normally run on port 80. Keep the redirect files synchronized with the server files.

Upload server custom content into:

```text
\renx-data\CustomContent
```

Paste required map/package links into `Required Content URLs`, and optional links into `Custom Content URLs`. Use one URL per line or separate URLs with semicolons. Supported direct files are `.zip`, `.udk`, `.u`, `.upk`, `.ini`, and `.int`. Zip files are extracted, then synced using the same rules as uploaded files.

Startup sync rules:

```text
CustomContent\CookedPC\*  -> UDKGame\CookedPC
CustomContent\Maps\*      -> UDKGame\CookedPC\Maps\RenX
CustomContent\Config\*    -> UDKGame\Config
Zip-contained UDKGame\CookedPC structure is preserved
Loose *.udk files         -> UDKGame\CookedPC\Maps\RenX
Loose *.u and *.upk files -> UDKGame\CookedPC
Loose *.ini files         -> UDKGame\Config
Loose *.int files         -> UDKGame\Localization\INT
```

To load mutators, set the GSA `Mutators` parameter to comma-separated class names, for example:

```text
RenX_ExampleMutators.InfiniteAmmo,RenX_ExampleMutators.SuddenDeath
```

Most mutators need their package on both server and client. Place the `.u` package in `CustomContent`, and configure HTTP redirect if you expect public players to download it cleanly.

## GSA Parameters

Key parameters:

```text
Starting Map
Game Class Override
Map Cycle Class
Map Rotation
Server Payload URLs
Refresh Server Payload
Install Optional Map Pack 1
Install Optional Map Pack 2
Install Optional Map Pack 3
Mutators
Admin/RCON Password
Server Password
Message Of The Day
List Server
Fixed Map Rotation
Disable Bots
GDI Bot Count
NOD Bot Count
Allow Downloads
HTTP Redirect URL
Redirect Uses Compression
Required Content URLs
Web Port
Multihome IP
Custom Content URLs
Refresh Content Downloads
Extra Launch Args
```

Recommended first test:

```text
Starting Map = CNC-Field
Game Class Override = blank
Map Cycle Class = Rx_Game
Max Players = 40
List Server = true
Fixed Map Rotation = false
Disable Bots = false
RCON Port = GSA allocated rcon port
HTTP Redirect URL = https://community-content.totemarts.services/
```

Survival test:

```text
Starting Map = DEF-DarkNight
Game Class Override = RenX_Coop.Rx_Game_Survival
Map Cycle Class = Rx_Game_Survival
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
  -e RENX_MAX_PLAYERS="40" `
  -e RENX_GAME_PORT="7777" `
  -e RENX_PEER_PORT="7778" `
  -e RENX_QUERY_PORT="27015" `
  -e RENX_RCON_PORT="37015" `
  -e RENX_SERVER_PAYLOAD_URLS="https://example.com/renx-server-payload.zip" `
  -e RENX_REQUIRED_CONTENT_URLS="https://example.com/renx-required-maps.zip" `
  ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-core20-ltsc2022-r2
```

## References

- Totem Arts Wiki: Server Settings
- Totem Arts Wiki: Downloads
- Totem Arts Wiki: Mutator
- Totem Arts forum: Private LAN Server Creation
- Totem Arts forum: RenegadeX Server Loader

## Credits

Renegade X is created by Totem Arts. This project is an unofficial community hosting wrapper by TwistedBobRoss.
