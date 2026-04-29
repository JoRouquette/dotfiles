# dotfiles

Configuration personnelle versionnée : `.gitconfig`, alias git, scripts
worktree, fragments bash. Synchronisation automatique entre plusieurs PC
via GitHub.

---

## TL;DR — Installation complète en 5 minutes

```bash
# 1. Fork ce repo sur GitHub (bouton "Fork" en haut à droite)
#    puis clone TON fork :
git clone git@github.com:<TON_USER>/dotfiles.git ~/.projects/dotfiles
cd ~/.projects/dotfiles

# 2. Lance le bootstrap (installe + configure identité)
./bootstrap.sh

# 3. Recharge le shell
source ~/.bashrc

# 4. (Windows) Active la sync auto — voir section "Sync automatique"
```

> ⚠️ **Fork obligatoire** : Ce repo utilise la sync automatique (`git dsync`)
> qui pousse tes modifications. Tu as besoin de ton propre repo pour ça.

---

## Contenu

```
dotfiles/
├── README.md                         ← ce fichier
├── bootstrap.sh                      ← setup premier usage (install + identité)
├── install.sh                        ← (ré)création des symlinks
├── uninstall.sh                      ← retrait propre
├── git/
│   ├── .gitconfig                    ← config git principale (publique)
│   ├── gitconfig.local.template      ← template pour ton identité
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
    ├── Register-AutoSyncTask.ps1     ← sync planifiée (12h/17h)
    ├── Setup-StartupSync.ps1         ← alternative sans admin
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

## Installation complète (machine vierge)

### Étape 1 : Fork ce repo (obligatoire)

> ⚠️ **Pourquoi forker ?** Ce repo utilise la synchronisation automatique
> (`git dsync`) qui commit et pousse tes modifications. Sans ton propre repo,
> les push échoueront (tu n'as pas les droits sur le repo original).

1. **Fork** ce repo sur GitHub : clique sur le bouton **Fork** en haut à droite
2. **Clone ton fork** (pas l'original) :

```bash
# Remplace <TON_USER> par ton username GitHub
git clone git@github.com:<TON_USER>/dotfiles.git ~/.projects/dotfiles
```

Ce repo est **public** et ne contient aucune donnée personnelle.
L'identité git (nom, email) est configurée séparément (voir étape 2).

### Étape 2 : Lance le bootstrap

```bash
cd ~/.projects/dotfiles
./bootstrap.sh
```

Le script :

- Vérifie les prérequis (git, bash, Developer Mode Windows)
- Crée les symlinks vers `~/.gitconfig`, `~/.config/git/bin`, etc.
- **Te guide pour configurer ton identité git** (nom, email)
- Propose de créer un repo privé `dotfiles-config` pour versionner ton identité

### Étape 3 : Recharge le shell

```bash
source ~/.bashrc
```

Vérifie que tout fonctionne :

```bash
git config user.name   # doit afficher ton nom
git config user.email  # doit afficher ton email
git aliases            # liste tous les alias
which git-dsync        # => ~/.config/git/bin/git-dsync
```

### Étape 4 : Active la sync automatique (Windows)

Voir la section [Synchronisation automatique](#synchronisation-automatique-windows) ci-dessous.

---

## Configuration de l'identité git

Le repo public ne contient **aucune identité**. Tu dois configurer ton nom
et email via l'une des méthodes suivantes :

### Option A : Config locale simple (recommandé pour débuter)

```bash
cp ~/.projects/dotfiles/git/gitconfig.local.template ~/.gitconfig.local
nano ~/.gitconfig.local   # ou code, vim...
# Remplace "Prénom NOM" et "prenom.nom@example.com" par tes vraies valeurs
```

### Option B : Config privée versionnée (synchronisée entre machines)

Crée un repo privé `dotfiles-config` sur GitHub, puis :

```bash
mkdir -p ~/.projects/dotfiles-config
cd ~/.projects/dotfiles-config
git init
cp ~/.projects/dotfiles/git/gitconfig.local.template gitconfig.local
# Édite gitconfig.local avec ton nom et email
git add -A && git commit -m "init: personal identity"
git remote add origin git@github.com:<TON_USER>/dotfiles-config.git
git push -u origin main
```

Ce repo sera **synchronisé automatiquement** avec dotfiles (même tâche
planifiée, même trap EXIT).

**Sur une autre machine**, après avoir installé dotfiles :

```bash
git clone git@github.com:<TON_USER>/dotfiles-config.git ~/.projects/dotfiles-config
source ~/.bashrc   # détecte le repo et configure DOTFILES_SYNC_REPOS
```

### Chaîne d'include

```
git/.gitconfig
  └─→ ~/.projects/dotfiles-config/gitconfig.local  (si existe, versionné privé)
        └─→ ~/.gitconfig.local  (non versionné, override local)
