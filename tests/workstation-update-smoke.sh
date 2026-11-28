#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly MYUPDATE="$ROOT_DIR/scripts/personal-bin/myupdate"

# Build the expected Safe-chain coverage rows with the table's own format so the
# assertions compare the rendered columns, not hand-counted spaces.
coverage_row() {
  printf '%-18s %-10s %s\n' "$1" "$2" "$3"
}

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

fixture_home="$test_dir/home"
fixture_bin="$fixture_home/.local/bin"
mkdir -p "$fixture_bin"

cat >"$fixture_bin/update-ai" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count_file="$TEST_COUNTER_DIR/update-ai"
count=0
[[ ! -r $count_file ]] || read -r count <"$count_file"
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"
printf 'update-ai:%s:%s\n' "$count" "$*" >>"$TEST_COMMAND_LOG"
if [[ -n ${TEST_STARTED_FILE:-} ]]; then
  : >"$TEST_STARTED_FILE"
fi
if [[ -n ${TEST_BLOCK_FILE:-} ]]; then
  while [[ ! -e $TEST_BLOCK_FILE ]]; do
    sleep 0.02
  done
fi
if [[ -n ${TEST_SAFE_CHAIN_INFO:-} ]]; then
  printf 'Safe-chain: Some package versions were suppressed during package metadata resolution due to minimum package age.\n' >&2
fi
if [[ -n ${TEST_SAFE_CHAIN_BLOCK:-} ]]; then
  cat >&2 <<'SAFE_CHAIN'
