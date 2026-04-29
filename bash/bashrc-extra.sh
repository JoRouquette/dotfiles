# ============================================================
# ~/.projects/dotfiles/bash/bashrc-extra.sh
# Fragment sourcé par ~/.bashrc.
# Ajouté automatiquement par `install.sh` avec un marker pour
# pouvoir être détecté/mis à jour.
# ============================================================

# Dossier racine du repo dotfiles (utilisé par git-dsync)
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.projects/dotfiles}"

# Config privée versionnée (optionnel, pour git-dsync multi-repo)
export DOTFILES_CONFIG_DIR="${DOTFILES_CONFIG_DIR:-$HOME/.projects/dotfiles-config}"

# Liste des repos à synchroniser automatiquement (séparés par |)
# Inclut dotfiles-config s'il existe
if [ -d "$DOTFILES_CONFIG_DIR/.git" ]; then
    export DOTFILES_SYNC_REPOS="${DOTFILES_SYNC_REPOS:-$DOTFILES_DIR|$DOTFILES_CONFIG_DIR}"
else
    export DOTFILES_SYNC_REPOS="${DOTFILES_SYNC_REPOS:-$DOTFILES_DIR}"
fi

# Scripts git-* externes sur le PATH
case ":$PATH:" in
    *":$HOME/.config/git/bin:"*) ;;
    *) export PATH="$HOME/.config/git/bin:$PATH" ;;
esac

# Shell functions worktree (wsw, wgo, wadd, wnew, wroot)
[ -f "$HOME/.config/git/bashrc-git.sh" ] && source "$HOME/.config/git/bashrc-git.sh"

# --- Sync dotfiles à la fermeture du terminal ---------------
# Lancé en arrière-plan pour ne pas bloquer l'exit.
# Les tâches planifiées Windows font le gros du boulot, ceci
# est juste une sécurité supplémentaire par session bash.
_dotfiles_sync_on_exit() {
    # Skip si pas dans un terminal interactif
    [[ $- == *i* ]] || return 0
    # Skip si le repo n'existe pas (bootstrap pas encore fait)
    [ -d "$DOTFILES_DIR/.git" ] || return 0
    # Lance en détaché, silencieux
    ( git dsync --quiet >/dev/null 2>&1 & disown ) 2>/dev/null
}
trap _dotfiles_sync_on_exit EXIT
