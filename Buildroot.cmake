# Buildroot.cmake: CMake wrapper for the Buildroot firmware build system.
#
# Copyright 2016 Raumfeld
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file LICENSE for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.

#.rst:
# Buildroot.cmake
# ---------------
#
# Wraps the Buildroot build system inside a CMake build system.
#
# This may be useful if you have multiple Buildroot builds which depend on each
# other, and you want to drive them from one place.
#
# It provides two commands: buildroot_target and buildroot_toolchain. See below
# for documentation.

include("support/cmake/DefaultValue")
include("support/cmake/EnsureAllArgumentsParsed")
include("support/cmake/FindArtifactFile")

if(("${BUILDROOT_SOURCE_DIR}" STREQUAL "${CMAKE_BINARY_DIR}") AND
    ("${CMAKE_GENERATOR}" STREQUAL "Unix Makefiles"))
    message(FATAL_ERROR "Please run CMake with a work directory that is not "
                        "the top of the repo. Otherwise, the generated "
                        "Makefile will overwrite Buildroot's Makefile.")
endif()

set(BUILDROOT_SCRIPTS_DIR ${CMAKE_CURRENT_LIST_DIR}/support/scripts)

find_program(
    BUILDROOT_CHECK_TARGET_CREATED_FILES check-target-created-files
        ${BUILDROOT_SCRIPTS_DIR} NO_DEFAULT_PATH)
find_program(
    BUILDROOT_CLEAN buildroot-clean
        ${BUILDROOT_SCRIPTS_DIR} NO_DEFAULT_PATH)
find_program(
    BUILDROOT_CONFIG_TOOL config
        ${BUILDROOT_SCRIPTS_DIR} NO_DEFAULT_PATH)
find_program(
    BUILDROOT_MAKE_WRAPPER buildroot-make-wrapper
        ${BUILDROOT_SCRIPTS_DIR} NO_DEFAULT_PATH)

# Buildroot downloads nearly 700MB of source code, it makes sense to share
# this between each of the builds. We use the BR2_DL_DIR setting to do that.
set(BUILDROOT_DOWNLOAD_DIR ${CMAKE_CURRENT_BINARY_DIR}/dl)
file(MAKE_DIRECTORY ${BUILDROOT_DOWNLOAD_DIR})