npm error code E403
npm error 403 403 Forbidden - blocked by safe-chain direct download minimum package age (@aws-sdk/signature-v4-multi-region@3.996.48) - GET https://registry.npmjs.org/@aws-sdk/signature-v4-multi-region/-/signature-v4-multi-region-3.996.48.tgz
Safe-chain: blocked 7 direct package download request(s) due to minimum package age:
 - @aws-sdk/signature-v4-multi-region@3.996.48 (https://registry.npmjs.org/@aws-sdk/signature-v4-multi-region/-/signature-v4-multi-region-3.996.48.tgz)
 - @aws-sdk/core@3.978.2 (https://registry.npmjs.org/@aws-sdk/core/-/core-3.978.2.tgz)
 - @aws-sdk/nested-clients@3.997.47 (https://registry.npmjs.org/@aws-sdk/nested-clients/-/nested-clients-3.997.47.tgz)
 - @aws-sdk/token-providers@3.1149.0 (https://registry.npmjs.org/@aws-sdk/token-providers/-/token-providers-3.1149.0.tgz)
 - @aws-sdk/middleware-websocket@3.972.55 (https://registry.npmjs.org/@aws-sdk/middleware-websocket/-/middleware-websocket-3.972.55.tgz)
 - @aws-sdk/credential-provider-node@3.972.85 (https://registry.npmjs.org/@aws-sdk/credential-provider-node/-/credential-provider-node-3.972.85.tgz)
 - @aws-sdk/credential-provider-sso@3.973.17 (https://registry.npmjs.org/@aws-sdk/credential-provider-sso/-/credential-provider-sso-3.973.17.tgz)
SAFE_CHAIN
  exit 43
fi
if [[ -n ${TEST_SAFE_CHAIN_MALWARE:-} ]]; then
  printf 'Safe-chain: Exiting without installing malicious packages.\n' >&2
  exit 44
fi
if [[ -n ${TEST_SAFE_CHAIN_GENERIC_BLOCK:-} ]]; then
  printf 'npm error 403 403 Forbidden - blocked by safe-chain: package is not allowed by policy\n' >&2
  exit 45
fi
if ((count <= ${TEST_AI_FAILURES:-0})); then
  printf 'injected update-ai failure\n' >&2
  exit 41
fi
[[ ${MISE_LOCKED:-} == 1 ]]
EOF

cat >"$fixture_bin/mise" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'upgrade herdr')
    [[ -z ${MISE_LOCKED:-} ]]
    count_file="$TEST_COUNTER_DIR/mise"
    count=0
    [[ ! -r $count_file ]] || read -r count <"$count_file"
    count=$((count + 1))
    printf '%s\n' "$count" >"$count_file"
    printf 'mise:%s\n' "$count" >>"$TEST_COMMAND_LOG"
    if ((count <= ${TEST_MISE_FAILURES:-0})); then
      printf 'injected mise failure\n' >&2
      exit 42
    fi
    ;;
  'audit --json')
    printf 'mise-audit:1\n' >>"$TEST_COMMAND_LOG"
    audit_report='{"vulnerabilities":[{"tool":"node","version":"18.0.0","id":"CVE-2022-32212","aliases":[],"severity":null,"summary":"command injection","fixed":[],"url":"https://osv.dev/vulnerability/CVE-2022-32212"},{"tool":"npm:lodash","version":"4.17.15","id":"GHSA-35jh-r3h4-6jhm","aliases":[],"severity":"high","summary":"command injection","fixed":["4.17.21"],"url":"https://osv.dev/vulnerability/GHSA-35jh-r3h4-6jhm"}],"unchecked":[{"tool":"neovim","version":"0.12.3"}]}'
    # The report always goes to stdout; warnings and errors stay on stderr.
    case "${TEST_AUDIT_MODE:-clean}" in
      clean)
        printf '{"vulnerabilities":[],"unchecked":[]}\n'
        ;;
      findings)
        printf '%s\n' "$audit_report"
        exit 1
        ;;
      # A lockfile that no longer matches the config: an empty report, exit 1,
      # and the unchecked versions named on stderr.
      unresolved)
        printf '{"vulnerabilities":[],"unchecked":[]}\n'
        printf 'mise ERROR not checked, the version did not resolve: node@18.0.0\n' >&2
        exit 1
        ;;
      # Some versions resolved and one did not: real findings plus a gap.
      partial)
        printf '%s\n' "$audit_report"
        printf 'mise ERROR not checked, the version did not resolve: node@18.0.0\n' >&2
        exit 1
        ;;
      error)
        printf 'mise ERROR failed to query osv.dev\n' >&2
        exit 1
        ;;
      unsupported)
        printf "error: unrecognized subcommand 'audit'\n" >&2
        exit 2
        ;;
      *)
        printf 'unexpected audit mode: %s\n' "$TEST_AUDIT_MODE" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    printf 'unexpected mise command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF

cat >"$fixture_bin/agent-harness-dist" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
count_file="$TEST_COUNTER_DIR/agent-harness"
count=0
[[ ! -r $count_file ]] || read -r count <"$count_file"
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"
printf 'agent-harness:%s:%s\n' "$count" "$*" >>"$TEST_COMMAND_LOG"
if ((count <= ${TEST_AGENT_HARNESS_FAILURES:-0})); then
  printf 'injected agent-harness failure\n' >&2
  exit 51
fi
case "${1:-}" in
  update) printf 'state=already-current\nrevision=test\n' ;;
  status) printf 'record-match=yes\nlinks=ok\n' ;;
  *) printf 'unexpected agent-harness command: %s\n' "$*" >&2; exit 1 ;;
esac
EOF
chmod +x "$fixture_bin/update-ai" "$fixture_bin/mise" "$fixture_bin/agent-harness-dist"

prepare_run() {
  local name=$1
  RUN_COUNTER_DIR="$test_dir/$name-counters"
  RUN_COMMAND_LOG="$test_dir/$name-commands.log"
  mkdir -p "$RUN_COUNTER_DIR"
  : >"$RUN_COMMAND_LOG"
  # Every case starts without an audit baseline so none of them depends on the
  # order the earlier cases ran in.
  rm -f -- "$fixture_home/.local/state/workstation-update/mise-audit.json" \
    "$fixture_home/.local/state/workstation-update/mise-audit-latest.json" \
    "$fixture_home/.local/state/workstation-update/mise-audit-latest.err"
}

