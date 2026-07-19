#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly GPC="$ROOT_DIR/scripts/personal-bin/gpc"
readonly GAC="$ROOT_DIR/scripts/personal-bin/gac"
readonly CLP="$ROOT_DIR/scripts/personal-bin/clp"

test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

configure_repo() {
  local repo=$1
  git -C "$repo" config user.name Fixture
  git -C "$repo" config user.email fixture@example.invalid
}

create_repo() {
  local name=$1
  local remote="$test_dir/${name}.git"
  local repo="$test_dir/$name"

  git init --bare "$remote" >/dev/null
  git --git-dir="$remote" symbolic-ref HEAD refs/heads/main
  git init -b main "$repo" >/dev/null
  configure_repo "$repo"
  git -C "$repo" commit --allow-empty -m initial >/dev/null
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -u origin main >/dev/null
  printf '%s\n' "$repo"
}

# gpc: merged PR cleanup succeeds and deletes only its local head.
mock_bin="$test_dir/mock-bin"
mkdir -p "$mock_bin"
cat >"$mock_bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == auth && ${2:-} == status ]]; then
  exit 0
fi
if [[ ${1:-} == pr && ${2:-} == view && -n ${3:-} ]]; then
  branch=${3}
  head_oid=${GH_MOCK_HEAD_OID:-$(git rev-parse --verify "$branch")}
  printf 'MERGED\t2026-07-06T00:00:00Z\tmain\t%s\t%s\n' "$branch" "$head_oid"
  exit 0
fi
exit 1
EOF
chmod +x "$mock_bin/gh"

[[ $($GPC --help) == *'Usage: gpc'* ]]
[[ $($GAC --help) == *'Usage: gac'* ]]

pr_repo=$(create_repo pr-repo)
git -C "$pr_repo" switch -c feature/pr >/dev/null
git -C "$pr_repo" commit --allow-empty -m feature >/dev/null
PATH="$mock_bin:$PATH" git -C "$pr_repo" status --short >/dev/null
(
  cd "$pr_repo"
  PATH="$mock_bin:$PATH" "$GPC" >/dev/null
)
[[ $(git -C "$pr_repo" branch --show-current) == main ]]
if git -C "$pr_repo" show-ref --verify --quiet refs/heads/feature/pr; then
  printf 'gpc left its merged head branch.\n' >&2
  exit 1
fi

# Local commits ahead of the PR head stop cleanup before switching to base.
git -C "$pr_repo" switch -c feature/extra >/dev/null
git -C "$pr_repo" commit --allow-empty -m pr-head >/dev/null
expected_oid=$(git -C "$pr_repo" rev-parse --verify feature/extra)
git -C "$pr_repo" commit --allow-empty -m local-extra >/dev/null
if (
  cd "$pr_repo"
  GH_MOCK_HEAD_OID="$expected_oid" PATH="$mock_bin:$PATH" "$GPC" >/dev/null 2>&1
); then
  printf 'gpc accepted a head branch with local commits ahead of PR head.\n' >&2
  exit 1
fi
[[ $(git -C "$pr_repo" branch --show-current) == feature/extra ]]
git -C "$pr_repo" show-ref --verify --quiet refs/heads/feature/extra

# A dirty primary tree stops before any PR operation.
git -C "$pr_repo" switch -c feature/pr >/dev/null
touch "$pr_repo/untracked"
if (
  cd "$pr_repo"
  PATH="$mock_bin:$PATH" "$GPC" >/dev/null 2>&1
); then
  printf 'gpc accepted a dirty worktree.\n' >&2
  exit 1
fi
[[ $(git -C "$pr_repo" branch --show-current) == feature/pr ]]
rm "$pr_repo/untracked"
git -C "$pr_repo" switch main >/dev/null
git -C "$pr_repo" branch -D feature/pr >/dev/null

# A linked worktree is outside gpc's responsibility.
git -C "$pr_repo" branch feature/linked
git -C "$pr_repo" worktree add "$test_dir/pr-linked" feature/linked >/dev/null
if (
  cd "$test_dir/pr-linked"
  PATH="$mock_bin:$PATH" "$GPC" >/dev/null 2>&1
); then
  printf 'gpc accepted a linked worktree.\n' >&2
  exit 1
fi
git -C "$pr_repo" worktree remove "$test_dir/pr-linked"
git -C "$pr_repo" branch -D feature/linked >/dev/null

