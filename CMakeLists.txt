# Copyright 2016 Raumfeld
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file LICENSE for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.

# This is an example project for the Buildroot.cmake CMake module.
#
# To build it, you will first need a clone of buildroot.git. The upstream
# location is <git://git.buildroot.net/buildroot>.
#
# Then, build the example like this:
#
#   mkdir build
#   cmake .. -DBUILDROOT_SOURCE_DIR=<path to Buildroot.git>
#   make

cmake_minimum_required(VERSION 3.14)

# Set up the module path so Buildroot.cmake and Git.cmake are found.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/)

include("cmake/Buildroot.cmake")
include("cmake/Git.cmake")
include("cmake/GitUtils.cmake")

project(examples)

GitUtils_Define(
  buildroot
  "https://git.buildroot.net/buildroot"
  TAG "2015.11"
  FOLDER "build"
  DEPTH 1
  FREEZE SINGLE DEPTHONE
)

# Compile a Buildroot toolchain
buildroot_target(
  raspberrypi2
  OUTPUT images/rootfs.tar.gz
  CONFIG examples/raspberrypi2_defconfig
)

add_custom_target(all-buildroot ALL DEPENDS raspberrypi2)
