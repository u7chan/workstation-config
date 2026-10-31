#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  actions-lock)
    # workflow が使う外部 action は actions.lock で commit に固定し、workflow 側は
    # バージョン付き ref のまま保つ。lockfile が無い・ref が major のみ・verify が
    # 無い状態を CI で検出するため、存在と形だけを静的に確認する。
    lockfile="$ROOT_DIR/.github/workflows/actions.lock"
    workflow="$ROOT_DIR/.github/workflows/ci.yml"
    dependabot="$ROOT_DIR/.github/dependabot.yml"

    test -f "$lockfile"
    grep -Fq "'.github/workflows/ci.yml':" "$lockfile"
    grep -Fq "'actions/checkout@" "$lockfile"
    grep -Fq "commit: 'sha1-" "$lockfile"
    grep -Fq "owner_id: " "$lockfile"
    grep -Fq "repo_id: " "$lockfile"

    grep -Fq 'uses: actions/checkout@v6.1.0' "$workflow"
    # major のみ（@v6）の参照に戻ると、lockfile の narrow とずれる。
    if grep -Eq '^ +uses: actions/checkout@v[0-9]+$' "$workflow"; then
      printf 'ci.yml must reference actions/checkout with a version, not a major tag.\n' >&2
      exit 1
    fi
    grep -Fq 'gh actions-lock --verify' "$workflow"
    grep -Fq 'persist-credentials: false' "$workflow"
    grep -Fq 'GH_TOKEN: ${{ github.token }}' "$workflow"

    test -f "$dependabot"
    grep -Fq 'package-ecosystem: "github-actions"' "$dependabot"
    grep -Fq 'directory: "/"' "$dependabot"

    # 運用手順が docs から辿れること。手順が消えると再生成の方法が失われる。
    grep -Fq 'gh actions-lock' "$ROOT_DIR/docs/workstation.md"
    grep -Fq '.github/workflows/actions.lock' "$ROOT_DIR/docs/workstation.md"
    ;;
  *)
    printf 'Usage: %s <stage: actions-lock>\n' "$0" >&2
    exit 2
    ;;
esac