run_update() {
  local -a optional_environment=()

  [[ ! ${WORKSTATION_UPDATE_AI_TOOLS+x} ]] || \
    optional_environment+=("WORKSTATION_UPDATE_AI_TOOLS=$WORKSTATION_UPDATE_AI_TOOLS")
  [[ ! ${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS+x} ]] || \
    optional_environment+=("SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=$SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS")
  HOME="$fixture_home" \
  PATH="$fixture_bin:/usr/bin:/bin" \
  TEST_COUNTER_DIR="$RUN_COUNTER_DIR" \
  TEST_COMMAND_LOG="$RUN_COMMAND_LOG" \
  TEST_AI_FAILURES="${TEST_AI_FAILURES:-0}" \
  TEST_MISE_FAILURES="${TEST_MISE_FAILURES:-0}" \
  TEST_AUDIT_MODE="${TEST_AUDIT_MODE:-clean}" \
  TEST_SAFE_CHAIN_BLOCK="${TEST_SAFE_CHAIN_BLOCK:-}" \
  TEST_SAFE_CHAIN_GENERIC_BLOCK="${TEST_SAFE_CHAIN_GENERIC_BLOCK:-}" \
  TEST_SAFE_CHAIN_INFO="${TEST_SAFE_CHAIN_INFO:-}" \
  TEST_SAFE_CHAIN_MALWARE="${TEST_SAFE_CHAIN_MALWARE:-}" \
  TEST_STARTED_FILE="${TEST_STARTED_FILE:-}" \
  TEST_BLOCK_FILE="${TEST_BLOCK_FILE:-}" \
  WORKSTATION_UPDATE_RETRY_DELAY_SECONDS=0 \
  WORKSTATION_AGENT_HARNESS_DIST="$fixture_bin/agent-harness-dist" \
  TEST_AGENT_HARNESS_FAILURES="${TEST_AGENT_HARNESS_FAILURES:-0}" \
    env "${optional_environment[@]}" "$MYUPDATE"
}

# All steps succeed and the Herdr update does not install plugins.
prepare_run normal
normal_output="$(run_update 2>&1)"
grep -Fq 'all updates completed successfully' <<<"$normal_output"
# The coverage table makes every Safe-chain decision visible before the steps,
# including the deliberate age gate skip for the Pi core.
grep -Fqx '==> Safe-chain coverage' <<<"$normal_output"
grep -Fqx "$(coverage_row target 'npm path' 'age gate')" <<<"$normal_output"
grep -Fqx "$(coverage_row 'pi core' yes skipped)" <<<"$normal_output"
grep -Fqx "$(coverage_row 'pi packages (4)' yes 48h)" <<<"$normal_output"
grep -Fqx "$(coverage_row codex yes 48h)" <<<"$normal_output"
grep -Fqx "$(coverage_row claude no -)" <<<"$normal_output"
grep -Fqx "$(coverage_row opencode no -)" <<<"$normal_output"
grep -Fqx "$(coverage_row antigravity no -)" <<<"$normal_output"
grep -Fqx "$(coverage_row herdr no -)" <<<"$normal_output"
[[ $(sed -n '1p' "$RUN_COMMAND_LOG") == update-ai:1: ]]
[[ $(sed -n '2p' "$RUN_COMMAND_LOG") == agent-harness:1:update ]]
[[ $(sed -n '3p' "$RUN_COMMAND_LOG") == agent-harness:2:status ]]
[[ $(sed -n '4p' "$RUN_COMMAND_LOG") == mise:1 ]]
[[ $(sed -n '5p' "$RUN_COMMAND_LOG") == 'mise-audit:1' ]]
[[ $(wc -l <"$RUN_COMMAND_LOG") -eq 5 ]]
grep -Fqx '==> mise audit' <<<"$normal_output"
grep -Fqx 'mise audit: no known vulnerabilities' <<<"$normal_output"
if grep -Eq 'plugin[[:space:]]+install|herdr-bin|mise-which:herdr' "$RUN_COMMAND_LOG"; then
  printf 'Herdr update unexpectedly installed or resolved a plugin.\n' >&2
  exit 1
