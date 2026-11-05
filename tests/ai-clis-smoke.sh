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
  printf 'npm exclusion=%s before=%s args=%s\n' "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" "${npm_config_before:-}" "$*" >>"$TEST_INSTALL_LOG"
  if [[ $* == 'install --global --ignore-scripts @openai/codex' ]]; then
    cat >"$HOME/.local/bin/codex" <<'SCRIPT'
#!/usr/bin/env bash
printf 'codex-cli 0.148.0\n'
SCRIPT
    chmod +x "$HOME/.local/bin/codex"
    return 0
  fi
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
      npm:pi-web-access|npm:pi-codex-image-gen|npm:@howaboua/pi-codex-conversion|npm:@ogulcancelik/pi-session-recall) ;;
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
  *claude.ai*) name=claude; version='2.1.314 (Claude Code)' ;;
  *opencode.ai*) name=opencode; version='opencode v2.2.2' ;;
  *) exit 98 ;;
esac
printf 'curl %s exclusion=%s\n' "$name" "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" >>"$TEST_INSTALL_LOG"
# Hand the installer to the caller so the smoke test still exercises the
# download-and-run path; the installer writes the CLI the summary reads.
cat <<SCRIPT
mkdir -p "\$HOME/.local/bin"
cat >"\$HOME/.local/bin/${name}" <<'INNER'
#!/usr/bin/env bash
printf '%s\\n' '${version}'
INNER
chmod +x "\$HOME/.local/bin/${name}"
SCRIPT
EOF
chmod +x "$test_bin/node" "$test_bin/npm" "$test_bin/curl"

mkdir -p "$HOME/.pi/agent/extensions"
printf '%s\n' '{"packages":["npm:existing"],"unmanaged":{"keep":true}}' \
  >"$HOME/.pi/agent/settings.json"
printf '%s\n' 'export default {}' >"$HOME/.pi/agent/extensions/herdr-agent-state.ts"

"$ROOT_DIR/scripts/update-ai" >"$test_dir/update-ai.out"

# Every installer prints its own version shape, so the summary must label each
# tool and normalize the version the same way.
cmp <(printf '%s\n' '==> AI CLI versions' 'pi 0.84.2' 'codex 0.148.0' 'claude 2.1.314' 'opencode 2.2.2') \
  <(sed -n '/^==> AI CLI versions$/,$p' "$test_dir/update-ai.out")

# The Pi core install skips the Safe-chain minimum package age gate and keeps
# the malware scan, so it must not resolve against npm_config_before.
grep -Fqx 'npm exclusion= before= args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest --safe-chain-skip-minimum-package-age' "$log"
# Codex keeps the age gate and resolves against its cutoff, without bypassing
# Safe-chain or running lifecycle scripts.
grep -Eq '^npm exclusion= before=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z args=install --global --ignore-scripts @openai/codex$' "$log"
grep -Fqx 'pi install npm:pi-web-access --no-approve' "$log"
grep -Fqx 'pi install npm:pi-codex-image-gen --no-approve' "$log"
grep -Fqx 'pi install npm:@howaboua/pi-codex-conversion --no-approve' "$log"
grep -Fqx 'pi install npm:@ogulcancelik/pi-session-recall --no-approve' "$log"
[[ -e "$HOME/.pi/agent/extensions/herdr-agent-state.ts" ]]
[[ ! -e "$HOME/.pi/agent/web-search.json" ]]
[[ ! -e "$HOME/.pi/agent/extensions/codex-image-gen.json" ]]
[[ ! -e "$HOME/.pi/agent/generated-images" ]]
jq -e '
  .packages == ["npm:existing", "npm:pi-web-access", "npm:pi-codex-image-gen", "npm:@howaboua/pi-codex-conversion", "npm:@ogulcancelik/pi-session-recall"]
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
grep -Fq '  "update": "disable"' "$ROOT_DIR/home/dot_config/opencode/opencode.json"
grep -Fqx 'export DISABLE_AUTOUPDATER=1' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"
# shellcheck disable=SC2016
grep -Fqx 'export PATH="$HOME/.opencode/bin:$PATH"' "$ROOT_DIR/home/dot_config/workstation/shell/init.bash"

# Selective flag behavior: only the requested tool(s) are invoked.
for flag in claude codex opencode pi; do
  flag_test_dir="$(mktemp -d)"
  flag_home="$flag_test_dir/home"
  flag_bin="$flag_test_dir/bin"
  flag_log="$flag_test_dir/install.log"
  mkdir -p "$flag_home/.safe-chain/scripts" "$flag_home/.local/bin" "$flag_bin"
  export HOME="$flag_home" PATH="$flag_bin:$flag_home/.local/bin:$PATH" TEST_INSTALL_LOG="$flag_log"

  cat >"$flag_home/.safe-chain/scripts/init-posix.sh" <<EOF
