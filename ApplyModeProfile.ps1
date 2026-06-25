$ErrorActionPreference = "Stop"

function Get-Setting {
    param([string]$Name, [string]$Default = "")

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }

    return $value.Trim()
}

function Get-BoolSetting {
    param([string]$Name, [bool]$Default)

    switch ((Get-Setting $Name ([string]$Default)).ToLowerInvariant()) {
        "1" { return "true" }
        "true" { return "true" }
        "yes" { return "true" }
        "on" { return "true" }
        "0" { return "false" }
        "false" { return "false" }
        "no" { return "false" }
        "off" { return "false" }
        default { return ([string]$Default).ToLowerInvariant() }
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
    $matches = [System.Collections.Generic.List[int]]::new()
    for ($i = $sectionIndex + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anySectionPattern) {
            $insertIndex = $i
            break
        }
        if ($lines[$i] -match $keyPattern) {
            $matches.Add($i)
        }
    }

    if ($matches.Count -eq 0) {
        $lines.Insert($insertIndex, "$Key=$Value")
    }
    else {
        $lines[$matches[0]] = "$Key=$Value"
        for ($i = $matches.Count - 1; $i -ge 1; $i--) {
            $lines.RemoveAt($matches[$i])
        }
    }

    [System.IO.File]::WriteAllLines($Path, $lines)
}

function Set-ModeVoteSettings {
    param([string]$Path, [string]$Section)

    Set-IniValue $Path $Section "bFixedMapRotation" (Get-BoolSetting "RENX_VOTE_FIXED_ROTATION" $false)
    Set-IniValue $Path $Section "MaxMapVoteSize" (Get-Setting "RENX_VOTE_MAX_CHOICES" "5")
    Set-IniValue $Path $Section "RecentMapsToExclude" (Get-Setting "RENX_VOTE_RECENT_EXCLUDE" "2")
    Set-IniValue $Path $Section "MapVoteTime" (Get-Setting "RENX_VOTE_DURATION" "35")
    Set-IniValue $Path $Section "ChangeMapDisabledTime" (Get-Setting "RENX_VOTE_CHANGE_MAP_LOCKOUT" "600")
    Set-IniValue $Path $Section "bAdminsStartMapVote" (Get-BoolSetting "RENX_VOTE_ADMINS_START" $false)
    Set-IniValue $Path $Section "bBotVotesDisabled" (Get-BoolSetting "RENX_VOTE_BOTS_DISABLED" $true)
    Set-IniValue $Path $Section "bRemoveVariantMapsInVoteList" (Get-BoolSetting "RENX_VOTE_REMOVE_VARIANTS" $true)
}

$root = Get-Setting "RENX_ROOT" "C:\renx-data\ServerFiles"
$configRoot = Join-Path $root "UDKGame\Config"
$renxIni = Join-Path $configRoot "UDKRenegadeX.ini"
$survivalIni = Join-Path $configRoot "UDKSurvival.ini"
$defaultSurvivalIni = Join-Path $configRoot "DefaultSurvival.ini"
$mode = (Get-Setting "RENX_MODE_PROFILE" "cnc").ToLowerInvariant()

if ($mode -notin @("cnc", "aow", "survival")) {
    Write-Host "WARNING: Unknown RENX_MODE_PROFILE '$mode'; using cnc."
    $mode = "cnc"
}

if ($mode -eq "survival" -and -not (Test-Path -LiteralPath $survivalIni) -and (Test-Path -LiteralPath $defaultSurvivalIni)) {
    Copy-Item -LiteralPath $defaultSurvivalIni -Destination $survivalIni -Force
}

