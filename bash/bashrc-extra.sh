# ============================================================
# <repo dotfiles>/bash/bashrc-extra.sh
# Fragment sourcé par ~/.bashrc.
# Ajouté automatiquement par `install.sh` avec un marker pour
# pouvoir être détecté/mis à jour.
# ============================================================

# Les repos à synchroniser sont déterminés par git-dsync lui-même (le repo
# qui le contient, plus dotfiles-config s'il est voisin). Ce fragment n'exporte
# donc ni DOTFILES_DIR, ni DOTFILES_CONFIG_DIR, ni DOTFILES_SYNC_REPOS : les
# poser à la main reste possible pour forcer d'autres repos.
# _dotfiles_repo ne sert qu'au trap EXIT ci-dessous.
_dotfiles_src="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || realpath "${BASH_SOURCE[0]}" 2>/dev/null || true)"
_dotfiles_repo=""
[ -n "$_dotfiles_src" ] && _dotfiles_repo="$(cd "$(dirname "$_dotfiles_src")/.." && pwd)"
unset _dotfiles_src

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
    [ -d "${DOTFILES_DIR:-$_dotfiles_repo}/.git" ] || return 0
    # Lance en détaché, silencieux
    ( git dsync --quiet >/dev/null 2>&1 & disown ) 2>/dev/null
}
trap _dotfiles_sync_on_exit EXIT
