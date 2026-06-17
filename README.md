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

## Bootstrap Hosting Model

There does not appear to be a separate tiny dedicated-server-only package. Current community tooling and forum examples still launch `UDK.exe server` from a Renegade X install folder.

This container is now a bootstrap image. The Docker image contains only the launch scripts. The Renegade X server runtime is downloaded during first start into the persistent GSA mount:

```text
C:\renx-data\ServerFiles
```

This keeps the published image small and avoids baking multi-gigabyte cooked client content into GHCR.

The runtime payload URL should point at a prepared Renegade X server zip or split zip parts. A safe server-focused payload keeps:

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

Planned image name:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r3
```

This is a Windows container image intended for Windows Server 2022 / LTSC 2022 Windows container hosts.

## Build Image

Run the `Build Renegade X Bootstrap Windows Image` workflow manually and provide:

```text
image_tag = 1.0.1022-ltsc2022-r3
```

The workflow no longer downloads or embeds the Renegade X payload. It builds the small bootstrap image directly from this repository.

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

On first start, `Start.ps1` downloads and extracts the payload into:

```text
C:\renx-data\ServerFiles
```

Set `Refresh Server Payload` to true only when you intentionally want to redownload and reinstall the runtime.

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
C:\renx-data\Config
C:\renx-data\CustomContent
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
  ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r3
```

## References

- Totem Arts Wiki: Server Settings
- Totem Arts Wiki: Downloads
- Totem Arts Wiki: Mutator
- Totem Arts forum: Private LAN Server Creation
- Totem Arts forum: RenegadeX Server Loader

## Credits

Renegade X is created by Totem Arts. This project is an unofficial community hosting wrapper by TwistedBobRoss.
