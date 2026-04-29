# dotfiles

Configuration personnelle versionnée : `.gitconfig`, alias git, scripts
worktree, fragments bash. Synchronisation automatique entre plusieurs PC
via GitHub.

## Contenu

```
dotfiles/
├── README.md                         ← ce fichier
├── bootstrap.sh                      ← setup premier usage
├── install.sh                        ← (ré)création des symlinks
├── uninstall.sh                      ← retrait propre
├── git/
│   ├── .gitconfig                    ← config git principale
│   ├── bashrc-git.sh                 ← shell functions (wsw, wgo…)
│   ├── bin/                          ← scripts externes `git-*`
│   │   ├── git-wadd, git-wnew, git-wswitch, git-wgo, git-wstatus,
│   │   ├── git-wclean, git-wremove     ← workflow worktree
│   │   ├── git-dsync                   ← sync auto du repo dotfiles
│   │   ├── git-iswitch, git-rebase-source, git-cpick-move, …
│   │   └── …  (~35 scripts)
│   └── lib/
│       └── wt-common.sh              ← helpers partagés
├── bash/
│   └── bashrc-extra.sh               ← fragment ajouté à ~/.bashrc
└── windows/
    ├── Register-AutoSyncTask.ps1     ← enregistre la sync Task Scheduler
    └── Unregister-AutoSyncTask.ps1
```

---

## Prérequis

- **Git** (Git for Windows pour Windows)
- **Bash** (Git Bash sur Windows suffit)
- **GitHub credentials configurés** : Git Credential Manager (fourni avec
  Git for Windows récent) ou clé SSH. Sans ça, l'auto-push échouera
  silencieusement — les commits resteront locaux.
- **Developer Mode activé sur Windows** (indispensable pour les vrais
  symlinks depuis Git Bash) :
  Paramètres → Confidentialité et sécurité → Pour les développeurs → ON.

---

## Première installation (machine vierge)

### 1. Fork ou clone ce repo

Ce repo peut être **public** — il ne contient aucune donnée personnelle.
L'identité git (nom, email) est configurée séparément dans `~/.gitconfig.local`
ou dans un repo privé `dotfiles-config` (voir étape 6).

```bash
# Option 1 : Fork sur GitHub puis clone ton fork
git clone git@github.com:<TON_USER>/dotfiles.git ~/.projects/dotfiles

# Option 2 : Clone direct + nouveau remote
git clone https://github.com/ORIGINAL_USER/dotfiles.git ~/.projects/dotfiles
cd ~/.projects/dotfiles
git remote set-url origin git@github.com:<TON_USER>/dotfiles.git
```

### 2. Lance l'installation

```bash
cd ~/.projects/dotfiles
./install.sh
```

Ce que ça fait :

- Vérifie que Git Bash peut créer des symlinks (Developer Mode).
- Backup `~/.gitconfig` existant en `~/.gitconfig.backup-YYYYMMDD-HHMMSS`.
- Crée les symlinks :
  - `~/.gitconfig` → `~/.projects/dotfiles/git/.gitconfig`
  - `~/.config/git/bin` → `~/.projects/dotfiles/git/bin`
  - `~/.config/git/lib` → `~/.projects/dotfiles/git/lib`
  - `~/.config/git/bashrc-git.sh` → `~/.projects/dotfiles/git/bashrc-git.sh`
- Ajoute un bloc dans `~/.bashrc` (entre markers, ré-entrant) qui source
  `~/.projects/dotfiles/bash/bashrc-extra.sh`. Ce fragment ajoute le PATH,
  charge les shell functions, et installe un trap EXIT pour
  synchroniser à la fermeture du terminal.

### 3. Recharge le shell

```bash
source ~/.bashrc
```

Vérifie :

```bash
git aliases          # liste tous les alias
git wst              # (dans un repo) dashboard worktrees
which git-dsync      # => ~/.config/git/bin/git-dsync
```

### 4. Active la sync automatique planifiée (Windows)

```powershell
powershell -ExecutionPolicy Bypass `
  -File ~\.projects\dotfiles\windows\Register-AutoSyncTask.ps1
