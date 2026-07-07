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

function Get-BoolSetting {
    param(
        [string]$Name,
        [string]$Default
    )

    $value = (Get-Setting $Name $Default).ToLowerInvariant()
    switch ($value) {
        "1" { return "true" }
        "true" { return "true" }
        "yes" { return "true" }
        "on" { return "true" }
        "0" { return "false" }
        "false" { return "false" }
        "no" { return "false" }
        "off" { return "false" }
        default { return $Default.ToLowerInvariant() }
    }
}

function Set-IniValue {
    param(
        [string]$Path,
        [string]$Section,
        [string]$Key,
        [string]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
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
    Set-IniValue $Path "UTGame.UTGame" "GameSpecificMapCycles" "(GameClassName=`"$CycleClass`",Maps=($escapedMaps))"
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

$serverName = Get-Setting "RENX_SERVER_NAME" "Renegade X Server"
$map = Get-Setting "RENX_MAP" "CNC-Field"
$gameClass = Get-Setting "RENX_GAME_CLASS" ""
if ($gameClass -eq "none") {
    $gameClass = ""
}
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
$fixedMapRotation = Get-BoolSetting "RENX_FIXED_MAP_ROTATION" "false"
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
$maxMapVoteSize = Get-Setting "RENX_MAX_MAP_VOTE_SIZE" "5"
$recentMapsToExclude = Get-Setting "RENX_RECENT_MAPS_TO_EXCLUDE" "2"
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

Install-SeedRuntime $seedRoot $root $bootstrapRoot
Install-ServerPayload $serverPayloadUrls $root $dataRoot $bootstrapRoot $refreshServerPayload
$launcher = Join-Path $root "LaunchRenegadeXServer.bat"

$installConfigDir = Join-Path $root "UDKGame\Config"
$configDir = Join-Path $dataRoot "Config"
$customContentDir = Join-Path $dataRoot "CustomContent"
$downloadedContentDir = Join-Path $customContentDir "_Downloaded"
$requiredContentDir = Join-Path $customContentDir "_Required"
$optionalMapDir = Join-Path $customContentDir "_OptionalMaps"
$logDir = Join-Path $dataRoot "Logs"

New-Item -ItemType Directory -Force -Path $configDir, $customContentDir, $logDir | Out-Null
Initialize-RuntimeConfig $installConfigDir $configDir

$udkGame = Join-Path $configDir "UDKGame.ini"
$udkEngine = Join-Path $configDir "UDKEngine.ini"
$udkRenegadeX = Join-Path $configDir "UDKRenegadeX.ini"
$udkWeb = Join-Path $configDir "UDKWeb.ini"

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
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "MaxMapVoteSize" $maxMapVoteSize
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "RecentMapsToExclude" $recentMapsToExclude
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "SpawnCrates" $spawnCrates
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "NodDifficulty" $nodBotDifficulty
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "GDIDifficulty" $gdiBotDifficulty
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "NODAttackingValue" $nodAttackPercent
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "GDIAttackingValue" $gdiAttackPercent
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
Set-IniValue (Join-Path $installConfigDir "UDKGame.ini") "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue (Join-Path $installConfigDir "UDKGame.ini") "Engine.GameReplicationInfo" "MessageOfTheDay" (Get-Setting "RENX_MOTD" "")
Set-IniValue (Join-Path $installConfigDir "DefaultGame.ini") "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue (Join-Path $installConfigDir "DefaultGame.ini") "Engine.GameReplicationInfo" "MessageOfTheDay" (Get-Setting "RENX_MOTD" "")

# Keep the runtime and default Renegade X config aligned. The shipped defaults
# advertise a 50 minute CnC timer, so marathon values must be reinforced in both
# places before the game process starts.
$runtimeRenegadeX = Join-Path $installConfigDir "UDKRenegadeX.ini"
$defaultRenegadeX = Join-Path $installConfigDir "DefaultRenegadeX.ini"
foreach ($renegadeXTarget in @($runtimeRenegadeX, $defaultRenegadeX)) {
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "TimeLimit" $timeLimit
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "CnCModeTimeLimit" $cncTimeLimit
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "DMModeTimeLimit" $dmTimeLimit
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "bBuildingsRevive" $buildingsRevive
    Set-IniValue $renegadeXTarget "RenX_Game.Rx_Game" "bEnableAirdrops" $enableAirdrops
}

$runtimeServerName = Get-IniValue (Join-Path $installConfigDir "UDKGame.ini") "Engine.GameReplicationInfo" "ServerName"
$defaultServerName = Get-IniValue (Join-Path $installConfigDir "DefaultGame.ini") "Engine.GameReplicationInfo" "ServerName"
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
