# Feature Specification: Containerized Developer Experience

**Feature Branch**: `001-docker-dev-env`  
**Created**: 2025-11-14  
**Status**: Draft  
**Input**: User description: "I don't want to install this project locally. Ideally, I want to use a docker image. Even better would be a docker image with interfaced first with a docker compose file and secondly with a .devcontainer. Look at the #file:installers folder and check if you can create such a thing. How would you iteratively build and test this? Do you require a docker mcp server to better solve this problem?"

### Environment Prerequisites

- Host machines provide an NVIDIA GPU compatible with Arena simulators (e.g., Gazebo, Isaac) and the NVIDIA Container Toolkit (`nvidia-container-toolkit`) is installed and configured so Docker defaults to the `nvidia` runtime.
- Docker Engine (with BuildKit) and Docker Compose v2 use the NVIDIA runtime to expose GPU devices to containers; documentation will reference `--gpus all` usage where applicable.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Launch Arena via Docker Compose (Priority: P1)

A robotics developer clones the repository, runs the documented docker compose command, and obtains a running Arena bringup stack without installing ROS or Python tooling on the host.

**Why this priority**: Enables contributors to evaluate Arena-ROSNav quickly, removing the highest barrier to entry (manual ROS + installer workflow).

**Independent Test**: Execute the compose workflow on a clean host with only Docker installed; verify core launch topics (e.g., `/task_generator_node/task_reset`) and safety KPIs are produced inside the container.

**Acceptance Scenarios**:

1. **Given** a host with Docker Engine, Compose v2, an NVIDIA GPU, and NVIDIA Container Toolkit configured, **When** the contributor runs the documented compose bootstrap command, **Then** the Arena container builds (or pulls) successfully, launches the default `arena_bringup/launch/arena.launch.py`, and exposes ROS 2 topics for inspection via `docker compose exec` with GPU devices visible inside the container.
2. **Given** the compose stack is running, **When** a benchmark scenario is executed using the provided deterministic seed configuration, **Then** the logged collision rate and minimum distance KPIs match the baseline gathered from a native installation within ±5%.

---

### User Story 2 - Develop inside VS Code Dev Container (Priority: P2)

A contributor opens the repository in VS Code, accepts the devcontainer prompt, and gets an interactive shell and ROS 2 toolchain that mirrors the compose runtime for coding, linting, and launching simulations.

**Why this priority**: Aligns day-to-day development with the container runtime, keeping Python, ROS, and task generator dependencies consistent across contributors.

**Independent Test**: Attach VS Code to the devcontainer defined in `.devcontainer/devcontainer.json`, open `task_generator/task_generator/task_generator_node.py`, run unit tests or `colcon` commands from the container, and confirm results mirror compose behavior.

**Acceptance Scenarios**:

1. **Given** Docker Desktop or Engine with the NVIDIA runtime enabled and the VS Code Remote Containers extension installed, **When** the repository is reopened in the provided devcontainer, **Then** Poetry environments, ROS overlays, GPU-dependent simulators, and arena-specific scripts (`tools/source.bash`, `tools/colcon_build`) are available without extra host steps.

---

### User Story 3 - Iterate on Container Image and Tests (Priority: P3)

Maintainers update the container image, rerun automated checks, and publish guidance describing how to validate planners, human simulators, and training loops inside the container stack.

**Why this priority**: Ensures the container workflow remains reproducible as installers or ROS packages evolve, and codifies the build-test cycle requested by the user.

**Independent Test**: Follow the documented iteration checklist to rebuild the image, run smoke tests (arena bringup, sample training script, Gazebo optional installer), and record outcomes in CI or manual logs.

**Acceptance Scenarios**:

1. **Given** a maintainer changes dependencies (e.g., updates `installers/1_gazebo.sh`), **When** they execute the documented rebuild and regression test commands on a GPU-enabled host, **Then** the process validates deterministic seeds, collision KPIs, confirms GPU access through the NVIDIA runtime, and publishes a summary checklist entry before merge.

---

### Edge Cases

