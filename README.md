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

## What The Headless Image Needs

There does not appear to be a separate tiny dedicated-server-only package. Current community tooling and forum examples still launch `UDK.exe server` from a Renegade X install folder.

The safe server-focused payload keeps:

- `Binaries\Win64`
- `UDKGame\Config`
- `UDKGame\CookedPC`
- root and support files needed by the UDK build

The default payload script removes likely client-only pieces:

- `Binaries\Win32`
- `Binaries\InstallData`
- `UDKGame\Movies`
- `PreviewVids`

Do not blindly remove shared `UDKGame\CookedPC` packages. Even headless UDK servers load map, actor, weapon, vehicle, sound, and mutator packages. The script can include only selected `.udk` map files, but it keeps shared packages because package dependency discovery is safer to prove by live testing than by filename guesses.

## Image

Planned image name:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r2
```

This is a Windows container image intended for Windows Server 2022 / LTSC 2022 Windows container hosts.

## Prepare Payload

Do not commit Renegade X game files directly into this repository. Use a GitHub Release payload asset instead.

Full server-focused payload:

```powershell
.\scripts\Prepare-RenXPayload.ps1 `
  -SourceZip "C:\Users\imgon\Downloads\renegade_x_Release_1.0.1022_3.zip" `
  -OutputDir ".\payload-parts"
```

Smaller first-test payload with one stock map file plus shared packages:

```powershell
.\scripts\Prepare-RenXPayload.ps1 `
  -SourceZip "C:\Users\imgon\Downloads\renegade_x_Release_1.0.1022_3.zip" `
  -OutputDir ".\payload-parts-field" `
  -Maps CNC-Field
```

Upload the generated assets to a GitHub Release, for example tag:

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

The easiest path is to upload the split payload and dispatch the GitHub build workflow with:

```powershell
.\scripts\Publish-RenXPayloadAndBuild.ps1 `
  -Owner TwistedBobRoss `
  -Repo Renegade-X-GSA-Windows `
  -PayloadPartsDir ".\payload-parts" `
  -PayloadReleaseTag "renx-payload-1.0.1022" `
  -ImageTag "1.0.1022-ltsc2022-r2"
```

You can also run the `Build Renegade X Windows Image` workflow manually and provide:

```text
payload_release_tag = renx-payload-1.0.1022
image_tag = 1.0.1022-ltsc2022-r2
```

If the GitHub-hosted Windows runner runs out of disk space, use a self-hosted Windows Server 2022 runner with Docker configured for Windows containers.

See `BUILD_IMAGE.md` for the full build and publishing process.

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

You can also paste direct public download links into the `Custom Content URLs` parameter. Use one URL per line or separate URLs with semicolons. Supported direct files are `.zip`, `.udk`, `.u`, `.upk`, `.ini`, and `.int`. Zip files are extracted into `CustomContent\_Downloaded`, then synced using the same rules as uploaded files.

Startup sync rules:

```text
CustomContent\CookedPC\*  -> UDKGame\CookedPC
CustomContent\Maps\*      -> UDKGame\CookedPC\Maps\RenX
CustomContent\Config\*    -> UDKGame\Config
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
  ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r2
```

## References

- Totem Arts Wiki: Server Settings
- Totem Arts Wiki: Downloads
- Totem Arts Wiki: Mutator
- Totem Arts forum: Private LAN Server Creation
- Totem Arts forum: RenegadeX Server Loader

## Credits

Renegade X is created by Totem Arts. This project is an unofficial community hosting wrapper by TwistedBobRoss.
