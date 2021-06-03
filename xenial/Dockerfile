FROM ubuntu:xenial

# Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    cmake \
    curl \
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
    libeigen3-dev \
    libglew-dev \
    libjpeg-dev \
    liblocale-msgfmt-perl \
    libomniorb4-dev=4.1.6-2ubuntu1 \
    libopenni2-dev \
    libpcap-dev \
    libpcl-dev \
    libpng12-dev \
    libqhull-dev \
    libqt5x11extras5-dev \
    libusb-1.0-0-dev \
    libxfixes-dev \
    libyaml-dev \
    lsb-release \
    make \
    omniidl=4.1.6-2ubuntu1 \
    omniorb-nameserver=4.1.6-2ubuntu1 \
    pkg-config \
    python3-dev \
    uuid-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Fix missing links of vtk.
RUN ln -s /usr/lib/python2.7/dist-packages/vtk/libvtkRenderingPythonTkWidgets.x86_64-linux-gnu.so /usr/lib/x86_64-linux-gnu/libvtkRenderingPythonTkWidgets.so && \
    ln -s /usr/bin/vtk6 /usr/bin/vtk

# Create directory to distribute artifacts.
RUN mkdir -p /home/usr

# Install OpenRTM-aist 1.1.2.
RUN cd /opt && \
    curl -sLO http://openrtm.org/pub/OpenRTM-aist/cxx/1.1.2/OpenRTM-aist-1.1.2.tar.gz && \
    tar xzf OpenRTM-aist-1.1.2.tar.gz && \
    cd OpenRTM-aist-1.1.2 && \
    ./configure --prefix=/home/usr --without-doxygen && \
    make && \
    make install && \
    make clean

# Define variables.
ARG CHOREONOID_REPO=choreonoid/choreonoid
ARG CHOREONOID_VER=master
# ARG GRASP_PLUGIN_REPO=atsut97/graspPlugin
# ARG GRASP_PLUGIN_TAG=master

# Download Choreonoid source code.
RUN cd /opt && \
    git clone --depth 1 --branch ${CHOREONOID_VER} git://github.com/${CHOREONOID_REPO}.git && \
    mkdir -p /opt/choreonoid/build

WORKDIR /opt/choreonoid/build

# Build Choreonoid.
# RUN cd /opt && \
#     git clone --depth 1 --branch ${CHOREONOID_VER} git://github.com/${CHOREONOID_REPO}.git && \
#     git clone --depth 1 --branch ${GRASP_PLUGIN_TAG} git://github.com/${GRASP_PLUGIN_REPO}.git /opt/choreonoid/ext/graspPlugin && \
#     mkdir -p /opt/choreonoid/build && \
#     cd /opt/choreonoid/build && \
#     cmake \
#         -DBUILD_CORBA_PLUGIN:BOOL=ON \
#         -DBUILD_GRASP_PCL_PLUGIN:BOOL=ON \
#         -DBUILD_GROBOT_PLUGIN:BOOL=ON \
#         -DBUILD_OPENRTM_PLUGIN:BOOL=ON \
#         -DBUILD_PYTHON_PLUGIN:BOOL=ON \
#         -DCMAKE_BUILD_TYPE=Release \
#         -DCNOID_ENABLE_GETTEXT:BOOL=ON \
#         -DENABLE_CORBA:BOOL=ON \
#         -DOPENRTM_DIR:PATH=/home/usr \
#         -DOpenRTM_DIR:PATH=/home/usr/lib/openrtm-1.1/cmake \
#         -DUSE_QT5:BOOL=ON \
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
#     .. && \
#     make

# RUN cmake .. -Wno-dev -DCMAKE_BUILD_TYPE=Release -DBUILD_CORBA_PLUGIN:BOOL=ON -DBUILD_GRASP_PCL_PLUGIN:BOOL=ON -DBUILD_GROBOT_PLUGIN:BOOL=ON -DBUILD_OPENRTM_PLUGIN:BOOL=ON -DBUILD_PYTHON_PLUGIN:BOOL=ON -DCNOID_ENABLE_GETTEXT:BOOL=ON -DENABLE_CORBA:BOOL=ON -DOPENRTM_DIR:PATH=/home/usr -DOpenRTM_DIR:PATH=/home/usr/lib/openrtm-1.1/cmake -DUSE_QT5:BOOL=ON -DGRASP_PLUGINS="CnoidRos;ConstraintIK;GeometryHandler;Grasp;GraspConsumer;GraspDataGen;MotionFile;ObjectPlacePlanner;PCL;PRM;PickAndPlacePlanner;RobotInterface;RtcGraspPathPlan;SoftFingerStability;VisionTrigger;"
