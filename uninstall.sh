#!/usr/bin/env bash
# uninstall.sh
#   Retire les symlinks créés par install.sh.
#   Si une backup .backup-* est trouvée, la restaure.
#   Retire aussi le fragment dans ~/.bashrc.
#
#   NB : ne supprime PAS le repo lui-même ($HOME/dotfiles).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")" && pwd)"

if [ -t 1 ]; then
    C_R=$'\033[0m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_BL=$'\033[34m'
else
    C_R=''; C_G=''; C_Y=''; C_BL=''
fi
info() { printf '%s→%s %s\n' "$C_BL" "$C_R" "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_G"  "$C_R" "$*"; }
warn() { printf '%s!%s %s\n' "$C_Y"  "$C_R" "$*" >&2; }

remove_link() {
    local dest="$1"
    if [ -L "$dest" ]; then
        rm -f "$dest"
        ok "Supprimé : $dest"
        # Cherche une backup récente à restaurer
        local latest
        latest=$(ls -1t "${dest}.backup-"* 2>/dev/null | head -n 1 || true)
        if [ -n "$latest" ]; then
            info "Backup trouvée : $latest → restaure vers $dest"
            mv "$latest" "$dest"
            ok "Restauré"
        fi
    elif [ -e "$dest" ]; then
        warn "$dest existe mais n'est pas un symlink (laissé tel quel)."
    fi
}

remove_link "$HOME/.gitconfig"
remove_link "$HOME/.config/git/bin"
remove_link "$HOME/.config/git/lib"
remove_link "$HOME/.config/git/bashrc-git.sh"

# Nettoie le fragment .bashrc
BASHRC="$HOME/.bashrc"
MARKER_START="# >>> dotfiles (managed by ~/dotfiles/install.sh) >>>"
MARKER_END="# <<< dotfiles <<<"

if [ -f "$BASHRC" ] && grep -qF "$MARKER_START" "$BASHRC"; then
    # Retire le bloc entre les markers (inclusifs)
    # On utilise `|` comme délimiteur parce que les markers contiennent `/`
    cp "$BASHRC" "${BASHRC}.backup-$(date +%Y%m%d-%H%M%S)"
    sed -i "\|$MARKER_START|,\|$MARKER_END|d" "$BASHRC"
    ok "Fragment retiré de $BASHRC (backup créée)"
fi

echo
ok "Désinstallation terminée."
info "Le repo est conservé : $REPO_DIR"
info "Pour le supprimer : rm -rf $REPO_DIR"
