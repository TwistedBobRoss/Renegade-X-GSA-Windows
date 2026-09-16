# Build The Renegade X Bootstrap Windows Image

This repository builds a small Windows bootstrap image:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.2.1109-ltsc2022-r1
```

The image does not bake Renegade X game files into GHCR. It contains only:

- `Start.ps1`
- `LaunchRenegadeXServer.bat`
- Windows Server Core LTSC 2022 runtime

The actual Renegade X server runtime is downloaded during GSA install/first start into:

```text
C:\renx-data\ServerFiles
```

## Build In GitHub

Run the `Build Renegade X Bootstrap Windows Image` workflow and provide:

```text
image_tag = 1.2.1109-ltsc2022-r1
```

No payload release is required for the image build.

If you want to host the runtime zip parts on this repository's GitHub Releases, you can still use:

```powershell
.\scripts\Publish-RenXPayloadAndBuild.ps1 `
  -PayloadPartsDir ".\payload-parts" `
  -PayloadReleaseTag "renx-core20-1.2.1109-r1" `
  -ImageTag "1.2.1109-ltsc2022-r1"
```

The script uploads the payload release assets, dispatches the bootstrap image workflow, and prints release download URLs that can be pasted into GSA's `Server Payload URLs` field.

For the full 20-map GSA image, run `Build Renegade X Core 20 Windows Image` with the core payload release tag and a new versioned image tag. After the build and smoke test pass, update the public blueprint to that exact tag and reinstall each GSA server manually.

The server does not check a release manifest or update itself during startup. This keeps installation deterministic and makes the image tag the authoritative Renegade X version.

## Runtime Payload URLs

The blueprint includes current payload fallback URLs for manual recovery. Normal installations use the runtime baked into the versioned full image.

Use one direct public zip URL:

```text
https://example.com/renx-server-payload.zip
```

or split zip parts:

```text
https://example.com/renx-server-payload.zip.001
https://example.com/renx-server-payload.zip.002
https://example.com/renx-server-payload.zip.003
```

When a payload download is needed, the startup script downloads those files into:

```text
C:\renx-data\PayloadCache
```

Then it extracts the payload and finds the folder containing:

```text
Binaries\Win64\UDK.exe
```

## Required Maps And Content

Use `Required Content URLs` for stock map packs, map dependency packs, or other files that must exist before launch. Zip files may include normal Renegade X folder structure such as:

```text
UDKGame\CookedPC\Maps\RenX\CNC-Field.udk
UDKGame\CookedPC\RenX\...
UDKGame\Config\...
```

Loose `.udk`, `.u`, `.upk`, `.ini`, and `.int` files are also supported.

Use `Custom Content URLs` for optional mods/maps that are not required for the base launch.

## Refreshing Files

- `Refresh Server Payload` redownloads and reinstalls the runtime payload.
- `Refresh Content Downloads` redownloads required/custom content.

Leave both off for normal operation so GSA uses the persistent cache.
