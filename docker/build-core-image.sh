#!/usr/bin/env bash
set -euo pipefail

# Helper to build and reuse the heavy base layer locally before starting the devcontainer.
# Example: ./docker/build-core-image.sh            # build base + runtime images
#          ./docker/build-core-image.sh --base-only # only build the base stage for debugging

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKERFILE="${ROOT_DIR}/docker/Dockerfile"

ARENA_ROS_VERSION=${ARENA_ROS_VERSION:-humble}
ARENA_BRANCH=${ARENA_BRANCH:-humble}
INSTALLERS_PATH=${INSTALLERS_PATH:-/opt/arena/installers}
ARENA_BASE_IMAGE=${ARENA_BASE_IMAGE:-arena-rosnav/core-base:${ARENA_ROS_VERSION}}
ARENA_IMAGE=${ARENA_IMAGE:-arena-rosnav/core:dev}

BASE_ONLY=false
NO_CACHE=false

usage() {
  cat <<'EOF'
Usage: ./docker/build-core-image.sh [--base-only] [--no-cache]

Builds the heavy "base" stage (ROS + installers) once and then a thin runtime image
that the devcontainer/compose setup can start quickly.

Environment overrides:
  ARENA_ROS_VERSION   ROS 2 distro to install (default: humble)
  ARENA_BRANCH        Arena branch passed into installers (default: humble)
  ARENA_BASE_IMAGE    Tag to use for the cached base layer (default: arena-rosnav/core-base:${ARENA_ROS_VERSION})
  ARENA_IMAGE         Tag for the final runtime image (default: arena-rosnav/core:dev)
  INSTALLERS_PATH     Path inside the image where installers are copied (default: /opt/arena/installers)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-only)
      BASE_ONLY=true
      ;;
    --no-cache)
      NO_CACHE=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

export DOCKER_BUILDKIT=${DOCKER_BUILDKIT:-1}

BASE_BUILD_ARGS=(
  docker build
  --progress=auto
  --target base
  --build-arg "ARENA_ROS_VERSION=${ARENA_ROS_VERSION}"
  --build-arg "ARENA_BRANCH=${ARENA_BRANCH}"
  --build-arg "INSTALLERS_PATH=${INSTALLERS_PATH}"
  -t "${ARENA_BASE_IMAGE}"
  -f "${DOCKERFILE}"
)

RUNTIME_BUILD_ARGS=(
  docker build
  --progress=auto
  --build-arg "BASE_IMAGE=${ARENA_BASE_IMAGE}"
  --build-arg "ARENA_ROS_VERSION=${ARENA_ROS_VERSION}"
  --build-arg "ARENA_BRANCH=${ARENA_BRANCH}"
  --build-arg "INSTALLERS_PATH=${INSTALLERS_PATH}"
  -t "${ARENA_IMAGE}"
  -f "${DOCKERFILE}"
)

if [[ "${NO_CACHE}" == "true" ]]; then
  BASE_BUILD_ARGS+=(--no-cache)
  RUNTIME_BUILD_ARGS+=(--no-cache)
fi

echo "Building base image: ${ARENA_BASE_IMAGE}"
"${BASE_BUILD_ARGS[@]}" "${ROOT_DIR}"

if [[ "${BASE_ONLY}" == "true" ]]; then
  exit 0
fi

echo "Building runtime image from base: ${ARENA_IMAGE}"
"${RUNTIME_BUILD_ARGS[@]}" "${ROOT_DIR}"
