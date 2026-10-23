#!/bin/sh
# Tests de git-credential-gh-multi et de ghx.
#   sh git/test-git-credential-gh-multi.sh
#
# Hermétiques : map d'exemple et faux gh (jetons factices) dans un dossier temporaire.
# Aucun compte réel, aucun réseau. Tests réels optionnels, avec la config de la machine :
#   GHMULTI_LIVE_REPOS="https://github.com/<o>/<r>.git ..." sh git/test-git-credential-gh-multi.sh
here=$(cd "$(dirname "$0")" && pwd)
h="$here/bin/git-credential-gh-multi"
ghx="$here/bin/ghx"
real_path=$PATH
fails=0
ok() { echo "OK   $1"; }
ko() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

d=$(mktemp -d) || exit 1
trap 'rm -rf "$d"' EXIT
mkdir "$d/bin"
printf 'owner-a acct-a\n# commentaire\nOwner-B acct-b\n' > "$d/map"
printf 'owner-a acct-a\r\nowner-b acct-b\r\n' > "$d/map-crlf"
printf 'owner-a acct-a\nOWNER-A acct-x\n' > "$d/map-dup"
cat > "$d/bin/gh" <<'EOF'
#!/bin/sh
# Faux gh : jeton factice par compte et par hôte (comme gh, l'hôte par défaut
# vient de GH_HOST) ; sinon affiche ce que ghx lui transmet.
if [ "$1 $2" = "auth token" ]; then
    host=${GH_HOST:-github.com} user=
    shift 2
    while [ $# -gt 0 ]; do
        case "$1" in --hostname) host=$2; shift ;; --user) user=$2; shift ;; esac
        shift
    done
    [ "$host" = github.com ] || { echo "tok-autre-hote-$user"; exit 0; }
    case "$user" in acct-a|acct-b) echo "tok-$user"; exit 0 ;; esac
    exit 1
fi
echo "GH_TOKEN=$GH_TOKEN GH_HOST=${GH_HOST-unset}"
EOF
chmod +x "$d/bin/gh"
PATH="$d/bin:$PATH"
export GH_ACCOUNT_MAP="$d/map"
# Isolation de la config git de la machine (insteadOf, credential, etc.).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset GH_REPO GHX_OWNER GIT_CEILING_DIRECTORIES

get() { printf 'protocol=%s\nhost=%s\n%s\n' "$1" "$2" "${3:+path=$3
}" | sh "$h" get; }

# --- resolve -------------------------------------------------------
check "resolve owner-a"             '[ "$(sh "$h" resolve owner-a)" = acct-a ]'
check "resolve sans casse"          '[ "$(sh "$h" resolve OWNER-b)" = acct-b ]'
check "resolve inconnu échoue"      '! sh "$h" resolve inconnu 2>/dev/null'
check "resolve doublon échoue"      '! GH_ACCOUNT_MAP="$d/map-dup" sh "$h" resolve owner-a 2>/dev/null'
check "map absente : message dédié" 'GH_ACCOUNT_MAP="$d/absente" sh "$h" resolve owner-a 2>&1 | grep -q "map illisible"'
check "map en CRLF"                 '[ "$(GH_ACCOUNT_MAP="$d/map-crlf" sh "$h" resolve owner-b)" = acct-b ]'

# --- get -----------------------------------------------------------
out=$(get https github.com owner-a/x.git)
check "get owner-a"                 'echo "$out" | grep -qx username=acct-a && echo "$out" | grep -qx password=tok-acct-a'
out=$(get https github.com owner-b/x.git)
check "get owner-b"                 'echo "$out" | grep -qx username=acct-b'
out=$(GH_HOST=autre.example get https github.com owner-a/x.git)
check "get : GH_HOST hérité sans effet"  'echo "$out" | grep -qx password=tok-acct-a'
out=$(get https github.com inconnu/x.git 2>/dev/null); rc=$?
check "get inconnu : quit=1"        '[ $rc -ne 0 ] && echo "$out" | grep -qx quit=1 && ! echo "$out" | grep -q ^password='
out=$(get https github.com '' 2>/dev/null); rc=$?
check "get sans path : quit=1"      '[ $rc -ne 0 ] && echo "$out" | grep -qx quit=1'
out=$(get https github.com 'owner-a/../owner-b/x.git' 2>/dev/null); rc=$?
check "get path avec .. : quit=1"   '[ $rc -ne 0 ] && echo "$out" | grep -qx quit=1'
out=$(get https gitlab.com owner-a/x.git); rc=$?
check "autre hôte : muet"           '[ $rc -eq 0 ] && [ -z "$out" ]'
out=$(get http github.com owner-a/x.git); rc=$?
check "http en clair : muet"        '[ $rc -eq 0 ] && [ -z "$out" ]'

