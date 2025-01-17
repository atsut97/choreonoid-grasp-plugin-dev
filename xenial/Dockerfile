FROM ubuntu:xenial

# Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    cmake \
    curl \
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
    liblocale-msgfmt-perl \
    libopenni2-dev \
    libpcl-dev \
    libpng12-dev \
    libqhull-dev \
    libqt5x11extras5-dev \
    libusb-1.0-0-dev \
    libxfixes-dev \
    libyaml-dev \
    lsb-release \
    omniidl \
    omniidl-python \
    omniorb-nameserver \
    pkg-config \
    python-omniorb \
    python-yaml \
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

# Configure environment variables.
ENV PATH=/home/usr/bin:$PATH
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
