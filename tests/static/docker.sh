#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="${ROOT_DIR:?ROOT_DIR must be exported by tests/static.sh}"

case "${1:-}" in
  docker)
    docker_tasks="$ROOT_DIR/ansible/roles/docker_ce/tasks/main.yml"
    grep -Fq 'download.docker.com/linux/ubuntu' "$ROOT_DIR/ansible/vars/main.yml"
    for docker_package in docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; do
      grep -Fq -- "- $docker_package" "$ROOT_DIR/ansible/vars/main.yml"
    done
    grep -Fq 'containerd.service' "$docker_tasks"
    grep -Fq 'docker.service' "$docker_tasks"
    grep -Fq 'groups:' "$docker_tasks"
    grep -Fq 'personal_docker_ce_enabled | bool' "$ROOT_DIR/ansible/playbook.yml"
    grep -Fq 'docker context show' "$ROOT_DIR/tests/docker-smoke.sh"
    grep -Fq 'docker buildx version' "$ROOT_DIR/tests/docker-smoke.sh"
    grep -Fq 'docker compose' "$ROOT_DIR/tests/docker-smoke.sh"
    ;;
  *)
    printf 'Usage: %s <stage: docker>\n' "$0" >&2
    exit 2
    ;;
esac