# ::
#
#     buildroot_target(<name>
#                      OUTPUT <output_file>
#                      [CONFIG <buildroot_config_file>]
#                      [TOOLCHAIN <toolchain_target_name>]
#                      [SOURCE_DIR <source_dir>]
#                      [ARTIFACT_OUTPUT <filename>]
#                      [ARTIFACT_PREBUILT <pattern>]
#                      [HOST_TOOLS_ARTIFACT_OUTPUT <filename>]
#                      [HOST_TOOLS_ARTIFACT_PREBUILT <pattern>]
#                      [DEVICE_TREE_FILES <filename> ...]
#                      [DEVICE_TREE_ARTIFACT_OUTPUT <filename>]
#                      [DEVICE_TREE_ARTIFACT_PREBUILT <pattern>]
#                      )
#
# Overview
# --------
#
# Creates a target called <name> which runs a Buildroot build.
#
# Each Buildroot targets runs in a separate directory. The BUILDROOT_BUILD_DIR
# target property is set to point to the build directory.
#
# The build directory is not cleaned before building. There is a ${name}-clean
# target that can set you up for clean builds.
#
# The OUTPUT keyword must be set to point to the final output of the Buildroot
# build. There must be only one output file.
#
# The target that is created does not get added to the ALL target, and won't be
# built by default. This example shows how you can add it to the ALL target:
#
#   buildroot_target(foo OUTPUT images/rootfs.tar.gz)
#   add_custom_target(all-foo ALL DEPENDS foo)
#
# Configs
# -------
#
# The config you build must be a complete config, not a defconfig or something
# that would cause the build to ask questions at build time. If the build hangs
# indefinitely, check the -log.txt file in the build directory: there is
# probably a menu or config prompt waiting there.
#
# To avoid this problem, you should prepare your config file in a Buildroot
# source checkout with `make defconfig` and/or `make oldconfig`
#
# Options
# -------
#
# The Buildroot config file to use can be specified with CONFIG. The default is
# to look for a file named 'config' in the current source directory.
#
# You can specify a prebuilt toolchain to use, with the TOOLCHAIN option. This
# must point to a target created with the buildroot_toolchain() command. If you
# use an external toolchain, the following config flags must be set in your
# config file:
#
#   BR2_TOOLCHAIN_EXTERNAL=y
#   BR2_TOOLCHAIN_EXTERNAL_PREINSTALLED=y
#   BR2_TOOLCHAIN_EXTERNAL_CUSTOM=y
#
# The BR2_TOOLCHAIN_PATH setting is set automatically in the final config file.
# It will point at the BUILDROOT_HOST_TOOLS_DIR of the toolchain target.
#
# If SOURCE_DIR is passed, the Buildroot source tree in that directory is used
# to run the build. If it is not specified, the value of the global
# BUILDROOT_SOURCE_DIR variable is used if set. If BUILDROOT_SOURCE_DIR is not
# set, the current directory is expected to contain a Buildroot source tree.
#
# Artifact caching integration
# ----------------------------
#
# The buildroot_toolchain() command supports creating links to output files in
# well-known locations. It also supports looking for prebuilt artifact files
# in well-known locations, and short-circuiting the build rules if some are
# found.
#
# The ARTIFACT_OUTPUT parameter adds a post-build step that creates a link to
# the OUTPUT file, at the given path. This can then be published with some
# other tool.
#
# The HOST_TOOLS_ARTIFACT_OUTPUT parameter adds a post-build step that creates
# a tarball of the entire host/ directory, then links to it at the given path.
# This can then be published with some other tool.
#
# The buildroot_toolchain() does not create any rules to remove or rename old
# files if it is called again with new output filenames.
#
# The ARTIFACT_PREBUILT parameter can specify a filename or glob pattern. The
# command searches at configure-time for a file matching that pattern. If one
# is found, the normal build rule is not created. Instead, the generated build
# rule for <name> just creates a symlink at the location of OUTPUT pointing to
# the file that was found.
#
# The HOST_TOOLS_ARTIFACT_PREBUILT parameter also specifies a filename or glob
# pattern. If a matching file is found, the generated build rule for <name>
# will unpack the matching file into the host/ subdirectory of the build tree.
#
# For all of the ARTIFACT_PREBUILT parameters, if more than one matching file
# is found, a fatal error is raised.
#
# Device trees
# ------------
#
# Building Linux device trees requires that the Linux kernel build tree is
# available, so it's best done as part of the relevant Buildroot rootfs build.
# The files live outside the rootfs, though, so they generally need to be
# treated as their own artifact.
#
# You can set DEVICE_TREE_FILES to match whatever files or directories your
# device tree build outputs, and then set DEVICE_TREE_ARTIFACT_OUTPUT to
# specify a final location for a tar.gz file containing those files. You must
# also specify a pattern to DEVICE_TREE_ARTIFACT_PREBUILT if you are using
# other prebuilt artifacts and have a device tree.
#
# You cannot pass globs to DEVICE_TREE_FILES, because it's tricky to expand
# globs inside CMake build rules.
function(buildroot_target name)
    set(one_value_keywords
            CONFIG OUTPUT SOURCE_DIR TOOLCHAIN
            ARTIFACT_OUTPUT ARTIFACT_PREBUILT
            DEVICE_TREE_ARTIFACT_OUTPUT DEVICE_TREE_ARTIFACT_PREBUILT
            HOST_TOOLS_ARTIFACT_OUTPUT HOST_TOOLS_ARTIFACT_PREBUILT
            )
    set(multi_value_keywords DEVICE_TREE_FILES)
    cmake_parse_arguments(BR "" "${one_value_keywords}" "${multi_value_keywords}" ${ARGN})
    ensure_all_arguments_parsed(buildroot_target "${BR_UNPARSED_ARGUMENTS}")

    default_value(BR_CONFIG ${CMAKE_CURRENT_SOURCE_DIR}/config)

    if(NOT ${BUILDROOT_OUTPUT})
        message(FATAL_ERROR "buildroot_target(${name}): the OUTPUT paramater is required")
    endif()

    # Sets build_dir, config_commands
    _buildroot_common_setup(${name})

    set(main_output ${build_dir}/${BR_OUTPUT})
    set(device_tree_output ${build_dir}/${name}-device-trees.tar.gz)
    set(device_tree_check_files ${BR_DEVICE_TREE_FILES})
    set(host_tools_output ${build_dir}/${name}-host-tools.tar.gz)
    set(host_tools_check_files host/)

    find_artifact_file(artifact_prebuilt "${BR_ARTIFACT_PREBUILT}")
    find_artifact_file(device_tree_artifact_prebuilt "${BR_DEVICE_TREE_ARTIFACT_PREBUILT}")
    find_artifact_file(host_tools_artifact_prebuilt "${BR_HOST_TOOLS_ARTIFACT_PREBUILT}")

    if(NOT artifact_prebuilt AND (device_tree_artifact_prebuilt OR
            host_tools_artifact_prebuilt))
        message(WARNING
                "Some artifacts for ${name} were found but the main artifact "
                "is missing, so ${name} will be built from source.")
    endif()

    set(all_outputs ${main_output})

    if(BR_TOOLCHAIN)
        # External toolchain configuration
        if(NOT TARGET ${BR_TOOLCHAIN})
            message(FATAL_ERROR "Toolchain ${BR_TOOLCHAIN} does not exist.")
        endif()

        get_target_property(toolchain_path ${BR_TOOLCHAIN} BUILDROOT_HOST_TOOLS_PREFIX)

        if(NOT toolchain_path)
            message(FATAL_ERROR
                "Toolchain ${BR_TOOLCHAIN} does not have "
                "BUILDROOT_HOST_TOOLS_PREFIX target property set -- are you "
                "sure this is a Buildroot toolchain created with the "
                "buildroot_toolchain() command?")
        endif()

        list(APPEND config_commands --set-str BR2_TOOLCHAIN_EXTERNAL_PATH ${toolchain_path})
        set(toolchain_depends ${BR_TOOLCHAIN})
    else()
        set(toolchain_depends)
    endif()

    _buildroot_prepare_config(${source_dir} ${build_dir} ${BR_CONFIG} ${config_commands})

    set(build_log ${CMAKE_CURRENT_BINARY_DIR}/${name}-log.txt)
    set(extra_depends ${BR_CONFIG} ${toolchain_depends})

    if(artifact_prebuilt)
        _buildroot_use_prebuilt_file(
            ${name} ${artifact_prebuilt} ${main_output})

        if(device_tree_artifact_prebuilt)
            _buildroot_use_prebuilt_directory(
                "${name} device trees" ${device_tree_artifact_prebuilt}
                ${device_tree_output} ${build_dir} "${device_tree_check_files}"
                "")
            list(APPEND all_outputs ${device_tree_output})
        elseif(BR_DEVICE_TREE_ARTIFACT_PREBUILT)
            message(FATAL_ERROR
                    "Did not find expected device-trees artifact for ${name}. "
                    "Was looking for ${BR_DEVICE_TREE_ARTIFACT_PREBUILT}")
        endif()

        if(host_tools_artifact_prebuilt)
            _buildroot_use_prebuilt_directory(
                "${name} host tools" ${host_tools_artifact_prebuilt}
                ${host_tools_output} ${build_dir} "${host_tools_check_files}"
                "${toolchain_depends}"
                )
            list(APPEND all_outputs ${host_tools_output})

            if(BR_TOOLCHAIN)
                # When building the original host tools, we passed an absolute
                # path to BR_TOOLCHAIN_EXTERNAL_PATH, which will be hardcoded
                # into the 'ext-toolchain-wrapper' program Buildroot builds.
                # That path will probably now be wrong if we are using a
                # host-tools artifact built on a different machine.
                #
                # Luckily, running 'make toolchain' with a config file that has
                # a correct BR_TOOLCHAIN_EXTERNAL_PATH is enough to fix it up.
                _buildroot_make(
                    "toolchain" ${name}-host-tools-fixup ${source_dir}
                    ${build_dir} "" "" "${host_tools_output}" ${build_log}
                    "Fixing up external toolchain paths for ${name}")
                list(APPEND all_outputs ${CMAKE_CURRENT_BINARY_DIR}/_make.stamp)
            endif()
        elseif(BR_HOST_TOOLS_ARTIFACT_PREBUILT)
            message(FATAL_ERROR
                    "Did not find expected host-tools artifact for ${name}. "
                    "Was looking for ${BR_HOST_TOOLS_ARTIFACT_PREBUILT}")
        endif()
    else()
        _buildroot_make(
            all ${name} ${source_dir} ${build_dir} "${main_output}" ""
            "${extra_depends}" ${build_log}
            "Building Buildroot config ${BR_CONFIG} to produce ${main_output}")

        if(BR_ARTIFACT_OUTPUT)
            _buildroot_create_artifact_from_file(${main_output} ${BR_ARTIFACT_OUTPUT})
            list(APPEND all_outputs ${BR_ARTIFACT_OUTPUT})
        endif()

        if(BR_DEVICE_TREE_ARTIFACT_OUTPUT)
            _buildroot_create_artifact_from_directory(
                ${device_tree_output} ${BR_DEVICE_TREE_ARTIFACT_OUTPUT}
                ${build_dir} "${BR_DEVICE_TREE_FILES}" ${main_output})
            list(APPEND all_outputs ${device_tree_output})
            list(APPEND all_outputs ${BR_DEVICE_TREE_ARTIFACT_OUTPUT})
        endif()

        if(BR_HOST_TOOLS_ARTIFACT_OUTPUT)
            _buildroot_create_artifact_from_directory(
                ${host_tools_output} ${BR_HOST_TOOLS_ARTIFACT_OUTPUT}
                ${build_dir} "host/;staging" ${main_output})
            list(APPEND all_outputs ${host_tools_output})
            list(APPEND all_outputs ${BR_HOST_TOOLS_ARTIFACT_OUTPUT})
        endif()
    endif()

    # Actual target
    add_custom_target(${name}
        DEPENDS ${all_outputs}
        SOURCES ${BR_CONFIG}
    )

    set_target_properties(${name} PROPERTIES
        BUILDROOT_BUILD_DIR
            ${build_dir}
        BUILDROOT_OUTPUT
            ${main_output}
        BUILDROOT_HOST_TOOLS_OUTPUT
            ${host_tools_output}
        BUILDROOT_HOST_TOOLS_PREFIX
            ${build_dir}/host/usr
        BUILDROOT_STAGING_DIR
            ${build_dir}/staging
    )

    _buildroot_clean_target(${name} ${build_dir} "${all_outputs}")
    _buildroot_source_fetch_target(${name} ${build_dir} ${source_dir})
