#!/usr/bin/env bash
set -euo pipefail

# container_iteration.sh
# Rebuilds the Arena container image, restarts the compose stack, and executes the KPI smoke tests.

COMPOSE_FILE=${COMPOSE_FILE:-docker/docker-compose.gpu.yaml}
SERVICE=${SERVICE:-core}
SCENARIO_PATH=${SCENARIO_PATH:-configs/benchmark/configs/default.yaml}

if [ ! -f "${COMPOSE_FILE}" ]; then
  echo "Compose file ${COMPOSE_FILE} not found" >&2
  exit 1
fi

echo "[arena] Rebuilding image..."
docker compose -f "${COMPOSE_FILE}" build "$@"

echo "[arena] Restarting stack..."
docker compose -f "${COMPOSE_FILE}" down
mkdir -p .arena-runtime/install .arena-runtime/log .arena-runtime/cache/pip

docker compose -f "${COMPOSE_FILE}" up -d

echo "[arena] Running KPI smoke test..."
SERVICE=${SERVICE} COMPOSE_FILE=${COMPOSE_FILE} tools/container_smoke_tests.sh "${SCENARIO_PATH}"

echo "[arena] Iteration complete. Review .arena-runtime/log/latest for KPI outputs."
