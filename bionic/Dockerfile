FROM ubuntu:bionic

# Install packages to handle GPG keys.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    dirmngr \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*

# Setup PPA to install OpenRTM-aist packages.
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys CC8761DEBFB5DC87CC07DC964BCE106E087AFAC0 && \
    echo "deb http://openrtm.org/pub/Linux/ubuntu bionic main" >/etc/apt/sources.list.d/openrtm-aist.list

# Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cmake \
    freeglut3-dev \
    g++ \
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
    omniidl \
    omniidl-python \
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
RUN ln -s /usr/lib/python2.7/dist-packages/vtk/libvtkRenderingPythonTkWidgets.x86_64-linux-gnu.so /usr/lib/x86_64-linux-gnu/libvtkRenderingPythonTkWidgets.so && \
    ln -s /usr/bin/vtk6 /usr/bin/vtk

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
