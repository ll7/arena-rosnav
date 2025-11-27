# syntax=docker/dockerfile:1.7

ARG ARENA_ROS_VERSION=humble
ARG ARENA_BRANCH=humble
ARG INSTALLERS_PATH=/opt/arena/installers
ARG BASE_IMAGE=base

FROM ubuntu:22.04 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG ARENA_ROS_VERSION
ARG ARENA_BRANCH
ARG INSTALLERS_PATH

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    RTI_NC_LICENSE_ACCEPTED=yes \
    PATH=/root/.local/bin:/root/.pyenv/bin:$PATH \
    PYENV_ROOT=/root/.pyenv \
    ARENA_WS_DIR=/arena4_ws \
    ARENA_NON_INTERACTIVE=1 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

# Configure timezone early to avoid tzdata prompts
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Base packages + prerequisites for installers and ROS repositories
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      apt-transport-https \
      build-essential \
      ca-certificates \
      cmake \
      curl \
      git \
      gnupg2 \
      lsb-release \
      python3 \
      python3-dev \
      python3-pip \
      python-is-python3 \
      software-properties-common \
      sudo \
      wget \
      libbz2-dev \
      libffi-dev \
      libgdbm-dev \
      liblzma-dev \
      libncurses5-dev \
      libnss3-dev \
      libreadline-dev \
      libsqlite3-dev \
      libssl-dev \
      zlib1g-dev && \
    rm -rf /var/lib/apt/lists/*

# Add ROS 2 apt repository for Humble
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    apt-get update && \
    rm -rf /var/lib/apt/lists/*

# Copy installers bundle into the image
COPY installers/ ${INSTALLERS_PATH}/
WORKDIR ${INSTALLERS_PATH}

# Execute installers in non-interactive mode
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    --mount=type=cache,target=/root/.cache/pip \
    chmod +x install.sh && \
    ARENA_WS_DIR=${ARENA_WS_DIR} \
    ARENA_ROS_DISTRO=${ARENA_ROS_VERSION} \
    ARENA_BRANCH=${ARENA_BRANCH} \
    RCFILE=/root/.bashrc \
    bash -lc 'yes "" | bash install.sh'

# Default workspace and entrypoint shell
WORKDIR /workspace

ENV ARENA_WS_DIR=/arena4_ws \
    COLCON_HOME=/arena4_ws

CMD ["bash"]

FROM ${BASE_IMAGE} AS core

ARG ARENA_ROS_VERSION
ARG ARENA_BRANCH
ARG INSTALLERS_PATH

LABEL org.opencontainers.image.source="https://github.com/Arena-Rosnav/arena-rosnav" \
      org.opencontainers.image.description="Arena-ROSNav GPU-ready development image" \
      com.nvidia.requires-gpu="true" \
      org.arena.ros_distro="${ARENA_ROS_VERSION}" \
      org.arena.branch="${ARENA_BRANCH}" \
      org.arena.installers_path="${INSTALLERS_PATH}"

WORKDIR /workspace

ENV ARENA_WS_DIR=/arena4_ws \
    COLCON_HOME=/arena4_ws

CMD ["bash"]
