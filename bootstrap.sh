#!/usr/bin/env bash
# bootstrap.sh
#   Installation complète sur un nouveau PC :
#     1. Vérifie les prérequis (git, bash)
#     2. Clone ce repo dans $HOME/.projects/dotfiles si besoin
#     3. Lance install.sh
#     4. Configure l'identité git (nom, email)
#     5. Propose de créer dotfiles-config pour versionner l'identité
#     6. Affiche les instructions pour la sync auto Windows
#
#   Usage :
#     # Option A : clone manuel puis bootstrap
#     git clone git@github.com:<user>/dotfiles.git ~/.projects/dotfiles
#     ~/.projects/dotfiles/bootstrap.sh
#
#     # Option B : one-liner
#     bash <(curl -fsSL https://raw.githubusercontent.com/<user>/dotfiles/main/bootstrap.sh)

set -euo pipefail

REPO_URL_DEFAULT="${DOTFILES_REPO:-}"
TARGET_DIR="${DOTFILES_DIR:-$HOME/.projects/dotfiles}"
CONFIG_DIR="${DOTFILES_CONFIG_DIR:-$HOME/.projects/dotfiles-config}"
BRANCH="${DOTFILES_BRANCH:-main}"

if [ -t 1 ]; then
    C_R=$'\033[0m'; C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_BL=$'\033[34m'; C_R2=$'\033[31m'
else
    C_R=''; C_B=''; C_G=''; C_Y=''; C_BL=''; C_R2=''
fi
info()  { printf '%s→%s %s\n' "$C_BL" "$C_R" "$*"; }
ok()    { printf '%s✓%s %s\n' "$C_G"  "$C_R" "$*"; }
warn()  { printf '%s!%s %s\n' "$C_Y"  "$C_R" "$*" >&2; }
die()   { printf '%s✗%s %s\n' "$C_R2" "$C_R" "$*" >&2; exit 1; }
ask()   { printf '%s?%s %s ' "$C_B" "$C_R" "$1"; }

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
            ask "URL du repo dotfiles :"
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

# ============================================================
#                 CONFIGURATION DE L'IDENTITÉ
# ============================================================
echo
printf '%s%s Configuration de l'\''identité git %s\n\n' "$C_B" "📋" "$C_R"

# Vérifie si une identité est déjà configurée
CURRENT_NAME=$(git config --global user.name 2>/dev/null || true)
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || true)

if [ -n "$CURRENT_NAME" ] && [ -n "$CURRENT_EMAIL" ]; then
    ok "Identité déjà configurée : $CURRENT_NAME <$CURRENT_EMAIL>"
    ask "Garder cette identité ? [O/n]"
    read -r KEEP_IDENTITY
    KEEP_IDENTITY=${KEEP_IDENTITY:-O}
    if [[ "$KEEP_IDENTITY" =~ ^[Oo]$ ]]; then
        info "Identité conservée."
    else
        CURRENT_NAME=""
        CURRENT_EMAIL=""
    fi
fi

# Demande l'identité si pas configurée
if [ -z "$CURRENT_NAME" ] || [ -z "$CURRENT_EMAIL" ]; then
    echo "L'identité git (nom + email) n'est pas configurée."
    echo "Elle sera utilisée pour tous tes commits."
    echo
    
    ask "Ton nom complet (ex: Jean Dupont) :"
    read -r USER_NAME
    [ -z "$USER_NAME" ] && die "Nom requis."
    
    ask "Ton email git (ex: jean.dupont@example.com) :"
    read -r USER_EMAIL
    [ -z "$USER_EMAIL" ] && die "Email requis."
    
    CURRENT_NAME="$USER_NAME"
    CURRENT_EMAIL="$USER_EMAIL"
fi

# ============================================================
#           CHOIX DU MODE DE STOCKAGE DE L'IDENTITÉ
# ============================================================
echo
printf '%s%s Où stocker ton identité ? %s\n\n' "$C_B" "💾" "$C_R"
echo "  1) ~/.gitconfig.local        (fichier local, non versionné)"
echo "  2) dotfiles-config           (repo privé, synchronisé entre machines)"
echo
ask "Choix [1/2] :"
read -r IDENTITY_CHOICE
IDENTITY_CHOICE=${IDENTITY_CHOICE:-1}

