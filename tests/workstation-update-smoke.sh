#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly RUNNER="$ROOT_DIR/scripts/workstation-update-runner"
readonly WATCH_UPDATE="$ROOT_DIR/scripts/personal-bin/watch-update"
readonly UPDATE_WORKSTATION="$ROOT_DIR/scripts/personal-bin/update-workstation"
readonly LOCKED_GIT="$ROOT_DIR/scripts/workstation-update-locked-git"
readonly SHELL_INIT="$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
readonly USER_UNIT="$ROOT_DIR/ansible/roles/personal/files/workstation-update.service"
readonly USER_UNIT_ENV="$ROOT_DIR/ansible/roles/personal/templates/workstation-update.env.j2"

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
printf 'update-ai raw output attempt %s\n' "$count"
if [[ -n ${TEST_STARTED_FILE:-} ]]; then
  : >"$TEST_STARTED_FILE"
fi
if [[ ${TEST_KILL_RUNNER:-0} == 1 ]]; then
  kill -KILL "$PPID"
  exit 137
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
  local -a optional_environment=()

  [[ ! ${WORKSTATION_UPDATE_AI_TOOLS+x} ]] || \
    optional_environment+=("WORKSTATION_UPDATE_AI_TOOLS=$WORKSTATION_UPDATE_AI_TOOLS")
  [[ ! ${WORKSTATION_UPDATE_AGENT_SKILLS_ENABLED+x} ]] || \
    optional_environment+=("WORKSTATION_UPDATE_AGENT_SKILLS_ENABLED=$WORKSTATION_UPDATE_AGENT_SKILLS_ENABLED")
  HOME="$fixture_home" \
  PATH="${RUN_PATH:-$fixture_bin:/usr/bin:/bin}" \
  TEST_COUNTER_DIR="$RUN_COUNTER_DIR" \
  TEST_COMMAND_LOG="$RUN_COMMAND_LOG" \
  TEST_AI_FAILURES="${TEST_AI_FAILURES:-0}" \
  TEST_MISE_FAILURES="${TEST_MISE_FAILURES:-0}" \
  TEST_KILL_RUNNER="${TEST_KILL_RUNNER:-0}" \
  WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
  WORKSTATION_UPDATE_AGENT_SKILLS_DIR="$CASE_REPO" \
  WORKSTATION_UPDATE_RETRY_DELAY_SECONDS=0 \
  SHOULD_NOT_BE_LOGGED=fixture-secret-value \
    env "${optional_environment[@]}" "$RUNNER"
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
[[ $(sed -n '1p' "$RUN_COMMAND_LOG") == update-ai:1: ]]
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

# Ansible-selected AI tools are the only flags passed to update-ai.
create_repo selected-ai
prepare_run selected-ai
WORKSTATION_UPDATE_AI_TOOLS=codex,opencode run_update
grep -Fqx 'update-ai:1:--codex --opencode' "$RUN_COMMAND_LOG"
[[ $(state_field "$RUN_STATE_DIR" status) == success ]]

# An empty AI tool selection and disabled agent-skills are explicit successful skips.
create_repo empty-ai
prepare_run empty-ai
WORKSTATION_UPDATE_AI_TOOLS= run_update
if grep -q '^update-ai:' "$RUN_COMMAND_LOG"; then
  printf 'empty personal_ai_tools unexpectedly invoked update-ai.\n' >&2
  exit 1
fi
grep -Fq 'AI CLI update skipped: personal_ai_tools is empty' "$(log_for "$RUN_STATE_DIR")"
[[ $(state_field "$RUN_STATE_DIR" status) == success ]]

prepare_run disabled-agent-skills
CASE_REPO="$test_dir/missing-agent-skills"
WORKSTATION_UPDATE_AGENT_SKILLS_ENABLED=false run_update
if [[ -e $CASE_REPO ]]; then
  printf 'disabled agent-skills update unexpectedly created its repository.\n' >&2
  exit 1
fi
grep -Fq 'agent-skills update skipped: personal_agent_skills_enabled is false' \
  "$(log_for "$RUN_STATE_DIR")"
awk -F '\t' '$2 == "agent-skills" { exit !($3 == "success" && $4 == 1) }' \
  "$(summary_for "$RUN_STATE_DIR")"
[[ $(state_field "$RUN_STATE_DIR" status) == success ]]

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

# A competing branch switch after the final inspection cannot redirect the fast-forward.
create_repo branch-switch-race
add_remote_commit remote-race-update
race_old_oid="$(git -C "$CASE_REPO" rev-parse HEAD)"
race_remote_oid="$(git -C "$CASE_SEED" rev-parse HEAD)"
git -C "$CASE_REPO" branch feature/race
race_bin="$test_dir/race-bin"
race_attempted="$test_dir/race-attempted"
race_succeeded="$test_dir/race-succeeded"
mkdir -p "$race_bin"
cat >"$race_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ " $* " == *' merge --ff-only '* && ! -e $TEST_RACE_ATTEMPTED ]]; then
  : >"$TEST_RACE_ATTEMPTED"
  if env -u GIT_INDEX_FILE /usr/bin/git -C "$TEST_RACE_REPO" switch feature/race \
    >/dev/null 2>&1; then
    : >"$TEST_RACE_SUCCEEDED"
  fi
