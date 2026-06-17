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
Invoke-CustomContentDownloads $requiredContentUrls $requiredContentDir $refreshContentDownloads "required content"
Invoke-CustomContentDownloads $contentUrls $downloadedContentDir $refreshContentDownloads "custom content"
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
