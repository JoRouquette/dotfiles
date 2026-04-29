<#
.SYNOPSIS
    Enregistre la tâche planifiée Windows pour synchroniser
    le repo dotfiles automatiquement.

.DESCRIPTION
    Crée 1 tâche "DotfilesAutoSync-Timer" qui s'exécute :
      - À 12:00 et 17:00 chaque jour
      - En arrière-plan (invisible, pas de fenêtre)

    La tâche lance :
        bash.exe -lc 'git dsync --quiet'

    Les logs vont dans %USERPROFILE%\.dotfiles-sync.log

    ⚠️  IMPORTANT : Cette méthode nécessite des droits administrateur
    pour enregistrer une tâche avec le mode "S4U" (Service for User).
    
    Si vous n'avez pas les droits admin, utilisez plutôt :
        Setup-StartupSync.ps1
    qui ajoute un raccourci dans le dossier Startup (sans admin).

.PARAMETER BashPath
    Chemin vers bash.exe. Détecté automatiquement si absent.

.EXAMPLE
    # En tant qu'administrateur :
    powershell -ExecutionPolicy Bypass -File .\Register-AutoSyncTask.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass `
      -File .\Register-AutoSyncTask.ps1 `
      -BashPath "C:\Git\bin\bash.exe"

.NOTES
    Requiert des droits administrateur pour le mode S4U.
    Alternative sans admin : Setup-StartupSync.ps1
#>

[CmdletBinding()]
param(
    [string]$BashPath = ""
)

$ErrorActionPreference = 'Stop'

# --- Vérification des droits admin ---
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  ⚠️  ATTENTION : Ce script nécessite des droits administrateur." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Le mode 'S4U' (Service for User) permet d'exécuter la tâche" -ForegroundColor Gray
    Write-Host "  en arrière-plan sans fenêtre visible, mais requiert les droits admin." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Options :" -ForegroundColor Cyan
    Write-Host "    1. Relancez PowerShell en tant qu'administrateur"
    Write-Host "    2. Utilisez l'alternative sans admin :"
    Write-Host "       powershell -ExecutionPolicy Bypass ``" -ForegroundColor Green
    Write-Host "         -File `"$PSScriptRoot\Setup-StartupSync.ps1`"" -ForegroundColor Green
    Write-Host ""
    exit 1
}

# --- Détection automatique de bash.exe si non fourni ---
if (-not $BashPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Git\usr\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "C:\Program Files\Git\usr\bin\bash.exe",
        "C:\Program Files\Git\bin\bash.exe"
    )
    $BashPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $BashPath) {
        Write-Error "bash.exe introuvable. Précise -BashPath avec le bon chemin (ex: $env:LOCALAPPDATA\Programs\Git\usr\bin\bash.exe)."
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

# Commande bash à exécuter : -l pour charger le PATH (et donc git-dsync)
$BashArgs = "-lc `"git dsync --quiet`""

Write-Host ""
Write-Host "Enregistrement de la tâche planifiée 'DotfilesAutoSync'" -ForegroundColor Cyan
Write-Host "  bash.exe      : $BashPath"
Write-Host "  Horaires      : 12:00 et 17:00"
Write-Host "  Utilisateur   : $env:USERNAME"
Write-Host "  Mode          : arrière-plan (invisible)"
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

# Exécution sous le user courant en arrière-plan (S4U = invisible, pas de fenêtre)
$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType S4U `
    -RunLevel Limited

# ============================================================
#  Tâche : Timer quotidien à 12:00 et 17:00
# ============================================================
$Trigger12h = New-ScheduledTaskTrigger -Daily -At "12:00"
$Trigger17h = New-ScheduledTaskTrigger -Daily -At "17:00"

# Supprime l'ancienne si présente
if (Get-ScheduledTask -TaskName $TimerTaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TimerTaskName -Confirm:$false
    Write-Host "  Ancienne tâche $TimerTaskName supprimée."
}

# Supprime aussi l'ancienne tâche Logoff si elle existe encore
if (Get-ScheduledTask -TaskName "DotfilesAutoSync-Logoff" -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName "DotfilesAutoSync-Logoff" -Confirm:$false
    Write-Host "  Ancienne tâche DotfilesAutoSync-Logoff supprimée."
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