# --- git credential fill : helper réel et bouchon --------------------
fill() { # helper... ; lit la requête sur stdin
    set -- -c credential.https://github.com.helper= "$@"
    GIT_ASKPASS="$d/askpass" SSH_ASKPASS="$d/askpass" GIT_TERMINAL_PROMPT=0 \
        git -c credential.https://github.com.useHttpPath=true "$@" credential fill
}
printf '#!/bin/sh\ntouch "%s/askpass-appele"\necho x\n' "$d" > "$d/askpass"; chmod +x "$d/askpass"
stub='!f() { echo quit=1; }; f'
out=$(printf 'protocol=https\nhost=github.com\npath=owner-a/x.git\n\n' | fill -c "credential.https://github.com.helper=!sh '$h'" -c "credential.https://github.com.helper=$stub")
check "git credential fill : bon compte" 'echo "$out" | grep -qx username=acct-a'
err=$(printf 'protocol=https\nhost=github.com\npath=owner-a/x.git\n\n' | fill -c 'credential.https://github.com.helper=!sh /introuvable/helper' -c "credential.https://github.com.helper=$stub" 2>&1 >/dev/null); rc=$?
check "bouchon : quit propre, sans askpass" '[ $rc -ne 0 ] && echo "$err" | grep -q "told us to quit" && [ ! -e "$d/askpass-appele" ]'

# --- ghx : le compte suit le propriétaire déclaré ------------------
# repo-b : origin owner-b. repo-fork : origin owner-a, upstream owner-b.
# repo-ghe : origin sur un tenant ghe.com. hors : aucun dépôt.
mkdir "$d/repo-b" "$d/repo-fork" "$d/repo-ghe" "$d/repo-ssh443" "$d/hors"
export GIT_CEILING_DIRECTORIES="$d"
git -C "$d/repo-b" init -q && git -C "$d/repo-b" remote add origin https://github.com/owner-b/r.git
git -C "$d/repo-fork" init -q && git -C "$d/repo-fork" remote add origin https://github.com/owner-a/r.git
git -C "$d/repo-fork" remote add upstream https://github.com/owner-b/r.git
git -C "$d/repo-ghe" init -q && git -C "$d/repo-ghe" remote add origin https://x.ghe.com/owner-b/r.git
git -C "$d/repo-ssh443" init -q && git -C "$d/repo-ssh443" remote add origin ssh://git@ssh.github.com:443/owner-b/r.git
G="sh '$ghx'"
# at <dossier> <commande avec $G> : sortie du faux gh (compte choisi) ; code dans $rc.
at() { out=$(cd "$d/$1" && eval "$2" 2>/dev/null); rc=$?; echo "$out"; }
acct() { at "$1" "$2" | grep -q "GH_TOKEN=tok-$3"; }

check "owner-b dans repo-b"                   'acct repo-b "$G owner-b pr list" acct-b'
check "propriétaire sans casse"               'acct repo-b "$G OWNER-B pr list" acct-b'
check "owner-a hors dépôt"                    'acct hors "$G owner-a pr list" acct-a'
check "-R concordant : remote ignorée"        'acct repo-b "$G owner-a -R owner-a/x pr list" acct-a'
check "--repo= concordant"                    'acct repo-b "$G owner-a --repo=owner-a/x pr list" acct-a'
check "GH_REPO concordant"                    'acct repo-b "GH_REPO=owner-a/x $G owner-a pr list" acct-a'
check "URL concordante hors dépôt"            'acct hors "$G owner-a pr view https://github.com/owner-a/x/pull/1" acct-a'
check "URL www et casse, concordante"         'acct hors "$G owner-a pr view https://WWW.GitHub.com/owner-a/x/pull/1" acct-a'
check "api : remote ignorée"                  'acct repo-b "$G owner-a api repos/owner-a/x" acct-a'
check "api --paginate concordant"             'acct repo-b "$G owner-a api --paginate repos/owner-a/x/issues" acct-a'
check "api placeholder : remote concordante"  "acct repo-b \"\$G owner-b api 'repos/{owner}/{repo}/pulls'\" acct-b"
check "search --owner concordant"             'acct repo-b "$G owner-a search issues --owner owner-a" acct-a'
check "repo list -L 5 owner-a"                'acct repo-b "$G owner-a repo list -L 5 owner-a" acct-a'
check "repo view owner-a/x : remote ignorée"  'acct repo-b "$G owner-a repo view --web owner-a/x" acct-a'
check "-t hors auth accepté (--title)"        'acct repo-b "$G owner-b pr create -t titre" acct-b'
check "valeur auth acceptée"                  'acct repo-b "$G owner-b issue list --label auth --state open" acct-b'
check "auth status accepté"                   'acct repo-b "$G owner-b auth status" acct-b'
check "auth status -a accepté"                'acct repo-b "$G owner-b auth status -a" acct-b'
check "texte avec lien accepté"               'acct repo-b "$G owner-b pr comment 1 -b \"voir https://github.com/owner-a/y\"" acct-b'
check "GH_HOST hérité effacé"                 'at repo-b "GH_HOST=evil.example $G owner-b pr list" | grep -q GH_HOST=unset'
check "ghx : GH_HOST hérité sans effet sur le jeton" 'acct repo-b "GH_HOST=autre.example $G owner-b pr list" acct-b'
check "remote ssh.github.com concordante"   'acct repo-ssh443 "$G owner-b pr list" acct-b'
check "secret -o concordant hors dépôt"     'acct hors "$G owner-a secret list -o owner-a" acct-a'
at repo-b "$G inconnu pr list" >/dev/null
check "propriétaire absent du mapping : échec" '[ $rc -ne 0 ]'

