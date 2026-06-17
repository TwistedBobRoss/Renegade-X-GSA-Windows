# Build The Renegade X Windows Image

This repository contains the Dockerfile and GitHub Actions workflow needed to build the Windows container image:

```text
ghcr.io/twistedbobross/renegade-x-gsa-windows:1.0.1022-ltsc2022-r2
```

The image cannot be built from only the GitHub source files. Renegade X does not provide a separate tiny dedicated-server package, so the build also needs a prepared server payload from the Renegade X distribution.

## One Command Build Path

From the repository folder, prepare the payload:

```powershell
.\scripts\Prepare-RenXPayload.ps1 `
  -SourceZip "C:\Users\imgon\Downloads\renegade_x_Release_1.0.1022_3.zip" `
  -OutputDir ".\payload-parts"
```

Then upload the split payload parts to a GitHub Release and start the GitHub Actions build:

```powershell
.\scripts\Publish-RenXPayloadAndBuild.ps1 `
  -Owner TwistedBobRoss `
  -Repo Renegade-X-GSA-Windows `
  -PayloadPartsDir ".\payload-parts" `
  -PayloadReleaseTag "renx-payload-1.0.1022" `
  -ImageTag "1.0.1022-ltsc2022-r2"
```

If you are replacing existing release assets, add:

```powershell
-ClobberAssets
```

## Requirements

- GitHub CLI installed from `https://cli.github.com/`
- `gh auth login` completed with access to `TwistedBobRoss/Renegade-X-GSA-Windows`
- GitHub Packages enabled for the repository
- GitHub Actions enabled for the repository

The split payload parts are intentionally below GitHub's 2 GiB per-release-asset limit.

## Manual Build Path

If you do not want to use the publishing script:

1. Run `scripts\Prepare-RenXPayload.ps1`.
2. Create a GitHub Release named `renx-payload-1.0.1022`.
3. Upload every `renx-server-payload.zip.###` file from `payload-parts`.
4. Open Actions in GitHub.
5. Run `Build Renegade X Windows Image`.
6. Use:

```text
payload_release_tag = renx-payload-1.0.1022
image_tag = 1.0.1022-ltsc2022-r2
```

If the GitHub-hosted `windows-2022` runner runs out of disk space while expanding the payload or building Windows layers, move this workflow to a self-hosted Windows Server 2022 runner with Docker configured for Windows containers.
