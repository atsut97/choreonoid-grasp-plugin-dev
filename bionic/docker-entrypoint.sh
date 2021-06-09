#!/bin/sh

set -e

build_grasp_plugin() {
  mkdir -p /opt/choreonoid/build
  cd /opt/choreonoid/build
  cmake ..\
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_CORBA_PLUGIN:BOOL=ON \
    -DBUILD_GRASP_PCL_PLUGIN:BOOL=ON \
    -DBUILD_GROBOT_PLUGIN:BOOL=ON \
    -DBUILD_OPENRTM_PLUGIN:BOOL=ON \
    -DBUILD_PYTHON_PLUGIN:BOOL=ON \
    -DCNOID_ENABLE_GETTEXT:BOOL=ON \
    -DENABLE_CORBA:BOOL=ON \
    -DINSTALL_DEPENDENCIES:BOOL=TRUE \
    -DINSTALL_SDK:BOOL=TRUE \
    -DUSE_EXTERNAL_EIGEN:BOOL=TRUE \
    -DUSE_EXTERNAL_YAML:BOOL=TRUE \
    -DUSE_QT5:BOOL=ON \
    -DGRASP_PLUGINS="CnoidRos;ConstraintIK;GeometryHandler;Grasp;GraspConsumer;GraspDataGen;MotionFile;ObjectPlacePlanner;PCL;PRM;PickAndPlacePlanner;RobotInterface;RtcGraspPathPlan;SoftFingerStability;VisionTrigger;"
  cmake . --build
}

if [ "$1" = build ]; then
  shift
  build_grasp_plugin
fi

if [ $# -eq 0 ]; then
  exec /bin/bash
else
  exec "$@"
fi