fi

# First failures are retried independently and can still aggregate to success.
prepare_run retry-success
TEST_AI_FAILURES=1 TEST_MISE_FAILURES=1 run_update >/dev/null 2>&1
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 2 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 2 ]]

# A failed step does not stop the later step, and any exhausted retry returns 1.
prepare_run ai-failure
set +e
TEST_AI_FAILURES=2 run_update >/dev/null 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 2 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 1 ]]

prepare_run aggregate-failure
set +e
TEST_AI_FAILURES=2 TEST_MISE_FAILURES=2 run_update >/dev/null 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 2 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 2 ]]

# A SafeChain policy block reports its reason, keeps the raw output, and does
# not spend the retry on a failure that repeats deterministically.
prepare_run safe-chain-age
set +e
TEST_SAFE_CHAIN_BLOCK=1 TEST_MISE_FAILURES=2 run_update >"$test_dir/safe-chain-age.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 1 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 2 ]]
grep -Fq 'update-ai failed (exit 43): SafeChain blocked downloads under its minimum package age' \
  "$test_dir/safe-chain-age.out"
[[ $(grep -c '^myupdate:   - ' "$test_dir/safe-chain-age.out") -eq 7 ]]
grep -Fq '  - @aws-sdk/signature-v4-multi-region@3.996.48' "$test_dir/safe-chain-age.out"
grep -Fq '  - @aws-sdk/core@3.978.2' "$test_dir/safe-chain-age.out"
grep -Fq '  - @aws-sdk/token-providers@3.1149.0' "$test_dir/safe-chain-age.out"
grep -Fq 'retry skipped' "$test_dir/safe-chain-age.out"
grep -Fq 'update failed: update-ai (SafeChain minimum package age), mise upgrade herdr' \
  "$test_dir/safe-chain-age.out"
grep -Fq 'blocked by safe-chain' "$fixture_home/.local/state/workstation-update/step-update-ai.log"

prepare_run safe-chain-malware
set +e
TEST_SAFE_CHAIN_MALWARE=1 run_update >"$test_dir/safe-chain-malware.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 1 ]]
grep -Fq 'SafeChain blocked a malicious package download' "$test_dir/safe-chain-malware.out"
grep -Fq 'retry skipped' "$test_dir/safe-chain-malware.out"
grep -Fq 'update failed: update-ai (SafeChain malware block)' "$test_dir/safe-chain-malware.out"

# A SafeChain block without a specific reason still stops after one attempt and
# is reported with its own label.
prepare_run safe-chain-generic-block
set +e
TEST_SAFE_CHAIN_GENERIC_BLOCK=1 run_update >"$test_dir/safe-chain-generic.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 1 ]]
grep -Fq 'update-ai failed (exit 45): SafeChain blocked a download' "$test_dir/safe-chain-generic.out"
grep -Fq 'retry skipped because the block is deterministic' "$test_dir/safe-chain-generic.out"
grep -Fq 'update failed: update-ai (SafeChain block)' "$test_dir/safe-chain-generic.out"

# SafeChain prints the metadata-suppression notice on successful installs, so a
# later transient failure in the same step must still spend the retry.
prepare_run safe-chain-info-then-failure
set +e
TEST_SAFE_CHAIN_INFO=1 TEST_AI_FAILURES=2 run_update >"$test_dir/safe-chain-info.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 2 ]]
grep -Fq 'retrying in' "$test_dir/safe-chain-info.out"
grep -Fq 'update failed: update-ai' "$test_dir/safe-chain-info.out"
if grep -Fq 'retry skipped' "$test_dir/safe-chain-info.out"; then
  printf 'the metadata age notice must not suppress the retry.\n' >&2
  exit 1
