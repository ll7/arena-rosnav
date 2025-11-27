# Arena ROSNav dev container images

The main Dockerfile now has a reusable `base` stage (ROS + installers) and a thin `core` stage for the devcontainer runtime. Build the heavy base layer once locally, reuse it for fast `docker compose`/devcontainer start-ups, and rebuild only when you actually change the installers.

## Build locally once

```bash
# Build the heavy base layer for caching and debugging
./docker/build-core-image.sh --base-only

# Build the runtime image that devcontainer/docker compose will start
./docker/build-core-image.sh
```

Defaults:
- Base image tag: `arena-rosnav/core-base:${ARENA_ROS_VERSION:-humble}`
- Runtime tag: `arena-rosnav/core:dev`
- ROS distro/branch: `ARENA_ROS_VERSION` / `ARENA_BRANCH` env vars

## Point docker compose/devcontainer at your cached base

Create `docker/.env` (or export env vars) so the compose build uses your prebuilt base layer and skips reinstalling ROS each time:

```bash
cp docker/.env.example docker/.env
```

`ARENA_BASE_IMAGE` in that file should match the base tag you built. With it set, `docker compose -f docker/docker-compose.gpu.yaml build core` (used by the devcontainer) only stitches the final stage together and starts quickly.

## Debugging the build

- Use `./docker/build-core-image.sh --base-only` to iterate on the heavy stage without touching the runtime image.
- Add `ARENA_ROS_VERSION`, `ARENA_BRANCH`, or `ARENA_IMAGE` overrides as needed for testing.
