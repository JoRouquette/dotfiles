# Contribuer à ce repo dotfiles

Ce document décrit les conventions du repo pour qu'un humain ou une IA
puisse ajouter, modifier ou supprimer un script sans casser la
synchronisation entre machines.

---

## 1. Architecture

```
dotfiles/
├── install.sh                    # Crée les symlinks depuis $HOME vers le repo
├── uninstall.sh                  # Retire les symlinks, restaure les backups
├── bootstrap.sh                  # Clone + install.sh (machine vierge)
├── git/
│   ├── .gitconfig                # Config git principale (versionnée, symlinkée vers ~/.gitconfig)
│   ├── bashrc-git.sh             # Shell functions chargées dans le shell interactif (wsw, wgo, wnew, wadd, wroot)
│   ├── bin/                      # Scripts git-* sur le PATH (symlinkés vers ~/.config/git/bin)
│   │   ├── git-wadd              # ┐
│   │   ├── git-wnew              # │ Workflow worktree
│   │   ├── git-wswitch           # │
│   │   ├── git-wgo               # │
│   │   ├── git-wstatus           # │
│   │   ├── git-wclean            # │
│   │   ├── git-wremove           # ┘
│   │   ├── git-dsync             # Sync auto (commit + rebase + push)
│   │   └── ...                   # ~35 scripts au total
│   └── lib/
│       └── wt-common.sh          # Helpers partagés (die, info, confirm, project_root, etc.)
├── bash/
│   └── bashrc-extra.sh           # Fragment injecté dans ~/.bashrc (PATH, source bashrc-git.sh, trap EXIT)
└── windows/
    ├── Register-AutoSyncTask.ps1 # Tâche planifiée Windows (sync à 12h et 17h)
    └── Unregister-AutoSyncTask.ps1
```

