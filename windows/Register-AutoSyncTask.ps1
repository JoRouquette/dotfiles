<#
.SYNOPSIS
    Enregistre les tâches planifiées Windows pour synchroniser
    le repo dotfiles automatiquement.

.DESCRIPTION
    Crée 2 tâches sous le nom "DotfilesAutoSync" :
      1. "DotfilesAutoSync-Timer"   → toutes les 30 minutes
      2. "DotfilesAutoSync-Logoff"  → à la déconnexion de session

    Chaque tâche lance :
        bash.exe -c 'git dsync --quiet'

    Les logs vont dans %USERPROFILE%\.dotfiles-sync.log

.PARAMETER BashPath
    Chemin vers bash.exe (par défaut : C:\Program Files\Git\bin\bash.exe).

.PARAMETER IntervalMinutes
    Intervalle du timer en minutes (par défaut : 30).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Register-AutoSyncTask.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass `
      -File .\Register-AutoSyncTask.ps1 `
      -BashPath "C:\Git\bin\bash.exe" `
      -IntervalMinutes 15

.NOTES
    À exécuter normalement (pas admin). Les tâches tournent sous l'utilisateur courant.
#>

[CmdletBinding()]
param(
    [string]$BashPath = "C:\Program Files\Git\bin\bash.exe",
    [int]$IntervalMinutes = 30
)

$ErrorActionPreference = 'Stop'

# --- Vérifs ---
if (-not (Test-Path $BashPath)) {
    Write-Error "bash.exe introuvable : $BashPath. Précise -BashPath avec le bon chemin."
    exit 1
}

$TimerTaskName  = "DotfilesAutoSync-Timer"
$LogoffTaskName = "DotfilesAutoSync-Logoff"
$Description    = "Synchronise le repo dotfiles (commit + push) automatiquement."

# Commande bash à exécuter : -i -c pour charger le PATH (et donc git-dsync)
$BashArgs = "-lc `"git dsync --quiet`""

Write-Host ""
Write-Host "Enregistrement des tâches planifiées 'DotfilesAutoSync'" -ForegroundColor Cyan
Write-Host "  bash.exe      : $BashPath"
Write-Host "  Intervalle    : $IntervalMinutes min"
Write-Host "  Utilisateur   : $env:USERNAME"
Write-Host ""

# --- Action commune ---
$Action = New-ScheduledTaskAction `
    -Execute $BashPath `
    -Argument $BashArgs

# --- Paramètres communs ---
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Exécution sous le user courant (pas de SYSTEM, sinon les credentials git manquent)
$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Limited

# ============================================================
#  Tâche 1 : Timer (toutes les X min)
# ============================================================
$TimerTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Supprime l'ancienne si présente
if (Get-ScheduledTask -TaskName $TimerTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TimerTaskName -Confirm:$false
    Write-Host "  Ancienne tâche $TimerTaskName supprimée."
}

Register-ScheduledTask `
    -TaskName $TimerTaskName `
    -Description "$Description (timer $IntervalMinutes min)" `
    -Action $Action `
    -Trigger $TimerTrigger `
    -Settings $Settings `
    -Principal $Principal `
    | Out-Null
Write-Host "  [OK] $TimerTaskName" -ForegroundColor Green

# ============================================================
#  Tâche 2 : Logoff (à la déconnexion de session Windows)
# ============================================================
# Utilise un CIM-style trigger via event subscription
# Event ID 4647 (logoff initiated) dans Security

$LogoffTrigger = New-CimInstance `
    -CimClass (Get-CimClass -ClassName MSFT_TaskEventTrigger -Namespace Root/Microsoft/Windows/TaskScheduler) `
    -ClientOnly -Property @{
        Subscription = @"
<QueryList>
  <Query Id="0" Path="System">
    <Select Path="System">*[System[Provider[@Name='Microsoft-Windows-Winlogon'] and (EventID=7002)]]</Select>
  </Query>
</QueryList>
"@
        Enabled = $true
    }

# Event ID 7002 dans System = "User Logoff Notification for Customer Experience Improvement Program"
# (déclenché fiabilement au logoff, plus fiable que 4647 qui exige audit policy)
# Fallback : ID 1074 (System/User32 = shutdown/restart initiated)

if (Get-ScheduledTask -TaskName $LogoffTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $LogoffTaskName -Confirm:$false
    Write-Host "  Ancienne tâche $LogoffTaskName supprimée."
}

try {
    Register-ScheduledTask `
        -TaskName $LogoffTaskName `
        -Description "$Description (au logoff)" `
        -Action $Action `
        -Trigger $LogoffTrigger `
        -Settings $Settings `
        -Principal $Principal `
        | Out-Null
    Write-Host "  [OK] $LogoffTaskName" -ForegroundColor Green
} catch {
    Write-Warning "Échec création de la tâche logoff (événement $_.Exception.Message)"
    Write-Host "  → La tâche timer $IntervalMinutes min suffit comme fallback." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Tâches enregistrées. Voir 'taskschd.msc' ou :" -ForegroundColor Cyan
Write-Host "  Get-ScheduledTask -TaskName DotfilesAutoSync-*"
Write-Host ""
Write-Host "Pour désinstaller : Unregister-AutoSyncTask.ps1" -ForegroundColor DarkGray
Write-Host ""
