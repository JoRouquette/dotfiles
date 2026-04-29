<#
.SYNOPSIS
    Supprime la tâche planifiée "DotfilesAutoSync-Timer".
    Supprime aussi l'ancienne tâche "DotfilesAutoSync-Logoff" si elle existe encore.

.NOTES
    Pour supprimer le raccourci Startup (Setup-StartupSync.ps1), utilisez :
      Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DotfilesSync.lnk"
    Ou lancez :
      powershell -ExecutionPolicy Bypass -File Setup-StartupSync.ps1 -Remove
#>

$ErrorActionPreference = 'SilentlyContinue'

# Tâche actuelle + ancienne tâche Logoff (rétro-compatibilité)
$tasks = @("DotfilesAutoSync-Timer", "DotfilesAutoSync-Logoff")

foreach ($t in $tasks) {
    if (Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $t -Confirm:$false
        Write-Host "[OK] $t supprimée" -ForegroundColor Green
    } else {
        Write-Host "[--] $t : absente" -ForegroundColor DarkGray
    }
}

# Vérifie aussi le raccourci Startup
$StartupShortcut = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DotfilesSync.lnk"
if (Test-Path $StartupShortcut) {
    Write-Host ""
    Write-Host "[!] Raccourci Startup détecté : $StartupShortcut" -ForegroundColor Yellow
    Write-Host "    Pour le supprimer : Setup-StartupSync.ps1 -Remove" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Tâches supprimées. Les scripts et le repo dotfiles ne sont pas touchés." -ForegroundColor Cyan