fi
exec /usr/bin/git "$@"
EOF
chmod +x "$race_bin/git"
prepare_run branch-switch-race
TEST_RACE_REPO="$CASE_REPO" \
TEST_RACE_ATTEMPTED="$race_attempted" \
TEST_RACE_SUCCEEDED="$race_succeeded" \
RUN_PATH="$race_bin:$fixture_bin:/usr/bin:/bin" \
  run_update
[[ -e $race_attempted && ! -e $race_succeeded ]]
[[ $(git -C "$CASE_REPO" branch --show-current) == main ]]
[[ $(git -C "$CASE_REPO" rev-parse main) == "$race_remote_oid" ]]
[[ $(git -C "$CASE_REPO" rev-parse feature/race) == "$race_old_oid" ]]

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
WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
  "$LOCKED_GIT" -C "$CASE_REPO" branch provisioning/serialized &
provisioning_git_pid=$!
sleep 0.05
if git -C "$CASE_REPO" show-ref --verify --quiet refs/heads/provisioning/serialized; then
  printf 'provisioning Git update overlapped the automatic runner.\n' >&2
  exit 1
fi
: >"$lock_release"
wait "$first_runner_pid"
wait "$watch_pid"
wait "$provisioning_git_pid"
git -C "$CASE_REPO" show-ref --verify --quiet refs/heads/provisioning/serialized
grep -Fq 'running' "$lock_watch_output"
grep -Fq 'workstation update completed successfully' "$lock_watch_output"

# SIGKILL leaves state running, then watch-update detects the dead process and converges it to failed.
create_repo stale-running
prepare_run stale-running
if TEST_KILL_RUNNER=1 run_update 2>"$test_dir/stale-runner-kill.err"; then
  printf 'runner unexpectedly survived the abrupt-death fixture.\n' >&2
  exit 1
fi
[[ $(state_field "$RUN_STATE_DIR" status) == running ]]
stale_watch="$(
  HOME="$fixture_home" \
  WORKSTATION_UPDATE_STATE_DIR="$RUN_STATE_DIR" \
  WORKSTATION_UPDATE_WATCH_INTERVAL_SECONDS=0.02 \
    "$WATCH_UPDATE"
)"
grep -Fq 'workstation update incomplete: update-ai' <<<"$stale_watch"
[[ $(state_field "$RUN_STATE_DIR" status) == failed ]]
[[ $(state_field "$RUN_STATE_DIR" message) == 'runner process is no longer alive' ]]
grep -Fq 'stale state marked failed' "$(log_for "$RUN_STATE_DIR")"

# The sixth run retains only the five newest raw logs and step summaries.
create_repo retention
prepare_run retention
for _ in {1..6}; do
  rm -f "$RUN_COUNTER_DIR/update-ai" "$RUN_COUNTER_DIR/mise"
  run_update
done
[[ $(find "$RUN_STATE_DIR/runs" -maxdepth 1 -type f -name '*.log' | wc -l) -eq 5 ]]
[[ $(find "$RUN_STATE_DIR/runs" -maxdepth 1 -type f -name '*.summary.tsv' | wc -l) -eq 5 ]]