```

---

## Synchronisation automatique (Windows)

Le repo se synchronise automatiquement grâce à :

1. **Trap EXIT** : `git dsync` à chaque fermeture de terminal (toujours actif)
2. **Tâche planifiée** : sync à 12h et 17h (optionnel, nécessite configuration)

### Option 1 : Tâche planifiée (⚠️ Nécessite droits administrateur)

> **Note** : Cette méthode nécessite des droits administrateur pour
> enregistrer une tâche avec le mode "S4U" (Service for User, invisible).
> Si tu n'as pas les droits admin, utilise l'Option 2 ci-dessous.

```powershell
# Ouvre PowerShell en tant qu'administrateur, puis :
powershell -ExecutionPolicy Bypass `
  -File "$env:USERPROFILE\.projects\dotfiles\windows\Register-AutoSyncTask.ps1"
```

Crée une tâche `DotfilesAutoSync-Timer` qui s'exécute à 12h et 17h chaque jour.

### Option 2 : Sync au démarrage Windows (sans droits admin)

Si tu n'as pas les droits administrateur, utilise le script de démarrage :

```powershell
# PowerShell normal (pas besoin d'admin)
powershell -ExecutionPolicy Bypass `
  -File "$env:USERPROFILE\.projects\dotfiles\windows\Setup-StartupSync.ps1"
```

Cette méthode :

- Ajoute un raccourci dans `shell:startup` (exécuté à chaque connexion Windows)
- Lance `git dsync` au démarrage de la session
- Ne nécessite **aucun droit administrateur**
- Fonctionne même sur les postes d'entreprise verrouillés

### Vérifier la sync

```bash
# Logs de sync
tail -f ~/.dotfiles-sync.log

# Sync manuelle
git dsync
git dsync --no-push   # commit local seulement
git dsync --quiet     # mode silencieux
```

---

## Installation sur une autre machine

```bash
# 1. Clone dotfiles
git clone git@github.com:<TON_USER>/dotfiles.git ~/.projects/dotfiles
cd ~/.projects/dotfiles
./bootstrap.sh

# 2. (Optionnel) Clone ta config privée si tu en as une
git clone git@github.com:<TON_USER>/dotfiles-config.git ~/.projects/dotfiles-config

# 3. Recharge
source ~/.bashrc

# 4. Active la sync auto (voir section Synchronisation automatique)
```

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

### Retirer la sync automatique Windows

```powershell
# Tâche planifiée (si installée via Register-AutoSyncTask.ps1)
powershell -ExecutionPolicy Bypass `
  -File ~\.projects\dotfiles\windows\Unregister-AutoSyncTask.ps1

# Raccourci startup (si installé via Setup-StartupSync.ps1)
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\DotfilesSync.lnk" -ErrorAction SilentlyContinue
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

### "La tâche planifiée 'DotfilesAutoSync-Timer' ne s'enregistre pas"

**Cause probable** : droits administrateur requis pour le mode S4U.

**Solutions** :

1. Lance PowerShell **en tant qu'administrateur** et réessaie
2. Ou utilise l'alternative sans admin :
   ```powershell
   powershell -ExecutionPolicy Bypass `
     -File ~\.projects\dotfiles\windows\Setup-StartupSync.ps1
   ```

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
