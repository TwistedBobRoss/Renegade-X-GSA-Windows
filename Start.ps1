$ErrorActionPreference = "Stop"

$root = if ($env:RENX_ROOT) { $env:RENX_ROOT } else { "C:\serverfiles" }
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
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $keyPattern) {
            $lines[$i] = "$Key=$Value"
            [System.IO.File]::WriteAllLines($Path, $lines)
            return
        }

        if ($lines[$i] -match $anySectionPattern) {
            $insertIndex = $i
            break
        }
    }

    $lines.Insert($insertIndex, "$Key=$Value")
    [System.IO.File]::WriteAllLines($Path, $lines)
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

    Get-ChildItem -LiteralPath $SourceRoot -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Copy-CustomContentFile $_.FullName $InstallRoot
    }
}

function Invoke-CustomContentDownloads {
    param(
        [string]$Urls,
        [string]$DestinationRoot,
        [bool]$Refresh
    )

    if ([string]::IsNullOrWhiteSpace($Urls)) {
        return
    }

    New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null

    $urlList = @(
        $Urls -split "[`r`n;]+" |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    foreach ($url in $urlList) {
        $uri = [Uri]$url
        $fileName = [System.IO.Path]::GetFileName($uri.AbsolutePath)
        if ([string]::IsNullOrWhiteSpace($fileName)) {
            $fileName = "renx-content-{0}.bin" -f ([Guid]::NewGuid().ToString("N"))
        }

        $downloadPath = Join-Path $DestinationRoot $fileName
        if ($Refresh -or -not (Test-Path -LiteralPath $downloadPath)) {
            Write-Host "Downloading custom content: $url"
            Invoke-WebRequest -Uri $url -OutFile $downloadPath -UseBasicParsing
        }
        else {
            Write-Host "Using cached custom content: $fileName"
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
$listed = Get-Setting "RENX_LISTED" "true"
$fixedMapRotation = Get-Setting "RENX_FIXED_MAP_ROTATION" "false"
$botsDisabled = Get-Setting "RENX_BOTS_DISABLED" "false"
$allowDownloads = Get-Setting "RENX_ALLOW_DOWNLOADS" "true"
$redirectUrl = Get-Setting "RENX_REDIRECT_URL" "https://community-content.totemarts.services/"
$redirectUseCompression = Get-Setting "RENX_REDIRECT_USE_COMPRESSION" "false"
$contentUrls = Get-Setting "RENX_CONTENT_URLS" ""
$refreshContentDownloads = [System.Convert]::ToBoolean((Get-Setting "RENX_REFRESH_CONTENT_DOWNLOADS" "false"))
$gdiBots = Get-Setting "RENX_GDI_BOTS" ""
$nodBots = Get-Setting "RENX_NOD_BOTS" ""
$multihome = Get-Setting "RENX_MULTIHOME" ""
$extraArgs = Get-Setting "RENX_EXTRA_ARGS" ""

$installConfigDir = Join-Path $root "UDKGame\Config"
$configDir = Join-Path $dataRoot "Config"
$customContentDir = Join-Path $dataRoot "CustomContent"
$downloadedContentDir = Join-Path $customContentDir "_Downloaded"
$logDir = Join-Path $dataRoot "Logs"

New-Item -ItemType Directory -Force -Path $configDir, $customContentDir, $logDir | Out-Null
Initialize-RuntimeConfig $installConfigDir $configDir

$udkGame = Join-Path $configDir "UDKGame.ini"
$udkEngine = Join-Path $configDir "UDKEngine.ini"
$udkRenegadeX = Join-Path $configDir "UDKRenegadeX.ini"
$udkWeb = Join-Path $configDir "UDKWeb.ini"

Set-IniValue $udkGame "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue $udkGame "Engine.GameReplicationInfo" "MessageOfTheDay" (Get-Setting "RENX_MOTD" "")
Set-IniValue $udkGame "Engine.GameInfo" "MaxPlayers" $maxPlayers
Set-IniValue $udkGame "Engine.AccessControl" "AdminPassword" $adminPassword
Set-IniValue $udkGame "Engine.AccessControl" "GamePassword" $serverPassword
Set-MapRotation $udkGame $mapCycleClass $mapRotation

Set-IniValue $udkEngine "URL" "Port" $gamePort
Set-IniValue $udkEngine "URL" "PeerPort" $peerPort
Set-IniValue $udkEngine "URL" "LocalMap" "$map.udk"
Set-IniValue $udkEngine "OnlineSubsystemSteamworks.OnlineSubsystemSteamworks" "QueryPort" $queryPort
Set-IniValue $udkEngine "IpDrv.TcpNetDriver" "AllowDownloads" $allowDownloads
Set-IniValue $udkEngine "IpDrv.HTTPDownload" "RedirectToURL" $redirectUrl
Set-IniValue $udkEngine "IpDrv.HTTPDownload" "UseCompression" $redirectUseCompression

Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bListed" $listed
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bFixedMapRotation" $fixedMapRotation
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bBotsDisabled" $botsDisabled
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "bLogRcon" "true"
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Rcon" "bEnableRcon" "True"
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Rcon" "RconPort" $rconPort

Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "ListenPort" $webPort

Copy-Item -Path (Join-Path $configDir "*") -Destination $installConfigDir -Force
Invoke-CustomContentDownloads $contentUrls $downloadedContentDir $refreshContentDownloads
Sync-CustomContent $customContentDir $root

$env:RENX_MAP = $map
$env:RENX_GAME_CLASS = $gameClass
$env:RENX_MAX_PLAYERS = $maxPlayers
$env:RENX_GAME_PORT = $gamePort
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
exit $LASTEXITCODE
