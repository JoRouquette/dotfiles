# Fonctions worktree des dotfiles (wsw, wgo, wnew, wadd, wroot)
$dotfilesWorktree = Join-Path $env:USERPROFILE '.projects\Perso\Workspace\repos\dotfiles\main\windows\git-worktree.ps1'
if (Test-Path -LiteralPath $dotfilesWorktree) { . $dotfilesWorktree }
Remove-Variable dotfilesWorktree

# Commandes courtes de la night-shift (ns, nl, nr, nw, np, nb, nm, nh)
$nightAliases = Join-Path $env:USERPROFILE '.projects\tooling\night-shift\windows\NightAliases.ps1'
if (Test-Path -LiteralPath $nightAliases) { . $nightAliases }
Remove-Variable nightAliases
