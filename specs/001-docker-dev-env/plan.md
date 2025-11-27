# Implementation Plan: Containerized Developer Experience

**Branch**: `001-docker-dev-env` | **Date**: 2025-11-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-docker-dev-env/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Deliver a GPU-enabled Arena-ROSNav development experience backed by a unified container image, docker compose stack, and VS Code devcontainer. The implementation will adapt the existing installers to run non-interactively inside the container, expose deterministic ROS 2 Humble launch workflows (including safety KPI capture), and document the iterative rebuild/test process for maintainers.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Dockerfile (OCI) + Bash (POSIX), ROS 2 Humble (Python 3.10 runtime)  
**Primary Dependencies**: ROS 2 Humble binaries, Poetry 1.x, NVIDIA Container Toolkit, Gazebo/Isaac optional installers  
**Storage**: N/A (bind-mounted workspace volumes, no persistent DB)  
**Testing**: `tools/colcon_build`, `testing/scripts/drl_agent_node.py`, container smoke tests executed via `docker compose`  
**Target Platform**: Ubuntu 22.04 host with NVIDIA GPU + Docker Engine/Compose v2  
**Project Type**: Robotics simulation infrastructure (multi-package ROS 2 workspace)  
**Performance Goals**: Containerized bringup reaches running state ≤20 minutes; VS Code devcontainer attaches ≤5 minutes; collision KPIs within ±5% baseline  
**Constraints**: Must use `--gpus all` / NVIDIA runtime, deterministic seeds, maintain installer/container alignment, avoid privileged containers beyond GPU device access  
**Scale/Scope**: Single-host developer setup supporting Arena bringup, Gazebo/Isaac simulators, and PPO training workflows

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Deterministic Simulation Integrity**: Container build will invoke installers non-interactively with fixed environment variables (`ARENA_ROS_DISTRO=humble`, pinned Poetry lock). Compose quickstart will document seed configuration (`configs/task_generator.yaml`, benchmark suites) and require regression runs comparing baseline logs stored under `configs/benchmark/`.
- **Safety-First Navigation Outcomes**: Compose workflows will expose KPI topics (`task_reset`, logged collision counts) and document verification using `testing/scripts/drl_agent_node.py` within the container. Quickstart includes steps to capture minimum distance metrics for benchmark maps.
- **Continuous Validation & ROS 2 Quality Assurance**: Plan introduces smoke-test targets (container `colcon test`, `ros2 launch arena_bringup/arena.launch.py`) plus GPU availability checks (`nvidia-smi`) executed during compose up and devcontainer bootstrap.
- **Configuration & Dependency Traceability**: Updates will touch `installers/install.sh`, `installers/1_gazebo.sh`, `docker/Dockerfile`, `docker/docker-compose.gpu.yaml`, `.devcontainer/devcontainer.json`, and supporting docs (`specs/.../quickstart.md`). All dependency changes sync with `pyproject.toml`/Poetry lock if modified.
- **Installer & Container Cohesion**: Container image and installers share sourcing logic; any installer update is mirrored in Docker build stages and documented smoke tests. Compose/devcontainer rely on the same image tag ensuring parity.

**Post-Design Re-evaluation**: Phase 1 outputs (research, data model, contracts, quickstart) preserve all constitutional requirements; no violations detected.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

ios/ or android/
```text
arena_bringup/
├── launch/
├── configs/
└── installers-interface (via scripts)

installers/
├── install.sh
├── 1_gazebo.sh
├── 2_isaac.sh
└── 3_planners.sh

tools/
├── colcon_build
├── source.bash
└── poetry_install

.devcontainer/        # to be created/updated by this feature
docker/
├── Dockerfile        # updated to match installers
└── docker-compose.gpu.yaml  # GPU-focused compose definition

specs/001-docker-dev-env/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
└── contracts/
```

**Structure Decision**: Update existing installers, relocate Docker assets under `docker/`, and add compose/devcontainer artifacts so that development, runtime, and documentation remain collocated within the repository root as shown above.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |
