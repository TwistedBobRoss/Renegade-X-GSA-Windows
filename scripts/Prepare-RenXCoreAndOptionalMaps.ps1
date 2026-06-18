[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PayloadRoot,

    [string]$OutputDir = ".\tiered-payload",

    [string]$CoreMapList = ".\maps\core-maps.txt",

    [int]$CorePartSizeMB = 1900,

    [int]$OptionalArchiveCount = 3
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$sourceRoot = (Resolve-Path -LiteralPath $PayloadRoot).Path.TrimEnd("\")
$mapRoot = Join-Path $sourceRoot "UDKGame\CookedPC\Maps\RenX"
$outputRoot = (New-Item -ItemType Directory -Force -Path $OutputDir).FullName
$coreZip = Join-Path $outputRoot "renx-core20-payload.zip"

if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot "Binaries\Win64\UDK.exe"))) {
    throw "Payload root does not contain Binaries\Win64\UDK.exe: $sourceRoot"
}

$coreMaps = @(
    Get-Content -LiteralPath $CoreMapList |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith("#") }
)
$allMapFiles = @(Get-ChildItem -LiteralPath $mapRoot -Filter "*.udk" -File | Sort-Object Name)
$allMapNames = @($allMapFiles.BaseName)
$missingCore = @($coreMaps | Where-Object { $allMapNames -notcontains $_ })

if ($missingCore.Count -gt 0) {
    throw "Core map list contains missing maps: $($missingCore -join ', ')"
}

$coreMapFiles = @($allMapFiles | Where-Object { $coreMaps -contains $_.BaseName })
$optionalMapFiles = @($allMapFiles | Where-Object { $coreMaps -notcontains $_.BaseName })

if ($allMapFiles.Count -ne 47 -or $coreMapFiles.Count -ne 20 -or $optionalMapFiles.Count -ne 27) {
    throw "Expected 47 total, 20 core, and 27 optional map files. Found $($allMapFiles.Count), $($coreMapFiles.Count), and $($optionalMapFiles.Count)."
}

Get-ChildItem -LiteralPath $outputRoot -File |
    Where-Object { $_.Name -like "renx-core20-payload.zip*" -or $_.Name -like "renx-optional-maps-*.zip" -or $_.Name -eq "renx-tiered-payload-manifest.json" } |
    Remove-Item -Force

function New-ZipFromFiles {
    param(
        [string]$ZipPath,
        [object[]]$Files,
        [scriptblock]$GetEntryName
    )

    $stream = [System.IO.File]::Create($ZipPath)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new(
            $stream,
            [System.IO.Compression.ZipArchiveMode]::Create,
            $false
        )
        try {
            foreach ($file in $Files) {
                $entryName = & $GetEntryName $file
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                    $archive,
                    $file.FullName,
                    $entryName,
                    [System.IO.Compression.CompressionLevel]::Optimal
                ) | Out-Null
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

Write-Host "Creating 20-map core runtime archive..."
$coreFiles = @(
    Get-ChildItem -LiteralPath $sourceRoot -File -Recurse |
        Where-Object {
            if ($_.DirectoryName -ne $mapRoot) {
                return $true
            }
            return $coreMaps -contains $_.BaseName
        }
)
New-ZipFromFiles $coreZip $coreFiles {
    param($file)
    $file.FullName.Substring($sourceRoot.Length + 1).Replace("\", "/")
}

Write-Host "Splitting core runtime archive..."
$partSize = [int64]$CorePartSizeMB * 1MB
$buffer = New-Object byte[] (4MB)
$inputStream = [System.IO.File]::OpenRead($coreZip)
try {
    $partNumber = 1
    while ($inputStream.Position -lt $inputStream.Length) {
        $partPath = "{0}.{1:D3}" -f $coreZip, $partNumber
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

Write-Host "Balancing 27 optional maps across $OptionalArchiveCount archives..."
$bins = @(
    for ($i = 0; $i -lt $OptionalArchiveCount; $i++) {
        [pscustomobject]@{
            Index = $i + 1
            Bytes = [int64]0
            Files = [System.Collections.Generic.List[object]]::new()
        }
    }
)

foreach ($mapFile in ($optionalMapFiles | Sort-Object Length -Descending)) {
    $bin = $bins | Sort-Object Bytes, Index | Select-Object -First 1
    $bin.Files.Add($mapFile)
    $bin.Bytes += $mapFile.Length
}

$optionalArchives = @()
foreach ($bin in ($bins | Sort-Object Index)) {
    $zipName = "renx-optional-maps-{0:D2}.zip" -f $bin.Index
    $zipPath = Join-Path $outputRoot $zipName
    Write-Host "Creating $zipName with $($bin.Files.Count) maps..."
    New-ZipFromFiles $zipPath @($bin.Files) {
        param($file)
        "UDKGame/CookedPC/Maps/RenX/$($file.Name)"
    }
    $optionalArchives += Get-Item -LiteralPath $zipPath
}

$coreParts = @(
    Get-ChildItem -LiteralPath $outputRoot -Filter "renx-core20-payload.zip.*" -File |
        Where-Object { $_.Name -match '\.\d+$' } |
        Sort-Object Name
)

$manifest = [ordered]@{
    source_payload_root = $sourceRoot
    core_map_count = $coreMapFiles.Count
    optional_map_count = $optionalMapFiles.Count
    core_maps = @($coreMapFiles.BaseName | Sort-Object)
    optional_maps = @($optionalMapFiles.BaseName | Sort-Object)
    core_zip = [ordered]@{
        name = (Get-Item $coreZip).Name
        bytes = (Get-Item $coreZip).Length
        sha256 = (Get-FileHash -LiteralPath $coreZip -Algorithm SHA256).Hash
    }
    core_parts = @($coreParts | ForEach-Object {
        [ordered]@{
            name = $_.Name
            bytes = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
    optional_archives = @($optionalArchives | ForEach-Object {
        $archive = $_
        $binNumber = [int]([regex]::Match($archive.BaseName, '(\d+)$').Groups[1].Value)
        $bin = $bins | Where-Object Index -eq $binNumber
        [ordered]@{
            name = $archive.Name
            bytes = $archive.Length
            sha256 = (Get-FileHash -LiteralPath $archive.FullName -Algorithm SHA256).Hash
            maps = @($bin.Files.BaseName | Sort-Object)
        }
    })
}

$manifestPath = Join-Path $outputRoot "renx-tiered-payload-manifest.json"
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Host "Created tiered Renegade X payload in $outputRoot"
Write-Host "Core maps: $($coreMapFiles.Count)"
Write-Host "Optional maps: $($optionalMapFiles.Count)"
Write-Host "Core parts: $($coreParts.Count)"
Write-Host "Optional archives: $($optionalArchives.Count)"
