<#
.SYNOPSIS
    Enregistre la tâche planifiée Windows pour synchroniser
    le repo dotfiles automatiquement.

.DESCRIPTION
    Crée 1 tâche "DotfilesAutoSync-Timer" qui s'exécute :
      - À 12:00 et 17:00 chaque jour (rattrapée à l'ouverture de session
        si le poste était éteint ou en veille)
      - Dans la session ouverte de l'utilisateur (mode "Interactive"),
        sans droits administrateur

    La tâche lance, fenêtre masquée :
        bash.exe -lc 'git dsync --quiet'

    Les logs vont dans %USERPROFILE%\.dotfiles-sync.log

    Pourquoi pas le mode "S4U" : sur un poste joint à un domaine, une tâche
    S4U ne démarre pas sans contrôleur de domaine joignable (erreur
    0x8007051F hors réseau d'entreprise ou sans VPN). La synchro d'un repo
    personnel ne doit dépendre d'aucun réseau. Contrepartie : la tâche ne
    tourne que lorsqu'une session est ouverte.

.PARAMETER BashPath
    Chemin vers bash.exe. Détecté automatiquement si absent.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Register-AutoSyncTask.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass `
      -File .\Register-AutoSyncTask.ps1 `
      -BashPath "C:\Git\bin\bash.exe"

.NOTES
    Aucun droit administrateur requis, sauf pour remplacer une ancienne
    tâche enregistrée depuis une console admin (ancienne version S4U).
#>

[CmdletBinding()]
param(
    [string]$BashPath = ""
)

$ErrorActionPreference = 'Stop'

# --- Détection automatique de bash.exe si non fourni ---
if (-not $BashPath) {
    $candidates = @(
        "$env:ProgramFiles\Git\usr\bin\bash.exe",
        "$env:ProgramFiles\Git\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\usr\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe"
    )
    $BashPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $BashPath) {
        Write-Error "bash.exe introuvable. Précise -BashPath avec le bon chemin (ex: $env:ProgramFiles\Git\usr\bin\bash.exe)."
        exit 1
    }
    Write-Host "  bash.exe détecté : $BashPath"
}

if (-not (Test-Path $BashPath)) {
    Write-Error "bash.exe introuvable : $BashPath. Précise -BashPath avec le bon chemin."
    exit 1
}

$TimerTaskName  = "DotfilesAutoSync-Timer"
$Description    = "Synchronise le repo dotfiles (commit + push) automatiquement à 12h et 17h."
$UserId         = "$env:USERDOMAIN\$env:USERNAME"

# bash est lancé par un PowerShell masqué : une tâche "Interactive" ouvre
# sinon une console visible. -l charge le PATH (et donc git-dsync).
$Command = "& '$BashPath' -lc 'git dsync --quiet'"

Write-Host ""
Write-Host "Enregistrement de la tâche planifiée 'DotfilesAutoSync'" -ForegroundColor Cyan
Write-Host "  bash.exe      : $BashPath"
Write-Host "  Horaires      : 12:00 et 17:00"
Write-Host "  Utilisateur   : $UserId"
Write-Host "  Mode          : session ouverte (Interactive), fenêtre masquée"
Write-Host ""

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -Command `"$Command`"" `
    -WorkingDirectory $env:USERPROFILE

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Session ouverte de l'utilisateur : aucun contrôleur de domaine requis.
$Principal = New-ScheduledTaskPrincipal `
    -UserId $UserId `
    -LogonType Interactive `
    -RunLevel Limited

# ============================================================
#  Tâche : Timer quotidien à 12:00 et 17:00
# ============================================================
$Trigger12h = New-ScheduledTaskTrigger -Daily -At "12:00"
$Trigger17h = New-ScheduledTaskTrigger -Daily -At "17:00"

foreach ($OldTask in @($TimerTaskName, "DotfilesAutoSync-Logoff")) {
    if (Get-ScheduledTask -TaskName $OldTask -ErrorAction SilentlyContinue) {
        try {
            Unregister-ScheduledTask -TaskName $OldTask -Confirm:$false
            Write-Host "  Ancienne tâche $OldTask supprimée."
        }
        catch {
            Write-Host ""
            Write-Host "  Impossible de supprimer l'ancienne tâche $OldTask : $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  Elle a sans doute été enregistrée depuis une console admin." -ForegroundColor Gray
            Write-Host "  Relance ce script une fois en tant qu'administrateur." -ForegroundColor Gray
            Write-Host ""
            exit 1
        }
    }
}

Register-ScheduledTask `
    -TaskName $TimerTaskName `
    -Description $Description `
    -Action $Action `
    -Trigger @($Trigger12h, $Trigger17h) `
    -Settings $Settings `
    -Principal $Principal `
    | Out-Null
Write-Host "  [OK] $TimerTaskName (12:00 + 17:00)" -ForegroundColor Green

Write-Host ""
Write-Host "Tâche enregistrée. Voir 'taskschd.msc' ou :" -ForegroundColor Cyan
Write-Host "  Get-ScheduledTask -TaskName DotfilesAutoSync-*"
Write-Host ""
Write-Host "Pour désinstaller : Unregister-AutoSyncTask.ps1" -ForegroundColor DarkGray
Write-Host ""
