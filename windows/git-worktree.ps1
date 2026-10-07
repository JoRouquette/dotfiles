# ============================================================
#  <repo dotfiles>/windows/git-worktree.ps1
#  Équivalent PowerShell de git/bashrc-git.sh : wsw, wgo, wnew, wadd, wroot.
#
#  Les alias `git w*` marchent déjà sous PowerShell (git les exécute avec son
#  propre bash). Ces fonctions ajoutent seulement le `cd` dans le worktree,
#  qu'un processus enfant ne peut pas faire à la place du shell courant.
#  Elles appellent les alias (ws, wg, wn, wa) et non `git wgo` & co : sous
#  PowerShell, ~/.config/git/bin n'est pas dans le PATH, seuls les alias
#  trouvent les scripts.
#
#  À charger depuis le profil PowerShell ($PROFILE.CurrentUserAllHosts) :
#      $f = "<repo dotfiles>\windows\git-worktree.ps1"   # chemin réel du repo
#      if (Test-Path -LiteralPath $f) { . $f } else { Write-Warning "Introuvable : $f" }
#  Ce chemin est à corriger dans le profil si le repo est déplacé.
#
#  Toute fonction `cd` ajoutée à git/bashrc-git.sh s'ajoute aussi ici.
#  Aucune variable d'environnement n'est posée : git-dsync se localise seul.
# ============================================================

# Convertit un chemin renvoyé par les scripts bash (/c/Users/...) en chemin Windows.
function ConvertTo-DotfilesWindowsPath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $Path = $Path.Trim()
    if ($Path -match '^/([a-zA-Z])/(.*)$') {
        return ('{0}:\{1}' -f $Matches[1].ToUpper(), ($Matches[2] -replace '/', '\'))
    }

    return ($Path -replace '/', '\')
}

# Lance `git <args>`, garde la dernière ligne non vide de stdout et s'y place.
# Les messages des scripts partent sur stderr et restent visibles.
function Invoke-DotfilesWorktreeJump {
    param([string[]]$GitArguments)

    $output = @(& git @GitArguments)
    if ($LASTEXITCODE -ne 0) {
        return
    }

    $last = $output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Last 1
    $target = ConvertTo-DotfilesWindowsPath -Path $last
    if ($target -and (Test-Path -LiteralPath $target -PathType Container)) {
        Set-Location -LiteralPath $target
        Write-Host ('→ {0}' -f (Get-Location).Path)
    }
    elseif ($last) {
        Write-Warning ('Dossier introuvable, pas de changement de répertoire : {0}' -f $last)
    }
}

# wsw = sélecteur interactif de worktree, avec cd
function wsw {
    Invoke-DotfilesWorktreeJump -GitArguments @('ws')
}

# wgo <branche> = va dans le worktree de la branche (le crée s'il manque)
function wgo {
    param([Parameter(Mandatory = $true)][string]$Branch)

    Invoke-DotfilesWorktreeJump -GitArguments @('wg', $Branch)
}

# wnew <branche> [--from base] = crée la branche et son worktree, puis cd
function wnew {
    Invoke-DotfilesWorktreeJump -GitArguments (@('wn') + $args)
}

# wadd <branche> = ajoute le worktree d'une branche existante, puis cd
function wadd {
    Invoke-DotfilesWorktreeJump -GitArguments (@('wa') + $args)
}

# wroot = cd vers la racine du dossier projet (celui qui contient le bare)
function wroot {
    $common = & git rev-parse --path-format=absolute --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $common) {
        Write-Error 'Pas dans un repo git.'
        return
    }

    $root = Split-Path (ConvertTo-DotfilesWindowsPath -Path $common) -Parent
    Set-Location -LiteralPath $root
    Write-Host ('→ {0}' -f (Get-Location).Path)
}

# Complétion de wgo : branches locales et distantes (sans le préfixe origin/)
Register-ArgumentCompleter -CommandName wgo -ParameterName Branch -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)

    $branches = @(& git for-each-ref --format='%(refname:short)' refs/heads 2>$null) +
                @(& git for-each-ref --format='%(refname:short)' refs/remotes 2>$null |
                    ForEach-Object { $_ -replace '^origin/', '' } |
                    Where-Object { $_ -ne 'HEAD' -and $_ -ne 'origin' })

    # Un nom de branche distant est contrôlé par un tiers et git y accepte
    # `$`, `(` ou `;` : hors caractères sûrs, on l'insère entre apostrophes
    # pour que PowerShell ne l'évalue jamais.
    $branches | Sort-Object -Unique | Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            # EscapeSingleQuotedStringContent double aussi les apostrophes
            # typographiques (U+2018 à U+201B), que PowerShell traite comme ' .
            $text = if ($_ -match '^[\w./-]+$') { $_ }
                    else { "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($_) + "'" }
            [System.Management.Automation.CompletionResult]::new($text, $_, 'ParameterValue', $_)
        }
}
