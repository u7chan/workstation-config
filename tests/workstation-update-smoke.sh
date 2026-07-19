#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly RUNNER="$ROOT_DIR/scripts/workstation-update-runner"
readonly WATCH_UPDATE="$ROOT_DIR/scripts/personal-bin/watch-update"
readonly UPDATE_WORKSTATION="$ROOT_DIR/scripts/personal-bin/update-workstation"
readonly SHELL_INIT="$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
readonly USER_UNIT="$ROOT_DIR/ansible/roles/personal/files/workstation-update.service"

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
printf 'update-ai:%s\n' "$count" >>"$TEST_COMMAND_LOG"
printf 'update-ai raw output attempt %s\n' "$count"
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
[[ $* == 'upgrade herdr' ]]
[[ -z ${MISE_LOCKED:-} ]]
count_file="$TEST_COUNTER_DIR/mise"
count=0
[[ ! -r $count_file ]] || read -r count <"$count_file"
count=$((count + 1))
printf '%s\n' "$count" >"$count_file"
printf 'mise:%s\n' "$count" >>"$TEST_COMMAND_LOG"
printf 'mise raw output attempt %s\n' "$count"
if ((count <= ${TEST_MISE_FAILURES:-0})); then
  printf 'injected mise failure\n' >&2
  exit 42
fi
EOF
chmod +x "$fixture_bin/update-ai" "$fixture_bin/mise"

configure_repo() {
  local repo=$1
  git -C "$repo" config user.name Fixture
  git -C "$repo" config user.email fixture@example.invalid
}

create_repo() {
  local name=$1
  CASE_REMOTE="$test_dir/$name.git"
  CASE_SEED="$test_dir/$name-seed"
  CASE_REPO="$test_dir/$name-repo"

  git init --bare "$CASE_REMOTE" >/dev/null
  git --git-dir="$CASE_REMOTE" symbolic-ref HEAD refs/heads/main
  git init -b main "$CASE_SEED" >/dev/null
  configure_repo "$CASE_SEED"
  git -C "$CASE_SEED" commit --allow-empty -m initial >/dev/null
  git -C "$CASE_SEED" remote add origin "$CASE_REMOTE"
  git -C "$CASE_SEED" push -u origin main >/dev/null 2>&1
  git clone --quiet --branch main "$CASE_REMOTE" "$CASE_REPO"
  configure_repo "$CASE_REPO"
}

add_remote_commit() {
  local message=$1
  git -C "$CASE_SEED" commit --allow-empty -m "$message" >/dev/null
  git -C "$CASE_SEED" push origin main >/dev/null 2>&1
}

prepare_run() {
  local name=$1
  RUN_STATE_DIR="$test_dir/$name-state"
  RUN_COUNTER_DIR="$test_dir/$name-counters"
  RUN_COMMAND_LOG="$test_dir/$name-commands.log"
  mkdir -p "$RUN_COUNTER_DIR"
  : >"$RUN_COMMAND_LOG"
}

run_update() {
  HOME="$fixture_home" \
  PATH="$fixture_bin:/usr/bin:/bin" \
  TEST_COUNTER_DIR="$RUN_COUNTER_DIR" \
  TEST_COMMAND_LOG="$RUN_COMMAND_LOG" \
  TEST_AI_FAILURES="${TEST_AI_FAILURES:-0}" \
  TEST_MISE_FAILURES="${TEST_MISE_FAILURES:-0}" \
  WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
  WORKSTATION_UPDATE_AGENT_SKILLS_DIR="$CASE_REPO" \
  WORKSTATION_UPDATE_RETRY_DELAY_SECONDS=0 \
  SHOULD_NOT_BE_LOGGED=fixture-secret-value \
    "$RUNNER"
}

state_field() {
  local state_dir=$1
  local key=$2
  awk -F '\t' -v key="$key" '$1 == key { print $2; exit }' "$state_dir/state.tsv"
}

