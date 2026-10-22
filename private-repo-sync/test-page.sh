#!/bin/bash
# Renders the settings page in php-cli: valid save writes cfg, injection attempt is rejected.
set -e
cd "$(dirname "$0")"
t=$(mktemp -d); sed '1,/^---$/d' private-repo-sync.page > "$t/page.php"
printf '#!/bin/bash\necho script-ran "$@"\n' > "$t/s.sh"; chmod +x "$t/s.sh"
run() { CA_CFG="$t/cfg" CA_SCRIPT="$t/s.sh" ${PHP:-php} -r '$var=["csrf_token"=>getenv("TOK")!==false?getenv("TOK"):"tok"]; $_SERVER["REQUEST_METHOD"]="POST"; $_POST=json_decode($argv[1],true); include $argv[2];' "$1" "$t/page.php"; }
run '{"csrf_token":"tok","action":"save","repos":"a/b\nc/d@dev","schedule":"5 * * * *","token":"ghp_x1"}' | grep -q Saved
grep -qx 'REPOS="a/b c/d@dev"' "$t/cfg"; grep -qx 'GITHUB_TOKEN="ghp_x1"' "$t/cfg"
run '{"csrf_token":"tok","action":"save","repos":"a/b\"; rm -rf /; \"","schedule":"5 * * * *"}' | grep -q 'Invalid repo'
run '{"csrf_token":"bad","action":"save","repos":"x/y","schedule":"5 * * * *"}' | grep -q 'Bad CSRF'
grep -qx 'REPOS="a/b c/d@dev"' "$t/cfg"              # rejected posts left cfg untouched
run '{"csrf_token":"tok","action":"sync"}' | grep -q script-ran
TOK= run '{"csrf_token":"","action":"save","repos":"x/y","schedule":"5 * * * *"}' | grep -q 'Bad CSRF'   # empty token must not pass
echo ok
