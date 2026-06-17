param(
    [Parameter(Mandatory = $true)]
    [string]$SourceZip,

    [string]$OutputDir = ".\payload-parts",

    [int]$PartSizeMB = 1900,

    [switch]$IncludeMovies,

    [switch]$IncludePreviewVideos,

    [switch]$IncludeWin32,

    [string[]]$Maps = @()
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourceZip)) {
    throw "Source zip not found: $SourceZip"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$outputRoot = Resolve-Path -LiteralPath (New-Item -ItemType Directory -Force -Path $OutputDir)
$workRoot = Join-Path $outputRoot "work"
$payloadRoot = Join-Path $workRoot "renx_payload"
$payloadZip = Join-Path $outputRoot "renx-server-payload.zip"

if (Test-Path -LiteralPath $workRoot) {
    Remove-Item -LiteralPath $workRoot -Recurse -Force
}

Get-ChildItem -LiteralPath $outputRoot -Filter "renx-server-payload.zip*" -File | Remove-Item -Force
New-Item -ItemType Directory -Force -Path $payloadRoot | Out-Null

function Should-IncludeEntry {
    param([string]$Path)

    if ($Path -notlike "renegadex_beta/*") {
        return $false
    }

    if ($Path -like "renegadex_beta/Binaries/InstallData/*") {
        return $false
    }

    if ((-not $IncludeWin32) -and $Path -like "renegadex_beta/Binaries/Win32/*") {
        return $false
    }

    if ((-not $IncludeMovies) -and $Path -like "renegadex_beta/UDKGame/Movies/*") {
        return $false
    }

    if ((-not $IncludePreviewVideos) -and $Path -like "renegadex_beta/PreviewVids/*") {
        return $false
    }

    if ($Path -like "renegadex_beta/UDKGame/Splash/*") {
        return $false
    }

    if ($Path -match '^renegadex_beta/Engine/Localization/(CHN|JPN|KOR)/') {
        return $false
    }

    if ($Path -like "renegadex_beta/Binaries/Win64/UDK_dx9debug.exe" -or
        $Path -like "renegadex_beta/Binaries/Win64/UDK_d3d9.log" -or
        $Path -like "renegadex_beta/Binaries/Win64/UnrealLightmass.exe" -or
        $Path -like "renegadex_beta/Binaries/Win64/UE3ShaderCompileWorker.exe") {
        return $false
    }

    if ($Path -match '^renegadex_beta/Binaries/(MobileShaderAnalyzer|RPCUtility|ShaderKeyTool|UDKLift|UnSetup)(\.|$)' -or
        $Path -like "renegadex_beta/Binaries/P4API.dll" -or
        $Path -like "renegadex_beta/Binaries/Ionic.Zip.Reduced.dll" -or
        $Path -like "renegadex_beta/Binaries/UnSetup.Manifests*.xml") {
        return $false
    }

    if ($Maps.Count -gt 0 -and $Path -match '^renegadex_beta/UDKGame/CookedPC/Maps/RenX/([^/]+)\.udk$') {
        return $Maps -contains $Matches[1]
    }

    return $true
}

$archive = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $SourceZip))
try {
    foreach ($entry in $archive.Entries) {
        if ([string]::IsNullOrEmpty($entry.Name)) {
            continue
        }

        if (-not (Should-IncludeEntry $entry.FullName)) {
            continue
        }

        $relative = $entry.FullName.Substring("renegadex_beta/".Length).Replace("/", "\")
        $target = Join-Path $payloadRoot $relative
        $targetDir = Split-Path -Parent $target
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    }
}
finally {
    $archive.Dispose()
}

Compress-Archive -Path (Join-Path $payloadRoot "*") -DestinationPath $payloadZip -CompressionLevel Optimal -Force

$partSize = [int64]$PartSizeMB * 1MB
$buffer = New-Object byte[] (4MB)
$inputStream = [System.IO.File]::OpenRead($payloadZip)
try {
    $partNumber = 1
    while ($inputStream.Position -lt $inputStream.Length) {
        $partPath = "{0}.{1:D3}" -f $payloadZip, $partNumber
        $outputStream = [System.IO.File]::Create($partPath)
        try {
            $written = [int64]0
            while ($written -lt $partSize -and $inputStream.Position -lt $inputStream.Length) {
                $remaining = [Math]::Min($buffer.Length, $partSize - $written)
                $read = $inputStream.Read($buffer, 0, [int]$remaining)
                if ($read -le 0) {
                    break
                }
                $outputStream.Write($buffer, 0, $read)
                $written += $read
            }
        }
        finally {
            $outputStream.Dispose()
        }
        $partNumber++
    }
}
finally {
    $inputStream.Dispose()
}

$manifest = [ordered]@{
    source_zip = (Resolve-Path -LiteralPath $SourceZip).Path
    payload_zip = $payloadZip
    include_movies = [bool]$IncludeMovies
    include_preview_videos = [bool]$IncludePreviewVideos
    include_win32 = [bool]$IncludeWin32
    headless_exclusions = @(
        "UDKGame/Splash"
        "Engine/Localization/CHN"
        "Engine/Localization/JPN"
        "Engine/Localization/KOR"
        "Binaries/Win64/UDK_dx9debug.exe"
        "Binaries/Win64/UDK_d3d9.log"
        "Binaries/Win64/UnrealLightmass.exe"
        "Binaries/Win64/UE3ShaderCompileWorker.exe"
        "Binaries setup and editor utilities"
    )
    maps = @($Maps)
    part_size_mb = $PartSizeMB
    parts = @(Get-ChildItem -LiteralPath $outputRoot -Filter "renx-server-payload.zip.*" -File |
        Where-Object { $_.Name -match '\.\d+$' } |
        Sort-Object Name |
        ForEach-Object {
        [ordered]@{
            name = $_.Name
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outputRoot "renx-server-payload-manifest.json") -Encoding UTF8

Write-Host "Created payload archive and split parts in $outputRoot"
Write-Host "Upload renx-server-payload.zip.* and renx-server-payload-manifest.json to a GitHub Release."