- Compose or devcontainer startup fails when the NVIDIA runtime is unavailable; documentation must specify pre-flight checks (`nvidia-smi`, `docker run --gpus all --rm nvidia/cuda:... nvidia-smi`) and instructions for resolving missing toolkit installation.
- Deterministic seeds drift when environment variables like `ARENA_ROS_DISTRO` differ between compose, devcontainer, and native installers; workflows must pin these values and flag mismatches during tests.
- Container image drift (stale Poetry cache, missing `installers` updates) causes compose up to fail; health checks must detect missing executables (`ros2`, `colcon`) before launch.
- ROS 2 Humble DDS configuration differs between host and container (e.g., FastDDS profile from `installers/2_isaac.sh`); ensure profiles mount correctly and failures are surfaced with actionable errors.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Provide an Arena-ROSNav container image that automates the steps currently handled by `installers/install.sh`, including optional installer hooks, in a non-interactive pipeline suitable for CI and local builds.
- **FR-002**: Deliver a docker compose project that starts the Arena bringup stack, exposes ROS 2 communication channels, enables GPU access via `deploy.runtime: nvidia` (or equivalent), and documents how to toggle optional services (Gazebo, Isaac, planners) via compose profiles.
- **FR-003**: Publish host-agnostic instructions for running arena benchmarks, capturing safety KPIs, and replaying deterministic seeds entirely from within the compose environment.
- **FR-004**: Supply a `.devcontainer/devcontainer.json` that reuses the compose services (or image) so VS Code sessions inherit the same ROS 2 Humble overlay, Poetry environment, NVIDIA runtime configuration, and helper scripts as runtime containers.
- **FR-005**: Document an iterative build-and-test workflow covering image rebuilds, compose smoke tests, and devcontainer validation, including how to surface failures back to maintainers (manual checklist or CI artifact).
- **FR-006**: Ensure safety KPIs (collision rate, minimum distance) and logging conventions from native runs remain observable inside the container stack, with guidance on where metrics are emitted.
- **FR-007**: Specify deterministic configuration inputs (random seeds, `configs/task_generator.yaml`, docker image tags) required to reproduce training and benchmark runs inside containers.
- **FR-008**: Identify required updates to `installers/`, ROS 2 launch files, and support scripts (`tools/source.bash`, `tools/colcon_build`, `pyproject.toml`) so containerized and native workflows stay aligned.

### Key Entities *(include if feature involves data)*

- **Arena Runtime Image**: Encapsulates ROS 2 Humble, Arena packages, optional simulators, and Poetry environment; versioned via tags referenced by compose and devcontainer configs.
- **Arena Compose Stack**: Defines services (core arena runtime, GPU-backed simulators, persistent volumes for logs) and injected environment variables controlling seeds, planners, and KPI exports.
- **Arena Devcontainer**: VS Code Remote Container definition that maps developer tooling (shell, colcon, pytest) to the runtime image and orchestrates bind mounts for source code and cache directories.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: New contributors complete the documented compose bootstrap and reach a running Arena bringup within 20 minutes on a Docker-capable Ubuntu host (95th percentile across internal trials).
- **SC-002**: Safety KPI outputs (collision rate, minimum inter-agent distance) collected from containerized runs stay within ±5% of the baseline produced by `tools/colcon_build` + native launch across three benchmark maps.
- **SC-003**: VS Code devcontainer attachment succeeds in under 5 minutes and provides immediate access to `colcon`, `poetry`, and GPU-enabled simulators without manual intervention in 9/10 test attempts.
- **SC-004**: Maintainers follow the published iteration workflow to rebuild the image and execute smoke tests in ≤30 minutes, logging results in the accompanying checklist before merging container-related changes.

## Assumptions

- Hosts provide Docker Engine with BuildKit and an NVIDIA GPU configured via NVIDIA Container Toolkit; no dedicated Docker MCP server is required because builds run locally or in CI using standard docker/buildx flows with GPU support.
- Container workflows assume GPU availability; non-GPU environments are out of scope for this feature.
- Contributors rely on existing ROS 2 Humble assets shipped in this repository; external licensing steps (e.g., Isaac EULA acceptance) stay outside the automated compose flow but are documented.
