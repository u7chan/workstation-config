#!/usr/bin/env bash
# Verify that `update-ai --pi` reports the versions the Safe-chain minimum
# package age holds back, so a deferred update is not mistaken for a current
# installation. The test stubs node, npm, curl, and Pi, and serves a fixture
# registry, so it needs no network and no managed runtime.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
test_bin="$test_dir/bin"
install_log="$test_dir/install.log"
registry="$test_dir/registry.json"
mkdir -p "$HOME/.safe-chain/scripts" "$HOME/.local/bin" "$test_bin"
export PATH="$test_bin:$HOME/.local/bin:$PATH"
export TEST_INSTALL_LOG="$install_log"
export TEST_REGISTRY="$registry"
# Skip the mise re-exec so the stubs on PATH are the whole environment.
export UPDATE_AI_MISE_ACTIVE=1

# update-ai sources the Safe-chain integration. The npm stub below stands in
# for the wrapper that the integration installs.
: >"$HOME/.safe-chain/scripts/init-posix.sh"

cat >"$test_bin/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'npm before=%s args=%s\n' "${npm_config_before:-}" "$*" >>"$TEST_INSTALL_LOG"
case "${1:-}" in
  view)
    jq -c --arg package "${2:?package name is required}" '.[$package]' "$TEST_REGISTRY"
    ;;
  install)
    ;;
  *)
    printf 'unexpected npm command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

cat >"$test_bin/node" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --version ]]; then
  printf 'v24.18.0\n'
  exit 0
fi
printf 'unexpected node command: %s\n' "$*" >&2
exit 1
EOF

cat >"$test_bin/curl" <<'EOF'
#!/usr/bin/env bash
printf 'unexpected curl invocation: %s\n' "$*" >&2
exit 1
EOF

cat >"$test_bin/pi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version)
    printf '1.1.0\n'
    ;;
  list)
    printf 'User packages:\n'
    printf '  %s\n' \
      npm:pi-web-access \
      npm:pi-codex-image-gen \
      npm:@howaboua/pi-codex-conversion \
      npm:@ogulcancelik/pi-session-recall
    ;;
  install|update)
    printf 'pi %s\n' "$*" >>"$TEST_INSTALL_LOG"
    ;;
  *)
    printf 'unexpected pi command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$test_bin/npm" "$test_bin/node" "$test_bin/curl" "$test_bin/pi"

install_pi_package() {
  local package_name=$1
  local version=$2

  mkdir -p -- "$HOME/.pi/agent/npm/node_modules/$package_name"
  jq -n --arg version "$version" '{version: $version}' \
    >"$HOME/.pi/agent/npm/node_modules/$package_name/package.json"
}

install_pi_package pi-web-access 0.38.0
install_pi_package pi-codex-image-gen 0.2.0
install_pi_package @howaboua/pi-codex-conversion 3.0.49
install_pi_package @ogulcancelik/pi-session-recall 1.0.7

# Relative publish times keep the gate decisions deterministic: a version two
# hours old is always inside the 48h gate, and one 100 hours old never is.
now_epoch="$(date +%s)"
recent_published="$(date -u -d "@$((now_epoch - 2 * 3600))" +%Y-%m-%dT%H:%M:%S.000Z)"
aged_published="$(date -u -d "@$((now_epoch - 100 * 3600))" +%Y-%m-%dT%H:%M:%S.000Z)"

jq -n --arg recent "$recent_published" --arg aged "$aged_published" '{
  "@earendil-works/pi-coding-agent": [
    { "dist-tags": { "latest": "1.2.0" }, "time": { "created": $aged, "1.2.0": $recent } }
  ],
  "pi-web-access": [
    { "dist-tags": { "latest": "0.39.0" }, "time": { "0.39.0": $recent } }
  ],
  "pi-codex-image-gen": [
    { "dist-tags": { "latest": "0.2.0" }, "time": { "0.2.0": $aged } }
  ],
  "@howaboua/pi-codex-conversion": [
    { "dist-tags": { "latest": "3.0.52" }, "time": { "3.0.52": $aged } }
  ],
  "@ogulcancelik/pi-session-recall": [
    { "dist-tags": { "latest": "1.0.7" }, "time": { "1.0.7": $aged } }
  ]
}' >"$registry"

fail() {
  printf 'update-ai-age-gate-status: %s\n' "$*" >&2
  exit 1
}

