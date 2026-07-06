#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -eq 0 ]]; then
  printf 'Run this smoke test as the configured regular user.\n' >&2
  exit 1
fi

if ! id -nG | tr ' ' '\n' | grep -Fxq docker; then
  printf 'The current session has not picked up docker group membership. Reconnect to WSL and retry.\n' >&2
  exit 1
fi

systemctl is-enabled --quiet containerd.service
systemctl is-active --quiet containerd.service
systemctl is-enabled --quiet docker.service
systemctl is-active --quiet docker.service

[[ $(docker context show) == default ]] || {
  printf 'Docker must use the local default context, not Docker Desktop.\n' >&2
  exit 1
}

docker info >/dev/null
docker buildx version >/dev/null
docker buildx inspect default >/dev/null
docker compose version >/dev/null
docker run --rm hello-world >/dev/null

test_dir=$(mktemp -d)
readonly test_dir
readonly project_name="workstation-config-smoke-$$"
cleanup() {
  docker compose --project-directory "$test_dir" --project-name "$project_name" down \
    --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -rf "$test_dir"
}
trap cleanup EXIT

cat >"$test_dir/compose.yaml" <<'EOF'
services:
  smoke:
    image: hello-world
EOF

docker compose --project-directory "$test_dir" --project-name "$project_name" config --quiet
docker compose --project-directory "$test_dir" --project-name "$project_name" run --rm smoke >/dev/null

printf 'Docker smoke checks passed.\n'