summary_for() {
  local state_dir=$1
  local run_id
  run_id="$(state_field "$state_dir" run_id)"
  printf '%s/runs/%s.summary.tsv\n' "$state_dir" "$run_id"
}

log_for() {
  local state_dir=$1
  local run_id
  run_id="$(state_field "$state_dir" run_id)"
  printf '%s/runs/%s.log\n' "$state_dir" "$run_id"
}

# Normal path: a clean, behind main branch is fast-forwarded after the first two steps.
create_repo normal
add_remote_commit remote-update
normal_remote_oid="$(git -C "$CASE_SEED" rev-parse HEAD)"
prepare_run normal
run_update
[[ $(git -C "$CASE_REPO" rev-parse HEAD) == "$normal_remote_oid" ]]
[[ $(state_field "$RUN_STATE_DIR" status) == success ]]
normal_summary="$(summary_for "$RUN_STATE_DIR")"
awk -F '\t' '
  NR == 1 { ok = $1 == 1 && $2 == "update-ai" && $3 == "success" && $4 == 1 }
  NR == 2 { ok = ok && $1 == 2 && $2 == "mise upgrade herdr" && $3 == "success" && $4 == 1 }
  NR == 3 { ok = ok && $1 == 3 && $2 == "agent-skills" && $3 == "success" && $4 == 1 }
  END { exit !(ok && NR == 3) }
' "$normal_summary"
[[ $(sed -n '1p' "$RUN_COMMAND_LOG") == update-ai:1 ]]
[[ $(sed -n '2p' "$RUN_COMMAND_LOG") == mise:1 ]]
normal_log="$(log_for "$RUN_STATE_DIR")"
grep -Fq 'update-ai raw output attempt 1' "$normal_log"
grep -Fq 'mise raw output attempt 1' "$normal_log"
if grep -Fq 'fixture-secret-value' "$normal_log"; then
  printf 'runner dumped an unrelated environment value into its log.\n' >&2
  exit 1
fi
[[ $(stat -c %a "$RUN_STATE_DIR/state.tsv") == 600 ]]

normal_watch="$(
  HOME="$fixture_home" WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" "$WATCH_UPDATE"
)"
grep -Fq '1/3 update-ai' <<<"$normal_watch"
grep -Fq '2/3 mise upgrade herdr' <<<"$normal_watch"
grep -Fq '3/3 agent-skills' <<<"$normal_watch"
grep -Fq 'workstation update completed successfully' <<<"$normal_watch"
verbose_watch="$(
  HOME="$fixture_home" WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" "$WATCH_UPDATE" --verbose
)"
grep -Fq 'update-ai raw output attempt 1' <<<"$verbose_watch"
grep -Fq 'mise raw output attempt 1' <<<"$verbose_watch"

# First failures are retried independently and can still aggregate to success.
create_repo retry-success
prepare_run retry-success
TEST_AI_FAILURES=1 TEST_MISE_FAILURES=1 run_update
[[ $(state_field "$RUN_STATE_DIR" status) == success ]]
retry_summary="$(summary_for "$RUN_STATE_DIR")"
awk -F '\t' '$2 == "update-ai" { exit !($3 == "success" && $4 == 2) }' "$retry_summary"
awk -F '\t' '$2 == "mise upgrade herdr" { exit !($3 == "success" && $4 == 2) }' "$retry_summary"
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 2 ]]
[[ $(grep -c '^mise:' "$RUN_COMMAND_LOG") -eq 2 ]]

# Two consecutive failures do not stop later steps; multiple failures are aggregated.
create_repo aggregate-failure
prepare_run aggregate-failure
if TEST_AI_FAILURES=2 TEST_MISE_FAILURES=2 run_update; then
  printf 'runner unexpectedly succeeded after two failures in multiple steps.\n' >&2
  exit 1
