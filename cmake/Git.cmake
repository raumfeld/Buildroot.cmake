# Git.cmake: CMake module for working with external Git repositories
#
# Copyright 2016 Raumfeld
#
# Distributed under the OSI-approved BSD License (the "License");
# see accompanying file LICENSE for details.
#
# This software is distributed WITHOUT ANY WARRANTY; without even the
# implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the License for more information.

# Related (but not directly reusable) code can be found in the CPM project:
#   <https://github.com/iauns/cpm/blob/master/util/CPMGit.cmake>.
#
# And in CMake's built-in ExternalProject module:
#   <https://cmake.org/gitweb?p=cmake.git;a=blob;f=Modules/ExternalProject.cmake>
#
# And in Ryan Pavlik's cmake modules:
#   <https://github.com/rpavlik/cmake-modules/blob/master/GetGitRevisionDescription.cmake>
#
# These functions could well be submitted upstream to CMake in the
# FindGit.cmake module. You'd need to write some tests though.

find_package(Git REQUIRED)

# ::
#
#    git_get_current_commit_sha1(<result_var> <repo>)
#
# Returns the ID of the Git commit that is currently checked out in <repo>.
#
# If <repo> is not a valid Git repository, or the call to `git` fails for some
# other reason, a CMake fatal error is reported.
#
function(git_get_current_commit_sha1 result_var repo)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
        WORKING_DIRECTORY ${repo}
        OUTPUT_VARIABLE output
        RESULT_VARIABLE result
    )

    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Unable to get commit SHA1 from repo ${repo_path}: ${result}")
    endif()

    string(STRIP ${output} output)
    set(${result_var} ${output} PARENT_SCOPE)
endfunction()

# ::
#
#    git_get_current_branch_name(<result_var> <repo>)
#
# Returns the name of the Git branch that is currently checked out in <repo>.
# If there is no branch corresponding to the commit that is currently checked
# out (sometimes known as "detached HEAD" mode) then the full commit SHA1 is
# returned instead.
#
# If <repo> is not a valid Git repository, or the call to `git` fails for some
# other reason, a CMake fatal error is reported.
#
function(git_get_current_branch_name result_var repo)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} rev-parse --abbrev-ref HEAD
        WORKING_DIRECTORY ${repo}
        OUTPUT_VARIABLE output
        RESULT_VARIABLE result
    )

    if(NOT result EQUAL 0)
        message(FATAL_ERROR "Unable to get branch name from repo ${repo}: ${result}")
    endif()

    string(STRIP ${output} output)

    if(output STREQUAL HEAD)
        # If the working directory is in the painful-sounding "detached HEAD"
        # mode, where the commit that is checked out does not correspond to any
        # branch, we return the commit SHA1 instead of the fairly useless
        # string "HEAD".
        git_get_current_commit_sha1(output ${repo})
    endif()

    set(${result_var} ${output} PARENT_SCOPE)
endfunction()

# ::
#
#    git_is_work_tree_clean(<result_var> <repo>)
#
# Sets <result_var> to TRUE if there are no changes to the working tree of
# <repo>. This includes changes that have been staged with `git add` or `git
# rm`. Sets <result_var> to FALSE otherwise.
#
# This can be a pretty slow operation, as it has to stat() every single file in
# the work tree.
#
# If <repo> is not a valid Git repository, or the call to `git` fails for some
# other reason, a CMake fatal error is reported.
#
function(git_is_work_tree_clean result_var repo)
    execute_process(
        COMMAND ${GIT_EXECUTABLE} diff-files --quiet --ignore-submodules
        WORKING_DIRECTORY ${repo}
        RESULT_VARIABLE unstaged_changes
    )

    execute_process(
        COMMAND ${GIT_EXECUTABLE} diff-index --cached --quiet --ignore-submodules HEAD --
        WORKING_DIRECTORY ${repo}
        RESULT_VARIABLE staged_changes
    )

    if(unstaged_changes OR staged_changes)
        set(${result_var} FALSE PARENT_SCOPE)
    else()
        set(${result_var} TRUE PARENT_SCOPE)
    endif()
endfunction()

# ::
#
#    git_add_external_repo(<name>
#                          [DESCRIPTION <description>]
#                          [DEFAULT_PATH <dir>])
#
# Provides a mechanism to locate a Git repository for a component.
#
# One cache property is defined:
#
#   <name>_SOURCE_DIR
#
# This can be specified by the user at configure-time. The default location to
# look for code is ${CMAKE_CURRENT_SOURCE_DIR}/<name>.
#
# If a Git repo is not found in this location, a CMake fatal error is raised.
#
# If a repo is found, two variables are set in the parent scope:
#
#   <name>_BRANCH_NAME  - the name of the branch checked out in the repo
#   <name>_COMMIT_SHA1  - the ID of the commit checked out in the repo
#
# This information is also reported as a STATUS message.
#
# As an exception, if those variables are all defined already, the values
# passed in by the caller are used, and no calls to Git are made.
#
# This function is intended for use by projects which want to drive
# subproject builds directly from CMake, and want to be able to make use of
# prebuilt artifacts when they available.
#
# There are several solutions for building external components including
# Biicode, CPM, Hunter and CMake's own ExternalProject module, which have their
# own code to download or locate external Git repos. None of these support any
# kind of caching of prebuilt artifacts, at the time of writing.
#
function(git_add_external_repo name)
    set(one_value_keywords DESCRIPTION DEFAULT_PATH)
    cmake_parse_arguments(REPO "" "${one_value_keywords}" "" ${ARGN})

    string(TOUPPER ${name} NAME)

    set(${NAME}_SOURCE_DIR "${REPO_DEFAULT_PATH}" CACHE PATH
        "Path to ${REPO_DESCRIPTION} source tree.")

    if(NOT ${NAME}_SOURCE_DIR)
        message(FATAL_ERROR
            "Please specify a path to the ${REPO_DESCRIPTION} source code "
            "checkout, using the ${NAME}_SOURCE_DIR option.")
    endif()

    if(NOT IS_ABSOLUTE ${${NAME}_SOURCE_DIR})
        get_filename_component(${NAME}_SOURCE_DIR ${${NAME}_SOURCE_DIR} ABSOLUTE)
    endif()

    if(NOT IS_DIRECTORY ${${NAME}_SOURCE_DIR})
        message(FATAL_ERROR
            "${REPO_DESCRIPTION} source code checkout was not found at "
            "${${NAME}_SOURCE_DIR}. Please clone the ${name} Git repo to that "
            "location, or set ${NAME}_SOURCE_DIR to point to an existing "
            "checkout of the source code.")
    endif()

    if(NOT ${NAME}_BRANCH_NAME)
        git_get_current_branch_name(${NAME}_BRANCH_NAME ${${NAME}_SOURCE_DIR})
    endif()
    if(NOT ${NAME}_COMMIT_SHA1)
        git_get_current_commit_sha1(${NAME}_COMMIT_SHA1 ${${NAME}_SOURCE_DIR})
    endif()

    set(${NAME}_BRANCH_NAME ${${NAME}_BRANCH_NAME} PARENT_SCOPE)
    set(${NAME}_COMMIT_SHA1 ${${NAME}_COMMIT_SHA1} PARENT_SCOPE)

    message(STATUS "Using ${name} branch ${${NAME}_BRANCH_NAME}")
    message(STATUS "  (commit ${${NAME}_COMMIT_SHA1})")
endfunction()
