#!/usr/bin/env bash
# ~/.config/git/bashrc-git.sh
# À sourcer dans ~/.bashrc (ou ~/.bash_profile) :
#     source ~/.config/git/bashrc-git.sh
#
# Ces fonctions wrappent les scripts `git-w*` pour faire un vrai `cd`.
# Un script enfant ne peut pas changer le cwd du shell parent,
# d'où le besoin de ces wrappers.

# wsw  = interactive switch (avec cd)
wsw() {
    local target
    target=$(git wswitch) || return $?
    [ -n "$target" ] && cd "$target" && printf '→ %s\n' "$PWD"
}

# wgo <branch>  = jump vers un worktree (avec cd), crée si absent
wgo() {
    if [ $# -ne 1 ]; then
        echo "Usage : wgo <branch>" >&2
        return 1
    fi
    local target
    target=$(git wgo "$1") || return $?
    [ -n "$target" ] && cd "$target" && printf '→ %s\n' "$PWD"
}

# wnew <branch> [--from base]  = crée + cd dans le nouveau worktree
wnew() {
    local out last_line
    out=$(git wnew "$@") || return $?
    # Le script affiche le chemin en DERNIÈRE ligne de stdout
    last_line=$(printf '%s' "$out" | tail -n 1)
    [ -d "$last_line" ] && cd "$last_line" && printf '→ %s\n' "$PWD"
}

# wadd <branch>  = ajoute + cd dans le worktree ajouté
wadd() {
    local out last_line
    out=$(git wadd "$@") || return $?
    last_line=$(printf '%s' "$out" | tail -n 1)
    [ -d "$last_line" ] && cd "$last_line" && printf '→ %s\n' "$PWD"
}

# wroot = cd vers la racine du dossier projet (contenant le bare)
wroot() {
    local root
    root=$(git rev-parse --git-common-dir 2>/dev/null) || { echo "Pas dans un repo git." >&2; return 1; }
    root=$(cd "$root/.." && pwd)
    cd "$root" && printf '→ %s\n' "$PWD"
}

# Complétion bash simple pour wgo (branches + worktrees existants)
_wgo_complete() {
    local cur branches
    cur="${COMP_WORDS[COMP_CWORD]}"
    branches=$( {
        git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null
        git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null \
            | sed 's|^origin/||' | grep -v '^HEAD$'
    } | sort -u )
    COMPREPLY=( $(compgen -W "$branches" -- "$cur") )
}
complete -F _wgo_complete wgo
complete -F _wgo_complete wadd
