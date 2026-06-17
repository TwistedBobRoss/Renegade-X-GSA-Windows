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
$cncTimeLimit = Get-Setting "RENX_CNC_TIME_LIMIT" "30"
$dmTimeLimit = Get-Setting "RENX_DM_TIME_LIMIT" "20"
$teamMode = Get-Setting "RENX_TEAM_MODE" "All"
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
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "CnCModeTimeLimit" $cncTimeLimit
Set-IniValue $udkRenegadeX "RenX_Game.Rx_Game" "DMModeTimeLimit" $dmTimeLimit
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
Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "ListenPort" $webPort
Set-IniValue $udkWeb "RenX_Game.Rx_WebServer" "MaxConnections" $webMaxConnections

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
