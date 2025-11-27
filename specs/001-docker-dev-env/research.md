# Research Summary

## Decision: Base Container Strategy
- **Rationale**: Reusing the existing `installers/install.sh` flow ensures container builds stay aligned with the manual installation path mandated by Principle V. Building from `ubuntu:22.04` with ROS 2 Humble repositories matches the current `docker/Dockerfile` while enabling deterministic Poetry + ROS environments. Incorporating the NVIDIA Container Toolkit runtime at compose time rather than inside the image keeps the image portable while satisfying GPU requirements.
- **Alternatives Considered**:
  - *Prebuilt ROS 2 Humble images (`osrf/ros:humble-desktop`)*: Rejected because they diverge from the repository’s installers and would require duplicating dependency management, violating Installer & Container Cohesion.
  - *Multi-stage image separating ROS build and runtime*: Deferred; current installers already orchestrate build steps and would need refactoring to avoid duplication.

## Decision: Docker Compose GPU Enablement
- **Rationale**: Use Compose profiles with `deploy.resources.reservations.devices` (Compose v2 syntax) or `runtime: nvidia` fallback to request GPU access. This pattern matches NVIDIA’s official recommendations and keeps compatibility with both Docker CLI (`--gpus all`) and Compose while surfacing explicit GPU requirements.
- **Alternatives Considered**:
  - *Relying on `docker run` wrappers*: Not acceptable because devcontainer and compose automation require declarative GPU configuration.
  - *Embedding GPU setup in entrypoint scripts*: Adds complexity and hides host prerequisites; explicit Compose configuration is clearer for developers.

## Decision: VS Code Devcontainer Integration
- **Rationale**: Reference the compose stack via `dockerComposeFile` in `.devcontainer/devcontainer.json`, leveraging the same services for parity. Mount the repository, reuse environment variables (`ARENA_ROS_DISTRO`, `ARENA_WS_DIR`), and configure `runServices` to ensure the core arena container starts with GPU access.
- **Alternatives Considered**:
  - *Standalone devcontainer image without compose*: Rejected because it would duplicate service definitions and risk drift from the runtime stack.
  - *Remote SSH development*: Out of scope; developer request explicitly prefers container-based workflow.

## Decision: Iterative Build & Test Workflow
- **Rationale**: Adopt a three-step loop—(1) rebuild image with BuildKit caching, (2) run `docker compose up --build` smoke tests (arena bringup, KPI logging), and (3) execute `poetry run pytest` / `colcon test` within the container. This aligns with Constitution Principle III and makes regression evidence reproducible.
- **Alternatives Considered**:
  - *Rely solely on CI pipelines*: Insufficient for local iteration; developers need documented manual steps.
  - *Manual ROS launch without compose*: Contradicts request to avoid local installs and would bypass container validation.

## Decision: Safety KPI Verification Inside Container
- **Rationale**: Automate KPI collection via existing scripts (`testing/scripts/action_publisher.py`, `testing/scripts/drl_agent_node.py`) executed in the container, logging outputs to mounted volumes for comparison against baselines. Ensures Principles I and II are met within the containerized workflow.
- **Alternatives Considered**:
  - *Ad-hoc ROS topic inspection*: Not deterministic and fails to produce auditable metrics.
  - *Relying on external visualization tools only (e.g., RViz)*: Provides qualitative feedback but not the quantitative KPIs mandated by the constitution.