case "$IDENTITY_CHOICE" in
    2)
        # --- Option 2 : dotfiles-config ---
        info "Configuration via dotfiles-config"
        
        if [ -d "$CONFIG_DIR/.git" ]; then
            ok "dotfiles-config déjà présent : $CONFIG_DIR"
        else
            echo
            echo "Tu peux créer un nouveau repo ou cloner un existant."
            ask "As-tu déjà un repo dotfiles-config sur GitHub ? [o/N]"
            read -r HAS_CONFIG_REPO
            HAS_CONFIG_REPO=${HAS_CONFIG_REPO:-N}
            
            if [[ "$HAS_CONFIG_REPO" =~ ^[Oo]$ ]]; then
                ask "URL du repo dotfiles-config :"
                read -r CONFIG_REPO_URL
                [ -z "$CONFIG_REPO_URL" ] && die "URL requise."
                info "Clone $CONFIG_REPO_URL → $CONFIG_DIR"
                git clone "$CONFIG_REPO_URL" "$CONFIG_DIR"
            else
                info "Création de $CONFIG_DIR"
                mkdir -p "$CONFIG_DIR"
                cd "$CONFIG_DIR"
                git init
                
                # Crée le fichier gitconfig.local
                cat > gitconfig.local <<EOF
; ============================================================
;  Configuration personnelle — dotfiles-config
;
;  Ce fichier est inclus automatiquement par git/.gitconfig
;  Synchronisé automatiquement par git-dsync
; ============================================================

[user]
	name  = $CURRENT_NAME
	email = $CURRENT_EMAIL

; --- Optionnel : Signing ---
; [commit]
; 	gpgsign = true
; [user]
; 	signingKey = ~/.ssh/id_ed25519.pub

; --- Optionnel : Credential helper spécifique ---
; [credential]
; 	helper = manager

; --- Optionnel : Email pro conditionnel (par dossier) ---
; [includeIf "gitdir:~/work/"]
; 	path = ~/.gitconfig.work
EOF
                
                git add -A
                git commit -m "init: personal identity"
                ok "Repo local créé avec ton identité"
                
                echo
                echo "Pour synchroniser entre machines, ajoute un remote GitHub :"
                echo "  cd $CONFIG_DIR"
                echo "  git remote add origin git@github.com:<TON_USER>/dotfiles-config.git"
                echo "  git push -u origin main"
            fi
        fi
        
        # Vérifie que le fichier existe
        if [ ! -f "$CONFIG_DIR/gitconfig.local" ]; then
            warn "Fichier $CONFIG_DIR/gitconfig.local introuvable."
            warn "Crée-le manuellement à partir de $REPO_DIR/git/gitconfig.local.template"
        fi
        ;;
        
    *)
        # --- Option 1 : ~/.gitconfig.local ---
        info "Configuration via ~/.gitconfig.local"
        
        LOCAL_CONFIG="$HOME/.gitconfig.local"
        if [ -f "$LOCAL_CONFIG" ]; then
            ok "$LOCAL_CONFIG existe déjà"
            ask "Écraser avec la nouvelle identité ? [o/N]"
            read -r OVERWRITE
            OVERWRITE=${OVERWRITE:-N}
            [[ "$OVERWRITE" =~ ^[Oo]$ ]] || info "Fichier conservé."
        else
            OVERWRITE="O"
        fi
        
        if [[ "$OVERWRITE" =~ ^[Oo]$ ]]; then
            cat > "$LOCAL_CONFIG" <<EOF
; ============================================================
;  Configuration locale — ~/.gitconfig.local
;
;  Ce fichier est inclus automatiquement par git/.gitconfig
;  Non versionné (gitignore par défaut)
; ============================================================

[user]
	name  = $CURRENT_NAME
	email = $CURRENT_EMAIL

; --- Optionnel : Signing ---
; [commit]
; 	gpgsign = true
; [user]
; 	signingKey = ~/.ssh/id_ed25519.pub
EOF
            ok "Identité écrite dans $LOCAL_CONFIG"
        fi
        ;;
esac

# ============================================================
#                       MESSAGE FINAL
# ============================================================
echo
ok "Bootstrap terminé !"
echo

# Détection Windows
IS_WINDOWS=false
case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) IS_WINDOWS=true ;;
esac

cat <<EOF
${C_B}Prochaines étapes :${C_R}

1. ${C_G}Recharge ton shell :${C_R}
     source ~/.bashrc

2. ${C_G}Vérifie ton identité :${C_R}
     git config user.name && git config user.email
EOF

if $IS_WINDOWS; then
    cat <<EOF

3. ${C_G}Active la sync automatique Windows :${C_R}

   ${C_Y}Option A — Tâche planifiée (nécessite droits admin) :${C_R}
     # Lance PowerShell en tant qu'administrateur, puis :
     powershell -ExecutionPolicy Bypass \`
       -File "\$env:USERPROFILE\\.projects\\dotfiles\\windows\\Register-AutoSyncTask.ps1"

   ${C_Y}Option B — Sync au démarrage (sans droits admin) :${C_R}
     # PowerShell normal (pas besoin d'admin) :
     powershell -ExecutionPolicy Bypass \`
       -File "\$env:USERPROFILE\\.projects\\dotfiles\\windows\\Setup-StartupSync.ps1"

EOF
fi

cat <<EOF
${C_B}Test rapide :${C_R}
     cd "$REPO_DIR"
     git dsync --no-push   # test local
     git dsync             # commit + push

EOF