```

Ça crée une tâche planifiée :

| Nom                      | Déclencheur                |
| ------------------------ | -------------------------- |
| `DotfilesAutoSync-Timer` | Chaque jour à 12 h et 17 h |

La tâche exécute `bash -lc 'git dsync --quiet'`. Les logs sont dans
`~/.dotfiles-sync.log`.

En plus, le **fragment bashrc installe un trap EXIT** qui lance
`git dsync --quiet` en arrière-plan à la fermeture de chaque terminal
interactif. Double filet.

### 5. Configure ton identité git

Le `.gitconfig` ne contient pas d'identité par défaut. Tu dois la configurer :

#### Option A : Config locale simple (recommandé pour débuter)

```bash
cp ~/.projects/dotfiles/git/gitconfig.local.template ~/.gitconfig.local
# Édite ~/.gitconfig.local avec ton nom et email
```

#### Option B : Config privée versionnée (pour synchroniser entre machines)

Crée un repo privé `dotfiles-config` :

```bash
mkdir -p ~/.projects/dotfiles-config
cd ~/.projects/dotfiles-config
git init
cp ~/.projects/dotfiles/git/gitconfig.local.template gitconfig.local
# Édite gitconfig.local avec ton nom et email
git add -A && git commit -m "init"
git remote add origin git@github.com:<TON_USER>/dotfiles-config.git
git push -u origin main
```

Ce repo sera **synchronisé automatiquement** avec dotfiles (mêmes tâches
planifiées, même trap EXIT).

Sur une autre machine, après avoir installé dotfiles :

```bash
git clone git@github.com:<TON_USER>/dotfiles-config.git ~/.projects/dotfiles-config
source ~/.bashrc  # recharge pour détecter le repo
```

---

## Installation sur une machine supplémentaire

### One-liner via clone puis bootstrap

```bash
git clone git@github.com:<TON_USER>/dotfiles.git ~/.projects/dotfiles
~/.projects/dotfiles/bootstrap.sh
```

Puis la même étape 4 (`source ~/.bashrc`) et étape 5 (sync Windows) que
la première machine. `bootstrap.sh` est idempotent et peut être relancé
sans danger.

---

## Workflow quotidien

### Tu modifies un script ou un alias

Tu édites directement le fichier sous `~/.projects/dotfiles/git/bin/`
(ou via le symlink dans `~/.config/git/bin/`, c'est pareil). Les
modifications sont **immédiatement actives** — pas de "réinstallation"
nécessaire.

### Tu veux pousser maintenant

```bash
git dsync                # commit + rebase + push
git dsync --no-push      # commit local seulement
git dsync --quiet        # mode tâche planifiée
```

### Tu veux voir l'activité

```bash
tail -f ~/.dotfiles-sync.log
```

### Tu veux synchroniser depuis un autre PC (tu as pushé depuis PC-A, tu es sur PC-B)

La tâche planifiée sur PC-B appelle `git dsync` deux fois par jour
(12 h et 17 h), qui fait un `git fetch + rebase --autostash` avant de
push. Donc PC-B se met à jour régulièrement. Pour forcer :

```bash
cd ~/.projects/dotfiles && git pull --rebase
```

### Tu as un conflit entre PC

Ça peut arriver si tu édites la même ligne sur deux PC sans sync entre
les deux. `git dsync` log alors un message d'erreur clair et interrompt
la sync. Résolution manuelle :

```bash
cd ~/.projects/dotfiles
git pull --rebase
# résous les conflits, git add, git rebase --continue
git push
```

Le cas est rare en pratique : les pushs sont fréquents (tâche planifiée

- trap EXIT), donc la fenêtre de divergence est courte.

---

## Désinstaller

### Juste les tâches Windows (garder les symlinks)

```powershell
powershell -ExecutionPolicy Bypass `
  -File ~\.projects\dotfiles\windows\Unregister-AutoSyncTask.ps1
```

### Tout retirer

```bash
cd ~/.projects/dotfiles && ./uninstall.sh
```

Restaure automatiquement le dernier `.backup-*` de `~/.gitconfig` si présent.

---

## Dépannage

### "L'auto-push ne marche pas"

Vérifier les credentials git :

```bash
cd ~/.projects/dotfiles
git push                 # doit marcher sans demande de mot de passe
```

Si une demande apparaît :

- **SSH** : vérifie `ssh -T git@github.com`, ajoute ta clé à l'agent.
- **HTTPS** : Git Credential Manager doit être installé
  (`git config --global credential.helper` doit afficher `manager` ou
  `manager-core`). Sinon installer Git for Windows récent.

### "Les symlinks ne marchent pas (ce sont des copies)"

Developer Mode pas activé. Paramètres Windows → Confidentialité et
sécurité → Pour les développeurs → ON. Puis relance `install.sh --force`.

### "La tâche planifiée 'DotfilesAutoSync-Timer' ne tourne pas"

Ouvre `taskschd.msc`, trouve la tâche, onglet **Historique**. Causes
fréquentes :

- Le chemin de `bash.exe` n'est pas bon → relance
  `Register-AutoSyncTask.ps1 -BashPath "C:\..."`.
- La session est verrouillée et la tâche est sur "Run only when user is
  logged on" → c'est normal, elle reprend au déverrouillage.

### "git dsync reste coincé sur un rebase"

```bash
cd ~/.projects/dotfiles
git rebase --abort   # ou --continue après résolution
git dsync
```

---

## Limites connues

- **Coupure de courant brutale** : si tu débranches le PC sans shutdown,
  le dernier commit potentiellement non-pushé est perdu (reste local au
  prochain boot, re-pushé au premier `git dsync`). Acceptable en pratique
  vu la fréquence de sync (tâche planifiée + trap EXIT).
- **Credentials spécifiques à une machine** : ne mets pas de secrets dans
  ce repo. Le `.gitconfig` ne contient que nom/email/alias ; pas de PAT
  ni de token.
- **Conflits entre PC** : résolution manuelle, comme décrit plus haut.

---

## Personnalisation par machine

Si tu as des alias ou une config que tu veux uniquement sur cette
machine (pas versionné), utilise la directive `include` de git :

```ini
# Dans git/.gitconfig (versionné)
[include]
    path = ~/.gitconfig.local
```

Et mets tout ce qui est spécifique à la machine dans `~/.gitconfig.local`
(qui n'est pas versionné). Git le charge en plus.
