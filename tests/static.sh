#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR

# Static checks are split into per-area files under tests/static/. Each area
# file exposes named stages, and this runner schedules every stage in the
# exact statement order of the original single-file script, so fail-fast
# still surfaces the same first failure as before. Comments reference the
# physical line numbers of the original tests/static.sh (6b80f01), verified
# with `git show 6b80f01:tests/static.sh | nl -ba`; blank lines are skipped.
run() {
  local file="$1" stage="$2"
  printf '[static] %s %s\n' "$file" "$stage"
  "$ROOT_DIR/tests/static/$file" "$stage"
}

run bootstrap.sh syntax                  # 旧L8-9
run docs.sh links                        # 旧L11-21
run bootstrap.sh vars                    # 旧L23-25
run claude.sh settings                   # 旧L26-30
run mise.sh config                       # 旧L31-50
run pi.sh keybindings                    # 旧L51-58
run pi.sh config                         # issue #174: models.json管理
run pi.sh web-search                     # issue #182: web-search.json create配布
run bootstrap.sh ci-workflow             # 旧L59
run mise.sh ansible-base                 # 旧L60-71
run smoke.sh syntax-tools                # 旧L72-74
run update-ai.sh syntax                  # 旧L75
run smoke.sh syntax-ai                   # 旧L76-80
run claude.sh syntax                     # 旧L81
run smoke.sh syntax-more                 # 旧L82-88
run personal.sh syntax                   # 旧L89
run smoke.sh syntax-update               # 旧L90
run personal.sh role                     # 旧L91-104
run mise.sh yazi                         # 旧L106-115
run shell-init.sh syntax-bashrc          # 旧L117
run gitconfig.sh syntax                  # 旧L118
run shell-init.sh syntax-init            # 旧L119
run herdr.sh syntax-status               # 旧L120-121 + status-resources.sh追加
run herdr.sh syntax-wsl-restart          # 旧L122
run ansible.sh wsl-workaround            # 旧L124-134
run shell-init.sh mise-activate          # 旧L136-137
run update-ai.sh safe-chain-and-greps    # 旧L138-184
run pi.sh base-role-guard                # 旧L185-190
run mise.sh base-role-order              # 旧L191-194
run smoke.sh run                         # 旧L195-201
run shell-init.sh autoupdate             # 旧L202-203
run docs.sh pi-packages                  # 旧L204-240
run herdr.sh wsl-restart-greps           # 旧L241-245
run herdr.sh config                      # 旧L246-259
run codex.sh config                      # 旧L260-262
run cagent.sh config                     # 旧L263-280
run herdr.sh runtime-data                # 旧L281-292
run pi.sh runtime-data                   # 旧L293-298
run ansible.sh vars-git                  # 旧L300
run mise.sh gh                           # 旧L301
run ansible.sh vars-packages             # 旧L302-303
run docker.sh docker                     # 旧L305-316
run bootstrap.sh sudo-env                # 旧L317-330
run windows-terminal.sh doc-json         # 旧L332-378
run gitconfig.sh suite                   # 旧L380-441
run shell-init.sh bashrc-suite           # 旧L443-485
run bootstrap.sh invalid-profile         # 旧L487-490
run lint.sh lint                         # 旧L492-543

printf 'Static checks passed.\n'
