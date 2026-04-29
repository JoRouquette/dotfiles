<#
.SYNOPSIS
    Supprime la tâche planifiée "DotfilesAutoSync-Timer".
    Supprime aussi l'ancienne tâche "DotfilesAutoSync-Logoff" si elle existe encore.
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

Write-Host ""
Write-Host "Tâche supprimée. Les scripts et le repo dotfiles ne sont pas touchés." -ForegroundColor Cyan
