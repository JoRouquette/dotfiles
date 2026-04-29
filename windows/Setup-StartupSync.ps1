<#
.SYNOPSIS
    Configure la synchronisation automatique des dotfiles au démarrage Windows.
    Alternative sans droits administrateur à Register-AutoSyncTask.ps1.

.DESCRIPTION
    Crée un raccourci dans le dossier Startup de l'utilisateur qui lance
    'git dsync --quiet' à chaque connexion Windows.

    Cette méthode :
      - Ne nécessite AUCUN droit administrateur
      - Fonctionne sur les postes d'entreprise verrouillés
      - S'exécute à chaque connexion de l'utilisateur
      - Lance bash en mode fenêtre minimisée

    Les logs vont dans %USERPROFILE%\.dotfiles-sync.log

.PARAMETER BashPath
    Chemin vers bash.exe. Détecté automatiquement si absent.

.PARAMETER Remove
    Supprime le raccourci au lieu de le créer.

.EXAMPLE
    # Installation (pas besoin d'admin)
    powershell -ExecutionPolicy Bypass -File .\Setup-StartupSync.ps1

.EXAMPLE
    # Désinstallation
    powershell -ExecutionPolicy Bypass -File .\Setup-StartupSync.ps1 -Remove

.NOTES
    Alternative à Register-AutoSyncTask.ps1 pour les utilisateurs sans droits admin.
    La sync se fait une fois au démarrage (vs 2x/jour pour la tâche planifiée).
    Le trap EXIT dans bashrc fournit une sync complémentaire à chaque fermeture de terminal.
#>

[CmdletBinding()]
param(
    [string]$BashPath = "",
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

$StartupFolder = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$ShortcutPath = "$StartupFolder\DotfilesSync.lnk"

# --- Mode suppression ---
if ($Remove) {
    if (Test-Path $ShortcutPath) {
        Remove-Item $ShortcutPath -Force
        Write-Host ""
        Write-Host "  ✓ Raccourci supprimé : $ShortcutPath" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "  ! Raccourci introuvable (déjà supprimé ?)" -ForegroundColor Yellow
        Write-Host ""
    }
    exit 0
}

# --- Détection automatique de bash.exe ---
if (-not $BashPath) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\Git\usr\bin\bash.exe",
        "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
        "C:\Program Files\Git\usr\bin\bash.exe",
        "C:\Program Files\Git\bin\bash.exe"
    )
    $BashPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $BashPath) {
        Write-Error "bash.exe introuvable. Précise -BashPath avec le bon chemin."
        exit 1
    }
}

if (-not (Test-Path $BashPath)) {
    Write-Error "bash.exe introuvable : $BashPath"
    exit 1
}

Write-Host ""
Write-Host "  Configuration de la sync au démarrage Windows" -ForegroundColor Cyan
Write-Host "  =============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  bash.exe        : $BashPath"
Write-Host "  Raccourci       : $ShortcutPath"
Write-Host "  Déclencheur     : À chaque connexion Windows"
Write-Host "  Mode            : Fenêtre minimisée"
Write-Host ""

# --- Création du raccourci ---
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

# bash -lc charge le profil (PATH, fonctions) puis exécute git dsync
$Shortcut.TargetPath = $BashPath
$Shortcut.Arguments = "-lc `"git dsync --quiet`""
$Shortcut.WorkingDirectory = $env:USERPROFILE
$Shortcut.WindowStyle = 7  # 7 = Minimized
$Shortcut.Description = "Synchronise les dotfiles (git dsync)"

# Icône Git si disponible
$GitDir = Split-Path (Split-Path $BashPath -Parent) -Parent
$GitIcon = "$GitDir\mingw64\share\git\git-for-windows.ico"
if (Test-Path $GitIcon) {
    $Shortcut.IconLocation = $GitIcon
}

$Shortcut.Save()

Write-Host "  ✓ Raccourci créé avec succès !" -ForegroundColor Green
Write-Host ""
Write-Host "  La sync s'exécutera automatiquement à chaque connexion Windows." -ForegroundColor Gray
Write-Host "  En plus, le trap EXIT dans bashrc sync à chaque fermeture de terminal." -ForegroundColor Gray
Write-Host ""
Write-Host "  Pour tester maintenant :" -ForegroundColor Cyan
Write-Host "    git dsync"
Write-Host ""
Write-Host "  Pour désinstaller :" -ForegroundColor Cyan
Write-Host "    powershell -ExecutionPolicy Bypass -File `"$PSScriptRoot\Setup-StartupSync.ps1`" -Remove"
Write-Host "    # ou supprimer manuellement : $ShortcutPath"
Write-Host ""