fi

# The same notice must not hide a real malware block in that step either.
prepare_run safe-chain-info-then-malware
set +e
TEST_SAFE_CHAIN_INFO=1 TEST_SAFE_CHAIN_MALWARE=1 run_update >"$test_dir/safe-chain-info-malware.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 1 ]]
grep -Fq 'SafeChain blocked a malicious package download' "$test_dir/safe-chain-info-malware.out"
grep -Fq 'update failed: update-ai (SafeChain malware block)' "$test_dir/safe-chain-info-malware.out"
# The environment selects only the requested AI tools; an empty value skips AI updates.
prepare_run selected-ai
WORKSTATION_UPDATE_AI_TOOLS=pi,opencode run_update >"$test_dir/selected-ai.out" 2>&1
grep -Fqx 'update-ai:1:--pi --opencode' "$RUN_COMMAND_LOG"
# The coverage table keeps unselected tools out of the listing.
grep -Fqx "$(coverage_row 'pi core' yes skipped)" "$test_dir/selected-ai.out"
grep -Fqx "$(coverage_row 'pi packages (4)' yes 48h)" "$test_dir/selected-ai.out"
grep -Fqx "$(coverage_row opencode no -)" "$test_dir/selected-ai.out"
grep -Fqx "$(coverage_row herdr no -)" "$test_dir/selected-ai.out"
if grep -Eq 'claude|codex' "$test_dir/selected-ai.out"; then
  printf 'unselected tools must not appear in the Safe-chain coverage table.\n' >&2
  exit 1
fi

prepare_run codex-only
WORKSTATION_UPDATE_AI_TOOLS=codex run_update >"$test_dir/codex-only.out" 2>&1
grep -Fqx 'update-ai:1:--codex' "$RUN_COMMAND_LOG"
grep -Fqx "$(coverage_row codex yes 48h)" "$test_dir/codex-only.out"
if grep -Eq 'pi core|pi packages|claude|opencode' "$test_dir/codex-only.out"; then
  printf 'Codex-only updates must not include other AI tools.\n' >&2
  exit 1
fi

prepare_run empty-ai
WORKSTATION_UPDATE_AI_TOOLS='' run_update >"$test_dir/empty-ai.out" 2>&1
if grep -q '^update-ai:' "$RUN_COMMAND_LOG"; then
  printf 'empty WORKSTATION_UPDATE_AI_TOOLS unexpectedly invoked update-ai.\n' >&2
  exit 1
fi
grep -Fqx 'agent-harness:1:update' "$RUN_COMMAND_LOG"
grep -Fqx 'agent-harness:2:status' "$RUN_COMMAND_LOG"
grep -Fqx 'mise:1' "$RUN_COMMAND_LOG"
grep -Fqx '==> Safe-chain coverage' "$test_dir/empty-ai.out"
grep -Fqx "$(coverage_row herdr no -)" "$test_dir/empty-ai.out"
if grep -Fq 'pi core' "$test_dir/empty-ai.out"; then
  printf 'skipped AI updates must not appear in the Safe-chain coverage table.\n' >&2
  exit 1
fi

# The displayed age gate follows SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS, and an
# unparsable value fails before any step starts.
prepare_run coverage-age-hours
SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=10 run_update >"$test_dir/coverage-age-hours.out" 2>&1
grep -Fqx "$(coverage_row 'pi packages (4)' yes 10h)" "$test_dir/coverage-age-hours.out"
grep -Fqx "$(coverage_row codex yes 10h)" "$test_dir/coverage-age-hours.out"

prepare_run invalid-age-hours
set +e
SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=48h run_update >"$test_dir/invalid-age-hours.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 2 ]]
grep -Fq 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS must be a whole number of hours' \
  "$test_dir/invalid-age-hours.out"
[[ ! -s $RUN_COMMAND_LOG ]]