fi
[[ $(state_field "$RUN_STATE_DIR" status) == failed ]]
failure_summary="$(summary_for "$RUN_STATE_DIR")"
awk -F '\t' '$2 == "update-ai" { exit !($3 == "failed" && $4 == 2 && $6 == 41) }' "$failure_summary"
awk -F '\t' '$2 == "mise upgrade herdr" { exit !($3 == "failed" && $4 == 2 && $6 == 42) }' "$failure_summary"
awk -F '\t' '$2 == "agent-skills" { exit !($3 == "success" && $4 == 1) }' "$failure_summary"
[[ $(state_field "$RUN_STATE_DIR" failed_step) == 'update-ai, mise upgrade herdr' ]]

assert_unsafe_agent_case() {
  local name=$1
  local before_head before_status after_summary

  before_head="$(git -C "$CASE_REPO" rev-parse HEAD)"
  before_status="$(git -C "$CASE_REPO" status --porcelain --untracked-files=normal)"
  prepare_run "$name"
  if run_update; then
    printf 'unsafe agent-skills case unexpectedly succeeded: %s\n' "$name" >&2
    exit 1
  fi
  [[ $(git -C "$CASE_REPO" rev-parse HEAD) == "$before_head" ]]
  [[ $(git -C "$CASE_REPO" status --porcelain --untracked-files=normal) == "$before_status" ]]
  after_summary="$(summary_for "$RUN_STATE_DIR")"
  awk -F '\t' '$2 == "agent-skills" { exit !($3 == "failed" && $4 == 2 && $6 == 20) }' \
    "$after_summary"
}

# Git safety: clean/up-to-date succeeds; dirty, another branch, and diverged stay unchanged.
create_repo clean
prepare_run clean
run_update
[[ $(state_field "$RUN_STATE_DIR" status) == success ]]

create_repo dirty
printf 'local work\n' >"$CASE_REPO/untracked.txt"
assert_unsafe_agent_case dirty

create_repo another-branch
git -C "$CASE_REPO" switch -c feature/test >/dev/null 2>&1
assert_unsafe_agent_case another-branch

create_repo diverged
git -C "$CASE_REPO" commit --allow-empty -m local-divergence >/dev/null
add_remote_commit remote-divergence
assert_unsafe_agent_case diverged

# A held lock prevents a second runner and watch-update follows the first run to completion.
create_repo locking
prepare_run locking
lock_started="$test_dir/lock-started"
lock_release="$test_dir/lock-release"
lock_watch_output="$test_dir/lock-watch-output"
HOME="$fixture_home" \
PATH="$fixture_bin:/usr/bin:/bin" \
TEST_COUNTER_DIR="$RUN_COUNTER_DIR" \
TEST_COMMAND_LOG="$RUN_COMMAND_LOG" \
TEST_STARTED_FILE="$lock_started" \
TEST_BLOCK_FILE="$lock_release" \
WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
WORKSTATION_UPDATE_AGENT_SKILLS_DIR="$CASE_REPO" \
WORKSTATION_UPDATE_RETRY_DELAY_SECONDS=0 \
  "$RUNNER" &
first_runner_pid=$!
for _ in {1..100}; do
  [[ -e $lock_started && -r $RUN_STATE_DIR/state.tsv ]] && break
  sleep 0.02
done
[[ -e $lock_started && -r $RUN_STATE_DIR/state.tsv ]]
HOME="$fixture_home" \
WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
WORKSTATION_UPDATE_WATCH_INTERVAL_SECONDS=0.02 \
  "$WATCH_UPDATE" >"$lock_watch_output" &
watch_pid=$!
duplicate_output="$(
  HOME="$fixture_home" \
  PATH="$fixture_bin:/usr/bin:/bin" \
  TEST_COUNTER_DIR="$RUN_COUNTER_DIR" \
  TEST_COMMAND_LOG="$RUN_COMMAND_LOG" \
  WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
  WORKSTATION_UPDATE_AGENT_SKILLS_DIR="$CASE_REPO" \
  WORKSTATION_UPDATE_RETRY_DELAY_SECONDS=0 \
    "$RUNNER" 2>&1
)"
grep -Fq 'an update is already running' <<<"$duplicate_output"
[[ $(grep -c '^update-ai:' "$RUN_COMMAND_LOG") -eq 1 ]]
: >"$lock_release"
wait "$first_runner_pid"
wait "$watch_pid"
grep -Fq 'running' "$lock_watch_output"
grep -Fq 'workstation update completed successfully' "$lock_watch_output"

