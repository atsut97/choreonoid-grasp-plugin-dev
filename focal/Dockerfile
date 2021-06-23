FROM ubuntu:focal

# Install packages to handle GPG keys.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    dirmngr \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Setup PPA to install OpenRTM-aist packages.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CC8761DEBFB5DC87CC07DC964BCE106E087AFAC0 && \
    echo "deb http://openrtm.org/pub/Linux/ubuntu focal main" >/etc/apt/sources.list.d/openrtm-aist.list

# Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cmake \
    freeglut3-dev \
    g++ \
    gcc \
    gettext \
    git \
    libboost-filesystem-dev \
    libboost-iostreams-dev \
    libboost-program-options-dev \
    libboost-python-dev \
    libboost-regex-dev \
    libboost-thread-dev \
    libcos4-dev \
    libeigen3-dev \
    libglew-dev \
    libjpeg-dev \
    libomniorb4-dev \
    libpcap-dev \
    libpcl-dev \
    libpng-dev \
    libqhull-dev \
    libqt5opengl5-dev \
    libqt5x11extras5-dev \
    libusb-1.0-0-dev \
    libxfixes-dev \
    libyaml-dev \
    lsb-release \
    make \
    omniidl \
    omniidl-python \
    omniorb \
    omniorb-idl \
    omniorb-nameserver \
    openrtm-aist-dev \
    pkg-config \
    python-omniorb \
    python-yaml \
    python3-dev \
    qt5-default \
    uuid-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Fix missing links of vtk.
RUN ln -s /usr/bin/vtk7 /usr/bin/vtk

# Configure environment variables.
ENV PYTHONPATH=/usr/lib/omniidl

# Define variables used when building.
ARG CHOREONOID_REPO=choreonoid/choreonoid
ARG CHOREONOID_TAG=master
# The following variables may not be used.
ARG GRASP_PLUGIN_REPO=kensuke-harada/graspPlugin
ARG GRASP_PLUGIN_TAG=master

# Download Choreonoid source code.
RUN cd /opt && \
    git clone --depth 1 --branch ${CHOREONOID_TAG} git://github.com/${CHOREONOID_REPO}.git && \
    mkdir -p /opt/choreonoid/build

# Setup entrypoint.
COPY docker-entrypoint.sh /

ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/bin/bash" ]

# Build Choreonoid.
# RUN cd /opt && \
#     git clone --depth 1 --branch v1.6.0 git://github.com/${CHOREONOID_REPO}.git && \
#     git clone --depth 1 --branch ${GRASP_PLUGIN_BRANCH} git://github.com/${GRASP_PLUGIN_REPO}.git /opt/choreonoid/ext/graspPlugin && \
#     mkdir -p /opt/choreonoid/build && \
#     cd /opt/choreonoid/build && \
#     cmake \
#         -DBUILD_CORBA_PLUGIN:BOOL=TRUE \
#         -DBUILD_GRASP_PCL_PLUGIN:BOOL=ON \
#         -DBUILD_GROBOT_PLUGIN:BOOL=TRUE \
#         -DBUILD_OPENRTM_PLUGIN:BOOL=TRUE \
#         -DBUILD_PYTHON_PLUGIN:BOOL=TRUE \
#         -DCMAKE_BUILD_TYPE=Release \
#         -DCNOID_ENABLE_GETTEXT:BOOL=TRUE \
#         -DENABLE_CORBA:BOOL=TRUE \
#         -DGRASP_PLUGINS="\
# CnoidRos;\
# ConstraintIK;\
# GeometryHandler;\
# Grasp;\
# GraspConsumer;\
# GraspDataGen;\
# MotionFile;\
# ObjectPlacePlanner;\
# PCL;\
# PRM;\
# PickAndPlacePlanner;\
# RobotInterface;\
# RtcGraspPathPlan;\
# SoftFingerStability;\
# VisionTrigger;\
# " \
#         -DINSTALL_DEPENDENCIES:BOOL=TRUE \
#         -DINSTALL_SDK:BOOL=TRUE \
#         -DUSE_EXTERNAL_EIGEN:BOOL=TRUE \
#         -DUSE_EXTERNAL_YAML:BOOL=TRUE \
#         -DUSE_QT5:BOOL=ON \
#     .. && \
#     make

# RUN cmake .. -DCMAKE_BUILD_TYPE=Release -DUSE_QT5:BOOL=ON -DUSE_EXTERNAL_EIGEN:BOOL=TRUE -DUSE_EXTERNAL_YAML:BOOL=TRUE -DBUILD_PYTHON_PLUGIN:BOOL=TRUE -DCNOID_ENABLE_GETTEXT:BOOL=TRUE -DINSTALL_DEPENDENCIES:BOOL=TRUE -DINSTALL_SDK:BOOL=TRUE -DBUILD_CORBA_PLUGIN:BOOL=TRUE -DBUILD_GRASP_PCL_PLUGIN:BOOL=ON -DBUILD_GROBOT_PLUGIN:BOOL=TRUE -DBUILD_OPENRTM_PLUGIN:BOOL=TRUE -DENABLE_CORBA:BOOL=TRUE -DGRASP_PLUGINS="CnoidRos;ConstraintIK;GeometryHandler;Grasp;GraspConsumer;GraspDataGen;MotionFile;ObjectPlacePlanner;PCL;PRM;PickAndPlacePlanner;RobotInterface;RtcGraspPathPlan;SoftFingerStability;VisionTrigger;"