Quand tu ajoutes un nouveau script : il va dans `git/bin/`. Quand tu ajoutes un helper interne réutilisable : il va dans `git/lib/wt-common.sh`. Quand tu ajoutes une shell function qui doit modifier le shell appelant (`cd`, variable d'environnement) : elle va dans `git/bashrc-git.sh`.

---

## 2. Conventions de nommage

**Scripts dans `git/bin/`** : préfixe `git-` obligatoire, kebab-case. Git expose automatiquement `git-foo` comme `git foo` tant que le fichier est exécutable et sur le PATH. Exemples : `git-wadd`, `git-dsync`, `git-clone-worktree`.

**Scripts worktree** : préfixe `git-w`. Les sept scripts du workflow sont `git-wadd`, `git-wnew`, `git-wswitch`, `git-wgo`, `git-wstatus`, `git-wclean`, `git-wremove`.

**Helpers internes** : dans `git/lib/`, pas de préfixe `git-`. Sourcés par les scripts, jamais exécutés directement. Aujourd'hui il n'y a que `wt-common.sh`.

**Shell functions** : dans `git/bashrc-git.sh`, nom court sans préfixe (`wsw`, `wgo`, `wnew`, `wadd`, `wroot`). Une function est nécessaire quand le script doit modifier l'état du shell appelant (typiquement `cd`).

---

## 3. Squelette d'un nouveau script `git-*`

Copier ce template, renommer en `git/bin/git-<nom>`, remplir le corps.

```bash
#!/usr/bin/env bash
# git-<nom> [options] <args>
#   Description courte (une phrase).

set -euo pipefail
source "$(dirname "$(readlink -f "$0")")/../lib/wt-common.sh"

usage() {
    cat >&2 <<EOF
Usage : git <nom> [options] <args>

Description plus détaillée si nécessaire.

Options :
  --dry-run   N'effectue rien, affiche seulement.
  -h, --help  Affiche cette aide.
EOF
    exit 0
}

# ---- Arguments -----------------------------------------------
MY_FLAG=false
MY_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)    MY_FLAG=true ;;
        -h|--help)    usage ;;
        -*)           die "Option inconnue : $1" ;;
        *)            MY_ARG="$1" ;;
    esac
    shift
done

[ -z "$MY_ARG" ] && usage

require_git_repo

# ---- Logique principale -------------------------------------

# ...

ok "Terminé."
```

Rendre exécutable : `chmod +x git/bin/git-<nom>`.

Codes de sortie : `die()` sort en 1 (erreur utilisateur). Réserver le code 2 pour une erreur système irrécupérable (binaire manquant, réseau). Ne pas utiliser `exit` directement sauf dans `usage` — passer par `die()` pour avoir un message formaté.

Si le script n'a pas besoin des helpers de `wt-common.sh` (pas de `die`, `confirm`, `project_root`, etc.), le `source` peut être omis. Voir `git-c` ou `git-resume` comme exemples de scripts autonomes.

---

## 4. Squelette d'une nouvelle shell function

Ajouter dans `git/bashrc-git.sh`. Utiliser une function (et pas un script) **uniquement** quand le shell appelant doit être modifié — en pratique : `cd` vers un dossier.

```bash
# myfunc = description courte
myfunc() {
    local out last_line
    out=$(git myscript "$@") || return $?
    # Le script affiche le chemin cible en DERNIÈRE ligne de stdout
    last_line=$(printf '%s' "$out" | tail -n 1)
    [ -d "$last_line" ] && cd "$last_line" && printf '→ %s\n' "$PWD"
}
```

Convention : la function appelle le script `git-*` correspondant, capture stdout, et fait `cd` vers la dernière ligne si c'est un dossier. Toute la logique métier reste dans le script — la function ne fait que le `cd`.

Si une complétion bash est utile, l'ajouter juste après la function (voir `_wgo_complete` comme modèle).

---

## 5. Modifications du `.gitconfig`

Le fichier versionné est `git/.gitconfig`. Il est symlinkée vers `~/.gitconfig` — ne jamais éditer `~/.gitconfig` directement.

**Où ajouter un alias** : dans la section `[alias]`, regroupé par catégorie. Les catégories existantes sont marquées par des commentaires (`# --- Basics ---`, `# --- Worktrees ---`, etc.). Placer le nouvel alias dans la catégorie appropriée, ou en créer une si aucune ne convient.

**Alias inline vs script externe** : si la commande tient en une ligne sans logique conditionnelle, c'est un alias inline. Sinon c'est un script dans `git/bin/`.

```ini
# Alias inline — OK
st = status

# Trop complexe pour un alias — faire un script
# mauvais: montruc = "!f() { if ...; then ...; fi; }; f"
# bon:     montruc = !git-montruc
```

**Ne jamais mettre dans `git/.gitconfig`** :

- Email professionnel ou identité machine-spécifique
- Signing key (`user.signingKey`)
- Credential helper (`credential.helper`)
- Paths absolus spécifiques à une machine

Ces éléments vont dans `~/.gitconfig.local`, chargé via `[include] path = ~/.gitconfig.local` en fin de `git/.gitconfig`. Ce fichier n'est pas versionné.

---

## 6. Tests avant commit

Après toute modification, lancer dans l'ordre :

**Syntaxe bash** de chaque script touché :

```bash
bash -n git/bin/git-monscript
```

**ShellCheck** (si installé) :

```bash
shellcheck git/bin/git-monscript
```

Ignorer SC2155 (`declare and assign separately`) si la variable est immédiatement utilisée en read-only. Ignorer SC1090 (`Can't follow non-constant source`) car le `source wt-common.sh` est résolu dynamiquement.

**`--help` fonctionne** :

```bash
git/bin/git-monscript --help
```

**Test fonctionnel** : lancer le script au moins une fois sur un repo de test (un `git init` temporaire dans `/tmp`).

**Après modification de `git/.gitconfig`** :

```bash
git config --list --file git/.gitconfig
```

Doit retourner la liste sans erreur de parsing.

**Après modification de `wt-common.sh`** :

```bash
bash -n git/lib/wt-common.sh
bash -c 'source git/lib/wt-common.sh'
```

---

## 7. Workflow de commit

Un commit = une intention. "Ajoute git-wprune" et "Corrige typo dans le README" sont deux commits séparés.

Format du message de commit :

```
ligne 1 : verbe impératif, minuscule, < 72 caractères
<ligne vide>
corps optionnel : explique le POURQUOI, pas le QUOI
```

Exemples réels :

```
ajoute git-wprune pour nettoyer les worktrees orphelins
corrige readlink -f manquant sur macOS dans git-wadd
supprime l'alias logout orphelin du .gitconfig
```

Ne jamais `git push --force` sur `main`. Le repo est synchronisé par `git dsync` (rebase + push) sur plusieurs machines. Un force-push crée des divergences qui nécessitent une intervention manuelle sur chaque PC.

---

## 8. Instructions pour assistants IA

Si tu es un LLM (Claude, Copilot, agent quelconque) qui travaille sur ce repo :

**Avant de modifier un script**, lis `git/lib/wt-common.sh`. Les helpers disponibles sont :

- `die "message"` — affiche une erreur formatée et sort en code 1
- `warn "message"` — avertissement sur stderr
- `info "message"` — message informatif sur stderr
- `ok "message"` — confirmation verte sur stderr
- `require_git_repo` — sort en erreur si pas dans un repo git
- `project_root` — retourne le dossier parent du bare repo (layout worktree)
- `sanitize_dirname "feature/HYG-123"` — retourne `feature-HYG-123`
- `worktree_path_for_branch "branch"` — chemin cible d'un worktree
- `find_worktree_by_branch "branch"` — chemin si le worktree existe, code 1 sinon
- `list_all_branches` — toutes les branches (locales + remote), dédoublonnées
- `branch_is_merged "branch" "base"` — code 0 si mergée
- `confirm "Question ?" [y|n]` — demande confirmation interactive
- `pick_from_list "Prompt" item1 item2 ...` — sélection numérotée
- `parse_worktree_list wt_paths wt_branches` — remplit deux tableaux avec les worktrees (chemin, branche), exclut les bare repos

Ne réimplémente pas ces fonctions.

**Avant d'ajouter un alias** dans `git/.gitconfig`, vérifie qu'il n'existe pas déjà. Cherche dans la section `[alias]` du fichier.

**Ne modifie jamais `~/.gitconfig`** directement. Toujours éditer `git/.gitconfig` dans le repo. Le fichier `~/.gitconfig` est un symlink, et certains éditeurs résolvent les symlinks silencieusement.

**Ne committe jamais** `~/.gitconfig.local`, ni quoi que ce soit contenant un email, un token, un PAT, une signing key, ou un path absolu spécifique à une machine (ex : `C:\Users\jonathan\...`).

**Quand on te demande "ajoute une fonctionnalité X"**, la réponse par défaut est :

1. Script `git/bin/git-x` (copié depuis le squelette section 3)
2. Alias court dans `git/.gitconfig` section `[alias]` qui appelle `!git-x`
3. Si le script doit `cd` : ajouter une shell function wrapper dans `git/bashrc-git.sh`
4. `chmod +x git/bin/git-x`
5. Vérifications de la section 6

---

## 9. Anti-patterns

**Ne pas hardcoder un path Windows** dans un script `git/bin/`. Les scripts tournent sous Git Bash, WSL, et potentiellement Linux/macOS. Utiliser `$HOME`, `$REPO_DIR`, ou des détections `uname` si un comportement OS-spécifique est nécessaire. Le dossier `windows/` existe pour le code exclusivement Windows.

**Ne pas créer un script qui modifie le shell appelant.** Un script `git/bin/git-foo` tourne dans un sous-process — il ne peut pas faire `cd`, exporter de variable, ni modifier le prompt du shell parent. Si c'est nécessaire, le script affiche le chemin sur stdout et une shell function dans `bashrc-git.sh` fait le `cd`.

**Ne pas ajouter un dossier au top-level** sans mettre à jour `install.sh` (pour créer les symlinks si nécessaire) et `uninstall.sh` (pour les retirer).

**Ne pas faire dépendre un script `git/bin/` d'un autre script `git/bin/`** directement. Si deux scripts partagent de la logique, cette logique va dans `git/lib/wt-common.sh`. Exception acceptée : un script peut appeler un autre script git via `git <commande>` (pas via `git-<commande>` directement) car c'est l'interface publique.

**Ne pas utiliser `eval`** pour construire des commandes. Utiliser des tableaux bash :

```bash
# mauvais
CMD="dotnet run --project \"$PROJECT\""
eval $CMD

# bon
args=(dotnet run --project "$PROJECT")
"${args[@]}"
```

**Ne pas utiliser `mapfile`** si la portabilité Bash 3.x est visée (macOS stock). Préférer `while IFS= read -r` dans ce cas. Actuellement le repo utilise `mapfile` (Bash 4+) — c'est accepté mais documenté ici.
