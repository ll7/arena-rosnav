# Task Plan: Containerized Developer Experience

## Phase 1 – Setup & Environment Alignment
- [X] T001 Update container Dockerfile with non-interactive installers and GPU labels (`docker/Dockerfile`)
- [X] T002 Create GPU-focused compose definition with profiles and NVIDIA runtime (`docker/docker-compose.gpu.yaml`)
- [X] T003 Scaffold `.devcontainer/devcontainer.json` referencing compose stack and GPU runtime (`.devcontainer/devcontainer.json`)
- [X] T004 Document GPU prerequisites and quickstart flow (`specs/001-docker-dev-env/quickstart.md`)

## Phase 2 – Foundational Validation
- [X] T005 Implement container smoke test script for KPI verification (`tools/container_smoke_tests.sh`)
- [X] T006 Wire compose workflow into CI or local automation doc (`specs/001-docker-dev-env/quickstart.md`)

## Phase 3 – User Story 1: Launch Arena via Docker Compose (P1)
- Story Goal: Provide docker compose workflow that launches Arena with GPU access.
- Independent Test Criterion: `docker compose -f docker/docker-compose.gpu.yaml up` finishes with ROS topics accessible and GPU visible inside container.
- [X] T007 [US1] Update installers scripts for container compatibility (`installers/install.sh`)
- [X] T008 [US1] Ensure GPU health check command is embedded in compose startup (`docker/docker-compose.gpu.yaml`)
- [X] T009 [US1] Add documentation for compose bootstrap and KPI validation (`specs/001-docker-dev-env/quickstart.md`)

## Phase 4 – User Story 2: VS Code Devcontainer (P2)
- Story Goal: Provide VS Code devcontainer aligned with compose stack and GPU runtime.
- Independent Test Criterion: `code .` -> reopen in container loads environment with `nvidia-smi` accessible and Poetry/ROS tools available.
- [X] T010 [US2] Configure devcontainer services and workspace mounts (`.devcontainer/devcontainer.json`)
- [X] T011 [US2] Add postCreateCommands for `tools/source.bash` and sample build (`.devcontainer/devcontainer.json`)
- [X] T012 [US2] Document devcontainer workflow (`specs/001-docker-dev-env/quickstart.md`)

## Phase 5 – User Story 3: Iterative Build/Test Workflow (P3)
- Story Goal: Enable maintainers to rebuild image and run regression tests with documented steps.
- Independent Test Criterion: Rebuild + smoke tests complete in ≤30 minutes with KPI logs saved.
- [X] T013 [US3] Create iterative rebuild script or make target (`tools/container_iteration.sh`)
- [X] T014 [US3] Log retention and baseline comparison instructions (`specs/001-docker-dev-env/quickstart.md`)
- [X] T015 [US3] Update checklist template to capture new regression evidence (`specs/001-docker-dev-env/checklists/requirements.md`)

## Phase 6 – Polish & Cross-Cutting
- [X] T016 Align `.github/copilot-instructions.md` with final container workflow (`.github/copilot-instructions.md`)
- [X] T017 Final review of docs and ensure seeds/configs referenced (`specs/001-docker-dev-env/quickstart.md`)

## Dependencies
1. Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 6

## Parallel Execution Examples
- Phase 1: T001 and T002 can proceed in parallel once Docker context agreed. T003 follows.
- Phase 3: T007 must precede T008, while T009 can follow once compose is validated.
- Phase 4: T010 and T011 coupled; T012 depends on successful validation.
- Phase 5: T013 before T014; T015 can run in parallel with T014 updates once script exists.

## Implementation Strategy
- MVP Scope: Complete Phases 1–3 (compose workflow) for initial delivery.
- Incremental Delivery: Phase 4 (devcontainer) next, then Phase 5 (iteration tooling), finishing with Phase 6 polish.
