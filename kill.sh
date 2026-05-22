#!/usr/bin/env bash
set -euo pipefail

TASK_DIR="/root/task"

echo "[kill.sh] Stopping and removing containers..."
docker-compose -f "${TASK_DIR}/docker-compose.yml" down --volumes --remove-orphans 2>/dev/null || true

echo "[kill.sh] Pruning Docker system (containers, images, volumes, networks)..."
docker system prune -a --volumes -f

echo "[kill.sh] Removing task directory ${TASK_DIR}..."
rm -rf "${TASK_DIR}"

echo "[kill.sh] Teardown complete."