# The installs keep resolving through npm_config_before and Pi, and the status
# block distinguishes current targets from deferred ones.
"$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout.log" 2>"$test_dir/stderr.log"

grep -Fxq '==> Pi versions (Safe-chain minimum package age: 48h)' "$test_dir/stdout.log"
grep -Eq '^npm before=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest$' "$install_log"
grep -Fqx 'pi update npm:pi-web-access --no-approve' "$install_log"
grep -Eq '^pi 1\.1\.0 -> 1\.2\.0 deferred until [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z \(published [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\)$' "$test_dir/stdout.log"
grep -Eq '^npm:pi-web-access 0\.38\.0 -> 0\.39\.0 deferred until ' "$test_dir/stdout.log"
grep -Fxq 'npm:pi-codex-image-gen 0.2.0 (newest allowed version)' "$test_dir/stdout.log"
grep -Fxq 'npm:@ogulcancelik/pi-session-recall 1.0.7 (newest allowed version)' "$test_dir/stdout.log"
if grep -Fq 'registry lookup failed' "$test_dir/stdout.log"; then
  fail 'a served registry fixture must not report a lookup failure.'
fi

# A version that is already past the gate but still not installed means the
# update did not take effect, which must be visible on stderr.
grep -Fxq 'npm:@howaboua/pi-codex-conversion 3.0.49 -> 3.0.52' "$test_dir/stdout.log"
grep -Fxq 'update-ai: npm:@howaboua/pi-codex-conversion 3.0.49 is behind 3.0.52, which is already past the age gate; the update did not take effect' "$test_dir/stderr.log"

# The reported install time is the publish time plus the age gate and the one
# hour of margin that compute_npm_before reserves.
deferred_line="$(grep -m1 -E '^pi 1\.1\.0 -> 1\.2\.0 deferred until ' "$test_dir/stdout.log")"
release_time="$(sed -E 's/^.* deferred until ([^ ]+) \(published .*$/\1/' <<<"$deferred_line")"
published_time="$(sed -E 's/^.* \(published ([^)]+)\)$/\1/' <<<"$deferred_line")"
expected_release_time="$(date -u -d "@$(( $(date -u -d "$published_time" +%s) + 49 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)"
[[ $release_time == "$expected_release_time" ]] || \
  fail "expected the deferred time $expected_release_time for $published_time, got $release_time"

# SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS moves both the header and the gate.
SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=10 \
  "$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout-age.log" 2>"$test_dir/stderr-age.log"
grep -Fxq '==> Pi versions (Safe-chain minimum package age: 10h)' "$test_dir/stdout-age.log"
deferred_line="$(grep -m1 -E '^pi 1\.1\.0 -> 1\.2\.0 deferred until ' "$test_dir/stdout-age.log")"
release_time="$(sed -E 's/^.* deferred until ([^ ]+) \(published .*$/\1/' <<<"$deferred_line")"
published_time="$(sed -E 's/^.* \(published ([^)]+)\)$/\1/' <<<"$deferred_line")"
expected_release_time="$(date -u -d "@$(( $(date -u -d "$published_time" +%s) + 11 * 3600 ))" +%Y-%m-%dT%H:%M:%SZ)"
[[ $release_time == "$expected_release_time" ]] || \
  fail "expected the 10h gate to defer until $expected_release_time, got $release_time"

# A registry that cannot answer is advisory only: the run still succeeds and
# the status line says why the deferral is unknown.
TEST_REGISTRY="$test_dir/missing-registry.json" \
  "$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout-missing.log" 2>"$test_dir/stderr-missing.log"
grep -Fxq 'pi 1.1.0 (registry lookup failed; age gate status unknown)' "$test_dir/stdout-missing.log"
grep -Fxq 'npm:pi-web-access 0.38.0 (registry lookup failed; age gate status unknown)' "$test_dir/stdout-missing.log"
grep -Fxq 'npm:@ogulcancelik/pi-session-recall 1.0.7 (registry lookup failed; age gate status unknown)' "$test_dir/stdout-missing.log"

# Without Pi's npm install tree the installed version is unknown, and the line
# must not pretend either outcome.
rm -rf "$HOME/.pi/agent/npm/node_modules/pi-codex-image-gen"
"$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout-unknown.log" 2>"$test_dir/stderr-unknown.log"
grep -Fxq 'npm:pi-codex-image-gen (installed version unknown)' "$test_dir/stdout-unknown.log"

printf 'update-ai age gate status checks passed.\n'
