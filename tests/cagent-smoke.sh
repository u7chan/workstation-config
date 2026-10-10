#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR
readonly profile="${1:-personal}"

[[ $profile == base || $profile == personal ]] || {
  printf 'Usage: %s [base|personal]\n' "${BASH_SOURCE[0]}" >&2
  exit 1
}

if [[ -n ${MISE:-} ]]; then
  mise_bin="$MISE"
elif [[ -x $HOME/.local/bin/mise ]]; then
  mise_bin="$HOME/.local/bin/mise"
else
  mise_bin="$(command -v mise || true)"
fi
[[ -n $mise_bin ]] || {
  printf 'cagent-smoke: mise is not installed\n' >&2
  exit 1
}

export MISE_CONFIG_DIR="$ROOT_DIR/provisioning/mise"
export MISE_LOCKED=1
cagent_bin="$("$mise_bin" which cagent)"
[[ -x $cagent_bin ]] || {
  printf 'cagent-smoke: mise did not resolve an executable cagent binary: %s\n' "$cagent_bin" >&2
  exit 1
}

version_output="$("$cagent_bin" --version)"
[[ $version_output == 1.1.0 ]] || {
  printf 'cagent-smoke: expected version 1.1.0, got %s\n' "$version_output" >&2
  exit 1
}

if [[ $profile == base ]]; then
  printf 'cagent base smoke checks passed: %s\n' "$cagent_bin"
  exit 0
fi

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
test_bin="$test_dir/bin"
mkdir -p "$test_bin"

# doctor checks command resolution for the OpenCode agent and Herdr.
# Keep these commands as inert shims so this smoke never starts an agent/model.
for bin in opencode herdr; do
  cat >"$test_bin/$bin" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$test_bin/$bin"
done

config="$ROOT_DIR/home/dot_config/cagent/config.yaml"
doctor_output="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" doctor)"
grep -Fq '[OK] config YAML parsed successfully' <<<"$doctor_output"
grep -Fq '[OK] opencode-go binary found:' <<<"$doctor_output"
grep -Fq '[OK] profile "worker-opencode" agent "opencode-go" is defined' <<<"$doctor_output"
grep -Fq '[OK] multiplexer adapter "herdr" has start/run command templates' <<<"$doctor_output"

default_output="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" --dry-run)"
grep -Fq '# Resolved profile: orchestrator' <<<"$default_output"
grep -Fq '# Resolved agent: opencode-go' <<<"$default_output"
grep -Fq '# Resolved model: deepseek-v4-pro' <<<"$default_output"
if grep -Fq '# Resolved effort:' <<<"$default_output"; then
  printf 'cagent-smoke: the default profile must not pass an effort flag.\n' >&2
  exit 1
fi
grep -Fq 'opencode --model opencode-go/deepseek-v4-pro' <<<"$default_output"

worker_opencode_output="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" --dry-run worker-opencode)"
grep -Fq '# Resolved profile: worker-opencode' <<<"$worker_opencode_output"
grep -Fq '# Resolved agent: opencode-go' <<<"$worker_opencode_output"
grep -Fq '# Resolved model: deepseek-v4-flash' <<<"$worker_opencode_output"
if grep -Fq '# Resolved effort:' <<<"$worker_opencode_output"; then
  exit 1
fi
grep -Fq 'opencode --model opencode-go/deepseek-v4-flash' <<<"$worker_opencode_output"

orchestrator_output="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" --dry-run orchestrator)"
grep -Fq '# Resolved profile: orchestrator' <<<"$orchestrator_output"
grep -Fq '# Resolved agent: opencode-go' <<<"$orchestrator_output"
grep -Fq '# Resolved model: deepseek-v4-pro' <<<"$orchestrator_output"
if grep -Fq '# Resolved effort:' <<<"$orchestrator_output"; then
  exit 1
fi
grep -Fq 'opencode --model opencode-go/deepseek-v4-pro' <<<"$orchestrator_output"

worker_opencode_mux="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" --dry-run mux start worker-opencode)"
grep -Fq '# Resolved profile: worker-opencode' <<<"$worker_opencode_mux"
grep -Fq '# Herdr dry-run command sequence:' <<<"$worker_opencode_mux"
grep -Fq 'No Herdr command was invoked.' <<<"$worker_opencode_mux"
grep -Fq "'--model' 'opencode-go/deepseek-v4-flash'" <<<"$worker_opencode_mux"
grep -Fq 'Pane IDs shown in this plan are placeholders, not resource IDs.' <<<"$worker_opencode_mux"

orchestrator_mux="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" --dry-run mux start orchestrator)"
grep -Fq '# Resolved profile: orchestrator' <<<"$orchestrator_mux"
grep -Fq '# Herdr dry-run command sequence:' <<<"$orchestrator_mux"
grep -Fq 'No Herdr command was invoked.' <<<"$orchestrator_mux"
grep -Fq "'--model' 'opencode-go/deepseek-v4-pro'" <<<"$orchestrator_mux"
grep -Fq 'Pane IDs shown in this plan are placeholders, not resource IDs.' <<<"$orchestrator_mux"

printf 'cagent personal smoke checks passed: %s\n' "$cagent_bin"
