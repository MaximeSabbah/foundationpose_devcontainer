# Official Isaac ROS NGC base image (requires NGC authentication: docker login nvcr.io).
# This ~500 MB image provides VPI 4, NvSci, CUDA and cuDNN on Ubuntu 24.04 Noble,
# which are proprietary NVIDIA libraries NOT available in any public apt repository.
# Without this base, ros-jazzy-isaac-ros-* packages fail to install (libnvvpi4, nvsci).
#
# Tag corresponds to Isaac ROS 4.x / release-4.2 (amd64, published 2026-02-25).
# To find newer tags: https://catalog.ngc.nvidia.com/orgs/nvidia/teams/isaac/containers/ros/tags
FROM nvcr.io/nvidia/isaac/ros:isaac_ros_740c8500df2685ab1f4a4e53852601df-amd64

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Locale — required by ROS 2
RUN apt-get update && apt-get install -y locales \
    && locale-gen en_US en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8

# System utilities and build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    software-properties-common \
    git \
    wget \
    build-essential \
    cmake \
    pkg-config \
    libssl-dev \
    libusb-1.0-0-dev \
    libgtk-3-dev \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    python3-pip \
    udev \
    && rm -rf /var/lib/apt/lists/*

# TensorRT is already included in the NGC base image.
# We only install the trtexec binary (part of tensorrt-dev) if not already present.
RUN apt-get update && apt-get install -y --no-install-recommends \
    tensorrt-dev \
    && rm -rf /var/lib/apt/lists/* || true

# ROS 2 Jazzy and Isaac ROS apt repositories are pre-configured in the NGC
# base image. Adding them again causes a Signed-By conflict. We only need to
# install the packages.
RUN apt-get update && apt-get install -y \
    ros-jazzy-ros-base \
    python3-colcon-common-extensions \
    python3-vcstool \
    python3-rosdep \
    && rm -rf /var/lib/apt/lists/*

# Isaac ROS 4.2 FoundationPose (Isaac ROS apt repo already in base image)
RUN apt-get update && apt-get install -y \
    ros-jazzy-isaac-ros-foundationpose \
    && rm -rf /var/lib/apt/lists/*

# rosdep is already initialised in the NGC base image; || true prevents failure.
RUN rosdep init || true && rosdep update

# Build and install librealsense from source (pinned to v2.55.1; supports Ubuntu 24.04)
WORKDIR /tmp
RUN git clone https://github.com/IntelRealSense/librealsense.git && \
    cd librealsense && \
    git checkout v2.55.1 && \
    mkdir build && cd build && \
    cmake .. \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_EXAMPLES=OFF \
      -DBUILD_GRAPHICAL_EXAMPLES=OFF && \
    make -j$(nproc) && \
    make install && \
    ldconfig && \
    cp /tmp/librealsense/config/99-realsense-libusb.rules /etc/udev/rules.d/ && \
    rm -rf /tmp/librealsense

# Create workspace directory structure.
# The actual workspace content (realsense-ros sources, build, install) is
# managed at devcontainer start via postCreateCommand — NOT at image build
# time — because docker-compose mounts ./workspace here at runtime.
WORKDIR /workspaces/isaac_ros_ws
RUN mkdir -p src

# build_engines.sh lives in workspace/scripts/ (volume-mounted at runtime).
# We create a wrapper in PATH that delegates to the mounted location.
RUN printf '#!/bin/bash\nexec /workspaces/isaac_ros_ws/scripts/build_engines.sh "$@"\n' \
    > /usr/local/bin/build_engines.sh && chmod +x /usr/local/bin/build_engines.sh

# Source ROS in interactive shells; workspace overlay is conditional because
# it may not exist yet on first container start.
RUN echo "source /opt/ros/jazzy/setup.bash" >> /root/.bashrc && \
    echo "[ -f /workspaces/isaac_ros_ws/install/setup.bash ] && source /workspaces/isaac_ros_ws/install/setup.bash" >> /root/.bashrc

WORKDIR /workspaces/isaac_ros_ws

CMD ["bash"]