endfunction()

# ::
#
#     buildroot_toolchain(<name>
#                         [CONFIG <buildroot_config_file>]
#                         [SOURCE_DIR <source_dir>]
#                         [ARTIFACT_OUTPUT <filename>]
#                         [ARTIFACT_PREBUILT <filename>])
#
# Creates a target called <name> which builds a Buildroot toolchain using the
# given config file.
#
# See the generic buildroot_target() for more information on wrapping Buildroot
# with CMake.
#
# The artifact for the toolchain behaves like the host tools artifacts of this
# module's normal Buildroot targets: a tar.gz is created of the whole host/
# directory.
#
function(buildroot_toolchain name)
    set(BR_TOOLCHAIN_SOURCE_DIR ${BUILDROOT_SOURCE_DIR})

    set(one_value_keywords ARTIFACT_OUTPUT ARTIFACT_PREBUILT CONFIG SOURCE_DIR)
    cmake_parse_arguments(BR_TOOLCHAIN "" "${one_value_keywords}" "" ${ARGN})
    ensure_all_arguments_parsed(buildroot_toolchain "${BR_TOOLCHAIN_UNPARSED_ARGUMENTS}")

    default_value(BR_TOOLCHAIN_CONFIG ${CMAKE_CURRENT_SOURCE_DIR}/config)

    # Sets build_dir, config_commands
    _buildroot_common_setup(${name})

    set(toolchain_output ${CMAKE_CURRENT_BINARY_DIR}/${name}.tar.gz)
    set(check_files ${build_dir}/host/usr/libexec/gcc)

    find_artifact_file(artifact_prebuilt ${BR_TOOLCHAIN_ARTIFACT_PREBUILT})

    if(artifact_prebuilt)
        _buildroot_use_prebuilt_directory(
            ${name} ${artifact_prebuilt} ${toolchain_output} ${build_dir} ${check_files} "")
    else()
        # Config preparation. This uses scripts/config from the Linux source tree.
        _buildroot_prepare_config(${source_dir} ${build_dir} ${BR_TOOLCHAIN_CONFIG} ${config_commands})

        set(build_log ${CMAKE_CURRENT_BINARY_DIR}/${name}-log.txt)
        set(extra_depends ${BR_TOOLCHAIN_CONFIG})

        _buildroot_make(
            toolchain ${name} ${source_dir} ${build_dir} ""
            "${check_files}" "${extra_depends}" ${build_log}
            "Building Buildroot toolchain from config ${BR_TOOLCHAIN_CONFIG}")

        if(BR_TOOLCHAIN_ARTIFACT_OUTPUT)
            _buildroot_create_artifact_from_directory(
                ${toolchain_output} ${BR_TOOLCHAIN_ARTIFACT_OUTPUT}
                ${build_dir} host/ ${CMAKE_CURRENT_BINARY_DIR}/_make.stamp)
        endif()
    endif()

    # Actual target
    add_custom_target(${name}
        DEPENDS ${toolchain_output}
        SOURCES ${BR_TOOLCHAIN_CONFIG}
    )

    set_target_properties(${name} PROPERTIES
        BUILDROOT_OUTPUT ${toolchain_output}
        BUILDROOT_HOST_TOOLS_PREFIX ${build_dir}/host/usr
    )

    _buildroot_clean_target(${name} ${build_dir} ${toolchain_output})
    _buildroot_source_fetch_target(${name} ${build_dir} ${source_dir})
