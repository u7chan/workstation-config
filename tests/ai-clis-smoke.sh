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
export UPDATE_AI_MISE_ACTIVE=1

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
cat >"$test_bin/node" <<'EOF'
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
chmod +x "$test_bin/node" "$test_bin/npm" "$test_bin/curl"

"$ROOT_DIR/scripts/update-ai" >/dev/null

grep -Fqx 'npm exclusion=@openai/codex args=install --global @openai/codex@latest' "$log"
grep -Fqx 'curl claude exclusion=' "$log"
grep -Fqx 'curl opencode exclusion=' "$log"
grep -Fqx '  "autoupdate": false' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
grep -Fqx 'export DISABLE_AUTOUPDATER=1' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
grep -Fqx 'export PATH="$HOME/.opencode/bin:$PATH"' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"

# Selective flag behavior: only the requested tool(s) are invoked.
for flag in codex claude opencode; do
  flag_test_dir="$(mktemp -d)"
  flag_home="$flag_test_dir/home"
  flag_bin="$flag_test_dir/bin"
  flag_log="$flag_test_dir/install.log"
  mkdir -p "$flag_home/.safe-chain/scripts" "$flag_home/.local/bin" "$flag_bin"
  export HOME="$flag_home" PATH="$flag_bin:$flag_home/.local/bin:$PATH" TEST_INSTALL_LOG="$flag_log"

  cat >"$flag_home/.safe-chain/scripts/init-posix.sh" <<EOF
npm() {
  printf 'npm exclusion=%s args=%s\n' "\${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" "\$*" >>"\$TEST_INSTALL_LOG"
  cat >"\$HOME/.local/bin/codex" <<'SCRIPT'
#!/usr/bin/env bash
printf 'codex test\n'
SCRIPT
  chmod +x "\$HOME/.local/bin/codex"
}
EOF

  cat >"$flag_bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
  cat >"$flag_bin/curl" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *claude.ai*) name=claude ;;
  *opencode.ai*) name=opencode ;;
  *) exit 98 ;;
esac
printf 'curl %s exclusion=%s\n' "$name" "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" >>"$TEST_INSTALL_LOG"
cat <<SCRIPT
mkdir -p "\$HOME/.local/bin"
printf '#!/usr/bin/env bash\\nprintf "${name} test\\n"\\n' >"\$HOME/.local/bin/${name}"
chmod +x "\$HOME/.local/bin/${name}"
SCRIPT
EOF
  chmod +x "$flag_bin/npm" "$flag_bin/curl"

  "$ROOT_DIR/scripts/update-ai" "--$flag" >/dev/null

  case "$flag" in
    codex)
      grep -Fqx 'npm exclusion=@openai/codex args=install --global @openai/codex@latest' "$flag_log"
      if grep -Eq '^curl ' "$flag_log"; then
        printf 'codex flag should not invoke curl.\n' >&2
        exit 1
      fi
      ;;
    claude|opencode)
      grep -Fqx "curl $flag exclusion=" "$flag_log"
      if grep -Eq '^npm ' "$flag_log"; then
        printf '%s flag should not invoke npm.\n' "$flag" >&2
        exit 1
      fi
      ;;
  esac

  rm -rf "$flag_test_dir"
done

# Invalid flag should fail early.
invalid_test_dir="$(mktemp -d)"
invalid_home="$invalid_test_dir/home"
invalid_bin="$invalid_test_dir/bin"
mkdir -p "$invalid_home/.safe-chain/scripts" "$invalid_bin"
export HOME="$invalid_home" PATH="$invalid_bin:$invalid_home/.local/bin:$PATH"
cat >"$invalid_home/.safe-chain/scripts/init-posix.sh" <<'EOF'
npm() { :; }
EOF
if "$ROOT_DIR/scripts/update-ai" --invalid >/dev/null 2>&1; then
  printf 'Invalid flag should fail.\n' >&2
  exit 1
fi
rm -rf "$invalid_test_dir"

printf 'AI CLI smoke checks passed.\n'
