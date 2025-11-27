#!/bin/bash -i
set -e

_RCFILE="${RCFILE:-$HOME/.$(ps -p $$ -o comm=)rc}"
if [ -z "${RCFILE+x}" ]; then
  echo "${_RCFILE}"
  if [ ! -f "${_RCFILE}" ] ; then
    echo RCFILE is not set, failed to autodetect
    echo pass manually using 'RCFILE=/my/rcfile sh install.sh'
    exit 1
  else
    echo "detected rcfile as ${_RCFILE}"
  fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export ARENA_ROSNAV_REPO=${ARENA_ROSNAV_REPO:-arena-rosnav/arena-rosnav}
export ARENA_BRANCH=${ARENA_BRANCH:-humble}
export ARENA_ROS_DISTRO=${ARENA_ROS_DISTRO:-humble}
export ARENA_NON_INTERACTIVE=${ARENA_NON_INTERACTIVE:-0}
export ARENA_USE_LOCAL_REPO=${ARENA_USE_LOCAL_REPO:-0}
export ARENA_FORCE_CLONE=${ARENA_FORCE_CLONE:-0}

sanitize_repos_file() {
  local file="$1"
  if [ -f "$file" ] && grep -qE 'version: .*@[0-9a-f]{7,40}' "$file"; then
    # Drop the "branch@" prefix and keep the pinned commit SHA (branch@<sha> -> <sha>)
    sed -E -i 's/(version:[[:space:]]*)[^[:space:]]+@([0-9a-f]{7,40})/\\1\\2/' "$file"
  fi
}

prompt_with_default(){
  local prompt="$1"
  local default_value="$2"
  local response

  if [ "${ARENA_NON_INTERACTIVE}" = "1" ]; then
    echo "${default_value}"
    return
  fi

  read -rp "${prompt}" response
  echo "${response:-${default_value}}"
}

# == read inputs ==
echo 'Configuring arena-rosnav...'

ARENA_WS_DIR=${ARENA_WS_DIR:-~/arena4_ws}
INPUT=$(prompt_with_default "arena-rosnav workspace directory [${ARENA_WS_DIR}] " "${ARENA_WS_DIR}")
ARENA_WS_DIR=$(realpath "$(eval echo "${INPUT:-${ARENA_WS_DIR}}")")
export ARENA_WS_DIR

echo "installing ${ARENA_ROSNAV_REPO}:${ARENA_BRANCH} on ROS2 ${ARENA_ROS_DISTRO} to ${ARENA_WS_DIR}"
sudo echo 'confirmed'
mkdir -p "$ARENA_WS_DIR"
cd "$ARENA_WS_DIR"

export INSTALLED="${ARENA_WS_DIR}/src/arena/arena-rosnav/.installed"

