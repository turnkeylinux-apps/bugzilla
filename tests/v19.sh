#!/bin/bash
set -Eeuo pipefail
umask 077

result=${TKL_TEST_RESULT:?TKL_TEST_RESULT is required}
app_password=${TKL_TEST_APP_PASS:?TKL_TEST_APP_PASS is required}
db_password=${TKL_TEST_DB_PASS:?TKL_TEST_DB_PASS is required}
base=https://localhost
admin_email=admin@example.invalid
response=/tmp/tkl-bugzilla-response.$$
payload=/tmp/tkl-bugzilla-payload.$$
policy=/tmp/tkl-bugzilla-policy.$$
cookies=/tmp/tkl-bugzilla-adminer-cookies.$$

cleanup() {
    rm -f -- "$response" "$payload" "$policy" "$cookies"
}
trap cleanup EXIT
trap 'printf "test_failure line=%s status=%s command=%q\n" "$LINENO" "$?" "$BASH_COMMAND" >&2' ERR

systemctl --quiet is-active apache2.service mariadb.service postfix.service \
    cron.service multi-user.target
systemctl --quiet is-enabled apache2.service mariadb.service postfix.service \
    cron.service
apache2ctl -t

bugzilla_commit=$(git -C /var/www/bugzilla rev-parse HEAD)
test "$bugzilla_commit" = 5756ec67b506c20ff4b2c32d80e6fcf35e536b76
test "$(git -C /var/www/bugzilla branch --show-current)" = 5.2
test "$(git -C /var/www/bugzilla remote get-url origin)" = \
    https://github.com/bugzilla/bugzilla.git
test "$(perl -MTemplate -e 'print $Template::VERSION')" = 3.106
test "$(perl -MDBD::MariaDB -e 'print $DBD::MariaDB::VERSION')" != ""
grep -Eq "^\$db_driver[[:space:]]*=[[:space:]]*'mariadb';" \
    /var/www/bugzilla/localconfig

curl --insecure --fail --silent --show-error "$base/" >"$response"
grep -qi '<title>.*Bugzilla' "$response"

curl --insecure --fail --silent --show-error \
    --get --data-urlencode "login=$admin_email" \
    --data-urlencode "password=$app_password" \
    "$base/rest/login" >"$response"
token=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])' <"$response")
test -n "$token"

cat >"$payload" <<EOF
{"product":"TestProduct","component":"TestComponent","version":"unspecified","summary":"TurnKey v19 acceptance bug","description":"Created through the Bugzilla REST API","token":"$token"}
EOF
curl --insecure --fail --silent --show-error \
    -H 'Content-Type: application/json' --data-binary @"$payload" \
    "$base/rest/bug" >"$response"
bug_id=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <"$response")
test "$bug_id" -gt 0

curl --insecure --fail --silent --show-error \
    "$base/rest/bug/$bug_id?token=$token" >"$response"
python3 - "$bug_id" "$response" <<'PYTHON'
import json
import sys

bug_id = int(sys.argv[1])
with open(sys.argv[2], encoding='utf-8') as stream:
    data = json.load(stream)
bug = data['bugs'][0]
assert bug['id'] == bug_id
assert bug['summary'] == 'TurnKey v19 acceptance bug'
PYTHON
mariadb --batch --skip-column-names bugzilla --execute \
    "SELECT short_desc FROM bugs WHERE bug_id=$bug_id" | \
    grep -Fxq 'TurnKey v19 acceptance bug'
systemctl restart mariadb.service
curl --insecure --fail --silent --show-error \
    "$base/rest/bug/$bug_id?token=$token" >"$response"
grep -q 'TurnKey v19 acceptance bug' "$response"

test "$(postconf -h inet_interfaces)" = localhost
ss -ltn | awk '$4 ~ /^(127\.0\.0\.1|\[::1\]):25$/ { found=1 } END { exit !found }'
python3 - <<'PYTHON'
import json

with open('/var/www/bugzilla/data/params.json', encoding='utf-8') as stream:
    params = json.load(stream)
