#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly ROOT_DIR

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
export HOME="$test_dir/home"
test_bin="$test_dir/bin"
log="$test_dir/install.log"
mkdir -p "$HOME/.safe-chain/scripts" "$HOME/.local/bin" "$test_bin"
export PATH="$test_bin:$HOME/.local/bin:$PATH"
export TEST_INSTALL_LOG="$log"

cat >"$HOME/.safe-chain/scripts/init-posix.sh" <<'EOF'
npm() {
  printf 'npm exclusion=%s args=%s\n' "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" "$*" >>"$TEST_INSTALL_LOG"
  cat >"$HOME/.local/bin/codex" <<'SCRIPT'
#!/usr/bin/env bash
printf 'codex test\n'
SCRIPT
  chmod +x "$HOME/.local/bin/codex"
}
EOF

cat >"$test_bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
cat >"$test_bin/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *claude.ai*) name=claude ;;
  *opencode.ai*) name=opencode ;;
  *) exit 98 ;;
esac
printf 'curl %s exclusion=%s\n' "$name" "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" >>"$TEST_INSTALL_LOG"
cat <<SCRIPT
mkdir -p "\$HOME/.local/bin"
printf '#!/usr/bin/env bash\\nprintf "${name} test\\\\n"\\n' >"\$HOME/.local/bin/${name}"
chmod +x "\$HOME/.local/bin/${name}"
SCRIPT
EOF
chmod +x "$test_bin/npm" "$test_bin/curl"

"$ROOT_DIR/scripts/update-ai" >/dev/null

grep -Fqx 'npm exclusion=@openai/codex args=install --global @openai/codex@latest' "$log"
grep -Fqx 'curl claude exclusion=' "$log"
grep -Fqx 'curl opencode exclusion=' "$log"
grep -Fqx '  "autoupdate": false' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
grep -Fqx 'export DISABLE_AUTOUPDATER=1' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
grep -Fqx 'export PATH="$HOME/.opencode/bin:$PATH"' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"

printf 'AI CLI smoke checks passed.\n'
