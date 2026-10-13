#!/usr/bin/env bash
# Verify that `update-ai --pi` reports the versions the Safe-chain minimum
# package age holds back, so a deferred update is not mistaken for a current
# installation. The test stubs node, npm, curl, Pi, and the clock, and serves a
# fixture registry, so it needs no network and no managed runtime.
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

# Freeze the clock that update-ai reads for the resolution cutoff. The second
# value stands in for a report that re-reads the clock after the gate deadline
# has passed: the deferral must still be decided against the cutoff the installs
# used, not against the report time.
real_date="$(type -P date)"
export TEST_DATE_STATE="$test_dir/date.state"
export TEST_CURRENT_EPOCH=1791849600 # 2026-10-13T00:00:00Z
export TEST_LATE_EPOCH=$((TEST_CURRENT_EPOCH + 2))
cat >"$test_bin/date" <<EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ \$# -eq 1 && \$1 == +%s ]]; then
  if [[ -e \$TEST_DATE_STATE ]]; then
    printf '%s\n' "\$TEST_LATE_EPOCH"
  else
    : >"\$TEST_DATE_STATE"
    printf '%s\n' "\$TEST_CURRENT_EPOCH"
  fi
  exit 0
fi
exec "$real_date" "\$@"
EOF

# Each run starts at the frozen second and would see the later value if it read
# the clock a second time.
reset_clock() {
  rm -f "$TEST_DATE_STATE"
}

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
chmod +x "$test_bin/date" "$test_bin/npm" "$test_bin/node" "$test_bin/curl" "$test_bin/pi"

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

fail() {
  printf 'update-ai-age-gate-status: %s\n' "$*" >&2
  exit 1
}

iso_seconds() {
  date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ
}

# The stub clock fixes the install start, so these are exactly the cutoffs that
# compute_npm_before passes to npm as npm_config_before.
start_epoch=$TEST_CURRENT_EPOCH
readonly start_epoch
cutoff_48=$((start_epoch - 49 * 3600))
cutoff_10=$((start_epoch - 11 * 3600))

# write_registry_fixture <path> <cutoff epoch>
#
# The Pi CLI and pi-web-access publish one second after the cutoff, so npm can
# only resolve the older version and the status must report a deferral. The Pi
# CLI timestamp carries milliseconds, which moves its installable second one
# second later than the truncated timestamp. The conversion publishes exactly
# at the cutoff, which npm-pick-manifest accepts (Date.parse(published) <=
# cutoff), so its newer version should have been installed and the status must
# warn instead of reporting a deferral.
write_registry_fixture() {
  local path=$1
  local cutoff_epoch=$2

  jq -n \
    --arg pi_milliseconds "$(printf '%s.459Z' "$(date -u -d "@$((cutoff_epoch + 1))" +%Y-%m-%dT%H:%M:%S)")" \
    --arg deferred "$(iso_seconds "$((cutoff_epoch + 1))")" \
    --arg at_cutoff "$(iso_seconds "$cutoff_epoch")" \
    --arg past_gate "$(iso_seconds "$((cutoff_epoch - 3600))")" \
    '{
      "@earendil-works/pi-coding-agent": [
        { "dist-tags": { "latest": "1.2.0" }, "time": { "created": $past_gate, "1.2.0": $pi_milliseconds } }
      ],
      "pi-web-access": [
        { "dist-tags": { "latest": "0.39.0" }, "time": { "0.39.0": $deferred } }
      ],
      "pi-codex-image-gen": [
        { "dist-tags": { "latest": "0.2.0" }, "time": { "0.2.0": $past_gate } }
      ],
      "@howaboua/pi-codex-conversion": [
        { "dist-tags": { "latest": "3.0.52" }, "time": { "3.0.52": $at_cutoff } }
      ],
      "@ogulcancelik/pi-session-recall": [
        { "dist-tags": { "latest": "1.0.7" }, "time": { "1.0.7": $past_gate } }
      ]
    }' >"$path"
}

# <label> <installed> <latest> <published> <installable epoch>
expected_deferred_line() {
  printf '%s %s -> %s deferred until %s (published %s)\n' \
    "$1" "$2" "$3" "$(iso_seconds "$5")" "$4"
}

# The installs keep resolving through npm_config_before and Pi, and the status
# block distinguishes current targets from deferred ones.
write_registry_fixture "$registry" "$cutoff_48"
reset_clock
"$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout.log" 2>"$test_dir/stderr.log"