endfunction()

# ::
#
#     buildroot_edit_config_file(<file> <config commands>)
#
# Uses support/scripts/config (taken from the Linux source tree) to edit the
# given Buildroot configuration file.
#
# All parameters are passed as commandline arguments to support/scripts/config.
# Run `support/scripts/config --help` to see the valid options.
#
# The changes are made at configure-time, i.e. when CMake itself executes. The
# recommended way to use this function is to make a copy of the input
# configuration, and separately, create a stamp file using configure_file().
# You can't create a copy of the file using configure_file() and then edit it
# directly, because the RERUN_CMAKE build run would then trigger every time as
# the mtime of the output config file would be updated after each configure.
#
# Creating a stamp with configure_file() means that if the user edits the input
# file, CMake will rerun, but otherwise it will not.
#
# For example:
#
#   configure_file(configs/qemu_x86_64_defconfig
#       ${CMAKE_CURRENT_BUILD_DIR}/configs/my-config.stamp)
#   execute_process(COMMAND cmake -E copy configs/qemu_x86_64_defconfig
#       ${CMAKE_CURRENT_BUILD_DIR}/configs/my-config)
#   buildroot_edit_config_file(${CMAKE_CURRENT_BUILD_DIR}/configs/my-config
#       --set-str BR2_TARGET_GENERIC_ISSUE "Welcome to my Buildroot system.")
#
# FIXME: setting the CMAKE_CONFIGURE_DEPENDS directory property might be
# better way to do this!
function(buildroot_edit_config_file file)
    # This uses scripts/config from the Linux source tree.
    if(NOT EXISTS ${BUILDROOT_CONFIG_TOOL})
        message(FATAL_ERROR "Could not find support/scripts/config.")
    endif()

    set(commands ${ARGN})
    execute_process(
        COMMAND env CONFIG_=BR2_ ${BUILDROOT_CONFIG_TOOL} --file ${file} ${commands}
    )