# --- ghx : refus (code 2) ------------------------------------------
while IFS='|' read -r where cmd; do
    [ -z "$cmd" ] && continue
    eval "c=\"$cmd\""   # développe $G une fois ; at() réinterprète ses guillemets
    at "$where" "$c" >/dev/null
    check "refus [$where] : $cmd" '[ $rc -eq 2 ]'
done <<'EOF'
hors|$G
hors|$G -R owner-a/x pr list
repo-b|$G owner-b auth switch
repo-b|$G owner-b auth token
repo-b|$G owner-b auth login
repo-b|$G owner-b auth refresh
repo-b|$G owner-b auth logout
repo-b|$G owner-b auth setup-git
repo-b|$G owner-b -R owner-b/y auth token
repo-b|$G owner-b auth status -t
repo-b|$G owner-b auth status -at
repo-b|$G owner-b auth status -t=true
repo-b|$G owner-b auth status --show-token
repo-b|$G owner-b auth status --show-token=true
repo-b|$G owner-b pr list --show-token
repo-b|$G owner-b api --hostname github.com /
repo-b|$G owner-b -R x.ghe.com/owner-b/r pr list
repo-b|$G owner-b -R gitlab.example/owner-b/r pr list
repo-b|GH_REPO=gitlab.example/owner-b/r $G owner-b pr list
repo-b|$G owner-b repo clone x.ghe.com/owner-b/r
repo-b|$G owner-b pr view https://x.ghe.com/owner-b/r/pull/1
repo-b|$G owner-b pr view https://evil.ghe.com/x@github.com/owner-b/r/pull/1
repo-ghe|$G owner-b pr list
repo-ghe|$G owner-b api user
repo-b|$G owner-a pr list
repo-fork|$G owner-a pr list
hors|$G owner-a -R owner-b/x pr list
hors|$G owner-a --repo=owner-b/x pr list
hors|$G owner-a -Rowner-b/x pr list
hors|GH_REPO=owner-b/x $G owner-a pr list
hors|$G owner-a pr view https://github.com/owner-b/x/pull/1
hors|$G owner-a pr view https://WWW.GitHub.com/owner-b/x/pull/1
hors|$G owner-a pr view --web https://github.com/owner-b/x/pull/1
repo-b|$G owner-a api repos/owner-b/x
repo-b|$G owner-a api --paginate repos/owner-b/x/issues
repo-b|$G owner-a search issues --owner owner-b
hors|$G owner-a secret list --org=owner-b
hors|$G owner-a secret list --org owner-b
hors|$G owner-a secret list -o owner-b
hors|$G owner-a variable list -o=owner-b
hors|$G owner-a ruleset list -oowner-b
repo-b|$G owner-a repo list -L 5 owner-b
hors|$G owner-a repo view --json name owner-b/x
hors|$G owner-a search issues --owner owner-b
hors|$G owner-a api repos/owner-b/x
hors|$G owner-a pr view https://api.github.com/repos/owner-b/x/pulls/1
repo-b|$G owner-a api repos/{owner}/{repo}/pulls
repo-ssh443|$G owner-a pr list
hors|$G owner-a pr view http://github.localhost/owner-a/x/pull/1
repo-b|$G owner-b tk
EOF

# --- Tests réels (optionnels) ----------------------------------------
if [ -n "$GHMULTI_LIVE_REPOS" ]; then
    for url in $GHMULTI_LIVE_REPOS; do
        (PATH=$real_path; unset GH_ACCOUNT_MAP GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM
         GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=0 timeout 30 git ls-remote "$url" HEAD >/dev/null 2>&1); rc=$?
        check "réel : ls-remote $url" '[ $rc -eq 0 ]'
    done
else
    echo "SKIP tests réels (GHMULTI_LIVE_REPOS absent)"
fi

echo "échecs : $fails"
[ $fails -eq 0 ]
