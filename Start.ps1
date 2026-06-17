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

$serverName = Get-Setting "RENX_SERVER_NAME" "Renegade X Server"
$map = Get-Setting "RENX_MAP" "CNC-Field"
$gameClass = Get-Setting "RENX_GAME_CLASS" "RenX_Game.Rx_Game"
$maxPlayers = Get-Setting "RENX_MAX_PLAYERS" "40"
$gamePort = Get-Setting "RENX_GAME_PORT" "7777"
$peerPort = Get-Setting "RENX_PEER_PORT" "7778"
$queryPort = Get-Setting "RENX_QUERY_PORT" "27015"
$rconPort = Get-Setting "RENX_RCON_PORT" "-1"
$webPort = Get-Setting "RENX_WEB_PORT" "6969"
$adminPassword = Get-Setting "RENX_ADMIN_PASSWORD" ""
$serverPassword = Get-Setting "RENX_SERVER_PASSWORD" ""
$extraArgs = Get-Setting "RENX_EXTRA_ARGS" ""

$installConfigDir = Join-Path $root "UDKGame\Config"
$configDir = Join-Path $dataRoot "Config"
$logDir = Join-Path $dataRoot "Logs"

New-Item -ItemType Directory -Force -Path $configDir, $logDir | Out-Null

foreach ($fileName in @("DefaultGame.ini", "DefaultEngine.ini", "DefaultMapList.ini", "DefaultRenegadeX.ini", "DefaultWeb.ini")) {
    $source = Join-Path $installConfigDir $fileName
    $target = Join-Path $configDir $fileName
    if ((-not (Test-Path -LiteralPath $target)) -and (Test-Path -LiteralPath $source)) {
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
}

$defaultGame = Join-Path $configDir "DefaultGame.ini"
$defaultEngine = Join-Path $configDir "DefaultEngine.ini"
$defaultRenegadeX = Join-Path $configDir "DefaultRenegadeX.ini"
$defaultWeb = Join-Path $configDir "DefaultWeb.ini"

Set-IniValue $defaultGame "Engine.GameReplicationInfo" "ServerName" $serverName
Set-IniValue $defaultGame "Engine.GameInfo" "MaxPlayers" $maxPlayers
Set-IniValue $defaultEngine "URL" "Port" $gamePort
Set-IniValue $defaultEngine "URL" "PeerPort" $peerPort
Set-IniValue $defaultEngine "OnlineSubsystemSteamworks.OnlineSubsystemSteamworks" "QueryPort" $queryPort
Set-IniValue $defaultRenegadeX "RenX_Game.Rx_Rcon" "bEnableRcon" "True"
Set-IniValue $defaultRenegadeX "RenX_Game.Rx_Rcon" "RconPort" $rconPort
Set-IniValue $defaultRenegadeX "RenX_Game.Rx_Game" "bLogRcon" "true"
Set-IniValue $defaultWeb "RenX_Game.Rx_WebServer" "ListenPort" $webPort

$env:RENX_MAP = $map
$env:RENX_GAME_CLASS = $gameClass
$env:RENX_MAX_PLAYERS = $maxPlayers
$env:RENX_GAME_PORT = $gamePort
$env:RENX_ADMIN_PASSWORD = $adminPassword
$env:RENX_SERVER_PASSWORD = $serverPassword
$env:RENX_EXTRA_ARGS = $extraArgs
$env:RENX_LOG_FILE = Join-Path $logDir "RenegadeXServer.log"

Copy-Item -Path (Join-Path $configDir "*") -Destination $installConfigDir -Force

if (-not (Test-Path -LiteralPath $launcher)) {
    throw "Renegade X launcher not found: $launcher"
}

Write-Host "Launching Renegade X server"
Write-Host "Install root: $root"
Write-Host "Data root: $dataRoot"
Write-Host "Map: $map"
Write-Host "Game class: $gameClass"
Write-Host "Server name: $serverName"
Write-Host "Max players: $maxPlayers"
Write-Host "Ports: game=$gamePort peer=$peerPort query=$queryPort rcon=$rconPort web=$webPort"

& cmd.exe /c "`"$launcher`""
exit $LASTEXITCODE
