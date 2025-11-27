# Quickstart: GPU-Enabled Arena Containers

## Prerequisites

1. Ubuntu 22.04 host with an NVIDIA GPU.
2. NVIDIA driver + CUDA userspace installed (`nvidia-smi` succeeds).
3. NVIDIA Container Toolkit configured (`/etc/docker/daemon.json` enables `nvidia` runtime).
4. Docker Engine 24+ with BuildKit, Docker Compose v2, and VS Code (optional) with Remote Containers extension.
5. Clone `arena-rosnav` and check out branch `001-docker-dev-env`.

## 1. Build or Pull the Runtime Image

```bash
# from repo root
docker compose -f docker/docker-compose.gpu.yaml build --pull
```

- Uses BuildKit cache; add `--no-cache` after dependency changes.
- Injects `ARENA_ROS_VERSION=humble` and `ARENA_BRANCH=humble` during build.

## 2. Launch the Compose Stack

```bash
# start core services with GPU access
docker compose -f docker/docker-compose.gpu.yaml --profile gazebo up -d

# verify GPU is visible inside container
docker compose -f docker/docker-compose.gpu.yaml exec core nvidia-smi
```

- Profiles: `gazebo`, `isaac`, `training`. Enable only those matching your hardware/licensing.
- Logs and ROS workspace bind mount under `.arena-runtime/` (created automatically).

## 3. Run Safety KPI Smoke Tests

```bash
# from host terminal
tools/container_smoke_tests.sh configs/benchmark/configs/default.yaml

# attach interactive shell inside running container
docker compose -f docker/docker-compose.gpu.yaml exec core bash
source tools/source.bash
python testing/scripts/drl_agent_node.py --scenario benchmark/configs/default.yaml --log
```

- `tools/container_smoke_tests.sh` wraps the compose checks and KPI run; pass an alternate scenario path to evaluate other benchmarks.
- Compare collision rate and minimum distance outputs with baseline data in `configs/benchmark/`.
- Logs emitted to `/arena4_ws/log/latest`; host path `.arena-runtime/log/latest`.
- Deterministic seeds originate from `configs/task_generator.yaml`; adjust values there (and mount overrides) to reproduce benchmark runs faithfully.

## 4. VS Code Devcontainer (Optional)

```bash
code .
# Accept "Reopen in Container" prompt
```

- `.devcontainer/devcontainer.json` references the same compose file; the `core` service auto-starts.
- Start hook runs `nvidia-smi` to confirm GPU visibility; post-create command executes `tools/colcon_build --packages-skip gazebo_ros` and `poetry install --with ros` for environment parity.

## 5. Iterative Rebuild & Test Loop

1. Update installers, `docker/Dockerfile`, or compose definitions.
2. Run `tools/container_iteration.sh` to rebuild, restart, and re-run KPIs (pass additional build args as needed).
3. Execute additional validations (e.g., `docker compose -f docker/docker-compose.gpu.yaml exec core bash -lc 'colcon test'`).
4. Capture KPI outputs from `.arena-runtime/log/latest` and compare against baseline metrics stored under `configs/benchmark/`.
5. Document results in `specs/001-docker-dev-env/checklists/requirements.md` (append new review notes).

## 6. Tear Down

```bash
docker compose -f docker/docker-compose.gpu.yaml down
```

- Removes containers while preserving bind-mounted logs and install cache.
- Use `docker volume prune` if named volumes were introduced.
