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

export MISE_CONFIG_FILE="$ROOT_DIR/mise/config.toml"
export MISE_LOCKED=1
cagent_bin="$("$mise_bin" which cagent)"
[[ -x $cagent_bin ]] || {
  printf 'cagent-smoke: mise did not resolve an executable cagent binary: %s\n' "$cagent_bin" >&2
  exit 1
}

version_output="$("$cagent_bin" --version)"
[[ $version_output == 0.1.2 ]] || {
  printf 'cagent-smoke: expected version 0.1.2, got %s\n' "$version_output" >&2
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

# doctor checks command resolution only for Codex and Herdr. Keep these
# commands as inert shims so this smoke never starts an agent or model.
for bin in codex herdr; do
  cat >"$test_bin/$bin" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$test_bin/$bin"
done

config="$ROOT_DIR/home/dot_config/cagent/config.yaml"
doctor_output="$(PATH="$test_bin:$PATH" CAGENT_CONFIG="$config" "$cagent_bin" doctor)"
grep -Fq '[OK] config YAML parsed successfully' <<<"$doctor_output"
grep -Fq '[OK] codex binary found:' <<<"$doctor_output"
grep -Fq '[OK] multiplexer adapter "herdr" has start/run command templates' <<<"$doctor_output"

codex_output="$(CAGENT_CONFIG="$config" "$cagent_bin" --dry-run low)"
grep -Fq '# Resolved level: low' <<<"$codex_output"
grep -Fq '# Resolved effort: xhigh' <<<"$codex_output"
grep -Fq 'codex --model gpt-5.6-luna' <<<"$codex_output"
grep -Fq 'model_reasoning_effort=\"xhigh\"' <<<"$codex_output"

opencode_output="$(CAGENT_CONFIG="$config" "$cagent_bin" --agent opencode-go --dry-run low)"
grep -Fq '# Resolved level: low' <<<"$opencode_output"
grep -Fq 'opencode --model opencode-go/deepseek-v4-flash' <<<"$opencode_output"

alternate_config="$test_dir/opencode-go-default.yaml"
sed '0,/^default_agent: codex$/s//default_agent: opencode-go/' "$config" >"$alternate_config"
alternate_output="$(CAGENT_CONFIG="$alternate_config" "$cagent_bin" --dry-run)"
grep -Fq '# Resolved level: mid' <<<"$alternate_output"
grep -Fq 'opencode --model opencode-go/deepseek-v4-pro' <<<"$alternate_output"

printf 'cagent personal smoke checks passed: %s\n' "$cagent_bin"
