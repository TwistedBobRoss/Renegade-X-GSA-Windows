$ErrorActionPreference = "Stop"

$bootstrapRoot = if ($env:RENX_BOOTSTRAP_ROOT) { $env:RENX_BOOTSTRAP_ROOT } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$root = if ($env:RENX_ROOT) { $env:RENX_ROOT } else { "C:\renx-data\ServerFiles" }
$dataRoot = if ($env:RENX_DATA_ROOT) { $env:RENX_DATA_ROOT } else { "C:\renx-data" }
$launcher = Join-Path $root "LaunchRenegadeXServer.bat"

function Get-Setting {
    param(
        [string]$Name,
        [string]$Default
    )

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value.Trim()
}

function ConvertTo-BoolString {
    param(
        [string]$Value,
        [string]$Default
    )

    $fallback = if ([string]::IsNullOrWhiteSpace($Default)) { "false" } else { $Default.Trim().ToLowerInvariant() }
    $normalized = if ([string]::IsNullOrWhiteSpace($Value)) { $fallback } else { $Value.Trim().ToLowerInvariant() }

    switch ($normalized) {
        "1" { return "true" }
        "true" { return "true" }
        "yes" { return "true" }
        "on" { return "true" }
        "0" { return "false" }
        "false" { return "false" }
        "no" { return "false" }
        "off" { return "false" }
        default { return $fallback }
    }
}

function Get-BoolSetting {
    param(
        [string]$Name,
        [string]$Default
    )

    return ConvertTo-BoolString (Get-Setting $Name $Default) $Default
}

function Set-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Force -Path $Path | Out-Null
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([System.IO.File]::ReadAllLines($Path))

    $sectionPattern = '^\s*\[' + [regex]::Escape($Section) + '\]\s*$'
    $anySectionPattern = '^\s*\[.+\]\s*$'
    $keyPattern = '^\s*' + [regex]::Escape($Key) + '\s*='

    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        $lines.Add("")
        $lines.Add("[$Section]")
        $lines.Add("$Key=$Value")
        [System.IO.File]::WriteAllLines($Path, $lines)
        return
    }

    $insertIndex = $lines.Count
    $matchingIndexes = [System.Collections.Generic.List[int]]::new()
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anySectionPattern) {
            $insertIndex = $i
            break
        }

        if ($lines[$i] -match $keyPattern) {
            $matchingIndexes.Add($i)
        }
    }

    if ($matchingIndexes.Count -eq 0) {
        $lines.Insert($insertIndex, "$Key=$Value")
    }
    else {
        $lines[$matchingIndexes[0]] = "$Key=$Value"
        for ($i = $matchingIndexes.Count - 1; $i -ge 1; $i--) {
            $lines.RemoveAt($matchingIndexes[$i])
        }
    }

    [System.IO.File]::WriteAllLines($Path, $lines)
}

function Get-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $sectionPattern = '^\s*\[' + [regex]::Escape($Section) + '\]\s*$'
    $anySectionPattern = '^\s*\[.+\]\s*$'
    $keyPattern = '^\s*' + [regex]::Escape($Key) + '\s*=(.*)$'
    $insideSection = $false

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match $sectionPattern) {
            $insideSection = $true
            continue
        }

        if ($insideSection -and $line -match $anySectionPattern) {
            break
        }

        if ($insideSection -and $line -match $keyPattern) {
            return $Matches[1].Trim()
        }
    }

    return $null
}

