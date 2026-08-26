#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly MYUPDATE="$ROOT_DIR/scripts/personal-bin/myupdate"

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
  *)
    printf 'unexpected mise command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fixture_bin/update-ai" "$fixture_bin/mise"

prepare_run() {
  local name=$1
  RUN_COUNTER_DIR="$test_dir/$name-counters"
  RUN_COMMAND_LOG="$test_dir/$name-commands.log"
  mkdir -p "$RUN_COUNTER_DIR"
  : >"$RUN_COMMAND_LOG"
}

run_update() {
  local -a optional_environment=()

  [[ ! ${WORKSTATION_UPDATE_AI_TOOLS+x} ]] || \
    optional_environment+=("WORKSTATION_UPDATE_AI_TOOLS=$WORKSTATION_UPDATE_AI_TOOLS")
  HOME="$fixture_home" \
  PATH="$fixture_bin:/usr/bin:/bin" \
  TEST_COUNTER_DIR="$RUN_COUNTER_DIR" \
  TEST_COMMAND_LOG="$RUN_COMMAND_LOG" \
  TEST_AI_FAILURES="${TEST_AI_FAILURES:-0}" \
  TEST_MISE_FAILURES="${TEST_MISE_FAILURES:-0}" \
  TEST_STARTED_FILE="${TEST_STARTED_FILE:-}" \
  TEST_BLOCK_FILE="${TEST_BLOCK_FILE:-}" \
  WORKSTATION_UPDATE_RETRY_DELAY_SECONDS=0 \
    env "${optional_environment[@]}" "$MYUPDATE"
}

# All steps succeed and the Herdr update does not install plugins.
prepare_run normal
normal_output="$(run_update 2>&1)"
grep -Fq 'all updates completed successfully' <<<"$normal_output"
[[ $(sed -n '1p' "$RUN_COMMAND_LOG") == update-ai:1: ]]
[[ $(sed -n '2p' "$RUN_COMMAND_LOG") == mise:1 ]]
[[ $(wc -l <"$RUN_COMMAND_LOG") -eq 2 ]]
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

# The environment selects only the requested AI tools; an empty value skips AI updates.
prepare_run selected-ai
WORKSTATION_UPDATE_AI_TOOLS=codex,pi,opencode run_update >/dev/null
grep -Fqx 'update-ai:1:--codex --pi --opencode' "$RUN_COMMAND_LOG"

prepare_run empty-ai
WORKSTATION_UPDATE_AI_TOOLS='' run_update >/dev/null
if grep -q '^update-ai:' "$RUN_COMMAND_LOG"; then
  printf 'empty WORKSTATION_UPDATE_AI_TOOLS unexpectedly invoked update-ai.\n' >&2
  exit 1
fi

# The config file is sourced only when the environment variable is unset.
mkdir -p "$fixture_home/.config/workstation"
printf '%s\n' 'WORKSTATION_UPDATE_AI_TOOLS="claude"' >"$fixture_home/.config/workstation/myupdate.conf"
prepare_run config-selection
run_update >/dev/null
grep -Fqx 'update-ai:1:--claude' "$RUN_COMMAND_LOG"
prepare_run config-override
WORKSTATION_UPDATE_AI_TOOLS=codex run_update >/dev/null
grep -Fqx 'update-ai:1:--codex' "$RUN_COMMAND_LOG"

# Invalid selections fail immediately with the documented usage exit code.
prepare_run invalid-ai
set +e
WORKSTATION_UPDATE_AI_TOOLS=invalid run_update >"$test_dir/invalid.out" 2>&1
exit_code=$?
set -e
[[ $exit_code -eq 2 ]]
grep -Fq 'invalid AI tool' "$test_dir/invalid.out"
[[ ! -s $RUN_COMMAND_LOG ]]

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

printf 'Workstation update smoke checks passed.\n'
