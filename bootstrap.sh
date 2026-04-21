#!/usr/bin/env bash
# bootstrap.sh
#   Installation depuis zéro sur un nouveau PC :
#     1. Vérifie les prérequis (git, bash)
#     2. Clone ce repo dans $HOME/.projects/dotfiles si besoin
#     3. Lance install.sh
#     4. Affiche la commande pour activer la sync auto Windows
#
#   Usage (depuis un PC vierge, après avoir cloné manuellement OU via :
#     curl) :
#
#     # Option A : clone manuel puis bootstrap
#     git clone git@github.com:<user>/dotfiles.git ~/.projects/dotfiles
#     ~/.projects/dotfiles/bootstrap.sh
#
#     # Option B : one-liner
#     bash <(curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/bootstrap.sh)
#
#   Quand lancé via curl, demande l'URL du repo puis clone et relance.

set -euo pipefail

REPO_URL_DEFAULT="${DOTFILES_REPO:-}"
TARGET_DIR="${DOTFILES_DIR:-$HOME/.projects/dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"

if [ -t 1 ]; then
    C_R=$'\033[0m'; C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_BL=$'\033[34m'
else
    C_R=''; C_B=''; C_G=''; C_Y=''; C_BL=''
fi
info() { printf '%s→%s %s\n' "$C_BL" "$C_R" "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_G"  "$C_R" "$*"; }
warn() { printf '%s!%s %s\n' "$C_Y"  "$C_R" "$*" >&2; }
die()  { printf '✗ %s\n' "$*" >&2; exit 1; }

# --- Prérequis ---
command -v git  >/dev/null || die "git n'est pas installé."
command -v bash >/dev/null || die "bash n'est pas installé."

# --- Cas 1 : on est déjà dans le repo → install direct ------
if [ -d "$(dirname "$0")/.git" ] \
   || [ -f "$(dirname "$0")/install.sh" ]; then
    REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
    info "Repo détecté : $REPO_DIR"
else
    # --- Cas 2 : on lance via curl, il faut cloner d'abord --
    if [ -d "$TARGET_DIR/.git" ]; then
        info "Repo déjà présent : $TARGET_DIR (git pull)"
        git -C "$TARGET_DIR" pull --ff-only || warn "Pull échoué, on continue avec la version locale."
    else
        if [ -z "$REPO_URL_DEFAULT" ]; then
            printf '%sURL du repo dotfiles :%s ' "$C_B" "$C_R"
            read -r REPO_URL
        else
            REPO_URL="$REPO_URL_DEFAULT"
        fi
        [ -z "$REPO_URL" ] && die "URL requise."
        info "Clone $REPO_URL → $TARGET_DIR"
        git clone --branch "$BRANCH" "$REPO_URL" "$TARGET_DIR"
    fi
    REPO_DIR="$TARGET_DIR"
fi

# --- Lancement de install.sh ---
info "Lancement de install.sh"
bash "$REPO_DIR/install.sh"

# --- Message final ---
echo
ok "Bootstrap terminé."
cat <<EOF

${C_B}Étapes suivantes :${C_R}

1. Recharge ton shell :
     source ~/.bashrc

2. Vérifie le repo :
     cd "$REPO_DIR" && git remote -v

3. Active la sync automatique (Windows, PowerShell en admin) :
     powershell -ExecutionPolicy Bypass \\
       -File "$REPO_DIR/windows/Register-AutoSyncTask.ps1"

4. Teste un commit/push manuel :
     cd "$REPO_DIR"
     echo "# test" >> README.md
     git dsync

EOF