grep -Fxq '==> Pi versions (Safe-chain minimum package age: 48h)' "$test_dir/stdout.log"
grep -Fxq "npm before=$(iso_seconds "$cutoff_48") args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest" "$install_log"
grep -Fqx 'pi update npm:pi-web-access --no-approve' "$install_log"
grep -Fxq "$(expected_deferred_line \
  pi 1.1.0 1.2.0 \
  "$(printf '%s.459Z' "$(date -u -d "@$((cutoff_48 + 1))" +%Y-%m-%dT%H:%M:%S)")" \
  "$((start_epoch + 2))")" "$test_dir/stdout.log"
grep -Fxq "$(expected_deferred_line \
  npm:pi-web-access 0.38.0 0.39.0 \
  "$(iso_seconds "$((cutoff_48 + 1))")" \
  "$((start_epoch + 1))")" "$test_dir/stdout.log"
grep -Fxq 'npm:pi-codex-image-gen 0.2.0 (newest allowed version)' "$test_dir/stdout.log"
grep -Fxq 'npm:@ogulcancelik/pi-session-recall 1.0.7 (newest allowed version)' "$test_dir/stdout.log"
if grep -Fq 'registry lookup failed' "$test_dir/stdout.log"; then
  fail 'a served registry fixture must not report a lookup failure.'
fi

# A version published exactly at the cutoff is already resolvable, so a target
# that is still on the older version did not take effect and must be visible.
grep -Fxq 'npm:@howaboua/pi-codex-conversion 3.0.49 -> 3.0.52' "$test_dir/stdout.log"
grep -Fxq 'update-ai: npm:@howaboua/pi-codex-conversion 3.0.49 is behind 3.0.52, which is already past the age gate; the update did not take effect' "$test_dir/stderr.log"
# Only the target past the gate may warn: the deferred targets are legitimate
# results of the cutoff that the installs used.
[[ $(grep -c '^update-ai: ' "$test_dir/stderr.log" || true) -eq 1 ]] || \
  fail "expected exactly one update-ai warning, got: $(cat "$test_dir/stderr.log")"

# SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS moves the header, the cutoff that npm
# receives, and the deferral arithmetic together.
write_registry_fixture "$registry" "$cutoff_10"
: >"$install_log"
reset_clock
SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=10 \
  "$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout-age.log" 2>"$test_dir/stderr-age.log"
grep -Fxq '==> Pi versions (Safe-chain minimum package age: 10h)' "$test_dir/stdout-age.log"
grep -Fxq "npm before=$(iso_seconds "$cutoff_10") args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest" "$install_log"
grep -Fxq "$(expected_deferred_line \
  pi 1.1.0 1.2.0 \
  "$(printf '%s.459Z' "$(date -u -d "@$((cutoff_10 + 1))" +%Y-%m-%dT%H:%M:%S)")" \
  "$((start_epoch + 2))")" "$test_dir/stdout-age.log"
grep -Fxq "$(expected_deferred_line \
  npm:pi-web-access 0.38.0 0.39.0 \
  "$(iso_seconds "$((cutoff_10 + 1))")" \
  "$((start_epoch + 1))")" "$test_dir/stdout-age.log"
[[ $(grep -c '^update-ai: ' "$test_dir/stderr-age.log" || true) -eq 1 ]] || \
  fail "expected exactly one age 10h warning, got: $(cat "$test_dir/stderr-age.log")"

# A registry that cannot answer is advisory only: the run still succeeds and
# the status line says why the deferral is unknown.
reset_clock
TEST_REGISTRY="$test_dir/missing-registry.json" \
  "$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout-missing.log" 2>"$test_dir/stderr-missing.log"
grep -Fxq 'pi 1.1.0 (registry lookup failed; age gate status unknown)' "$test_dir/stdout-missing.log"
grep -Fxq 'npm:pi-web-access 0.38.0 (registry lookup failed; age gate status unknown)' "$test_dir/stdout-missing.log"
grep -Fxq 'npm:@ogulcancelik/pi-session-recall 1.0.7 (registry lookup failed; age gate status unknown)' "$test_dir/stdout-missing.log"

# Without Pi's npm install tree the installed version is unknown, and the line
# must not pretend either outcome.
rm -rf "$HOME/.pi/agent/npm/node_modules/pi-codex-image-gen"
reset_clock
"$ROOT_DIR/scripts/update-ai" --pi >"$test_dir/stdout-unknown.log" 2>"$test_dir/stderr-unknown.log"
grep -Fxq 'npm:pi-codex-image-gen (installed version unknown)' "$test_dir/stdout-unknown.log"

printf 'update-ai age gate status checks passed.\n'