# The sixth run retains only the five newest raw logs and step summaries.
create_repo retention
prepare_run retention
for _ in {1..6}; do
  rm -f "$RUN_COUNTER_DIR/update-ai" "$RUN_COUNTER_DIR/mise"
  run_update
done
[[ $(find "$RUN_STATE_DIR/runs" -maxdepth 1 -type f -name '*.log' | wc -l) -eq 5 ]]
[[ $(find "$RUN_STATE_DIR/runs" -maxdepth 1 -type f -name '*.summary.tsv' | wc -l) -eq 5 ]]

# The manual CLI starts the same user service without sudo and returns immediately.
systemctl_bin="$test_dir/systemctl-bin"
systemctl_log="$test_dir/systemctl.log"
mkdir -p "$systemctl_bin"
cat >"$systemctl_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$TEST_SYSTEMCTL_LOG"
EOF
chmod +x "$systemctl_bin/systemctl"
TEST_SYSTEMCTL_LOG="$systemctl_log" PATH="$systemctl_bin:/usr/bin:/bin" \
  "$UPDATE_WORKSTATION" >/dev/null
grep -Fqx -- '--user start --no-block workstation-update.service' "$systemctl_log"
if grep -Rq 'sudo' "$UPDATE_WORKSTATION" "$USER_UNIT"; then
  printf 'workstation update entrypoints must not use sudo.\n' >&2
  exit 1
fi

# The unit is a one-shot default.target user service and passes a syntax check.
grep -Fqx 'Type=oneshot' "$USER_UNIT"
grep -Fqx 'ExecStart=%h/.local/bin/workstation-update-runner' "$USER_UNIT"
grep -Fqx 'WantedBy=default.target' "$USER_UNIT"
unit_verify_dir="$test_dir/unit-verify"
mkdir -p "$unit_verify_dir"
sed 's#^ExecStart=.*#ExecStart=/bin/true#' "$USER_UNIT" >"$unit_verify_dir/workstation-update.service"
systemd-analyze --user verify "$unit_verify_dir/workstation-update.service"

# Interactive Bash shows only running/failed state and never waits for the update.
shell_home="$test_dir/shell-home"
shell_state_dir="$shell_home/.local/state/workstation-update"
shell_output="$test_dir/shell-output"
mkdir -p "$shell_state_dir"
write_shell_state() {
  local status=$1
  local failed_step=${2:-}
  {
    printf 'status\t%s\n' "$status"
    printf 'step_index\t2\n'
    printf 'step_label\tmise upgrade herdr\n'
    printf 'failed_step\t%s\n' "$failed_step"
  } >"$shell_state_dir/state.tsv"
}
source_interactive_shell() {
  timeout 2s env HOME="$shell_home" PATH=/usr/bin:/bin \
    bash --noprofile --norc -ic 'source "$1" 2>"$2"' _ "$SHELL_INIT" "$shell_output" \
    >/dev/null 2>/dev/null
}

write_shell_state running
source_interactive_shell
grep -Fq '⟳ 2/3 mise upgrade herdr — watch-update' "$shell_output"

write_shell_state failed agent-skills
source_interactive_shell
grep -Fq '✗ agent-skills update failed — watch-update --verbose' "$shell_output"

write_shell_state success
source_interactive_shell
[[ ! -s $shell_output ]]

write_shell_state running
noninteractive_output="$(HOME="$shell_home" PATH=/usr/bin:/bin bash -c 'source "$1"' _ "$SHELL_INIT" 2>&1)"
[[ -z $noninteractive_output ]]

printf 'Workstation update smoke checks passed.\n'
