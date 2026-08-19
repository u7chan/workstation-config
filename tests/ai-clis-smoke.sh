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
  cat >"$HOME/.local/bin/pi" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
package_settings="$HOME/.pi/agent/settings.json"
case "${1:-}" in
  --version)
    printf '0.84.2\n'
    ;;
  list)
    if [[ -f $package_settings ]] && \
      jq -e '((.packages? // []) | type == "array" and length > 0)' \
        "$package_settings" >/dev/null; then
      printf 'User packages:\n'
      jq -r '.packages[] | "  " + .' "$package_settings"
    else
      printf 'No packages installed.\n'
    fi
    ;;
  install|update)
    case "${2:-}" in
      npm:pi-web-access|npm:pi-codex-image-gen|npm:@howaboua/pi-codex-conversion) ;;
      *)
        printf 'unexpected Pi package source: %s\n' "${2:-}" >&2
        exit 1
        ;;
    esac
    printf 'pi %s\n' "$*" >>"$TEST_INSTALL_LOG"
    mkdir -p -- "${package_settings%/*}"
    temporary_path="$(mktemp "${package_settings}.tmp.XXXXXXXXXX")"
    if [[ -f $package_settings ]]; then
      jq --arg source "${2}" '
        .packages = (
          if (.packages? | type) == "array" then .packages else [] end
          | if index($source) == null then . + [$source] else . end
        )
      ' "$package_settings" >"$temporary_path"
    else
      jq -n --arg source "${2}" '{packages: [$source]}' >"$temporary_path"
    fi
    mv -- "$temporary_path" "$package_settings"
    ;;
  *)
    printf 'unexpected pi command: %s\n' "$*" >&2
    exit 1
    ;;
esac
SCRIPT
  chmod +x "$HOME/.local/bin/pi"
}
EOF

cat >"$test_bin/npm" <<'EOF'
#!/usr/bin/env bash
exit 99
EOF
cat >"$test_bin/node" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == --version ]]; then
  printf 'v24.18.0\n'
else
  exit 99
fi
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

mkdir -p "$HOME/.pi/agent/extensions"
printf '%s\n' '{"packages":["npm:existing"],"unmanaged":{"keep":true}}' \
  >"$HOME/.pi/agent/settings.json"
printf '%s\n' 'export default {}' >"$HOME/.pi/agent/extensions/herdr-agent-state.ts"

"$ROOT_DIR/scripts/update-ai" >/dev/null

grep -Fqx 'npm exclusion=@openai/codex args=install --global @openai/codex@latest' "$log"
grep -Fqx 'npm exclusion=@earendil-works/* args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest' "$log"
grep -Fqx 'pi install npm:pi-web-access --no-approve' "$log"
grep -Fqx 'pi install npm:pi-codex-image-gen --no-approve' "$log"
grep -Fqx 'pi install npm:@howaboua/pi-codex-conversion --no-approve' "$log"
[[ -e "$HOME/.pi/agent/extensions/herdr-agent-state.ts" ]]
[[ ! -e "$HOME/.pi/web-search.json" ]]
[[ ! -e "$HOME/.pi/agent/extensions/codex-image-gen.json" ]]
[[ ! -e "$HOME/.pi/agent/generated-images" ]]
jq -e '
  .packages == ["npm:existing", "npm:pi-web-access", "npm:pi-codex-image-gen", "npm:@howaboua/pi-codex-conversion"]
  and .unmanaged.keep == true
  and .npmCommand == ["mise", "exec", "node", "--", "safe-chain", "npm"]
' "$HOME/.pi/agent/settings.json" >/dev/null
jq -e '
  .tools.webRun == false
  and .tools.imageGeneration == false
  and .tools.webRunOnly == false
  and .tools.imageGenerationOnly == false
' "$HOME/.pi/agent/pi-codex-conversion.json" >/dev/null
grep -Fqx 'curl claude exclusion=' "$log"
grep -Fqx 'curl opencode exclusion=' "$log"
grep -Fq '  "autoupdate": false' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
grep -Fqx 'export DISABLE_AUTOUPDATER=1' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
# shellcheck disable=SC2016
grep -Fqx 'export PATH="$HOME/.opencode/bin:$PATH"' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"

# Selective flag behavior: only the requested tool(s) are invoked.
for flag in codex claude opencode pi; do
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
  cat >"\$HOME/.local/bin/pi" <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
package_settings="\$HOME/.pi/agent/settings.json"
case "\${1:-}" in
  --version)
    printf '0.84.2\n'
    ;;
  list)
    if [[ -f \$package_settings ]] && jq -e '((.packages? // []) | type == "array" and length > 0)' "\$package_settings" >/dev/null; then
      printf 'User packages:\\n'
      jq -r '.packages[] | "  " + .' "\$package_settings"
    else
      printf 'No packages installed.\\n'
    fi
    ;;
  install|update)
    case "\${2:-}" in
      npm:pi-web-access|npm:pi-codex-image-gen|npm:@howaboua/pi-codex-conversion) ;;
      *)
        printf 'unexpected Pi package source: %s\\n' "\${2:-}" >&2
        exit 1
        ;;
    esac
    printf 'pi %s\\n' "\$*" >>"\$TEST_INSTALL_LOG"
    mkdir -p -- "\${package_settings%/*}"
    temporary_path="\$(mktemp "\${package_settings}.tmp.XXXXXXXXXX")"
    if [[ -f \$package_settings ]]; then
      jq --arg source "\${2}" '
        .packages = (
          if (.packages? | type) == "array" then .packages else [] end
          | if index(\$source) == null then . + [\$source] else . end
        )
      ' "\$package_settings" >"\$temporary_path"
    else
      jq -n --arg source "\${2}" '{packages: [\$source]}' >"\$temporary_path"
    fi
    mv -- "\$temporary_path" "\$package_settings"
    ;;
  *)
    printf 'unexpected pi command: %s\\n' "\$*" >&2
    exit 1
    ;;
esac
SCRIPT
  chmod +x "\$HOME/.local/bin/pi"
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
    pi)
      grep -Fqx 'npm exclusion=@earendil-works/* args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest' "$flag_log"
      grep -Fqx 'pi install npm:pi-web-access --no-approve' "$flag_log"
      grep -Fqx 'pi install npm:pi-codex-image-gen --no-approve' "$flag_log"
      grep -Fqx 'pi install npm:@howaboua/pi-codex-conversion --no-approve' "$flag_log"
      jq -e '
        .tools.webRun == false
        and .tools.imageGeneration == false
        and .tools.webRunOnly == false
        and .tools.imageGenerationOnly == false
      ' "$HOME/.pi/agent/pi-codex-conversion.json" >/dev/null
      if grep -Eq '^curl ' "$flag_log"; then
        printf 'pi flag should not invoke curl.\n' >&2
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
