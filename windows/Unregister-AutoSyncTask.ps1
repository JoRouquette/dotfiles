<#
.SYNOPSIS
    Supprime les tâches planifiées "DotfilesAutoSync-*".
#>

$ErrorActionPreference = 'SilentlyContinue'

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
Write-Host "Tâches supprimées. Les scripts et le repo dotfiles ne sont pas touchés." -ForegroundColor Cyan
