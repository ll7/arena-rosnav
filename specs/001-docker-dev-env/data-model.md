# Data Model

## Arena Runtime Image
- **Description**: Container image built from `docker/Dockerfile` encapsulating ROS 2 Humble, Arena packages, and optional simulator dependencies.
- **Attributes**:
  - `tag`: `<registry>/arena-rosnav:<version>`; immutable reference shared by compose and devcontainer.
  - `build_args`: `ARENA_ROS_VERSION`, `ARENA_BRANCH`; control ROS distribution and git branch.
  - `env`: `ARENA_WS_DIR`, `ARENA_ROS_DISTRO`, `PYENV_ROOT`; required during installers execution.
  - `artifacts`: `/arena4_ws/install`, `/arena4_ws/log`; mounted for persistence and KPI collection.
- **Relationships**:
  - Consumed by **Arena Compose Stack** service definitions.
  - Referenced in `.devcontainer/devcontainer.json` as build context or image source.
- **Validation Rules**:
  - Build must succeed via non-interactive installers (no prompts); failure triggers documented mitigation.
  - Image metadata must record git sha + installers revision for traceability (label injection).

## Arena Compose Stack
- **Description**: Docker Compose project orchestrating runtime services with GPU access.
- **Attributes**:
  - `services.core`: Main Arena container using the runtime image.
  - `profiles`: `gazebo`, `isaac`, `training`; enable optional installers.
  - `gpus`: `all` or explicit device list via NVIDIA runtime spec.
  - `volumes`: Bind mounts for source tree (`../:/workspace`), ROS logs, and cache directories.
  - `env_file` / `environment`: Seeds, log level, planner selections.
- **Relationships**:
  - Launches **Arena Runtime Image**; optionally coordinates auxiliary services (e.g., database mock, visualization container).
  - Shared with devcontainer configuration for consistency.
- **Validation Rules**:
  - `docker compose config` MUST succeed with documented environment variables.
  - `docker compose run` MUST expose GPU devices (`nvidia-smi` pass) before launching ROS.
  - Safety KPI scripts run inside the stack must produce log artifacts under mounted volumes.

## Arena Devcontainer
- **Description**: VS Code Remote Containers definition referencing the compose stack for interactive development.
- **Attributes**:
  - `name`: "Arena ROSNav GPU Dev".
  - `dockerComposeFile`: Path list referencing base compose and overrides (`../docker/docker-compose.gpu.yaml`).
  - `service`: Primary service to attach (e.g., `core`).
  - `workspaceFolder`: `/workspace` (bind-mounted repo).
  - `postCreateCommand`: `tools/colcon_build` smoke test or `poetry install` check.
  - `runArgs`: `--gpus=all` fallback ensuring GPU access when Compose integration unavailable.
- **Relationships**:
  - Shares environment variables and volumes with **Arena Compose Stack** ensuring deterministic runs.
  - Consumes **Arena Runtime Image** either by build or pull.
- **Validation Rules**:
  - Devcontainer reopen MUST complete without manual host configuration beyond documented prerequisites.
  - VS Code terminals must preload environment via `tools/source.bash` and display GPU availability (`nvidia-smi`).
