#!/usr/bin/env bash
# ~/.config/git/lib/wt-common.sh
# Fonctions partagées par les scripts git-w*
# À sourcer, pas à exécuter.

set -o pipefail

# -- Couleurs (désactivées si non-tty) -----------------------
if [ -t 1 ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_CYAN=''
fi

die()  { printf "%s✗%s %s\n" "$C_RED"    "$C_RESET" "$*" >&2; exit 1; }
warn() { printf "%s!%s %s\n" "$C_YELLOW" "$C_RESET" "$*" >&2; }
info() { printf "%s→%s %s\n" "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf "%s✓%s %s\n" "$C_GREEN"  "$C_RESET" "$*"; }

# -- require_git_repo ----------------------------------------
# Sort en erreur si pas dans un repo.
require_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || git rev-parse --is-bare-repository >/dev/null 2>&1 \
        || die "Pas dans un dépôt git."
}

# -- project_root --------------------------------------------
# Retourne le dossier "projet" qui contient le bare et les worktrees.
# Pour un layout bare-repo :
#   ~/projects/myproject/
#   ├── .bare/           <- git common dir
#   ├── .git             <- file "gitdir: ./.bare"
#   ├── main/
#   └── feature-xxx/
# common-dir = "~/projects/myproject/.bare" → dirname = project_root
# Pour un layout normal : common-dir = ".git" → project_root = parent du repo
project_root() {
    local common_dir parent
    common_dir=$(git rev-parse --git-common-dir 2>/dev/null) \
        || die "Impossible de localiser --git-common-dir."
    common_dir=$(cd "$common_dir" && pwd)
    parent=$(dirname "$common_dir")
    # Si common_dir est ".git" (repo normal), on prend le parent du parent
    # pour les worktrees en "dossier frère du repo", mais dans notre cas
    # Jonathan utilise bare → parent est le bon project_root.
    # Heuristique : si le basename du common_dir contient "bare" ou commence
    # par un point (.bare), c'est un bare → parent = project_root.
    # Sinon (repo normal), on met les worktrees en frère du repo.
    case "$(basename "$common_dir")" in
        .bare|bare|*.git)
            printf '%s\n' "$parent"
            ;;
        .git)
            # repo normal : project root = parent du dossier racine du repo
            # ex: /code/myrepo/.git → worktrees dans /code/myrepo-wt/ ?
            # Plus sûr : on met en frère du repo, donc parent du parent
            printf '%s\n' "$(dirname "$parent")"
            ;;
        *)
            printf '%s\n' "$parent"
            ;;
    esac
}

# -- sanitize_dirname ----------------------------------------
# "feature/HYG-123-foo" → "feature-HYG-123-foo"
# Garde le nom de branche intact, ne transforme que le nom de dossier.
sanitize_dirname() {
    printf '%s\n' "$1" | tr '/' '-' | tr -c 'A-Za-z0-9._-' '-' | sed 's/-\+/-/g; s/^-//; s/-$//'
}

# -- worktree_path_for_branch --------------------------------
# Donne le chemin qu'aurait le worktree pour cette branche.
worktree_path_for_branch() {
    local branch="$1"
    local root
    root=$(project_root) || return 1
    printf '%s/%s\n' "$root" "$(sanitize_dirname "$branch")"
}

# -- find_worktree_by_branch ---------------------------------
# Si un worktree existe déjà pour la branche donnée, retourne son chemin.
# Sinon rien et code 1.
find_worktree_by_branch() {
    local branch="$1"
    git worktree list --porcelain | awk -v b="refs/heads/$branch" '
        /^worktree / { path=$2 }
        /^branch /   { if ($2 == b) { print path; found=1; exit } }
        END          { exit !found }
    '
}

# -- list_all_branches ---------------------------------------
# Toutes les branches (locales + distantes sans doublons), une par ligne.
list_all_branches() {
    {
        git for-each-ref --format='%(refname:short)' refs/heads
        git for-each-ref --format='%(refname:short)' refs/remotes \
            | sed 's|^origin/||' \
            | grep -v '^HEAD$'
    } | sort -u
}

# -- branch_is_merged ----------------------------------------
# 0 si la branche est mergée dans $2 (ex: origin/main), 1 sinon.
branch_is_merged() {
    local branch="$1" base="$2"
    git merge-base --is-ancestor "$branch" "$base" 2>/dev/null
}

# -- confirm --------------------------------------------------
# confirm "Supprimer la branche foo ?" [default y|n]
confirm() {
    local prompt="$1" default="${2:-n}" answer
    local hint
    case "$default" in
        y|Y) hint='[Y/n]';;
        *)   hint='[y/N]';;
    esac
    printf '%s %s ' "$prompt" "$hint" >&2
    read -r answer
    [ -z "$answer" ] && answer="$default"
    case "$answer" in
        y|Y|yes|YES) return 0 ;;
        *)           return 1 ;;
    esac
}

# -- pick_from_list ------------------------------------------
# pick_from_list "Sélectionne :" item1 item2 item3
# echo le choix sur stdout. Utilise `select`.
pick_from_list() {
    local prompt="$1"; shift
    [ $# -eq 0 ] && die "pick_from_list: liste vide."
    if [ $# -eq 1 ]; then
        printf '%s\n' "$1"
        return
    fi
    printf '%s\n' "$prompt" >&2
    PS3=$'\n→ Numéro : '
    local choice
    select choice in "$@"; do
        if [ -n "$choice" ]; then
            printf '%s\n' "$choice"
            return
        fi
        printf 'Choix invalide.\n' >&2
    done
}