endfunction()

# ::
#
#     buildroot_config_value(<file> <option_name>)
#
# Uses support/scripts/config (taken from the Linux source tree) to read the
# value of an option from the given Buildroot configuration file.
#
# RETURN: Sets "br_config_value" to the value in the buildroot config
function(buildroot_config_value file option_name)
    set(ENV{CONFIG_} "BR2_")
    execute_process(
        COMMAND
            ${BUILDROOT_CONFIG_TOOL} --file ${file} --keep-case --state ${option_name}
        OUTPUT_VARIABLE
            out
    )
    string(STRIP ${out} out_stripped)
    set(br_config_value ${out_stripped} PARENT_SCOPE)
endfunction(buildroot_config_value)

## ::
##
## Properties set by this module

define_property(TARGET PROPERTY "BUILDROOT_BUILD_DIR"
    BRIEF_DOCS "Path to the directory that contains all Buildroot build output for this build."
    FULL_DOCS "x"
    )

define_property(TARGET PROPERTY "BUILDROOT_HOST_TOOLS_PREFIX"
    BRIEF_DOCS "Path to host tools prefix (/usr) within the Buildroot build output"
    FULL_DOCS "x"
    )

define_property(TARGET PROPERTY "BUILDROOT_OUTPUT"
    BRIEF_DOCS "Path to the main output file product by this target."
    FULL_DOCS "x"
    )