if ($mode -eq "survival") {
    $section = "RenX_Coop.Rx_Game_Survival"
    Set-IniValue $survivalIni $section "MinNetPlayers" (Get-Setting "RENX_SURVIVAL_MIN_PLAYERS" "1")
    Set-IniValue $survivalIni $section "NetWait" (Get-Setting "RENX_SURVIVAL_NET_WAIT" "15")
    Set-IniValue $survivalIni $section "bWaitForNetPlayers" (Get-BoolSetting "RENX_SURVIVAL_WAIT_FOR_PLAYERS" $false)
    Set-IniValue $survivalIni $section "InitialCredits" (Get-Setting "RENX_SURVIVAL_INITIAL_CREDITS" "200")
    Set-IniValue $survivalIni $section "SpawnCrates" (Get-BoolSetting "RENX_SURVIVAL_SPAWN_CRATES" $true)
    Set-IniValue $survivalIni $section "CrateRespawnAfterPickup" (Get-Setting "RENX_SURVIVAL_CRATE_RESPAWN" "30")
    Set-IniValue $survivalIni $section "DonationsDisabledTime" (Get-Setting "RENX_SURVIVAL_DONATION_LOCKOUT" "180")
    Set-IniValue $survivalIni $section "bAllowPowerUpDrop" (Get-BoolSetting "RENX_SURVIVAL_POWERUP_DROPS" $true)
    Set-IniValue $survivalIni $section "bReserveVehiclesToBuyer" (Get-BoolSetting "RENX_SURVIVAL_RESERVE_VEHICLES" $true)
    Set-IniValue $survivalIni $section "bEnableCommanders" (Get-BoolSetting "RENX_SURVIVAL_COMMANDERS" $true)
    Set-IniValue $survivalIni $section "bUseStaticCommanders" (Get-BoolSetting "RENX_SURVIVAL_STATIC_COMMANDERS" $false)
    Set-IniValue $survivalIni $section "InitialCP" (Get-Setting "RENX_SURVIVAL_INITIAL_CP" "600")
    Set-IniValue $survivalIni $section "Max_CP" (Get-Setting "RENX_SURVIVAL_MAX_CP" "3000")
    Set-IniValue $survivalIni $section "TimeBeforeCountdown" (Get-Setting "RENX_SURVIVAL_START_DELAY" "10")
    Set-IniValue $survivalIni $section "WaveGraceTime" (Get-Setting "RENX_SURVIVAL_WAVE_GRACE" "15")
    Set-IniValue $survivalIni $section "MaximumEnemy" (Get-Setting "RENX_SURVIVAL_MAX_ACTIVE_ENEMIES" "40")
    Set-IniValue $survivalIni $section "BaseWaveCreditsReward" (Get-Setting "RENX_SURVIVAL_WAVE_CREDITS" "100")
    Set-IniValue $survivalIni $section "BaseWaveCPReward" (Get-Setting "RENX_SURVIVAL_WAVE_CP" "100")
    Set-IniValue $survivalIni $section "BaseWaveVPReward" (Get-Setting "RENX_SURVIVAL_WAVE_VP" "5")
    Set-IniValue $survivalIni $section "bEnableFrustration" (Get-BoolSetting "RENX_SURVIVAL_FRUSTRATION_ENABLED" $true)
    Set-IniValue $survivalIni $section "FrustrationVentInterval" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_INTERVAL" "10")
    Set-IniValue $survivalIni $section "FrustrationCoolOffTimer" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_COOLDOWN" "30")
    Set-IniValue $survivalIni $section "FrustrationFailureChance" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_FAILURE" "0.7")
    Set-IniValue $survivalIni $section "FrustrationBuildUpStartWave" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_START_WAVE" "4")
    Set-IniValue $survivalIni $section "FrustrationBuildUpMult" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_BUILDUP" "0.5")
    Set-IniValue $survivalIni $section "FrustrationBuildDownMult" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_COOLDOWN_MULT" "5")
    Set-IniValue $survivalIni $section "FrustrationInfKillIncrement" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_INF_KILL" "1")
    Set-IniValue $survivalIni $section "FrustrationVehKillIncrement" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_VEH_KILL" "5")
    Set-IniValue $survivalIni $section "FrustrationPlayerKillDecrement" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_PLAYER_DEATH" "8")
    Set-IniValue $survivalIni $section "FrustrationWaveClearIncrement" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_GOOD_CLEAR" "25")
    Set-IniValue $survivalIni $section "FrustrationWaveClearDecrement" (Get-Setting "RENX_SURVIVAL_FRUSTRATION_WEAK_CLEAR" "75")
    Set-ModeVoteSettings $survivalIni $section
    Write-Host "Applied Survival-only profile settings to $survivalIni"
}
else {
    $section = "RenX_Game.Rx_Game"
    $isAow = ($mode -eq "aow")
    Set-IniValue $renxIni $section "InitialCredits" (Get-Setting "RENX_CNC_INITIAL_CREDITS" "200")
    Set-IniValue $renxIni $section "TimeLimit" (Get-Setting "RENX_CNC_TIME_LIMIT" "0")
    Set-IniValue $renxIni $section "CnCModeTimeLimit" (Get-Setting "RENX_CNC_TIME_LIMIT" "0")
    Set-IniValue $renxIni $section "DMModeTimeLimit" (Get-Setting "RENX_CNC_DM_TIME_LIMIT" "15")
    Set-IniValue $renxIni $section "TeamMode" (Get-Setting "RENX_CNC_TEAM_MODE" "6")
    Set-IniValue $renxIni $section "SpawnCrates" (Get-BoolSetting "RENX_CNC_SPAWN_CRATES" $true)
    Set-IniValue $renxIni $section "CrateRespawnAfterPickup" (Get-Setting "RENX_CNC_CRATE_RESPAWN" "30")
    Set-IniValue $renxIni $section "bAllowPowerUpDrop" (Get-BoolSetting "RENX_CNC_POWERUP_DROPS" $true)
    Set-IniValue $renxIni $section "DonationsDisabledTime" (Get-Setting "RENX_CNC_DONATION_LOCKOUT" "180")
    Set-IniValue $renxIni $section "bReserveVehiclesToBuyer" (Get-BoolSetting "RENX_CNC_RESERVE_VEHICLES" $true)
    Set-IniValue $renxIni $section "VehicleLimit" (Get-Setting "RENX_CNC_VEHICLE_LIMIT" "20")
    Set-IniValue $renxIni $section "bEnableCommanders" (Get-BoolSetting "RENX_CNC_COMMANDERS" $true)
    Set-IniValue $renxIni $section "bUseStaticCommanders" (Get-BoolSetting "RENX_CNC_STATIC_COMMANDERS" $false)
    Set-IniValue $renxIni $section "InitialCP" (Get-Setting "RENX_CNC_INITIAL_CP" "600")
    Set-IniValue $renxIni $section "Max_CP" (Get-Setting "RENX_CNC_MAX_CP" "3000")
    Set-IniValue $renxIni $section "bBuildingsRevive" (Get-BoolSetting "RENX_CNC_BUILDINGS_REVIVE" $false)
    Set-IniValue $renxIni $section "BuildingReviveTime" (Get-Setting "RENX_CNC_BUILDING_REVIVE_TIME" "600")
    Set-IniValue $renxIni $section "bStructuresAutoRevive" (Get-BoolSetting "RENX_CNC_STRUCTURES_AUTO_REVIVE" $false)
    Set-IniValue $renxIni $section "bEnableAirdrops" (Get-BoolSetting "RENX_CNC_AIRDROPS" $isAow)
    Set-IniValue $renxIni $section "bEnableOverTime" (Get-BoolSetting "RENX_CNC_OVERTIME" $true)
    Set-IniValue $renxIni $section "OverTimeTimeLimit" (Get-Setting "RENX_CNC_OVERTIME_LIMIT" "1200")
    Set-IniValue $renxIni $section "SuddenDeathTimeLimit" (Get-Setting "RENX_CNC_SUDDEN_DEATH_LIMIT" "600")
    Set-IniValue $renxIni $section "PointsToWinBy" (Get-Setting "RENX_CNC_POINTS_TO_WIN_BY" "15000")
    Set-IniValue $renxIni $section "SurrenderLength" (Get-Setting "RENX_CNC_SURRENDER_LENGTH" "150")
    Set-IniValue $renxIni $section "SurrenderDisabledTime" (Get-Setting "RENX_CNC_SURRENDER_LOCKOUT" "600")
    Set-IniValue $renxIni $section "bFillSpaceWithBots" (Get-BoolSetting "RENX_CNC_FILL_BOTS" $isAow)
    Set-IniValue $renxIni $section "bBotsDisabled" (Get-BoolSetting "RENX_CNC_BOTS_DISABLED" $false)
    Set-ModeVoteSettings $renxIni $section
    Write-Host "Applied $mode CnC-class profile settings to $renxIni"
}
