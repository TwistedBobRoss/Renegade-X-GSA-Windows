[CmdletBinding()]
param(
    [string]$Owner = "TwistedBobRoss",
    [string]$Repo = "Renegade-X-GSA-Windows",
    [string]$PayloadPartsDir = ".\payload-parts",
    [string]$PayloadReleaseTag = "renx-payload-1.0.1022-headless-r2",
    [string]$ImageTag = "1.0.1022-ltsc2022-r4",
    [string]$Workflow = "build.yml",
    [switch]$ClobberAssets
)

$ErrorActionPreference = "Stop"

$repoFull = "$Owner/$Repo"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI is required. Install it from https://cli.github.com/ and run 'gh auth login'."
}

$payloadDir = Resolve-Path -LiteralPath $PayloadPartsDir
$parts = Get-ChildItem -LiteralPath $payloadDir -Filter "renx-server-payload.zip.*" -File |
    Where-Object { $_.Name -match '\.\d+$' } |
    Sort-Object Name

if (-not $parts) {
    throw "No payload split parts were found in $payloadDir. Run scripts\Prepare-RenXPayload.ps1 first."
}

$tooLarge = $parts | Where-Object { $_.Length -ge 2147483648 }
if ($tooLarge) {
    $names = ($tooLarge | ForEach-Object { "$($_.Name) ($($_.Length) bytes)" }) -join ", "
    throw "GitHub Release assets must be under 2 GiB each. Re-split the payload with a smaller PartSizeMB. Too large: $names"
}

$manifest = Get-ChildItem -LiteralPath $payloadDir -Filter "renx-server-payload-manifest.json" -File -ErrorAction SilentlyContinue
$assets = @($parts)
if ($manifest) {
    $assets += $manifest
}

Write-Host "Repository: $repoFull"
Write-Host "Payload release tag: $PayloadReleaseTag"
Write-Host "Image tag: ghcr.io/$($repoFull.ToLower()):$ImageTag"
Write-Host "Assets to upload:"
$assets | ForEach-Object { Write-Host " - $($_.Name)" }

& gh release view $PayloadReleaseTag --repo $repoFull *> $null
$releaseExists = ($LASTEXITCODE -eq 0)

if (-not $releaseExists) {
    Write-Host "Creating payload release $PayloadReleaseTag..."
    $notes = "Renegade X server payload split into GitHub-release-safe parts for the Windows container image build."
    & gh release create $PayloadReleaseTag --repo $repoFull --title $PayloadReleaseTag --notes $notes
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create GitHub Release $PayloadReleaseTag."
    }
}
else {
    Write-Host "Payload release already exists."
}

foreach ($asset in $assets) {
    Write-Host "Uploading $($asset.Name)..."
    $uploadArgs = @("release", "upload", $PayloadReleaseTag, $asset.FullName, "--repo", $repoFull)
    if ($ClobberAssets) {
        $uploadArgs += "--clobber"
    }

    & gh @uploadArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upload $($asset.Name). Use -ClobberAssets if you are replacing an existing asset."
    }
}

Write-Host "Starting GitHub Actions bootstrap image build..."
& gh workflow run $Workflow --repo $repoFull -f "image_tag=$ImageTag"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to dispatch workflow $Workflow."
}

Write-Host "Build dispatched. Watch it with:"
Write-Host "  gh run list --repo $repoFull --workflow $Workflow --limit 3"
Write-Host ""
Write-Host "Payload release URLs can be used in the GSA Server Payload URLs field:"
foreach ($asset in $assets) {
    Write-Host "  https://github.com/$repoFull/releases/download/$PayloadReleaseTag/$($asset.Name)"
}
Write-Host ""
Write-Host "If it succeeds, the image will be:"
Write-Host "  ghcr.io/$($repoFull.ToLower()):$ImageTag"