## ::
##
## Internal helper functions and macros.

macro(_buildroot_common_setup target_name)
    # Set some variables used in buildroot_target() and buildroot_toolchain().

    set(source_dir ${BUILDROOT_SOURCE_DIR})

    if(NOT IS_DIRECTORY ${source_dir})
        message(FATAL_ERROR "Buildroot source directory ${source_dir} does not "
                            "exist, or is not a directory.")
    elseif(NOT EXISTS ${source_dir}/Makefile)
        message(FATAL_ERROR "Directory ${source_dir} does not seem to contain "
                            "a Buildroot source tree: no Makefile present")
    endif()

    get_filename_component(binary_dir_basename ${CMAKE_CURRENT_BINARY_DIR} NAME)
    if(${binary_dir_basename} STREQUAL ${target_name})
        set(build_dir ${CMAKE_CURRENT_BINARY_DIR})
    else()
        set(build_dir ${CMAKE_CURRENT_BINARY_DIR}/${target_name})
        file(MAKE_DIRECTORY ${build_dir})
    endif()

    set(config_commands)

    # It's possible to set BR2_DL_DIR in the environment, but the value
    # from the .config file seems to override, which is a bit useless.
    list(APPEND config_commands --set-str BR2_DL_DIR ${BUILDROOT_DOWNLOAD_DIR})
endmacro()

function(_buildroot_prepare_config source_dir build_dir input)
    set(commands ${ARGN})

    if(NOT IS_ABSOLUTE ${input})
        set(input ${CMAKE_CURRENT_SOURCE_DIR}/${input})
    endif()

    configure_file(${input} ${build_dir}/.config.stamp)
    execute_process(COMMAND cmake -E copy ${input} ${build_dir}/.config)
    buildroot_edit_config_file(${build_dir}/.config ${commands})
endfunction()

function(_buildroot_make buildroot_target cmake_target_name source_dir build_dir output check_files extra_depends build_log comment)
    if(NOT output)
        # If there's no specific output that we can look for, create a stamp.
        set(stamp ${CMAKE_CURRENT_BINARY_DIR}/_make.stamp)
        set(stamp_command COMMAND date > ${stamp})
        set(output ${stamp})
    else()
        set(stamp_command)
    endif()

    add_custom_command(
        OUTPUT ${output}
        COMMAND
            ${BUILDROOT_MAKE_WRAPPER} ${build_dir} ${buildroot_target} ${build_log}

        ${stamp_command}

        # Sanity check -- CMake itself doesn't seem to generate rules that would
        # check if the command actually creates the output that it's meant to.
        #
        # It's important *not* to list ${check_files} as outputs of the custom
        # command, though! CMake causes all the outputs of a custom command to
        # be deleted if the custom command fails. Buildroot's Makefile doesn't
        # keep track of every single output file, so it could be that deleting
        # the ${check_files} completely breaks the Buildroot build.
        COMMAND
            ${BUILDROOT_CHECK_TARGET_CREATED_FILES} ${name} ${output} ${check_files}

        WORKING_DIRECTORY
            ${source_dir}
        DEPENDS
            ${extra_depends}
        COMMENT ${comment}
        VERBATIM
    )