# The manual CLI waits only for the newly requested run to publish state.
systemctl_bin="$test_dir/systemctl-bin"
systemctl_log="$test_dir/systemctl.log"
manual_state_dir="$test_dir/manual-state"
mkdir -p "$systemctl_bin"
cat >"$systemctl_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$TEST_SYSTEMCTL_LOG"
(
  sleep 0.05
  mkdir -p "$TEST_MANUAL_STATE_DIR/runs"
  runner_pid=$BASHPID
  proc_stat="$(<"/proc/$runner_pid/stat")"
  proc_stat=${proc_stat##*) }
  runner_start_time="$(awk '{ print $20 }' <<<"$proc_stat")"
  state_tmp="$TEST_MANUAL_STATE_DIR/.state.$runner_pid.tmp"
  {
    printf 'status\trunning\n'
    printf 'run_id\t%s\n' "$TEST_MANUAL_RUN_ID"
    printf 'step_index\t1\n'
    printf 'step_total\t3\n'
    printf 'step_label\tupdate-ai\n'
    printf 'step_status\trunning\n'
    printf 'attempt\t1\n'
    printf 'started_at_epoch\t%s\n' "$(date +%s)"
    printf 'updated_at_epoch\t%s\n' "$(date +%s)"
    printf 'runner_pid\t%s\n' "$runner_pid"
    printf 'runner_start_time\t%s\n' "$runner_start_time"
    printf 'failed_step\t\n'
    printf 'message\t\n'
  } >"$state_tmp"
  : >"$TEST_MANUAL_STATE_DIR/runs/$TEST_MANUAL_RUN_ID.log"
  : >"$TEST_MANUAL_STATE_DIR/runs/$TEST_MANUAL_RUN_ID.summary.tsv"
  mv -f "$state_tmp" "$TEST_MANUAL_STATE_DIR/state.tsv"
  sleep 0.2
  sed -e 's/^status\trunning$/status\tsuccess/' \
    -e 's/^step_status\trunning$/step_status\tsuccess/' \
    "$TEST_MANUAL_STATE_DIR/state.tsv" >"$state_tmp"
  mv -f "$state_tmp" "$TEST_MANUAL_STATE_DIR/state.tsv"
) &
EOF
chmod +x "$systemctl_bin/systemctl"
TEST_SYSTEMCTL_LOG="$systemctl_log" \
TEST_MANUAL_STATE_DIR="$manual_state_dir" \
TEST_MANUAL_RUN_ID=manual-first \
HOME="$fixture_home" \
WORKSTATION_UPDATE_STATE_DIR="$manual_state_dir" \
WORKSTATION_UPDATE_START_TIMEOUT_SECONDS=2 \
WORKSTATION_UPDATE_START_POLL_INTERVAL_SECONDS=0.01 \
PATH="$systemctl_bin:/usr/bin:/bin" \
  "$UPDATE_WORKSTATION" >/dev/null
[[ $(state_field "$manual_state_dir" run_id) == manual-first ]]
first_manual_watch="$(
  HOME="$fixture_home" \
  WORKSTATION_UPDATE_STATE_DIR="$manual_state_dir" \
  WORKSTATION_UPDATE_WATCH_INTERVAL_SECONDS=0.01 \
    "$WATCH_UPDATE"
)"
grep -Fq 'workstation update completed successfully' <<<"$first_manual_watch"

TEST_SYSTEMCTL_LOG="$systemctl_log" \
TEST_MANUAL_STATE_DIR="$manual_state_dir" \
TEST_MANUAL_RUN_ID=manual-second \
HOME="$fixture_home" \
WORKSTATION_UPDATE_STATE_DIR="$manual_state_dir" \
WORKSTATION_UPDATE_START_TIMEOUT_SECONDS=2 \
WORKSTATION_UPDATE_START_POLL_INTERVAL_SECONDS=0.01 \
PATH="$systemctl_bin:/usr/bin:/bin" \
  "$UPDATE_WORKSTATION" >/dev/null
[[ $(state_field "$manual_state_dir" run_id) == manual-second ]]
second_manual_watch="$(
  HOME="$fixture_home" \
  WORKSTATION_UPDATE_STATE_DIR="$manual_state_dir" \
  WORKSTATION_UPDATE_WATCH_INTERVAL_SECONDS=0.01 \
    "$WATCH_UPDATE"
)"
grep -Fq 'workstation update completed successfully' <<<"$second_manual_watch"
[[ $(grep -c -Fx -- '--user start --no-block workstation-update.service' "$systemctl_log") -eq 2 ]]
if grep -Rq 'sudo' "$UPDATE_WORKSTATION" "$USER_UNIT"; then
  printf 'workstation update entrypoints must not use sudo.\n' >&2
  exit 1
fi

# The unit is a one-shot default.target user service and passes a syntax check.
grep -Fqx 'Type=oneshot' "$USER_UNIT"
grep -Fqx 'EnvironmentFile=%h/.config/systemd/user/workstation-update.env' "$USER_UNIT"
grep -Fqx 'ExecStart=%h/.local/bin/workstation-update-runner' "$USER_UNIT"
grep -Fqx 'WantedBy=default.target' "$USER_UNIT"
grep -Fqx "WORKSTATION_UPDATE_AI_TOOLS={{ personal_ai_tools | join(',') }}" "$USER_UNIT_ENV"
grep -Fq 'WORKSTATION_UPDATE_AGENT_SKILLS_ENABLED=' "$USER_UNIT_ENV"
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
  local liveness=${3:-alive}
  local runner_pid runner_start_time proc_stat

  if [[ $liveness == alive ]]; then
    runner_pid=$$
    proc_stat="$(<"/proc/$$/stat")"
    proc_stat=${proc_stat##*) }
    runner_start_time="$(awk '{ print $20 }' <<<"$proc_stat")"
  else
    runner_pid=99999999
    runner_start_time=1
  fi
  {
    printf 'status\t%s\n' "$status"
    printf 'step_index\t2\n'
    printf 'step_label\tmise upgrade herdr\n'
    printf 'runner_pid\t%s\n' "$runner_pid"
    printf 'runner_start_time\t%s\n' "$runner_start_time"
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

write_shell_state running '' stale
source_interactive_shell
grep -Fq '✗ workstation update stopped unexpectedly — watch-update' "$shell_output"

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