assert params['mailfrom'] == 'bugzilla-daemon@example.com'
assert params['mail_delivery_method'] == 'Sendmail'
PYTHON

crontab -u root -l | grep -Fq './collectstats.pl'
crontab -u root -l | grep -Fq './whineatnews.pl'
crontab -u root -l | grep -Fq './whine.pl'
test -x /var/www/bugzilla/collectstats.pl
test -x /var/www/bugzilla/whine.pl

dpkg-query -W adminer webmin-apache webmin-mysql webmin-postfix >/dev/null
curl --insecure --fail --silent --show-error \
    https://127.0.0.1:12322/ >"$response"
grep -qi 'Adminer' "$response"
curl --insecure --silent --show-error --location \
    --cookie-jar "$cookies" --cookie "$cookies" \
    --data-urlencode 'auth[driver]=server' \
    --data-urlencode 'auth[server]=localhost' \
    --data-urlencode 'auth[username]=adminer' \
    --data-urlencode "auth[password]=$db_password" \
    --data-urlencode 'auth[db]=bugzilla' \
    https://127.0.0.1:12322/ >"$response"
grep -qi 'bugzilla' "$response"
grep -qi 'Logout' "$response"
curl --insecure --fail --silent --show-error --head \
    https://127.0.0.1:12321/ >/dev/null

git -C /var/www/bugzilla fetch --quiet origin 5.2
candidate=$(git -C /var/www/bugzilla rev-parse FETCH_HEAD)
git -C /var/www/bugzilla merge-base --is-ancestor \
    "$bugzilla_commit" "$candidate"
/var/www/bugzilla/checksetup.pl --check-modules \
    >"$response"
grep -q 'COMMANDS TO INSTALL' "$response"
test "$(git -C /var/www/bugzilla rev-parse HEAD)" = \
    "$bugzilla_commit"

apache_version=$(dpkg-query -W -f='${Version}' apache2)
mariadb_version=$(dpkg-query -W -f='${Version}' mariadb-server)
adminer_version=$(dpkg-query -W -f='${Version}' adminer)
before="$apache_version|$mariadb_version|$adminer_version"
apt-get update >/dev/null
for package in apache2 mariadb-server adminer libdbd-mariadb-perl; do
    apt-cache policy "$package" >"$policy"
    candidate_version=$(awk '/Candidate:/ {print $2}' "$policy")
    test -n "$candidate_version"
    test "$candidate_version" != '(none)'
    grep -Eq 'trixie|deb13' "$policy"
done
after="$(dpkg-query -W -f='${Version}' apache2)|$(dpkg-query -W -f='${Version}' mariadb-server)|$(dpkg-query -W -f='${Version}' adminer)"
test "$after" = "$before"
grep -Rqs '^Suites: trixie' /etc/apt/sources.list.d
! grep -Rqi bookworm /etc/apt/sources.list.d

cat >"$result" <<EOF
package_source=Debian 13 Trixie APT repositories for Apache, MariaDB, Postfix, Adminer and Perl dependencies; pinned official Bugzilla 5.2 Git commit and Template Toolkit CPAN release
installed_version=bugzilla 5.2 commit $bugzilla_commit; Template Toolkit 3.106; apache2 $apache_version; mariadb-server $mariadb_version; adminer $adminer_version
runtime_checks=normal init; Apache HTTPS; Bugzilla administrator REST login; bug create and read with MariaDB readback and service restart; Postfix loopback and mail settings; cron; Adminer authenticated database view; Webmin endpoint
updater_command=apt-get update and apt-cache policy for Debian packages; git fetch origin 5.2 and checksetup.pl --check-modules for Bugzilla
updater_result=signed Debian metadata refreshed with installed packages unchanged; upstream 5.2 candidate $candidate descends from installed commit; current checksetup module replay passed without changing source
updater_channel=Debian and TurnKey Trixie APT repositories; official Bugzilla 5.2 Git branch
integrity_evidence=APT accepted signed repository metadata; Bugzilla initial commit pinned to $bugzilla_commit; Template Toolkit 3.106 download pinned by SHA-256; no Bookworm source remained
EOF