endfunction()

function(_buildroot_use_prebuilt_file name prebuilt_file output_file)
    if(NOT IS_ABSOLUTE ${output_file})
        set(output_file ${CMAKE_CURRENT_BINARY_DIR}/${output_file})
    endif()

    get_filename_component(output_dir ${output_file} DIRECTORY)
    file(MAKE_DIRECTORY ${output_dir})

    add_custom_command(
        COMMAND
            cmake -E create_symlink ${prebuilt_file} ${output_file}
        OUTPUT ${output_file}
        COMMENT "Using prebuilt version of ${name}"
        )
endfunction()

function(_buildroot_use_prebuilt_directory name prebuilt_file output_file output_dir check_files extra_depends)
    if(NOT IS_ABSOLUTE ${output_file})
        set(output_file ${CMAKE_CURRENT_BINARY_DIR}/${output_file})
    endif()

    get_filename_component(output_dir ${output_file} DIRECTORY)
    file(MAKE_DIRECTORY ${output_dir})

    add_custom_command(
        COMMAND
            cmake -E create_symlink ${prebuilt_file} ${output_file}
        COMMAND
            tar --extract --directory=${output_dir} --file ${output_file}
        COMMAND
            ${BUILDROOT_CHECK_TARGET_CREATED_FILES} "${name}" ${output_file} ${check_files}
        OUTPUT ${output_file} ${check_files}
        DEPENDS "${extra_depends}"
        COMMENT "Using prebuilt version of ${name}"
        )
endfunction()

function(_buildroot_create_artifact_from_file filename artifact_filename)
    if(NOT IS_ABSOLUTE ${artifact_filename})
        set(artifact_filename ${CMAKE_CURRENT_BINARY_DIR}/${artifact_filename})
    endif()

    get_filename_component(artifact_dir ${artifact_filename} DIRECTORY)
    file(MAKE_DIRECTORY ${artifact_dir})

    add_custom_command(
        OUTPUT ${artifact_filename}
        COMMAND cmake -E create_symlink ${filename} ${artifact_filename}
        DEPENDS ${filename}
        )
endfunction()

function(_buildroot_create_artifact_from_directory filename artifact_filename dir include_files depends)
    if(NOT IS_ABSOLUTE ${artifact_filename})
        set(artifact_filename ${CMAKE_CURRENT_BINARY_DIR}/${artifact_filename})
    endif()

    get_filename_component(artifact_dir ${artifact_filename} DIRECTORY)
    file(MAKE_DIRECTORY ${artifact_dir})

    add_custom_command(
        OUTPUT
            ${filename} ${artifact_filename}
        COMMAND
            tar --create --gzip --file ${filename} --directory ${dir} ${include_files}
        COMMAND
            cmake -E create_symlink ${filename} ${artifact_filename}
        DEPENDS
            ${depends}
        VERBATIM
    )
endfunction()

function(_buildroot_clean_target name build_dir outputs)
    add_custom_target(
        ${name}-clean
        COMMAND
            ${BUILDROOT_CLEAN} ${build_dir} ${outputs}
        VERBATIM
    )
endfunction()

# Meta target for fetching all buildroot package sources
# Is set to depend on all the buildroot-*-source-fetch targets.
add_custom_target(source-fetch)

function(_buildroot_source_fetch_target name build_dir source_dir)
    add_custom_target(
        ${name}-source-fetch
        COMMAND
            make O=${build_dir} source

        WORKING_DIRECTORY
            ${source_dir}
        VERBATIM
    )
    add_dependencies(
        source-fetch ${name}-source-fetch
    )
endfunction()
