function ghx { & "$env:ProgramFiles\Git\bin\sh.exe" "$HOME/.config/git/bin/ghx" @args }

# --- Journal des commandes : lancement, code de sortie, duree ; purge glissante ---
$global:CmdLogDir         = Join-Path $HOME 'PowerShell\CommandLog'
$global:CmdLogKeepDays    = 15
$global:CmdSession        = Get-Date -Format 'yyMMddHHmmss'
$global:CmdSeq            = 0
$global:CmdPending        = $null
$global:CmdErrBefore      = $null
$global:CmdSensitiveRegex = '(?i)password|passwd|token|secret|api[-_]?key|bearer|-AsPlainText|\bPAT\b'
New-Item -ItemType Directory -Path $global:CmdLogDir -Force | Out-Null

# Purge glissante
Get-ChildItem $global:CmdLogDir -Filter '*.tsv' -ErrorAction SilentlyContinue |
    Where-Object LastWriteTime -lt (Get-Date).AddDays(-$global:CmdLogKeepDays) |
    Remove-Item -Force -ErrorAction SilentlyContinue

function Write-CmdLogLine {
    param([string]$Text)
    $file = Join-Path $global:CmdLogDir ("{0}.tsv" -f (Get-Date -Format 'yyyy-MM-dd'))
    [System.IO.File]::AppendAllText($file, $Text + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

# Historique PSReadLine : ne garde pas les lignes sensibles (aucun log ici)
Set-PSReadLineOption -AddToHistoryHandler {
    param([string]$line)
    return -not ($line -match $global:CmdSensitiveRegex)
}

# Entree : journalise le lancement et affiche l'heure a droite de la ligne
Set-PSReadLineKeyHandler -Key Enter -ScriptBlock {
    $line = $null; $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    try {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($line, [ref]$tokens, [ref]$errors)

            if ($errors.Count -eq 0) {
                $now = Get-Date
                $global:CmdSeq++
                $id = "{0}-{1}-{2}" -f $global:CmdSession, $PID, $global:CmdSeq
                $global:CmdPending   = @{ Id = $id; Start = $now }
                $global:CmdErrBefore = if ($global:Error.Count -gt 0) { $global:Error[0] } else { $null }

                $shown = if ($line -match $global:CmdSensitiveRegex) { '[REDACTED]' } else { $line -replace '\s*[\r\n]+\s*', ' ' }
                Write-CmdLogLine ("S`t{0}`t{1}`t{2}`t{3}`t{4}" -f $id, $now.ToString('yyyy-MM-dd HH:mm:ss'), $PID, (Get-Location).Path, $shown)

                # Heure de lancement alignee a droite (ligne simple uniquement)
                if ($line -notmatch '[\r\n]') {
                    [Microsoft.PowerShell.PSConsoleReadLine]::EndOfLine()
                    $w     = $Host.UI.RawUI.WindowSize.Width
                    $stamp = $now.ToString('HH:mm:ss')
                    if (([Console]::CursorLeft + $stamp.Length + 3) -lt $w) {
                        $esc = [char]27
                        [Console]::Write("${esc}7${esc}[$($w - $stamp.Length)G${esc}[90m$stamp${esc}[0m${esc}8")
                    }
                }
            }
        }
    } catch { }

    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

# Prompt : journalise la fin (code, duree) et l'affiche avant l'invite
function prompt {
    $ok  = $?
    $lec = $global:LASTEXITCODE

    if ($global:CmdPending) {
        $p = $global:CmdPending
        $global:CmdPending = $null

        $newErr = ($global:Error.Count -gt 0) -and -not [object]::ReferenceEquals($global:Error[0], $global:CmdErrBefore)
        $code   = if ($ok) { 0 } elseif ($newErr) { 1 } elseif ($lec) { $lec } else { 1 }
        $end    = Get-Date
        $dur    = $end - $p.Start

        Write-CmdLogLine ("E`t{0}`t{1}`t{2}`t{3}" -f $p.Id, $end.ToString('yyyy-MM-dd HH:mm:ss'), $code, [int]$dur.TotalMilliseconds)

        $d = if ($dur.TotalSeconds -ge 1) { '{0:N1}s' -f $dur.TotalSeconds } else { '{0}ms' -f [int]$dur.TotalMilliseconds }
        Write-Host ("  fin {0} | code {1} | {2}" -f $end.ToString('HH:mm:ss'), $code, $d) -ForegroundColor $(if ($code -eq 0) { 'DarkGreen' } else { 'Red' })
    }

    "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
}

function Get-CmdLog {
    param([int]$Last = 50, [string]$Match, [int]$Days = 15, [switch]$Failed)

    $since  = (Get-Date).Date.AddDays(-($Days - 1))
    $starts = New-Object System.Collections.Generic.List[object]
    $ends   = @{}

    Get-ChildItem $global:CmdLogDir -Filter '????-??-??.tsv' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $since } | Sort-Object Name | ForEach-Object {
            foreach ($l in [System.IO.File]::ReadLines($_.FullName, [System.Text.Encoding]::UTF8)) {
                $f = $l -split "`t"
                if ($f[0] -eq 'S' -and $f.Count -ge 6) { $starts.Add($f) }
                elseif ($f[0] -eq 'E' -and $f.Count -ge 5) { $ends[$f[1]] = $f }
            }
        }

    $starts | ForEach-Object {
        $e = $ends[$_[1]]
        [pscustomobject]@{
            Heure    = $_[2]
            PID      = $_[3]
            Dossier  = $_[4]
            Commande = $_[5]
            Code     = if ($e) { $e[3] } else { '?' }
            DureeMs  = if ($e) { $e[4] } else { '' }
        }
    } | Where-Object {
        (-not $Match  -or $_.Commande -match $Match) -and
        (-not $Failed -or ($_.Code -ne '0'))
    } | Select-Object -Last $Last
}