# == remove ros problems ==
files=$( (grep -l "/ros" /etc/apt/sources.list.d/* | grep -v "ros2") || echo '')

if [ -n "$files" ]; then
    echo "The following files can cause some problems to installer:"
    echo "$files"
    choice=$(prompt_with_default "Do you want to delete these files? (Y/n) [Y]: " "Y")

    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        sudo rm -f $files
        echo "Deleted $files"
    fi
    unset choice
fi

# == python deps ==

# pyenv
if [ ! -d "$HOME/.pyenv" ] ; then
  rm -rf "$HOME/.pyenv"
  curl https://pyenv.run | "$(ps -p $$ -o comm=)"
  {     echo 'export PYENV_ROOT="$HOME/.pyenv"';
        echo '[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"';
        echo 'eval "$(pyenv init -)"';
  } >> "${_RCFILE}"
  
  . "${_RCFILE}"

  # resourcing does not work in the same shell
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)"

  which pyenv || (echo 'open a completely new shell'; exit 1)
fi

# Poetry
if ! which poetry ; then
  echo "Installing Poetry...:"
  curl -sSL https://install.python-poetry.org | python3 -
  if ! grep -q 'export PATH="$HOME/.local/bin"' "${_RCFILE}"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${_RCFILE}"
    . "${_RCFILE}"
  fi
  "$HOME/.local/bin/poetry" config virtualenvs.in-project true
fi

# == compile ros ==


sudo add-apt-repository universe -y
sudo apt-get update || echo 0
sudo apt-get install -y curl

# Gazebo (Ignition/Fortress) repo for simulation deps (irobot/turtlebot, nav2 map server plugins)
if [ ! -f /etc/apt/sources.list.d/gazebo-stable.list ] ; then
  echo "Adding OSRF Gazebo apt repository..."
  sudo wget -qO /usr/share/keyrings/gazebo-archive-keyring.gpg https://packages.osrfoundation.org/gazebo.key
  echo "deb [signed-by=/usr/share/keyrings/gazebo-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list >/dev/null
fi
sudo apt-get update || echo 0

echo "Installing tzdata...:"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get install -y tzdata libompl-dev
sudo dpkg-reconfigure --frontend noninteractive tzdata

# ROS
echo "Setting up ROS2 ${ARENA_ROS_DISTRO}..."

# sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo "$UBUNTU_CODENAME") main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null


# for building python
echo "Installing Python deps..." 
sudo apt-get install -y build-essential python3-pip zlib1g-dev libffi-dev libssl-dev libbz2-dev libreadline-dev libsqlite3-dev liblzma-dev libncurses-dev tk-dev python3-dev g++-9 gcc-9

if [ ! -d src/arena/arena-rosnav/tools ] ; then
  mkdir -p src/arena/arena-rosnav/tools
  pushd src/arena/arena-rosnav/tools
    curl "https://raw.githubusercontent.com/${ARENA_ROSNAV_REPO}/${ARENA_BRANCH}/tools/poetry_install" > poetry_install
    curl "https://raw.githubusercontent.com/${ARENA_ROSNAV_REPO}/${ARENA_BRANCH}/tools/colcon_build" > colcon_build
    curl "https://raw.githubusercontent.com/${ARENA_ROSNAV_REPO}/${ARENA_BRANCH}/tools/source.bash" > source.bash
  popd
fi

if [ ! -f "${ARENA_WS_DIR}/src/arena/arena-rosnav/pyproject.toml" ] ; then
  #python env
  
  mkdir -p src/arena/arena-rosnav
  pushd src/arena/arena-rosnav
    curl "https://raw.githubusercontent.com/${ARENA_ROSNAV_REPO}/${ARENA_BRANCH}/pyproject.toml" > pyproject.toml
  popd
fi
. src/arena/arena-rosnav/tools/poetry_install

# vcstool fork
python -m pip install git+https://github.com/voshch/vcstool.git
alias vcs='$HOME/.pyenv/shims/vcs' # avoid reopening shell

# Getting Packages
echo "Installing deps...:"
sudo apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    libasio-dev \
    libtinyxml2-dev \
    libcunit1-dev \
    libpcl-dev \
    libboost-python-dev \
    python3-rosdep \
    libgps-dev \
    graphicsmagick \
    libgraphicsmagick1-dev \
    nlohmann-json3-dev \
    libxtensor-dev \
    libceres-dev \
    libsuitesparse-dev

# Check if the default ROS sources.list file already exists
ros_sources_list="/etc/ros/rosdep/sources.list.d/20-default.list"
if [[ -f "$ros_sources_list" ]]; then
  echo "rosdep appears to be already initialized"
  echo "Default ROS sources.list file already exists:"
  echo "$ros_sources_list"
else
  sudo rosdep init
fi

# Add local rosdep overrides for keys not in upstream (e.g., ament_python)
ROSDEP_LOCAL_SOURCE=/etc/ros/rosdep/sources.list.d/99-arena.list
if [ ! -f "${ROSDEP_LOCAL_SOURCE}" ]; then
  echo "yaml file://${SCRIPT_DIR}/rosdep-arena.yaml" | sudo tee "${ROSDEP_LOCAL_SOURCE}" >/dev/null
fi

rosdep update --rosdistro "${ARENA_ROS_DISTRO}"

if [ ! -d src/deps ] ; then
  #TODO resolve this through vcstool
  mkdir -p src/deps
  pushd src/deps
    git clone --filter=tree:0 --depth 1 https://github.com/ros-perception/pcl_msgs.git -b ros2
    git clone --filter=tree:0 --depth 1 https://github.com/rudislabs/actuator_msgs.git
    git clone --filter=tree:0 --depth 1 https://github.com/swri-robotics/gps_umd.git -b ros2-devel
    git clone --filter=tree:0 --depth 1 https://github.com/ros-perception/vision_msgs.git -b humble
    git clone --filter=tree:0 --depth 1 https://github.com/ros-perception/vision_opencv.git -b humble
  popd
fi

if [ ! -f src/ros2/compiled ] ; then
  # install ros2

  mkdir -p src/ros2
  curl "https://raw.githubusercontent.com/ros2/ros2/${ARENA_ROS_DISTRO}/ros2.repos" > ros2.repos
  vcs import src/ros2 < ros2.repos
  
  RTI_NC_LICENSE_ACCEPTED=yes \
  rosdep install \
    --from-paths src/ros2 \
    --ignore-src \
    --rosdistro "${ARENA_ROS_DISTRO}" \
    -y \
    || { echo 'rosdep failed to install all dependencies'; exit 1; }

  # fix rosidl error that was caused upstream https://github.com/ros2/rosidl/issues/822#issuecomment-2403368061
  pushd src/ros2/ros2/rosidl
    git -c user.name='Arena' -c user.email='anonymous@arena-rosnav.org' cherry-pick 654d6f5658b59009147b9fad9b724919633f38fe || echo 'already cherry picked'
  popd

  . src/arena/arena-rosnav/tools/colcon_build --paths src/ros2/*
  touch src/ros2/compiled
  
  # don't even ask
  rm -rf build/foonathan_memory_vendor
fi

# == install arena on top of ros2 ==

if [ ! -f "$INSTALLED" ] ; then
  if [ -d src/arena/arena-rosnav/.git ] && [ "${ARENA_FORCE_CLONE}" != "1" ]; then
    echo "Using existing arena-rosnav checkout (set ARENA_FORCE_CLONE=1 to re-clone)."
  else
    if [ "${ARENA_USE_LOCAL_REPO}" = "1" ] && [ -d src/arena/arena-rosnav ]; then
      echo "ARENA_USE_LOCAL_REPO=1 set but repo not found with .git; using existing contents."
    else
      if [ -d src/arena/arena-rosnav ]; then
        echo "Backing up existing arena-rosnav to src/arena/.arena-rosnav.bak"
        mv src/arena/arena-rosnav src/arena/.arena-rosnav.bak
      fi
      echo "Cloning Arena-Rosnav..."
      git clone --branch "${ARENA_BRANCH}" "https://github.com/${ARENA_ROSNAV_REPO}.git" src/arena/arena-rosnav
    fi
  fi

  ln -fs src/arena/arena-rosnav/tools/source.bash ./arena.bash
  ln -fs src/arena/arena-rosnav/tools/poetry_install .
  ln -fs src/arena/arena-rosnav/tools/colcon_build .

  . poetry_install

  # Fix upstream .repos files that pin commits as branch@sha (invalid for vcs) before import
  for repo_file in \
    "${ARENA_WS_DIR}/src/arena/arena-rosnav/.repos/arena.repos" \
    "${ARENA_WS_DIR}/src/arena/arena-rosnav/.repos/isaac.repos" \
    "${ARENA_WS_DIR}/src/arena/arena-rosnav/.repos/gazebo.repos" \
    "${ARENA_WS_DIR}/src/arena/arena-rosnav/.repos/planners.repos"
  do
    sanitize_repos_file "$repo_file"
  done
fi

vcs import src < src/arena/arena-rosnav/.repos/arena.repos
rosdep install -y \
  --from-paths src \
  --ignore-src \
  --rosdistro "$ARENA_ROS_DISTRO" \
  || { echo 'rosdep failed to install all dependencies'; exit 1; }
. poetry_install
touch "$INSTALLED"

if [ ! -d /usr/local/include/lightsfm ] ; then
  git clone https://github.com/robotics-upo/lightsfm.git lightsfm
  ( (cd lightsfm && make && sudo make install) || rm -rf lightsfm)
  rm -rf lightsfm || echo 'failed to install lightsfm'
fi

# run installers
# sudo apt upgrade

compile(){
  cd "${ARENA_WS_DIR}"
  . colcon_build #TODO get rid of this
  ARENA_ROS_DISTRO=${ARENA_ROS_DISTRO} ros2 run arena_bringup pull
  . colcon_build
}

compile

# robot dependencies

sudo apt install -y "ros-${ROS_DISTRO}-irobot-create-description"
sudo apt install -y "ros-${ROS_DISTRO}-irobot-create-msgs"

for installer in $(ls src/arena/arena-rosnav/installers | grep -E '^[0-9]+_.*.sh') ;
do 
  name=$(echo "$installer" | cut -d '_' -f 2)

  if grep -q "$name" "$INSTALLED" ; then
    echo "$name already installed"
  else
    choice=$(prompt_with_default "Do you want to install ${name}? [N] " "N")
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        . "src/arena/arena-rosnav/installers/$installer"
        compile
        echo "$name" >> "$INSTALLED"
    else
        echo "Skipping ${name} installation."
    fi
    unset choice
  fi
done


# final pass
compile

echo 'installation finished'
