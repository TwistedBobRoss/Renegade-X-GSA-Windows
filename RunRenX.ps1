$ErrorActionPreference = "Stop"

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
        [bool]$Default
    )

    switch ((Get-Setting $Name ([string]$Default)).ToLowerInvariant()) {
        "1" { return $true }
        "true" { return $true }
        "yes" { return $true }
        "on" { return $true }
        "0" { return $false }
        "false" { return $false }
        "no" { return $false }
        "off" { return $false }
        default { return $Default }
    }
}

function Write-NewLogContent {
    param(
        [string]$Path,
        [long]$Position
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $Position
    }

    $shareMode = [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
    $stream = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        $shareMode
    )

    try {
        if ($stream.Length -lt $Position) {
            $Position = 0
        }

        [void]$stream.Seek($Position, [System.IO.SeekOrigin]::Begin)
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8, $true, 4096, $true)
        try {
            while (($line = $reader.ReadLine()) -ne $null) {
                Write-Host $line
            }
        }
        finally {
            $reader.Dispose()
        }

        return $stream.Position
    }
    finally {
        $stream.Dispose()
    }
}

function Test-TcpEndpoint {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMilliseconds = 5000
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }

        $client.EndConnect($asyncResult)
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

$root = Get-Setting "RENX_ROOT" "C:\renx-data\ServerFiles"
$serverName = Get-Setting "RENX_SERVER_NAME" "Renegade X Server"
$map = Get-Setting "RENX_MAP" "CNC-Field"
$gameClass = Get-Setting "RENX_GAME_CLASS" ""
$maxPlayersSetting = Get-Setting "RENX_MAX_PLAYERS" "40"
$gamePort = Get-Setting "RENX_GAME_PORT" "7777"
$queryPort = Get-Setting "RENX_QUERY_PORT" "27015"
$mutators = Get-Setting "RENX_MUTATORS" ""
$gdiBots = Get-Setting "RENX_GDI_BOTS" ""
$nodBots = Get-Setting "RENX_NOD_BOTS" ""
$multihome = Get-Setting "RENX_MULTIHOME" ""
$extraArgs = Get-Setting "RENX_EXTRA_ARGS" ""
$logPath = Get-Setting "RENX_LOG_FILE" "C:\renx-data\Logs\RenegadeXServer.log"
$listed = Get-BoolSetting "RENX_LISTED" $true
$listingAddress = "devbot-rx.totemarts.services"
$listingPort = 21337
$surveyDate = [DateTime]::UtcNow.ToString("yyyyMMdd")

if ($gameClass -eq "none") {
    $gameClass = ""
}

$maxPlayers = 0
if (-not [int]::TryParse($maxPlayersSetting, [ref]$maxPlayers) -or $maxPlayers -lt 1) {
    Write-Host "WARNING: Invalid maximum player count '$maxPlayersSetting'; using 40."
    $maxPlayers = 40
}
elseif ($maxPlayers -gt 64) {
    Write-Host "WARNING: Renegade X supports at most 64 players; clamping requested value $maxPlayers to 64."
    $maxPlayers = 64
}

$runner = Join-Path $root "Binaries\Win64\UDK.exe"
if (-not (Test-Path -LiteralPath $runner)) {
    $runner = Join-Path $root "Binaries\Win64\UDK.com"
}
if (-not (Test-Path -LiteralPath $runner)) {
    throw "Renegade X executable was not found under $root\Binaries\Win64."
}

$url = "${map}?maxplayers=${maxPlayers}?bIsLanMatch=false"
if (-not [string]::IsNullOrWhiteSpace($gameClass)) {
    $url += "?Game=$gameClass"
}
if (-not [string]::IsNullOrWhiteSpace($mutators)) {
    $url += "?mutator=$mutators"
}
if (-not [string]::IsNullOrWhiteSpace($gdiBots)) {
    $url += "?GDIBotCount=$gdiBots"
}
if (-not [string]::IsNullOrWhiteSpace($nodBots)) {
    $url += "?NODBotCount=$nodBots"
}

$engineIniOverrides = "-ini:UDKEngine:HardwareSurvey.LastSurveyVersion=12791,HardwareSurvey.LastSurveyDate=$surveyDate,AppCompat.CompatLevelComposite=5"
$safeServerName = $serverName.Replace('"', '').Replace(',', ' ')
$serverNameOverride = "-ini:UDKGame:Engine.GameReplicationInfo.ServerName=`"$safeServerName`""
$argumentLine = "server $url -port=$gamePort -QueryPort=$queryPort $engineIniOverrides $serverNameOverride -abslog=`"$logPath`" -forcelogflush -unattended -nohomedir -nullrhi -nosound"
if (-not [string]::IsNullOrWhiteSpace($multihome)) {
    $argumentLine += " -MULTIHOME=$multihome"
}
if (-not [string]::IsNullOrWhiteSpace($extraArgs)) {
    $argumentLine += " $extraArgs"
}

$logDirectory = Split-Path -Parent $logPath
New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
$startupLine = "[{0}] Renegade X launch requested. Waiting for game log output." -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
[System.IO.File]::WriteAllText(
    $logPath,
    "$startupLine`r`n",
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host "Starting Renegade X dedicated server..."
Write-Host "Root: $root"
Write-Host "Server name: $serverName"
Write-Host "Map: $map"
Write-Host "Players: $maxPlayers"
Write-Host "Game port: $gamePort"
Write-Host "Query port: $queryPort"
Write-Host "Public listing mode: Internet"
Write-Host "Executable: $runner"
Write-Host "Live game log: $logPath"

if ($listed) {
    if (Test-TcpEndpoint -HostName $listingAddress -Port $listingPort) {
        Write-Host "Public listing endpoint reachable: ${listingAddress}:$listingPort"
    }
    else {
        Write-Host "WARNING: Public listing endpoint is unreachable: ${listingAddress}:$listingPort. Allow outbound TCP 21337 in the host, container, and network firewall."
    }
}
else {
    Write-Host "Public listing is disabled by bListed=false."
}

$logPosition = 0L
$logPosition = Write-NewLogContent -Path $logPath -Position $logPosition

$process = New-Object System.Diagnostics.Process
$process.StartInfo.FileName = $runner
$process.StartInfo.Arguments = $argumentLine
$process.StartInfo.WorkingDirectory = Split-Path -Parent $runner
$process.StartInfo.UseShellExecute = $false
$process.StartInfo.CreateNoWindow = $true
[void]$process.Start()

try {
    while (-not $process.HasExited) {
        Start-Sleep -Milliseconds 750
        $logPosition = Write-NewLogContent -Path $logPath -Position $logPosition
        $process.Refresh()
    }

    $logPosition = Write-NewLogContent -Path $logPath -Position $logPosition
    $exitCode = $process.ExitCode
}
finally {
    if (-not $process.HasExited) {
        $process.Kill()
    }

    $process.Dispose()
}

Write-Host "Renegade X process exited with code $exitCode."
exit $exitCode
