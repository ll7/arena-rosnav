#!/usr/bin/env bash
set -euo pipefail

# container_smoke_tests.sh
# Runs a minimal KPI validation workflow against the GPU-enabled compose stack.

COMPOSE_FILE=${COMPOSE_FILE:-docker/docker-compose.gpu.yaml}
SERVICE=${SERVICE:-core}
SCENARIO_PATH=${1:-configs/benchmark/configs/default.yaml}

if ! command -v docker >/dev/null 2>&1; then
    echo "docker command not found" >&2
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose plugin is required" >&2
    exit 1
fi

if [ ! -f "${COMPOSE_FILE}" ]; then
    echo "Compose file ${COMPOSE_FILE} not found" >&2
    exit 1
fi

if ! docker compose -f "${COMPOSE_FILE}" ps --status running "${SERVICE}" >/dev/null 2>&1; then
    echo "Service ${SERVICE} is not running. Start it with 'docker compose -f ${COMPOSE_FILE} up -d'" >&2
    exit 1
fi

echo "[arena] Checking GPU availability inside ${SERVICE}..."
docker compose -f "${COMPOSE_FILE}" exec "${SERVICE}" nvidia-smi >/dev/null

echo "[arena] Running KPI smoke test for scenario ${SCENARIO_PATH}..."
docker compose -f "${COMPOSE_FILE}" exec "${SERVICE}" bash -lc \
  "source tools/source.bash && python testing/scripts/drl_agent_node.py --scenario ${SCENARIO_PATH} --log"

echo "[arena] KPI logs written to .arena-runtime/log/latest"