npm() {
  printf 'npm exclusion=%s before=%s args=%s\n' "\${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" "\${npm_config_before:-}" "\$*" >>"\$TEST_INSTALL_LOG"
  if [[ \$* == 'install --global --ignore-scripts @openai/codex' ]]; then
    cat >"\$HOME/.local/bin/codex" <<'SCRIPT'
#!/usr/bin/env bash
printf 'codex-cli 0.148.0\n'
SCRIPT
    chmod +x "\$HOME/.local/bin/codex"
    return 0
  fi
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
      npm:pi-web-access|npm:pi-codex-image-gen|npm:@howaboua/pi-codex-conversion|npm:@ogulcancelik/pi-session-recall) ;;
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
  *claude.ai*) name=claude; version='2.1.314 (Claude Code)' ;;
  *opencode.ai*) name=opencode; version='opencode v2.2.2' ;;
  *) exit 98 ;;
esac
printf 'curl %s exclusion=%s\n' "$name" "${SAFE_CHAIN_MINIMUM_PACKAGE_AGE_EXCLUSIONS:-}" >>"$TEST_INSTALL_LOG"
# Hand the installer to the caller so the smoke test still exercises the
# download-and-run path; the installer writes the CLI the summary reads.
cat <<SCRIPT
mkdir -p "\$HOME/.local/bin"
cat >"\$HOME/.local/bin/${name}" <<'INNER'
#!/usr/bin/env bash
printf '%s\\n' '${version}'
INNER
chmod +x "\$HOME/.local/bin/${name}"
SCRIPT
EOF
  chmod +x "$flag_bin/npm" "$flag_bin/curl"

  "$ROOT_DIR/scripts/update-ai" "--$flag" >"$flag_test_dir/update-ai.out"

  # The summary contains exactly the selected CLI, not installed but unselected tools.
  [[ $(sed -n '/^==> AI CLI versions$/,$p' "$flag_test_dir/update-ai.out" | wc -l) -eq 2 ]]
  grep -Eq "^$flag [0-9]+[.][0-9]+[.][0-9]+$" "$flag_test_dir/update-ai.out"

  case "$flag" in
    pi)
      grep -Fqx 'npm exclusion= before= args=install --global --ignore-scripts @earendil-works/pi-coding-agent@latest --safe-chain-skip-minimum-package-age' "$flag_log"
      grep -Fqx 'pi install npm:pi-web-access --no-approve' "$flag_log"
      grep -Fqx 'pi install npm:pi-codex-image-gen --no-approve' "$flag_log"
      grep -Fqx 'pi install npm:@howaboua/pi-codex-conversion --no-approve' "$flag_log"
      grep -Fqx 'pi install npm:@ogulcancelik/pi-session-recall --no-approve' "$flag_log"
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
      if grep -Fq 'args=install --global --ignore-scripts @openai/codex' "$flag_log"; then
        printf 'pi flag should not install Codex.\n' >&2
        exit 1
      fi
      ;;
    codex)
      grep -Eq '^npm exclusion= before=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z args=install --global --ignore-scripts @openai/codex$' "$flag_log"
      [[ $(wc -l <"$flag_log") -eq 1 ]]
      [[ ! -e "$HOME/.pi/agent/settings.json" ]]

      # A custom age changes the cutoff; malformed values must fail before npm
      # is called rather than accidentally install without an age cutoff.
      earliest_cutoff=$(( $(date +%s) - 11 * 3600 ))
      SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=10 "$ROOT_DIR/scripts/update-ai" --codex >/dev/null
      latest_cutoff=$(( $(date +%s) - 11 * 3600 ))
      cutoff="$(tail -n 1 "$flag_log" | sed -E 's/^npm exclusion= before=([^ ]+) args=.*/\1/')"
      cutoff_epoch="$(date -u -d "$cutoff" +%s)"
      ((earliest_cutoff <= cutoff_epoch && cutoff_epoch <= latest_cutoff))
      [[ $(wc -l <"$flag_log") -eq 2 ]]
      if SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS=48h "$ROOT_DIR/scripts/update-ai" --codex \
        >"$flag_test_dir/invalid-age.out" 2>&1; then
        printf 'Codex must reject an invalid Safe-chain age.\n' >&2
        exit 1
      fi
      grep -Fq 'SAFE_CHAIN_MINIMUM_PACKAGE_AGE_HOURS must be a whole number of hours' \
        "$flag_test_dir/invalid-age.out"
      [[ $(wc -l <"$flag_log") -eq 2 ]]
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
