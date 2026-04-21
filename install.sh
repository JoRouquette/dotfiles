#!/usr/bin/env bash
# install.sh
#   Installe les dotfiles en créant des symlinks depuis $HOME
#   vers ce repo. Idempotent : relancer le script met à jour
#   les liens cassés ou manquants sans toucher aux fichiers OK.
#
#   Usage : ./install.sh [--force] [--no-bashrc] [--dry-run]

set -euo pipefail

# ---- Localisation ------------------------------------------
# Chemin absolu du repo (celui de ce script)
REPO_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0")")" && pwd)"

FORCE=false
NO_BASHRC=false
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --force)       FORCE=true ;;
        --no-bashrc)   NO_BASHRC=true ;;
        --dry-run)     DRY_RUN=true ;;
        -h|--help)
            cat <<EOF
Usage : ./install.sh [--force] [--no-bashrc] [--dry-run]

  --force       Écrase les fichiers existants (backup en .backup-TIMESTAMP).
  --no-bashrc   N'ajoute pas le fragment source dans ~/.bashrc.
  --dry-run     Affiche ce qui serait fait, sans rien changer.
EOF
            exit 0 ;;
    esac
done

# ---- Couleurs ----------------------------------------------
if [ -t 1 ]; then
    C_R=$'\033[0m'; C_B=$'\033[1m'
    C_G=$'\033[32m'; C_Y=$'\033[33m'; C_BL=$'\033[34m'; C_R2=$'\033[31m'
else
    C_R=''; C_B=''; C_G=''; C_Y=''; C_BL=''; C_R2=''
fi
info() { printf '%s→%s %s\n' "$C_BL" "$C_R" "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_G"  "$C_R" "$*"; }
warn() { printf '%s!%s %s\n' "$C_Y"  "$C_R" "$*" >&2; }
die()  { printf '%s✗%s %s\n' "$C_R2" "$C_R" "$*" >&2; exit 1; }

# ---- Détection Git Bash Windows + symlinks -----------------
IS_GITBASH=false
case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*) IS_GITBASH=true ;;
esac

check_symlinks_windows() {
    $IS_GITBASH || return 0
    local test_src test_dst
    test_src=$(mktemp)
    test_dst="${test_src}.link"
    if MSYS=winsymlinks:nativestrict ln -s "$test_src" "$test_dst" 2>/dev/null; then
        # Vérifier que c'est bien un vrai symlink
        if [ -L "$test_dst" ]; then
            rm -f "$test_src" "$test_dst"
            return 0
        fi
    fi
    rm -f "$test_src" "$test_dst"
    warn "Git Bash ne peut pas créer de vrais symlinks."
    warn "Active Developer Mode dans Windows :"
    warn "  Paramètres > Confidentialité & sécurité > Pour les développeurs > ON"
    warn "Puis relance ce script. (Sans ça, les 'liens' seront des copies."
    warn " Les modifs dans ~/ ne remonteront PAS vers le repo → auto-sync cassé.)"
    return 1
}

# ---- Créer un symlink de façon sûre ------------------------
# link_to <target_dans_repo> <chemin_dans_home>
link_to() {
    local target="$1" dest="$2"
    local parent
    parent=$(dirname "$dest")

    [ -d "$parent" ] || {
        $DRY_RUN || mkdir -p "$parent"
        info "mkdir -p $parent"
    }

    # Déjà le bon lien ?
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$target" ]; then
        ok "OK  $dest -> $target"
        return 0
    fi

    # Fichier/lien existe, à déplacer
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        if $FORCE; then
            local backup="${dest}.backup-$(date +%Y%m%d-%H%M%S)"
            $DRY_RUN || mv "$dest" "$backup"
            warn "Déplacé $dest → $backup"
        else
            warn "Existe déjà : $dest (utilise --force pour écraser, backup auto)"
            return 1
        fi
    fi

    if $DRY_RUN; then
        info "[dry-run] ln -s $target $dest"
    else
        MSYS=winsymlinks:nativestrict ln -s "$target" "$dest"
        ok "Lien  $dest -> $target"
    fi
}

# ============================================================
#                       INSTALLATION
# ============================================================

printf '\n%sInstallation des dotfiles depuis :%s %s\n\n' "$C_B" "$C_R" "$REPO_DIR"

# 1. Check prérequis
check_symlinks_windows || die "Symlinks indisponibles. Abandon."

# 2. Liens vers $HOME
link_to "$REPO_DIR/git/.gitconfig"       "$HOME/.gitconfig"

# 3. Liens vers ~/.config/git/
link_to "$REPO_DIR/git/bin"              "$HOME/.config/git/bin"
link_to "$REPO_DIR/git/lib"              "$HOME/.config/git/lib"
link_to "$REPO_DIR/git/bashrc-git.sh"    "$HOME/.config/git/bashrc-git.sh"

# 4. Permissions exécutables (au cas où le clone les aurait perdues)
if ! $DRY_RUN; then
    chmod +x "$REPO_DIR/git/bin/"git-* 2>/dev/null || true
    chmod +x "$REPO_DIR/git/bashrc-git.sh" 2>/dev/null || true
    chmod +x "$REPO_DIR/git/lib/"*.sh 2>/dev/null || true
fi

# 5. Ajout du fragment .bashrc
if ! $NO_BASHRC; then
    BASHRC="$HOME/.bashrc"
    MARKER_START="# >>> dotfiles (managed by ~/.projects/dotfiles/install.sh) >>>"
    MARKER_END="# <<< dotfiles <<<"
    SRC_LINE="[ -f \"$REPO_DIR/bash/bashrc-extra.sh\" ] && source \"$REPO_DIR/bash/bashrc-extra.sh\""

    if [ ! -f "$BASHRC" ]; then
        $DRY_RUN || touch "$BASHRC"
        info "Créé $BASHRC"
    fi

    if grep -qF "$MARKER_START" "$BASHRC" 2>/dev/null; then
        ok "Fragment déjà présent dans $BASHRC"
    else
        if $DRY_RUN; then
            info "[dry-run] Ajoutera le fragment à $BASHRC"
        else
            {
                echo ""
                echo "$MARKER_START"
                echo "$SRC_LINE"
                echo "$MARKER_END"
            } >> "$BASHRC"
            ok "Fragment ajouté à $BASHRC"
        fi
    fi
fi

# 6. Smoke test
if ! $DRY_RUN; then
    if [ -L "$HOME/.gitconfig" ]; then
        if git config --get user.email >/dev/null 2>&1; then
            ok "git config accessible (user.email OK)"
        else
            warn "git config ne retourne pas user.email — vérifier manuellement"
        fi
    fi
fi

printf '\n%sInstallation terminée.%s\n\n' "$C_G" "$C_R"
cat <<EOF
Prochaines étapes :

1. Recharger le shell :          source ~/.bashrc

2. (Windows) Activer la sync auto planifiée :
     powershell -ExecutionPolicy Bypass \\
       -File "$REPO_DIR/windows/Register-AutoSyncTask.ps1"

3. Tester la sync manuelle :     git dsync --no-push
                                 git dsync

4. Désinstaller plus tard :      ./uninstall.sh
EOF
