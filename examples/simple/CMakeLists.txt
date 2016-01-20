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

cmake_minimum_required(VERSION 3.2)

# Set up the module path so Buildroot.cmake and Git.cmake are found.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../)

include("Buildroot")
include("Git")

# Look for the Buildroot source code, by default alongside the checkout of
# Buildroot.cmake.git, but you can pass -DBUILDROOT_SOURCE_DIR=<path> to
# specify a location to look in.
git_add_external_repo(
    buildroot
    DESCRIPTION "Buildroot"
    DEFAULT_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../../buildroot)

# Compile a Buildroot toolchain
buildroot_target(
    raspberrypi2
    OUTPUT images/rootfs.tar.gz
    CONFIG raspberrypi2.config
    )

add_custom_target(all-buildroot ALL DEPENDS raspberrypi2)