# The config file is sourced only when the environment variable is unset.
mkdir -p "$fixture_home/.config/workstation"
printf '%s\n' 'WORKSTATION_UPDATE_AI_TOOLS="claude,codex"' >"$fixture_home/.config/workstation/myupdate.conf"
prepare_run config-selection
run_update >/dev/null
grep -Fqx 'update-ai:1:--claude --codex' "$RUN_COMMAND_LOG"
prepare_run config-override
WORKSTATION_UPDATE_AI_TOOLS=opencode run_update >/dev/null
grep -Fqx 'update-ai:1:--opencode' "$RUN_COMMAND_LOG"

# Invalid selections fail immediately with the documented usage exit code.
prepare_run invalid-ai
set +e
WORKSTATION_UPDATE_AI_TOOLS=invalid run_update >"$test_dir/invalid.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 2 ]]
grep -Fq 'invalid AI tool' "$test_dir/invalid.out"
[[ ! -s $RUN_COMMAND_LOG ]]

# A failed agent-harness step is retried independently, does not stop Herdr,
# and aggregates to exit 1 after the later step has run.
prepare_run agent-harness-retry
TEST_AGENT_HARNESS_FAILURES=1 run_update >/dev/null 2>&1
[[ $(grep -c '^agent-harness:' "$RUN_COMMAND_LOG") -eq 3 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 1 ]]

prepare_run agent-harness-failure
set +e
TEST_AGENT_HARNESS_FAILURES=2 run_update >"$test_dir/agent-harness-failure.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
[[ $(grep -c '^agent-harness:' "$RUN_COMMAND_LOG") -eq 2 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 1 ]]
grep -Fq 'agent-harness failed after 2 attempts' "$test_dir/agent-harness-failure.out"
grep -Fq 'update failed: agent-harness' "$test_dir/agent-harness-failure.out"

# A held update lock makes a concurrent invocation fail with exit code 3.
rm -f "$fixture_home/.config/workstation/myupdate.conf"
prepare_run locking
lock_started="$test_dir/lock-started"
lock_release="$test_dir/lock-release"
TEST_STARTED_FILE="$lock_started" TEST_BLOCK_FILE="$lock_release" run_update >/dev/null 2>&1 &
first_update_pid=$!
for _ in {1..100}; do
  [[ -e $lock_started ]] && break
  sleep 0.02
done
[[ -e $lock_started ]]
set +e
duplicate_output="$(run_update 2>&1)"
exit_code=$?
set -e
[[ $exit_code -eq 3 ]]
grep -Fq 'another update is already running' <<<"$duplicate_output"
: >"$lock_release"
wait "$first_update_pid"

prepare_run audit-skipped-after-failure
set +e
TEST_AI_FAILURES=2 run_update >"$test_dir/audit-skipped.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 1 ]]
if grep -q '^mise-audit:' "$RUN_COMMAND_LOG"; then
  printf 'mise audit must not run when an update step failed.\n' >&2
  exit 1
fi
if grep -Fq 'mise audit' "$test_dir/audit-skipped.out"; then
  printf 'a failed update must not print mise audit output.\n' >&2
  exit 1
fi

# Findings are reported but never fail the update, and the previous report is
# kept so a later run only prints what changed.
prepare_run audit-findings
set +e
TEST_AUDIT_MODE=findings run_update >"$test_dir/audit-findings.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 0 ]]
[[ $(grep -c '^mise-audit:' "$RUN_COMMAND_LOG") -eq 1 ]]
grep -Fqx '==> mise audit' "$test_dir/audit-findings.out"
grep -Fqx 'mise audit: 2 known vulnerabilities in 2 tool versions (1 with a fix, 1 high or critical); not checked: 1' \
  "$test_dir/audit-findings.out"
grep -Fqx 'mise audit: 2 new since the last run' "$test_dir/audit-findings.out"
grep -Fqx '  node 18.0.0 CVE-2022-32212 - no fix' "$test_dir/audit-findings.out"
grep -Fqx '  npm:lodash 4.17.15 GHSA-35jh-r3h4-6jhm high fix 4.17.21' \
  "$test_dir/audit-findings.out"