function Get-IniValueFromPaths {
    param(
        [string[]]$Paths,
        [string]$Section,
        [string]$Key
    )

    foreach ($path in $Paths) {
        $value = Get-IniValue $path $Section $Key
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    return $null
}

function Get-FirstEnvironmentSetting {
    param(
        [string[]]$Names,
        [string]$Default
    )

    foreach ($name in $Names) {
        $value = [Environment]::GetEnvironmentVariable($name)
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
    }

    return $Default
}

function Get-IniPreferredSetting {
    param(
        [string[]]$Paths,
        [string]$Section,
        [string]$Key,
        [string[]]$EnvironmentNames,
        [string]$Default
    )

    $iniValue = Get-IniValueFromPaths $Paths $Section $Key
    if (-not [string]::IsNullOrWhiteSpace($iniValue)) {
        return $iniValue
    }

    return Get-FirstEnvironmentSetting $EnvironmentNames $Default
}

function Get-IniPreferredBoolSetting {
    param(
        [string[]]$Paths,
        [string]$Section,
        [string]$Key,
        [string[]]$EnvironmentNames,
        [string]$Default
    )

    return ConvertTo-BoolString (Get-IniPreferredSetting $Paths $Section $Key $EnvironmentNames $Default) $Default
}

function Get-MapRotationFromIni {
    param(
        [string]$Path,
        [string]$CycleClass
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $sectionPattern = '^\s*\[UTGame\.UTGame\]\s*$'
    $anySectionPattern = '^\s*\[.+\]\s*$'
    $cyclePattern = '^\s*\+?GameSpecificMapCycles\s*=(.*)$'
    $classPattern = 'GameClassName\s*=\s*"' + [regex]::Escape($CycleClass) + '"'
    $insideSection = $false

    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line -match $sectionPattern) {
            $insideSection = $true
            continue
        }

        if ($insideSection -and $line -match $anySectionPattern) {
            break
        }

        if (-not $insideSection -or $line -notmatch $cyclePattern) {
            continue
        }

        $cycleValue = $Matches[1]
        if ($cycleValue -notmatch $classPattern -or $cycleValue -notmatch 'Maps\s*=\s*\((.*)\)') {
            continue
        }

        $mapsText = $Matches[1]
        $maps = @(
            [regex]::Matches($mapsText, '"([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value.Trim() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        if ($maps.Count -gt 0) {
            return ($maps -join ",")
        }
    }

    return $null
}

function Set-MapRotation {
    param(
        [string]$Path,
        [string]$CycleClass,
        [string]$MapsCsv
    )

    if ([string]::IsNullOrWhiteSpace($MapsCsv)) {
        return
    }

    $maps = @(
        $MapsCsv -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($maps.Count -eq 0) {
        return
    }

    $escapedMaps = @($maps | ForEach-Object { '"' + ($_ -replace '"', '') + '"' }) -join ","
    $lineKey = if ((Split-Path -Leaf $Path) -like "Default*") { "+GameSpecificMapCycles" } else { "GameSpecificMapCycles" }
    $newLine = "$lineKey=(GameClassName=`"$CycleClass`",Maps=($escapedMaps))"

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Force -Path $Path | Out-Null
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([System.IO.File]::ReadAllLines($Path))

    $sectionPattern = '^\s*\[UTGame\.UTGame\]\s*$'
    $anySectionPattern = '^\s*\[.+\]\s*$'
    $cyclePattern = '^\s*\+?GameSpecificMapCycles\s*=\s*\(.*GameClassName\s*=\s*"' + [regex]::Escape($CycleClass) + '"'

    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        $lines.Add("")
        $lines.Add("[UTGame.UTGame]")
        $lines.Add($newLine)
        [System.IO.File]::WriteAllLines($Path, $lines)
        return
    }

    $insertIndex = $lines.Count
    $matchingIndexes = [System.Collections.Generic.List[int]]::new()
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anySectionPattern) {
            $insertIndex = $i
            break
        }

        if ($lines[$i] -match $cyclePattern) {
            $matchingIndexes.Add($i)
        }
    }

    if ($matchingIndexes.Count -eq 0) {
        $lines.Insert($insertIndex, $newLine)
    }
    else {
        $lines[$matchingIndexes[0]] = $newLine
        for ($i = $matchingIndexes.Count - 1; $i -ge 1; $i--) {
            $lines.RemoveAt($matchingIndexes[$i])
        }
    }

    [System.IO.File]::WriteAllLines($Path, $lines)
}

function Get-MapListSectionForCycleClass {
    param([string]$CycleClass)

    switch ($CycleClass) {
        "Rx_Game_Survival" { return "DEFMapList Rx_MapList" }
        default { return "CNCMapList Rx_MapList" }
    }
}

function Set-MapList {
    param(
        [string]$Path,
        [string]$Section,
        [string]$MapsCsv
    )

    if ([string]::IsNullOrWhiteSpace($MapsCsv) -or [string]::IsNullOrWhiteSpace($Section)) {
        return
    }

    $maps = @(
        $MapsCsv -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($maps.Count -eq 0) {
        return
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType File -Force -Path $Path | Out-Null
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([System.IO.File]::ReadAllLines($Path))

    $sectionPattern = '^\s*\[' + [regex]::Escape($Section) + '\]\s*$'
    $anySectionPattern = '^\s*\[.+\]\s*$'
    $mapPattern = '^\s*Maps\s*='

    $sectionIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $sectionPattern) {
            $sectionIndex = $i
            break
        }
    }

    if ($sectionIndex -lt 0) {
        $lines.Add("")
        $lines.Add("[$Section]")
        foreach ($mapName in $maps) {
            $lines.Add('Maps=(Map="' + ($mapName -replace '"', '') + '")')
        }
        [System.IO.File]::WriteAllLines($Path, $lines)
        return
    }

    $insertIndex = $lines.Count
    $matchingIndexes = [System.Collections.Generic.List[int]]::new()
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anySectionPattern) {
            $insertIndex = $i
            break
        }

        if ($lines[$i] -match $mapPattern) {
            $matchingIndexes.Add($i)
        }
    }

    for ($i = $matchingIndexes.Count - 1; $i -ge 0; $i--) {
        $lines.RemoveAt($matchingIndexes[$i])
        if ($matchingIndexes[$i] -lt $insertIndex) {
            $insertIndex--
        }
    }

    $newLines = @($maps | ForEach-Object { 'Maps=(Map="' + ($_ -replace '"', '') + '")' })
    for ($i = 0; $i -lt $newLines.Count; $i++) {
        $lines.Insert($insertIndex + $i, $newLines[$i])
    }

    [System.IO.File]::WriteAllLines($Path, $lines)
}

function Set-IniSectionValues {
    param(
        [string]$Path,
        [string]$Section,
        [System.Collections.IDictionary]$Values
    )

    foreach ($key in $Values.Keys) {
        Set-IniValue $Path $Section $key ([string]$Values[$key])
    }
}

function Split-SettingList {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return @()
    }

    return @(
        $Value -split "[`r`n;]+" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
}

function Copy-CustomContentFile {
    param(
        [string]$File,
        [string]$InstallRoot
    )

    $cookedTarget = Join-Path $InstallRoot "UDKGame\CookedPC"
    $mapTarget = Join-Path $cookedTarget "Maps\RenX"
    $configTarget = Join-Path $InstallRoot "UDKGame\Config"
    $localizationTarget = Join-Path $InstallRoot "UDKGame\Localization\INT"

    New-Item -ItemType Directory -Force -Path $cookedTarget, $mapTarget, $configTarget, $localizationTarget | Out-Null

    $extension = [System.IO.Path]::GetExtension($File).ToLowerInvariant()
    switch ($extension) {
        ".udk" { Copy-Item -LiteralPath $File -Destination $mapTarget -Force; break }
        ".u" { Copy-Item -LiteralPath $File -Destination $cookedTarget -Force; break }
        ".upk" { Copy-Item -LiteralPath $File -Destination $cookedTarget -Force; break }
        ".ini" { Copy-Item -LiteralPath $File -Destination $configTarget -Force; break }
        ".int" { Copy-Item -LiteralPath $File -Destination $localizationTarget -Force; break }
    }
}

function Sync-CustomContent {
    param(
        [string]$SourceRoot,
        [string]$InstallRoot
    )

    if (-not (Test-Path -LiteralPath $SourceRoot)) {
        return
    }

    $structuredRoots = [System.Collections.Generic.List[string]]::new()
    $cookedTarget = Join-Path $InstallRoot "UDKGame\CookedPC"
    $configTarget = Join-Path $InstallRoot "UDKGame\Config"
    $localizationTarget = Join-Path $InstallRoot "UDKGame\Localization\INT"
    New-Item -ItemType Directory -Force -Path $cookedTarget, $configTarget, $localizationTarget | Out-Null

    Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "CookedPC" } |
        ForEach-Object {
            Write-Host "Syncing structured CookedPC content from $($_.FullName)"
            Copy-Item -Path (Join-Path $_.FullName "*") -Destination $cookedTarget -Recurse -Force
            $structuredRoots.Add($_.FullName.TrimEnd('\') + '\')
        }

    Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "Config" -and $_.FullName -notmatch '\\UDKGame\\CookedPC\\' } |
        ForEach-Object {
            Write-Host "Syncing structured Config content from $($_.FullName)"
            Copy-Item -Path (Join-Path $_.FullName "*") -Destination $configTarget -Recurse -Force
            $structuredRoots.Add($_.FullName.TrimEnd('\') + '\')
        }

    Get-ChildItem -LiteralPath $SourceRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq "INT" -and (Split-Path -Leaf (Split-Path -Parent $_.FullName)) -eq "Localization" } |
        ForEach-Object {
            Write-Host "Syncing structured localization content from $($_.FullName)"
            Copy-Item -Path (Join-Path $_.FullName "*") -Destination $localizationTarget -Recurse -Force
            $structuredRoots.Add($_.FullName.TrimEnd('\') + '\')
        }

    Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $insideStructuredRoot = $false
        foreach ($structuredRoot in $structuredRoots) {
            if ($_.FullName.StartsWith($structuredRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $insideStructuredRoot = $true
                break
            }
        }

        if (-not $insideStructuredRoot) {
            Copy-CustomContentFile $_.FullName $InstallRoot
        }
    }
}

function Invoke-CustomContentDownloads {
    param(
        [string]$Urls,
        [string]$DestinationRoot,
        [bool]$Refresh,
        [string]$Label = "custom content"
    )

    $urlList = Split-SettingList $Urls
    if ($urlList.Count -eq 0) {
        return
    }

    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null

    foreach ($url in $urlList) {
        $uri = [Uri]$url
        $fileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = "renx-content-{0}.bin" -f ([Guid]::NewGuid().ToString("N"))
        }

        $downloadPath = Join-Path $DestinationRoot $fileName
        if ($Refresh -or -not (Test-Path -LiteralPath $downloadPath)) {
            Write-Host "Downloading ${Label}: $url"
            Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing
        }
        else {
            Write-Host "Using cached ${Label}: $fileName"
        }

        if ([System.IO.Path]::GetExtension($downloadPath).ToLowerInvariant() -eq ".zip") {
            $extractPath = Join-Path $DestinationRoot ([System.IO.Path]::GetFileNameWithoutExtension($fileName))
            if ($Refresh -and (Test-Path -LiteralPath $extractPath)) {
                Remove-Item -LiteralPath $extractPath -Recurse -Force
            }

            if (-not (Test-Path -LiteralPath $extractPath)) {
                New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
                Expand-Archive -LiteralPath $downloadPath -DestinationPath $extractPath -Force
            }
        }
    }
}

function Find-ServerPayloadRoot {
    param([string]$ExtractRoot)

    $udk = Get-ChildItem -LiteralPath $ExtractRoot -Filter "UDK.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match '\\Binaries\\Win64\\UDK\.exe$' } |
        Select-Object -First 1

    if (-not $udk) {
        return $null
    }

    $win64Dir = Split-Path -Parent $udk.FullName
    $binariesDir = Split-Path -Parent $win64Dir
    return Split-Path -Parent $binariesDir
}

function Test-ServerRuntime {
    param(
        [string]$InstallRoot,
        [switch]$RequireLauncher
    )

    $requiredPaths = @(
        "Binaries\Win64\UDK.exe"
        "UDKGame\Config"
        "UDKGame\CookedPC"
        "UDKGame\CookedPC\Maps\RenX"
    )

    if ($RequireLauncher) {
        $requiredPaths += "LaunchRenegadeXServer.bat"
    }

    foreach ($relativePath in $requiredPaths) {
        if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot $relativePath))) {
            Write-Host "Renegade X runtime validation missing: $relativePath"
            return $false
        }
    }

    $mapCount = @(Get-ChildItem -LiteralPath (Join-Path $InstallRoot "UDKGame\CookedPC\Maps\RenX") -Filter "*.udk" -File -ErrorAction SilentlyContinue).Count
    if ($mapCount -lt 1) {
        Write-Host "Renegade X runtime validation found no maps."
        return $false
    }

    return $true
}

function Install-SeedRuntime {
    param(
        [string]$SeedRoot,
        [string]$InstallRoot,
        [string]$BootstrapRoot
    )

    if ((Test-ServerRuntime $InstallRoot) -or [string]::IsNullOrWhiteSpace($SeedRoot)) {
        return
    }

    if (-not (Test-ServerRuntime $SeedRoot)) {
        Write-Host "No valid baked Renegade X seed runtime was found; using payload download fallback."
        return
    }

    Write-Host "Installing baked 20-map Renegade X core runtime into persistent storage..."
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    Copy-Item -Path (Join-Path $SeedRoot "*") -Destination $InstallRoot -Recurse -Force

    $bootstrapLauncher = Join-Path $BootstrapRoot "LaunchRenegadeXServer.bat"
    if (Test-Path -LiteralPath $bootstrapLauncher) {
        Copy-Item -LiteralPath $bootstrapLauncher -Destination (Join-Path $InstallRoot "LaunchRenegadeXServer.bat") -Force
    }

    if (-not (Test-ServerRuntime $InstallRoot -RequireLauncher)) {
        throw "Baked Renegade X seed runtime failed validation after copying to $InstallRoot"
    }
}

function Install-ServerPayload {
    param(
        [string]$Urls,
        [string]$InstallRoot,
        [string]$PersistentRoot,
        [string]$BootstrapRoot,
        [bool]$Refresh
    )

    $udkPath = Join-Path $InstallRoot "Binaries\Win64\UDK.exe"
    $bootstrapLauncher = Join-Path $BootstrapRoot "LaunchRenegadeXServer.bat"
    $installLauncher = Join-Path $InstallRoot "LaunchRenegadeXServer.bat"

    if ((Test-ServerRuntime $InstallRoot) -and -not $Refresh) {
        if ((Test-Path -LiteralPath $bootstrapLauncher) -and -not (Test-Path -LiteralPath $installLauncher)) {
            Copy-Item -LiteralPath $bootstrapLauncher -Destination $installLauncher -Force
        }

        if (Test-ServerRuntime $InstallRoot -RequireLauncher) {
            Write-Host "Renegade X server runtime is already installed; skipping payload download."
            return
        }
    }

    $urlList = Split-SettingList $Urls
    if ($urlList.Count -eq 0) {
        throw "Renegade X server files are not installed at $InstallRoot and RENX_SERVER_PAYLOAD_URLS is empty. Provide a direct .zip URL or split .zip.001/.002 URLs."
    }

    $cacheRoot = Join-Path $PersistentRoot "PayloadCache"
    $downloadRoot = Join-Path $cacheRoot "Downloads"
    $extractRoot = Join-Path $cacheRoot "Extracted"
    New-Item -ItemType Directory -Force -Path $downloadRoot, $extractRoot, $InstallRoot | Out-Null

    if ($Refresh) {
        Get-ChildItem -LiteralPath $downloadRoot -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*.zip" -or $_.Name -match '\.zip\.\d+$' } |
            Remove-Item -Force
    }

    foreach ($url in $urlList) {
        $uri = [Uri]$url
        $fileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = "renx-payload-{0}.bin" -f ([Guid]::NewGuid().ToString("N"))
        }

        $downloadPath = Join-Path $downloadRoot $fileName
        if ($Refresh -or -not (Test-Path -LiteralPath $downloadPath)) {
            Write-Host "Downloading Renegade X server payload: $url"
            Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing
        }
        else {
            Write-Host "Using cached Renegade X server payload: $fileName"
        }
    }

    $zipParts = Get-ChildItem -LiteralPath $downloadRoot -Filter "*.zip.*" -File |
        Where-Object { $_.Name -match '\.\d+$' } |
        Sort-Object Name

    $zipFiles = @(Get-ChildItem -LiteralPath $downloadRoot -Filter "*.zip" -File | Sort-Object Name)
    $payloadZip = $null

    if ($zipParts.Count -gt 0) {
        $payloadZip = Join-Path $cacheRoot "renx-server-payload.zip"
        if ($Refresh -or -not (Test-Path -LiteralPath $payloadZip)) {
            if (Test-Path -LiteralPath $payloadZip) {
                Remove-Item -LiteralPath $payloadZip -Force
            }

            Write-Host "Reassembling Renegade X split payload parts..."
            $out = [System.IO.File]::Create($payloadZip)
            try {
                foreach ($part in $zipParts) {
                    Write-Host "Appending $($part.Name)"
                    $input = [System.IO.File]::OpenRead($part.FullName)
                    try {
                        $input.CopyTo($out)
                    }
                    finally {
                        $input.Dispose()
                    }
                }
            }
            finally {
                $out.Dispose()
            }
        }
    }
    elseif ($zipFiles.Count -eq 1) {
        $payloadZip = $zipFiles[0].FullName
    }
    elseif ($zipFiles.Count -gt 1) {
        throw "Multiple .zip payload files were found in $downloadRoot. Use one payload zip, or split parts named .zip.001, .zip.002, etc."
    }
    else {
        throw "No Renegade X payload .zip or split .zip.### files were found after download."
    }

    if ($Refresh -and (Test-Path -LiteralPath $extractRoot)) {
        Remove-Item -LiteralPath $extractRoot -Recurse -Force
    }

    if (-not (Test-Path -LiteralPath (Join-Path $extractRoot ".extracted"))) {
        if (Test-Path -LiteralPath $extractRoot) {
            Get-ChildItem -LiteralPath $extractRoot -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        }

        New-Item -ItemType Directory -Force -Path $extractRoot | Out-Null
        Write-Host "Extracting Renegade X server payload..."
        Expand-Archive -LiteralPath $payloadZip -DestinationPath $extractRoot -Force
        New-Item -ItemType File -Force -Path (Join-Path $extractRoot ".extracted") | Out-Null
    }

    $payloadRoot = Find-ServerPayloadRoot $extractRoot
    if (-not $payloadRoot) {
        throw "The extracted payload does not contain Binaries\Win64\UDK.exe."
    }

    if ($Refresh -and (Test-Path -LiteralPath $InstallRoot)) {
        Get-ChildItem -LiteralPath $InstallRoot -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    }

    Write-Host "Installing Renegade X server runtime to $InstallRoot"
    Copy-Item -Path (Join-Path $payloadRoot "*") -Destination $InstallRoot -Recurse -Force

    if (Test-Path -LiteralPath $bootstrapLauncher) {
        Copy-Item -LiteralPath $bootstrapLauncher -Destination $installLauncher -Force
    }

    if (-not (Test-ServerRuntime $InstallRoot -RequireLauncher)) {
        throw "Renegade X payload install failed runtime validation at $InstallRoot"
    }

    $installManifest = [ordered]@{
        installed_at_utc = [DateTime]::UtcNow.ToString("o")
        map_count = @(Get-ChildItem -LiteralPath (Join-Path $InstallRoot "UDKGame\CookedPC\Maps\RenX") -Filter "*.udk" -File).Count
        udk_path = $udkPath
    }
    $installManifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $InstallRoot ".renx-install.json") -Encoding UTF8
}

function Initialize-RuntimeConfig {
    param(
        [string]$InstallConfigDir,
        [string]$PersistentConfigDir
    )

    $configPairs = @(
        @{ Runtime = "UDKGame.ini"; Default = "DefaultGame.ini" },
        @{ Runtime = "UDKEngine.ini"; Default = "DefaultEngine.ini" },
        @{ Runtime = "UDKMapList.ini"; Default = "DefaultMapList.ini" },
        @{ Runtime = "UDKRenegadeX.ini"; Default = "DefaultRenegadeX.ini" },
        @{ Runtime = "UDKSurvival.ini"; Default = "DefaultSurvival.ini" },
        @{ Runtime = "UDKWeb.ini"; Default = "DefaultWeb.ini" }
    )

    foreach ($pair in $configPairs) {
        $runtimeSource = Join-Path $InstallConfigDir $pair.Runtime
        $defaultSource = Join-Path $InstallConfigDir $pair.Default
        $target = Join-Path $PersistentConfigDir $pair.Runtime

        if (Test-Path -LiteralPath $target) {
            continue
        }

        if (Test-Path -LiteralPath $runtimeSource) {
            Copy-Item -LiteralPath $runtimeSource -Destination $target -Force
        }
        elseif (Test-Path -LiteralPath $defaultSource) {
            Copy-Item -LiteralPath $defaultSource -Destination $target -Force
        }
    }
}

function Import-GsaRuntimeConfig {
    param(
        [string]$InstallConfigDir,
        [string]$PersistentConfigDir
    )

    if (-not (Test-Path -LiteralPath $InstallConfigDir)) {
        return
    }

    $configNames = @(
        "UDKGame.ini",
        "UDKEngine.ini",
        "UDKMapList.ini",
        "UDKRenegadeX.ini",
        "UDKSurvival.ini",
        "UDKWeb.ini"
    )

    New-Item -ItemType Directory -Force -Path $PersistentConfigDir | Out-Null

    foreach ($name in $configNames) {
        $source = Join-Path $InstallConfigDir $name
        $target = Join-Path $PersistentConfigDir $name

        if (-not (Test-Path -LiteralPath $source)) {
            continue
        }

        $shouldImport = $false
        if (-not (Test-Path -LiteralPath $target)) {
            $shouldImport = $true
        }
        else {
            $sourceInfo = Get-Item -LiteralPath $source
            $targetInfo = Get-Item -LiteralPath $target
            $shouldImport = $sourceInfo.LastWriteTimeUtc -gt $targetInfo.LastWriteTimeUtc.AddSeconds(1)
        }

        if ($shouldImport) {
            Copy-Item -LiteralPath $source -Destination $target -Force
            Write-Host "Imported GSA config template file: $name"
        }
    }
}

function Sync-RuntimeVersionSettings {
    param(
        [string]$InstallConfigDir,
        [string]$PersistentConfigDir
    )

    $persistentRenegadeX = Join-Path $PersistentConfigDir "UDKRenegadeX.ini"
    $runtimeRenegadeX = Join-Path $InstallConfigDir "UDKRenegadeX.ini"
    $defaultRenegadeX = Join-Path $InstallConfigDir "DefaultRenegadeX.ini"
    $sources = @($defaultRenegadeX, $runtimeRenegadeX)
    $targets = @($persistentRenegadeX, $runtimeRenegadeX, $defaultRenegadeX)

    foreach ($key in @("GameVersion", "GameVersionNumber")) {
        $value = $null
        foreach ($source in $sources) {
            $value = Get-IniValue $source "RenX_Game.Rx_Game" $key
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                break
            }
        }

        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        foreach ($target in $targets) {
            Set-IniValue $target "RenX_Game.Rx_Game" $key $value
        }

        Write-Host "Synced Renegade X runtime version setting: $key=$value"
    }
}

$serverName = Get-Setting "RENX_SERVER_NAME" "Renegade X Server"
$map = Get-Setting "RENX_MAP" "CNC-Field"
$gameClass = Get-Setting "RENX_GAME_CLASS" ""
if ($gameClass -eq "none") {
    $gameClass = ""
}
$modeProfile = Get-Setting "RENX_MODE_PROFILE" ""
$mapCycleClass = Get-Setting "RENX_MAP_CYCLE_CLASS" "Rx_Game"
$mapRotation = Get-Setting "RENX_MAP_ROTATION" ""
$mutators = Get-Setting "RENX_MUTATORS" ""
$maxPlayers = Get-Setting "RENX_MAX_PLAYERS" "40"
$gamePort = Get-Setting "RENX_GAME_PORT" "7777"
$peerPort = Get-Setting "RENX_PEER_PORT" "7778"
$queryPort = Get-Setting "RENX_QUERY_PORT" "27015"
$rconPort = Get-Setting "RENX_RCON_PORT" "-1"
$webPort = Get-Setting "RENX_WEB_PORT" "6969"
$adminPassword = Get-Setting "RENX_ADMIN_PASSWORD" ""
$serverPassword = Get-Setting "RENX_SERVER_PASSWORD" ""
$listed = Get-BoolSetting "RENX_LISTED" "true"
$fixedMapRotation = Get-BoolSetting "RENX_FIXED_MAP_ROTATION" (Get-BoolSetting "RENX_VOTE_FIXED_ROTATION" "false")
$botsDisabled = Get-BoolSetting "RENX_BOTS_DISABLED" "false"
$allowDownloads = Get-BoolSetting "RENX_ALLOW_DOWNLOADS" "true"
$redirectUrl = Get-Setting "RENX_REDIRECT_URL" "https://community-content.totemarts.services/"
$redirectUseCompression = Get-BoolSetting "RENX_REDIRECT_USE_COMPRESSION" "false"
$serverPayloadUrls = Get-Setting "RENX_SERVER_PAYLOAD_URLS" ""
$refreshServerPayload = [System.Convert]::ToBoolean((Get-BoolSetting "RENX_REFRESH_SERVER_PAYLOAD" "false"))
$seedRoot = Get-Setting "RENX_SEED_ROOT" ""
$installOptionalMapPack1 = [System.Convert]::ToBoolean((Get-BoolSetting "RENX_INSTALL_OPTIONAL_MAP_PACK_1" "false"))
$installOptionalMapPack2 = [System.Convert]::ToBoolean((Get-BoolSetting "RENX_INSTALL_OPTIONAL_MAP_PACK_2" "false"))
$installOptionalMapPack3 = [System.Convert]::ToBoolean((Get-BoolSetting "RENX_INSTALL_OPTIONAL_MAP_PACK_3" "false"))
$optionalMapPack1Url = Get-Setting "RENX_OPTIONAL_MAP_PACK_1_URL" ""
$optionalMapPack2Url = Get-Setting "RENX_OPTIONAL_MAP_PACK_2_URL" ""
$optionalMapPack3Url = Get-Setting "RENX_OPTIONAL_MAP_PACK_3_URL" ""
$requiredContentUrls = Get-Setting "RENX_REQUIRED_CONTENT_URLS" ""
$contentUrls = Get-Setting "RENX_CONTENT_URLS" ""
$refreshContentDownloads = [System.Convert]::ToBoolean((Get-BoolSetting "RENX_REFRESH_CONTENT_DOWNLOADS" "false"))
$gdiBots = Get-Setting "RENX_GDI_BOTS" ""
$nodBots = Get-Setting "RENX_NOD_BOTS" ""
$enableRcon = Get-BoolSetting "RENX_ENABLE_RCON" "true"
$rconSubscriberLimit = Get-Setting "RENX_RCON_SUBSCRIBER_LIMIT" "8"
$webEnabled = Get-BoolSetting "RENX_WEB_ENABLED" "false"
$webMaxConnections = Get-Setting "RENX_WEB_MAX_CONNECTIONS" "32"
$netWait = Get-Setting "RENX_NET_WAIT" "15"
$minNetPlayers = Get-Setting "RENX_MIN_NET_PLAYERS" "1"
$waitForNetPlayers = Get-BoolSetting "RENX_WAIT_FOR_NET_PLAYERS" "false"
$forceRespawn = Get-BoolSetting "RENX_FORCE_RESPAWN" "true"
$playersMustBeReady = Get-BoolSetting "RENX_PLAYERS_MUST_BE_READY" "false"
$restartWait = Get-Setting "RENX_RESTART_WAIT" "30"
$initialCredits = Get-Setting "RENX_INITIAL_CREDITS" "0"
$marathonMode = [System.Convert]::ToBoolean((Get-BoolSetting "RENX_MARATHON_MODE" "false"))
$timeLimit = Get-Setting "RENX_TIME_LIMIT" "50"
$cncTimeLimit = Get-Setting "RENX_CNC_TIME_LIMIT" "30"
$dmTimeLimit = Get-Setting "RENX_DM_TIME_LIMIT" "20"
$buildingsRevive = Get-BoolSetting "RENX_BUILDINGS_REVIVE" "true"
$enableAirdrops = Get-BoolSetting "RENX_ENABLE_AIRDROPS" "false"
$teamMode = Get-Setting "RENX_TEAM_MODE" "6"
$maxMapVoteSize = Get-Setting "RENX_MAX_MAP_VOTE_SIZE" (Get-Setting "RENX_VOTE_MAX_CHOICES" "5")
$recentMapsToExclude = Get-Setting "RENX_RECENT_MAPS_TO_EXCLUDE" (Get-Setting "RENX_VOTE_RECENT_EXCLUDE" "5")
$mapVoteTime = Get-Setting "RENX_VOTE_DURATION" "35"
$changeMapDisabledTime = Get-Setting "RENX_VOTE_CHANGE_MAP_LOCKOUT" "600"
$adminsStartMapVote = Get-BoolSetting "RENX_VOTE_ADMINS_START" "false"
$botVotesDisabled = Get-BoolSetting "RENX_VOTE_BOTS_DISABLED" "false"
$removeVariantMapsInVoteList = Get-BoolSetting "RENX_VOTE_REMOVE_VARIANTS" "true"
$surrenderLength = Get-Setting "RENX_CNC_SURRENDER_LENGTH" "120"
$surrenderDisabledTime = Get-Setting "RENX_CNC_SURRENDER_LOCKOUT" "600"
$spawnCrates = Get-BoolSetting "RENX_SPAWN_CRATES" "true"
$maxClientRate = Get-Setting "RENX_MAX_CLIENT_RATE" "15000"
$maxInternetClientRate = Get-Setting "RENX_MAX_INTERNET_CLIENT_RATE" "10000"
$serverTickRate = Get-Setting "RENX_SERVER_TICK_RATE" "30"
$gdiBotDifficulty = Get-Setting "RENX_GDI_BOT_DIFFICULTY" "1.0"
$nodBotDifficulty = Get-Setting "RENX_NOD_BOT_DIFFICULTY" "1.0"
$gdiAttackPercent = Get-Setting "RENX_GDI_ATTACK_PERCENT" "50"
$nodAttackPercent = Get-Setting "RENX_NOD_ATTACK_PERCENT" "50"
$multihome = Get-Setting "RENX_MULTIHOME" ""
$extraArgs = Get-Setting "RENX_EXTRA_ARGS" ""

if ($marathonMode) {
    $timeLimit = "0"
    $cncTimeLimit = "0"
    $buildingsRevive = "false"
    $enableAirdrops = "true"
}

$installConfigDir = Join-Path $root "UDKGame\Config"
$configDir = Join-Path $dataRoot "Config"
Import-GsaRuntimeConfig $installConfigDir $configDir

Install-SeedRuntime $seedRoot $root $bootstrapRoot
Install-ServerPayload $serverPayloadUrls $root $dataRoot $bootstrapRoot $refreshServerPayload
$launcher = Join-Path $root "LaunchRenegadeXServer.bat"

$customContentDir = Join-Path $dataRoot "CustomContent"
$downloadedContentDir = Join-Path $customContentDir "_Downloaded"
$requiredContentDir = Join-Path $customContentDir "_Required"
$optionalMapDir = Join-Path $customContentDir "_OptionalMaps"
$logDir = Join-Path $dataRoot "Logs"

New-Item -ItemType Directory -Force -Path $configDir, $customContentDir, $logDir | Out-Null
Initialize-RuntimeConfig $installConfigDir $configDir
Sync-RuntimeVersionSettings $installConfigDir $configDir

$udkGame = Join-Path $configDir "UDKGame.ini"
$udkEngine = Join-Path $configDir "UDKEngine.ini"
$udkMapList = Join-Path $configDir "UDKMapList.ini"
$udkRenegadeX = Join-Path $configDir "UDKRenegadeX.ini"
$udkSurvival = Join-Path $configDir "UDKSurvival.ini"
$udkWeb = Join-Path $configDir "UDKWeb.ini"
$runtimeGame = Join-Path $installConfigDir "UDKGame.ini"
$defaultGame = Join-Path $installConfigDir "DefaultGame.ini"
$runtimeEngine = Join-Path $installConfigDir "UDKEngine.ini"
$defaultEngine = Join-Path $installConfigDir "DefaultEngine.ini"
$runtimeMapList = Join-Path $installConfigDir "UDKMapList.ini"
$defaultMapList = Join-Path $installConfigDir "DefaultMapList.ini"
$runtimeRenegadeX = Join-Path $installConfigDir "UDKRenegadeX.ini"
$defaultRenegadeX = Join-Path $installConfigDir "DefaultRenegadeX.ini"
$runtimeSurvival = Join-Path $installConfigDir "UDKSurvival.ini"
$defaultSurvival = Join-Path $installConfigDir "DefaultSurvival.ini"

$gameIniSources = @($udkGame, $runtimeGame, $defaultGame)
$engineIniSources = @($udkEngine, $runtimeEngine, $defaultEngine)
$renegadeXIniSources = @($udkRenegadeX, $runtimeRenegadeX, $defaultRenegadeX)
$webIniSources = @($udkWeb)

$listed = Get-IniPreferredBoolSetting $renegadeXIniSources "RenX_Game.Rx_Game" "bListed" @("RENX_LISTED") $listed
$botsDisabled = Get-IniPreferredBoolSetting $renegadeXIniSources "RenX_Game.Rx_Game" "bBotsDisabled" @("RENX_BOTS_DISABLED") $botsDisabled
$allowDownloads = Get-IniPreferredBoolSetting $engineIniSources "IpDrv.TcpNetDriver" "AllowDownloads" @("RENX_ALLOW_DOWNLOADS") $allowDownloads
$redirectUrl = Get-IniPreferredSetting $engineIniSources "IpDrv.HTTPDownload" "RedirectToURL" @("RENX_REDIRECT_URL") $redirectUrl
$redirectUseCompression = Get-IniPreferredBoolSetting $engineIniSources "IpDrv.HTTPDownload" "UseCompression" @("RENX_REDIRECT_USE_COMPRESSION") $redirectUseCompression
$enableRcon = Get-IniPreferredBoolSetting $renegadeXIniSources "RenX_Game.Rx_Rcon" "bEnableRcon" @("RENX_ENABLE_RCON") $enableRcon
$rconSubscriberLimit = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Rcon" "SubscriberLimit" @("RENX_RCON_SUBSCRIBER_LIMIT") $rconSubscriberLimit
$webEnabled = Get-IniPreferredBoolSetting $webIniSources "RenX_Game.Rx_WebServer" "bEnabled" @("RENX_WEB_ENABLED") $webEnabled
$webMaxConnections = Get-IniPreferredSetting $webIniSources "RenX_Game.Rx_WebServer" "MaxConnections" @("RENX_WEB_MAX_CONNECTIONS") $webMaxConnections
$netWait = Get-IniPreferredSetting $gameIniSources "UTGame.UTGame" "NetWait" @("RENX_NET_WAIT") $netWait
$minNetPlayers = Get-IniPreferredSetting $gameIniSources "UTGame.UTGame" "MinNetPlayers" @("RENX_MIN_NET_PLAYERS") $minNetPlayers
$waitForNetPlayers = Get-IniPreferredBoolSetting $gameIniSources "UTGame.UTGame" "bWaitForNetPlayers" @("RENX_WAIT_FOR_NET_PLAYERS") $waitForNetPlayers
$forceRespawn = Get-IniPreferredBoolSetting $gameIniSources "UTGame.UTGame" "bForceRespawn" @("RENX_FORCE_RESPAWN") $forceRespawn
$playersMustBeReady = Get-IniPreferredBoolSetting $gameIniSources "UTGame.UTGame" "bPlayersMustBeReady" @("RENX_PLAYERS_MUST_BE_READY") $playersMustBeReady
$restartWait = Get-IniPreferredSetting $gameIniSources "UTGame.UTGame" "RestartWait" @("RENX_RESTART_WAIT") $restartWait
$initialCredits = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "InitialCredits" @("RENX_INITIAL_CREDITS") $initialCredits
$timeLimit = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "TimeLimit" @("RENX_TIME_LIMIT") $timeLimit
$cncTimeLimit = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "CnCModeTimeLimit" @("RENX_CNC_TIME_LIMIT") $cncTimeLimit
$dmTimeLimit = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "DMModeTimeLimit" @("RENX_DM_TIME_LIMIT") $dmTimeLimit
$buildingsRevive = Get-IniPreferredBoolSetting $renegadeXIniSources "RenX_Game.Rx_Game" "bBuildingsRevive" @("RENX_BUILDINGS_REVIVE") $buildingsRevive
$enableAirdrops = Get-IniPreferredBoolSetting $renegadeXIniSources "RenX_Game.Rx_Game" "bEnableAirdrops" @("RENX_ENABLE_AIRDROPS") $enableAirdrops
$teamMode = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "TeamMode" @("RENX_TEAM_MODE") $teamMode
$surrenderLength = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "SurrenderLength" @("RENX_CNC_SURRENDER_LENGTH") $surrenderLength
$surrenderDisabledTime = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "SurrenderDisabledTime" @("RENX_CNC_SURRENDER_LOCKOUT") $surrenderDisabledTime
$spawnCrates = Get-IniPreferredBoolSetting $renegadeXIniSources "RenX_Game.Rx_Game" "SpawnCrates" @("RENX_SPAWN_CRATES") $spawnCrates
$maxClientRate = Get-IniPreferredSetting $engineIniSources "IpDrv.TcpNetDriver" "MaxClientRate" @("RENX_MAX_CLIENT_RATE") $maxClientRate
$maxInternetClientRate = Get-IniPreferredSetting $engineIniSources "IpDrv.TcpNetDriver" "MaxInternetClientRate" @("RENX_MAX_INTERNET_CLIENT_RATE") $maxInternetClientRate
$serverTickRate = Get-IniPreferredSetting $engineIniSources "IpDrv.TcpNetDriver" "NetServerMaxTickRate" @("RENX_SERVER_TICK_RATE") $serverTickRate
$nodBotDifficulty = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "NodDifficulty" @("RENX_NOD_BOT_DIFFICULTY") $nodBotDifficulty
$gdiBotDifficulty = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "GDIDifficulty" @("RENX_GDI_BOT_DIFFICULTY") $gdiBotDifficulty
$nodAttackPercent = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "NODAttackingValue" @("RENX_NOD_ATTACK_PERCENT") $nodAttackPercent
$gdiAttackPercent = Get-IniPreferredSetting $renegadeXIniSources "RenX_Game.Rx_Game" "GDIAttackingValue" @("RENX_GDI_ATTACK_PERCENT") $gdiAttackPercent

if ($marathonMode) {
    $timeLimit = "0"
    $cncTimeLimit = "0"
    $buildingsRevive = "false"
    $enableAirdrops = "true"
}

$iniLocalMap = Get-IniValueFromPaths @($udkEngine, $runtimeEngine, $defaultEngine) "URL" "LocalMap"
if (-not [string]::IsNullOrWhiteSpace($iniLocalMap)) {
    $iniMapName = [System.IO.Path]::GetFileNameWithoutExtension($iniLocalMap.Trim().Trim('"'))
    if (-not [string]::IsNullOrWhiteSpace($iniMapName)) {
        $map = $iniMapName
        Write-Host "Using starting map from INI LocalMap: $map"
    }
}

if (
    $mapCycleClass -eq "Rx_Game" -and
    (
        $gameClass -eq "RenX_Coop.Rx_Game_Survival" -or
        $map.StartsWith("DEF-", [System.StringComparison]::OrdinalIgnoreCase)
    )
) {
    $mapCycleClass = "Rx_Game_Survival"
}

$isSurvivalMode = (
    $gameClass -eq "RenX_Coop.Rx_Game_Survival" -or
    $mapCycleClass -eq "Rx_Game_Survival" -or
    $map.StartsWith("DEF-", [System.StringComparison]::OrdinalIgnoreCase)
)
if ([string]::IsNullOrWhiteSpace($modeProfile)) {
    $modeProfile = if ($isSurvivalMode) { "survival" } else { "cnc" }
}
$mapListSection = Get-MapListSectionForCycleClass $mapCycleClass

$iniMapRotation = Get-MapRotationFromIni $udkGame $mapCycleClass
if (-not [string]::IsNullOrWhiteSpace($iniMapRotation)) {
    $mapRotation = $iniMapRotation
    Write-Host "Using $mapCycleClass map rotation from INI GameSpecificMapCycles."
}

$normalVoteSources = @($udkRenegadeX, $runtimeRenegadeX, $defaultRenegadeX)
$survivalVoteSources = @($udkSurvival, $runtimeSurvival, $defaultSurvival)
$voteSection = if ($isSurvivalMode) { "RenX_Coop.Rx_Game_Survival" } else { "RenX_Game.Rx_Game" }
$voteSources = if ($isSurvivalMode) { $survivalVoteSources } else { $normalVoteSources }

$fixedMapRotation = Get-IniPreferredBoolSetting $voteSources $voteSection "bFixedMapRotation" @("RENX_FIXED_MAP_ROTATION", "RENX_VOTE_FIXED_ROTATION") $fixedMapRotation
$maxMapVoteSize = Get-IniPreferredSetting $voteSources $voteSection "MaxMapVoteSize" @("RENX_MAX_MAP_VOTE_SIZE", "RENX_VOTE_MAX_CHOICES") $maxMapVoteSize
$recentMapsToExclude = Get-IniPreferredSetting $voteSources $voteSection "RecentMapsToExclude" @("RENX_RECENT_MAPS_TO_EXCLUDE", "RENX_VOTE_RECENT_EXCLUDE") $recentMapsToExclude
$mapVoteTime = Get-IniPreferredSetting $voteSources $voteSection "MapVoteTime" @("RENX_VOTE_DURATION") $mapVoteTime
$changeMapDisabledTime = Get-IniPreferredSetting $voteSources $voteSection "ChangeMapDisabledTime" @("RENX_VOTE_CHANGE_MAP_LOCKOUT") $changeMapDisabledTime
$adminsStartMapVote = Get-IniPreferredBoolSetting $voteSources $voteSection "bAdminsStartMapVote" @("RENX_VOTE_ADMINS_START") $adminsStartMapVote
$botVotesDisabled = Get-IniPreferredBoolSetting $voteSources $voteSection "bBotVotesDisabled" @("RENX_VOTE_BOTS_DISABLED") $botVotesDisabled
$removeVariantMapsInVoteList = Get-IniPreferredBoolSetting $voteSources $voteSection "bRemoveVariantMapsInVoteList" @("RENX_VOTE_REMOVE_VARIANTS") $removeVariantMapsInVoteList

$voteSettings = [ordered]@{
    bFixedMapRotation = $fixedMapRotation
    MaxMapVoteSize = $maxMapVoteSize
    RecentMapsToExclude = $recentMapsToExclude
    MapVoteTime = $mapVoteTime
    ChangeMapDisabledTime = $changeMapDisabledTime
    bAdminsStartMapVote = $adminsStartMapVote
    bBotVotesDisabled = $botVotesDisabled
    bRemoveVariantMapsInVoteList = $removeVariantMapsInVoteList
}

$surveyDate = [DateTime]::UtcNow.ToString("yyyyMMdd")
Set-IniValue $udkEngine "HardwareSurvey" "LastSurveyVersion" "12791"
Set-IniValue $udkEngine "HardwareSurvey" "LastSurveyDate" $surveyDate
Set-IniValue $udkEngine "AppCompat" "CompatLevelComposite" "5"

Set-IniValue $udkGame "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue $udkGame "Engine.GameReplicationInfo" "MessageOfTheDay" (Get-Setting "RENX_MOTD" "")
Set-IniValue $udkGame "Engine.GameInfo" "MaxPlayers" $maxPlayers
Set-IniValue $udkGame "Engine.AccessControl" "AdminPassword" $adminPassword
Set-IniValue $udkGame "Engine.AccessControl" "GamePassword" $serverPassword
Set-IniValue $udkGame "UTGame.UTGame" "bForceRespawn" $forceRespawn
Set-IniValue $udkGame "UTGame.UTGame" "bPlayersMustBeReady" $playersMustBeReady
Set-IniValue $udkGame "UTGame.UTGame" "NetWait" $netWait
Set-IniValue $udkGame "UTGame.UTGame" "MinNetPlayers" $minNetPlayers
Set-IniValue $udkGame "UTGame.UTGame" "bWaitForNetPlayers" $waitForNetPlayers
Set-IniValue $udkGame "UTGame.UTGame" "RestartWait" $restartWait
Set-MapRotation $udkGame $mapCycleClass $mapRotation
Set-MapList $udkMapList $mapListSection $mapRotation

Set-IniValue $udkEngine "URL" "Port" $gamePort
Set-IniValue $udkEngine "URL" "PeerPort" $peerPort
Set-IniValue $udkEngine "URL" "LocalMap" "$map.udk"
Set-IniValue $udkEngine "OnlineSubsystemSteamworks.OnlineSubsystemSteamworks" "QueryPort" $queryPort
Set-IniValue $udkEngine "IpDrv.TcpNetDriver" "AllowDownloads" $allowDownloads
Set-IniValue $udkEngine "IpDrv.TcpNetDriver" "MaxClientRate" $maxClientRate
Set-IniValue $udkEngine "IpDrv.TcpNetDriver" "MaxInternetClientRate" $maxInternetClientRate
Set-IniValue $udkEngine "IpDrv.TcpNetDriver" "NetServerMaxTickRate" $serverTickRate
Set-IniValue $udkEngine "IpDrv.HTTPDownload" "RedirectToURL" $redirectUrl
Set-IniValue $udkEngine "IpDrv.HTTPDownload" "UseCompression" $redirectUseCompression

Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bListed" $listed
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bFixedMapRotation" $fixedMapRotation
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bBotsDisabled" $botsDisabled
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bLogRcon" "true"
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "InitialCredits" $initialCredits
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "TimeLimit" $timeLimit
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "CnCModeTimeLimit" $cncTimeLimit
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "DMModeTimeLimit" $dmTimeLimit
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bBuildingsRevive" $buildingsRevive
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bEnableAirdrops" $enableAirdrops
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "TeamMode" $teamMode
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "SurrenderLength" $surrenderLength
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "SurrenderDisabledTime" $surrenderDisabledTime
Set-IniSectionValues $udkRenegadeX "RenX_Game.Rx_Game" $voteSettings
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "SpawnCrates" $spawnCrates
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "NodDifficulty" $nodBotDifficulty
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "GDIDifficulty" $gdiBotDifficulty
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "NODAttackingValue" $nodAttackPercent
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "GDIAttackingValue" $gdiAttackPercent

if ($isSurvivalMode) {
    Set-IniValue $udkSurvival "RenX_Coop.Rx_Game_Survival" "bListed" $listed
    Set-IniSectionValues $udkSurvival "RenX_Coop.Rx_Game_Survival" $voteSettings
}

Set-IniValue $udkRenegadeX "RenX_Game.Rx_Rcon" "bEnableRcon" $enableRcon
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Rcon" "RconPort" $rconPort
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Rcon" "SubscriberLimit" $rconSubscriberLimit

Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "bEnabled" $webEnabled
Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "ServerName" $serverName
Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "ListenPort" $webPort
Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "MaxConnections" $webMaxConnections

Copy-Item -Path (Join-Path $configDir "*") -Destination $installConfigDir -Force

# Reinforce identity settings after the persistent config copy. UE3 may rebuild a
# runtime config from DefaultGame.ini, so keep both sources aligned.
Set-IniValue $runtimeGame "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue $runtimeGame "Engine.GameReplicationInfo" "MessageOfTheDay" (Get-Setting "RENX_MOTD" "")
Set-IniValue $defaultGame "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue $defaultGame "Engine.GameReplicationInfo" "MessageOfTheDay" (Get-Setting "RENX_MOTD" "")
foreach ($gameTarget in @($runtimeGame, $defaultGame)) {
    Set-MapRotation $gameTarget $mapCycleClass $mapRotation
}
foreach ($mapListTarget in @($runtimeMapList, $defaultMapList)) {
    Set-MapList $mapListTarget $mapListSection $mapRotation
}

# Keep the runtime and default Renegade X config aligned. UE3 may rebuild the
# runtime config from defaults, so managed match-flow and voting values are
# reinforced in both places before the game process starts.
foreach ($renegadeXTarget in @($runtimeRenegadeX, $defaultRenegadeX)) {
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "TimeLimit" $timeLimit
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "CnCModeTimeLimit" $cncTimeLimit
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "DMModeTimeLimit" $dmTimeLimit
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "bBuildingsRevive" $buildingsRevive
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "bEnableAirdrops" $enableAirdrops
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "SurrenderLength" $surrenderLength
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "SurrenderDisabledTime" $surrenderDisabledTime
    Set-IniSectionValues $renegadeXTarget "RenX_Game.Rx_Game" $voteSettings
}

if ($isSurvivalMode) {
    foreach ($survivalTarget in @($runtimeSurvival, $defaultSurvival)) {
        Set-IniValue $survivalTarget "RenX_Coop.Rx_Game_Survival" "bListed" $listed
        Set-IniSectionValues $survivalTarget "RenX_Coop.Rx_Game_Survival" $voteSettings
    }
}

$runtimeServerName = Get-IniValue $runtimeGame "Engine.GameReplicationInfo" "ServerName"
$defaultServerName = Get-IniValue $defaultGame "Engine.GameReplicationInfo" "ServerName"
if ($runtimeServerName -ne $serverName -or $defaultServerName -ne $serverName) {
    throw "Renegade X server-name configuration validation failed. Runtime='$runtimeServerName'; Default='$defaultServerName'; Expected='$serverName'."
}
Write-Host "Verified Renegade X server name in runtime and default INI files: $serverName"

$runtimeTimeLimit = Get-IniValue $runtimeRenegadeX "RenX_Game.Rx_Game" "TimeLimit"
$runtimeCncTimeLimit = Get-IniValue $runtimeRenegadeX "RenX_Game.Rx_Game" "CnCModeTimeLimit"
$defaultTimeLimit = Get-IniValue $defaultRenegadeX "RenX_Game.Rx_Game" "TimeLimit"
$defaultCncTimeLimit = Get-IniValue $defaultRenegadeX "RenX_Game.Rx_Game" "CnCModeTimeLimit"
if ($runtimeTimeLimit -ne $timeLimit -or $runtimeCncTimeLimit -ne $cncTimeLimit -or $defaultTimeLimit -ne $timeLimit -or $defaultCncTimeLimit -ne $cncTimeLimit) {
    throw "Renegade X time-limit configuration validation failed. Runtime='$runtimeTimeLimit/$runtimeCncTimeLimit'; Default='$defaultTimeLimit/$defaultCncTimeLimit'; Expected='$timeLimit/$cncTimeLimit'."
}
Write-Host "Verified Renegade X time limits in runtime and default INI files: TimeLimit=$timeLimit; CnCModeTimeLimit=$cncTimeLimit"

if ($installOptionalMapPack1) {
    Invoke-CustomContentDownloads $optionalMapPack1Url $optionalMapDir $refreshContentDownloads "optional map pack 1"
}
if ($installOptionalMapPack2) {
    Invoke-CustomContentDownloads $optionalMapPack2Url $optionalMapDir $refreshContentDownloads "optional map pack 2"
}
if ($installOptionalMapPack3) {
    Invoke-CustomContentDownloads $optionalMapPack3Url $optionalMapDir $refreshContentDownloads "optional map pack 3"
}
Invoke-CustomContentDownloads $requiredContentUrls $requiredContentDir $refreshContentDownloads "required content"
Invoke-CustomContentDownloads $contentUrls $downloadedContentDir $refreshContentDownloads "custom content"
Sync-CustomContent $customContentDir $root

$env:RENX_MAP = $map
$env:RENX_GAME_CLASS = $gameClass
$env:RENX_MODE_PROFILE = $modeProfile
$env:RENX_MAX_PLAYERS = $maxPlayers
$env:RENX_GAME_PORT = $gamePort
$env:RENX_TIME_LIMIT = $timeLimit
$env:RENX_CNC_TIME_LIMIT = $cncTimeLimit
$env:RENX_DM_TIME_LIMIT = $dmTimeLimit
$env:RENX_CNC_DM_TIME_LIMIT = $dmTimeLimit
$env:RENX_BUILDINGS_REVIVE = $buildingsRevive
$env:RENX_CNC_BUILDINGS_REVIVE = $buildingsRevive
$env:RENX_ENABLE_AIRDROPS = $enableAirdrops
$env:RENX_CNC_AIRDROPS = $enableAirdrops
$env:RENX_MUTATORS = $mutators
$env:RENX_GDI_BOTS = $gdiBots
$env:RENX_NOD_BOTS = $nodBots
$env:RENX_MULTIHOME = $multihome
$env:RENX_EXTRA_ARGS = $extraArgs
$env:RENX_LOG_FILE = Join-Path $logDir "RenegadeXServer.log"

if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Renegade X launcher not found: $launcher"
}

Write-Host "Launching Renegade X server"
Write-Host "Install root: $root"
Write-Host "Data root: $dataRoot"
Write-Host "Map: $map"
Write-Host "Server name: $serverName"
Write-Host "Max players: $maxPlayers"
Write-Host "Ports: game=$gamePort peer=$peerPort query=$queryPort rcon=$rconPort web=$webPort"
Write-Host "Custom content root: $customContentDir"
& cmd.exe /c "`"$launcher`""
$serverExitCode = $LASTEXITCODE

Write-Host "Renegade X launcher returned exit code $serverExitCode."
if (Test-Path -LiteralPath $env:RENX_LOG_FILE) {
    Write-Host "Last 200 lines from $($env:RENX_LOG_FILE):"
    Get-Content -LiteralPath $env:RENX_LOG_FILE -Tail 200 -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host $_ }
}
else {
    Write-Host "No Renegade X log was created at $($env:RENX_LOG_FILE). This usually indicates an executable dependency or loader failure."
}

exit $serverExitCode
