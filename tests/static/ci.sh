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
    grep -Fq "commit: 'sha1-" "$lockfile"
    grep -Fq "owner_id: " "$lockfile"
    grep -Fq "repo_id: " "$lockfile"

    # ci.yml の外部 action 参照。`./` と `$/` は自リポジトリ参照なので除外する。
    # 特定のリリース値は固定しない。Dependabot が action と lockfile を同時に更新する
    # ため、ここで版を決め打ちすると正しい更新 PR が失敗する。
    mapfile -t action_refs < <(
      sed -n 's/^ *uses: *\([^ #]*\).*$/\1/p' "$workflow" | grep -Ev '^(\./|\$/)' || true
    )
    if [ "${#action_refs[@]}" -eq 0 ]; then
      printf 'ci.yml has no external action reference to check.\n' >&2
      exit 1
    fi

    for ref in "${action_refs[@]}"; do
      # major のみ（@v6）やタグ以外の ref は lockfile の narrow とずれる。
      if ! [[ "$ref" =~ ^[^@]+@v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf 'ci.yml must reference %s with a full version (vX.Y.Z).\n' "$ref" >&2
        exit 1
      fi
      # 参照と lockfile の対応が崩れたら再生成を促す。
      if ! grep -Fq "'$ref'" "$lockfile"; then
        printf 'actions.lock has no entry for %s; run `gh actions-lock`.\n' "$ref" >&2
        exit 1
      fi
    done

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