grep -Fq 'all updates completed successfully' "$test_dir/audit-findings.out"
[[ $(jq '.vulnerabilities | length' \
  "$fixture_home/.local/state/workstation-update/mise-audit.json") -eq 2 ]]

# The second run against the same report reprints the summary only.
prepare_run audit-repeat
TEST_AUDIT_MODE=findings run_update >"$test_dir/audit-repeat.out" 2>&1
grep -Fqx 'mise audit: 2 new since the last run' "$test_dir/audit-repeat.out"
TEST_AUDIT_MODE=findings run_update >"$test_dir/audit-repeat2.out" 2>&1
grep -Fqx 'mise audit: 2 known vulnerabilities in 2 tool versions (1 with a fix, 1 high or critical); not checked: 1' \
  "$test_dir/audit-repeat2.out"
if grep -Fq 'new since the last run' "$test_dir/audit-repeat2.out"; then
  printf 'an unchanged report must not reprint its findings.\n' >&2
  exit 1
fi

# A failed lookup with an empty report is not "no known vulnerabilities": it is
# skipped and the previous baseline survives.
prepare_run audit-unresolved
TEST_AUDIT_MODE=findings run_update >/dev/null 2>&1
TEST_AUDIT_MODE=unresolved run_update >"$test_dir/audit-unresolved.out" 2>&1
grep -Fqx 'mise audit skipped: mise could not check every tool version (exit 1): node@18.0.0' \
  "$test_dir/audit-unresolved.out"
if grep -Fq 'no known vulnerabilities' "$test_dir/audit-unresolved.out"; then
  printf 'an empty report from a failed lookup must not be reported as clean.\n' >&2
  exit 1
fi
grep -Fq 'all updates completed successfully' "$test_dir/audit-unresolved.out"
[[ $(jq '.vulnerabilities | length' \
  "$fixture_home/.local/state/workstation-update/mise-audit.json") -eq 2 ]]

# A partial report keeps its findings visible, says what was not checked, and
# does not become the baseline.
prepare_run audit-partial
TEST_AUDIT_MODE=findings run_update >/dev/null 2>&1
TEST_AUDIT_MODE=partial run_update >"$test_dir/audit-partial.out" 2>&1
grep -Fqx 'mise audit: 2 known vulnerabilities in 2 tool versions (1 with a fix, 1 high or critical); not checked: 1' \
  "$test_dir/audit-partial.out"
grep -Fqx 'mise audit: incomplete; not resolved: node@18.0.0' "$test_dir/audit-partial.out"
[[ $(jq '.vulnerabilities | length' \
  "$fixture_home/.local/state/workstation-update/mise-audit.json") -eq 2 ]]
grep -Fq 'all updates completed successfully' "$test_dir/audit-partial.out"

# A report that never arrives, or a mise without the subcommand, skips the step.
prepare_run audit-error
TEST_AUDIT_MODE=error run_update >"$test_dir/audit-error.out" 2>&1
grep -Fqx 'mise audit skipped: mise did not return a report (exit 1); see '"$fixture_home"'/.local/state/workstation-update/mise-audit-latest.err' \
  "$test_dir/audit-error.out"
grep -Fq 'all updates completed successfully' "$test_dir/audit-error.out"
[[ ! -e $fixture_home/.local/state/workstation-update/mise-audit.json ]]

prepare_run audit-unsupported
TEST_AUDIT_MODE=unsupported run_update >"$test_dir/audit-unsupported.out" 2>&1
grep -Fq 'mise audit skipped: mise did not return a report (exit 2)' \
  "$test_dir/audit-unsupported.out"
grep -Fq 'all updates completed successfully' "$test_dir/audit-unsupported.out"

printf 'Workstation update smoke checks passed.\n'