# gac: dry-run changes nothing; apply removes only managed worktrees.
agent_repo=$(create_repo agent-repo)
agent_parent="$test_dir/agent-repo-worktrees"
mkdir -p "$agent_parent"
git -C "$agent_repo" branch feature/managed
git -C "$agent_repo" branch feature/outside
git -C "$agent_repo" worktree add "$agent_parent/managed" feature/managed >/dev/null
git -C "$agent_repo" worktree add "$test_dir/outside-worktree" feature/outside >/dev/null
(
  cd "$agent_repo"
  "$GAC" >/dev/null
)
[[ -d $agent_parent/managed ]]
git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/managed
(
  cd "$agent_repo"
  "$GAC" --apply >/dev/null
)
[[ ! -e $agent_parent/managed ]]
if git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/managed; then
  printf 'gac left its managed branch.\n' >&2
  exit 1
fi
[[ -d $test_dir/outside-worktree ]]
git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/outside

# Preflight is atomic for dirty and unmerged managed worktrees.
git -C "$agent_repo" branch feature/clean
git -C "$agent_repo" worktree add "$agent_parent/clean" feature/clean >/dev/null
git -C "$agent_repo" worktree add -b feature/dirty "$agent_parent/dirty" main >/dev/null
configure_repo "$agent_parent/dirty"
git -C "$agent_parent/dirty" commit --allow-empty -m unmerged >/dev/null
touch "$agent_parent/dirty/untracked"
if (
  cd "$agent_repo"
  "$GAC" --apply >/dev/null 2>&1
); then
  printf 'gac accepted unsafe targets without --force.\n' >&2
  exit 1
fi
[[ -d $agent_parent/clean && -d $agent_parent/dirty ]]
git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/clean
git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/dirty
(
  cd "$agent_repo"
  "$GAC" --apply --force >/dev/null
)
[[ ! -e $agent_parent/clean && ! -e $agent_parent/dirty ]]
if git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/clean \
  || git -C "$agent_repo" show-ref --verify --quiet refs/heads/feature/dirty; then
  printf 'gac left a force-cleaned branch.\n' >&2
  exit 1
fi
[[ -d $test_dir/outside-worktree ]]

# Protected base branches are never removed, including with --force.
git -C "$agent_repo" switch -c feature/primary >/dev/null
git -C "$agent_repo" worktree add "$agent_parent/main" main >/dev/null
if (
  cd "$agent_repo"
  "$GAC" --apply --force >/dev/null 2>&1
); then
  printf 'gac accepted a protected base branch.\n' >&2
  exit 1
fi
[[ -d $agent_parent/main ]]
git -C "$agent_repo" show-ref --verify --quiet refs/heads/main
git -C "$agent_repo" worktree remove "$agent_parent/main"
git -C "$agent_repo" switch main >/dev/null
git -C "$agent_repo" branch -D feature/primary >/dev/null

# clp parses data without sourcing it and never requires secret files in the repo.
test_home="$test_dir/home"
claude_bin="$test_dir/claude-bin"
mkdir -p "$test_home/.config/envs/test" "$claude_bin"
cat >"$claude_bin/claude" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$ANTHROPIC_BASE_URL|$ANTHROPIC_AUTH_TOKEN|$ANTHROPIC_MODEL|$*"
EOF
chmod +x "$claude_bin/claude"
cat >"$test_home/.config/envs/test/.env" <<'EOF'
BASE_URL="https://provider.example.invalid"
API_KEY="$(touch should-not-exist)"
MODEL="example/model"
EOF
chmod 600 "$test_home/.config/envs/test/.env"
clp_output=$(HOME="$test_home" PATH="$claude_bin:$PATH" "$CLP" test --version 2>/dev/null)
# The literal command substitution verifies that clp does not source the file.
# shellcheck disable=SC2016
[[ $clp_output == 'https://provider.example.invalid|$(touch should-not-exist)|example/model|--version' ]]
[[ ! -e $test_home/should-not-exist ]]
[[ $(HOME="$test_home" "$CLP" --list) == test ]]
chmod 644 "$test_home/.config/envs/test/.env"
if HOME="$test_home" PATH="$claude_bin:$PATH" "$CLP" test >/dev/null 2>&1; then
  printf 'clp accepted a provider file without mode 600.\n' >&2
  exit 1
fi

"$ROOT_DIR/scripts/personal-bin/http" --help >/dev/null
"$ROOT_DIR/scripts/personal-bin/http-lan" --help >/dev/null 2>&1

printf 'Personal CLI smoke checks passed.\n'
