cmake_minimum_required(VERSION 3.3)


get_property(HAS_GIT_UTILS_REPOSITORY GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST DEFINED)
if (NOT ${HAS_GIT_UTILS_REPOSITORY})
    define_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST BRIEF_DOCS "Initialized git repositories list" FULL_DOCS "List of already initialized git repositories")
    set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST "")
endif()

function(__GitUtils_DefineIncludeMapItem PROJECT)
    get_property(HAS_PROJECT_INCLUDE GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} DEFINED)
    if (NOT ${HAS_PROJECT_INCLUDE})
        define_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT}
                        BRIEF_DOCS "Project ${PROJECT} git repository include property"
                        FULL_DOCS "Project ${PROJECT} git repository property with include paths list")
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} "")
    endif()
endfunction()


function(__GitUtils_AppendIncludeMapItem PROJECT PATH)
    __GitUtils_DefineIncludeMapItem(${PROJECT})
    get_property(PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT})
    if (NOT (${PATH} IN_LIST PROJECT_INCLUDE_LIST))
        list(APPEND PROJECT_INCLUDE_LIST ${PATH})
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} ${PROJECT_INCLUDE_LIST})
    endif()
endfunction()


function(__GitUtils_ResetIncludeMapItem PROJECT)
    __GitUtils_DefineIncludeMapItem(${PROJECT})
    set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${PROJECT} "")
endfunction()


function(__GitUtils_DefineDependencyMapItem PROJECT)
    get_property(HAS_PROJECT_DEPENDS GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} DEFINED)
    if (NOT ${HAS_PROJECT_DEPENDS})
        define_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT}
                        BRIEF_DOCS "Project ${PROJECT} git repository dependencies property"
                        FULL_DOCS "Project ${PROJECT} git repository property with dependencies list")
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} "")
    endif()
endfunction()


function(__GitUtils_AppendDependencyMapItem PROJECT DEPEND)
    __GitUtils_DefineDependencyMapItem(${PROJECT})
    get_property(PROJECT_DEPENDS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT})
    if (NOT (${DEPEND} IN_LIST PROJECT_DEPENDS_LIST))
        list(APPEND PROJECT_DEPENDS_LIST ${DEPEND})
        set_property(GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} ${PROJECT_DEPENDS_LIST})
    endif()
endfunction()


function(__GitUtils_RecurciveDependency PROJECT DEPENDENCY_INCLUDE_LIST)
    if (NOT DEFINED ${DEPENDENCY_INCLUDE_LIST})
        set(${DEPENDENCY_INCLUDE_LIST} "" PARENT_SCOPE)
    endif()

    get_property(HAS_DEPEND GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT} DEFINED)
    if (${HAS_DEPEND})
        get_property(DEPEND_PROJECTS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_DEPENDENCY_MAP_${PROJECT})
        foreach(DEPEND ${DEPEND_PROJECTS_LIST})
            __GitUtils_RecurciveDependency(${DEPEND} ${DEPENDENCY_INCLUDE_LIST})
            set(${DEPENDENCY_INCLUDE_LIST} ${${DEPENDENCY_INCLUDE_LIST}} PARENT_SCOPE)
        endforeach()
    endif()

    get_property(HAS_DEPEND_INCLUDE GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${DEPEND} DEFINED)
    if (NOT ${HAS_DEPEND_INCLUDE})
        message(FATAL_ERROR "[ERROR GIT] repository project ${DEPEND} must be defined before set as depend for target")
    endif()
    get_property(DEPEND_PROJECT_INCLUDE_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECT_INCLUDE_MAP_${DEPEND})
    foreach(DEPEND_INCLUDE ${DEPEND_PROJECT_INCLUDE_LIST})
        if (NOT (${DEPEND_INCLUDE} IN_LIST ${DEPENDENCY_INCLUDE_LIST}))
            list(APPEND ${DEPENDENCY_INCLUDE_LIST} ${DEPEND_INCLUDE})
            set(${DEPENDENCY_INCLUDE_LIST} ${${DEPENDENCY_INCLUDE_LIST}} PARENT_SCOPE)
        endif()
    endforeach()
endfunction()


function(GitUtils_Define PROJECT GIT_URL)
    set(ARGS_OPT FREEZE PULL LOCAL OVERRIDE NO_SUBMAKE SUBMODULES SINGLE DEPTHONE)
    set(ARGS_ONE TAG FOLDER FOLDER_ABS INCLUDE BUILD )
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGN})

    string(TOUPPER ${PROJECT} NAME)
    set(FULL_PROJECT_NAME ${PROJECT})

    if (${GIT_ARGS_SINGLE})
        set(SINGLE_BRANCH "--single-branch")
    else()
        set(SINGLE_BRANCH "--no-single-branch")
    endif()

    if (${GIT_ARGS_DEPTHONE})
        set(BRANCH_DEPTH "--shallow-submodules")
    else()
        set(BRANCH_DEPTH "--no-shallow-submodules")
    endif()

    get_property(PROJECTS_LIST GLOBAL PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST)
    if (NOT (${FULL_PROJECT_NAME} IN_LIST PROJECTS_LIST))
        if ((DEFINED GIT_ARGS_OVERRIDE) AND (${GIT_ARGS_OVERRIDE}))
            message("[OVERRIDE GIT] repository project ${PROJECT} to ${FULL_PROJECT_NAME}")
        else()
            message("[DEFINE GIT] repository project ${PROJECT} to ${FULL_PROJECT_NAME}")
        endif()

        if (NOT DEFINED GIT_ARGS_FOLDER)
            set(GIT_ARGS_FOLDER "external")
        endif()

        if ((DEFINED GIT_ARGS_LOCAL) AND (${GIT_ARGS_LOCAL}))
            set(INTERNAL_CMAKE_SOURCE ${CMAKE_CURRENT_SOURCE_DIR})
        else()
            set(INTERNAL_CMAKE_SOURCE ${CMAKE_SOURCE_DIR})
        endif()

        if ((DEFINED GIT_ARGS_OVERRIDE) AND (${GIT_ARGS_OVERRIDE}))
            __GitUtils_ResetIncludeMapItem(${PROJECT})
        endif()

        if (NOT DEFINED GIT_ARGS_FOLDER_ABS)
            set(GIT_ARGS_FOLDER_ABS ${INTERNAL_CMAKE_SOURCE}/${GIT_ARGS_FOLDER}/)
        endif()

        __GitUtils_AppendIncludeMapItem(${PROJECT} ${GIT_ARGS_FOLDER_ABS})

        get_filename_component(GIT_FOLDER ${GIT_ARGS_FOLDER_ABS}${FULL_PROJECT_NAME} ABSOLUTE)
        get_filename_component(ABS_GIT_URL "${GIT_URL}" ABSOLUTE)


        if(NOT EXISTS ${GIT_FOLDER})
            if (${GIT_ARGS_SINGLE} OR DEFINED GIT_ARGS_DEPTH)
                message("[CLONE GIT] ${FULL_PROJECT_NAME} : ${GIT_URL} @ ${GIT_ARGS_TAG}")
                execute_process(COMMAND git clone -b ${GIT_ARGS_TAG} ${SINGLE_BRANCH} ${BRANCH_DEPTH} ${GIT_URL} ${GIT_FOLDER}/)
            else()
                message("[CLONE GIT] ${FULL_PROJECT_NAME} : ${GIT_URL}")
                execute_process(COMMAND git clone -b ${GIT_ARGS_TAG} ${SINGLE_BRANCH} ${GIT_URL} ${GIT_FOLDER}/)
                if (DEFINED GIT_ARGS_TAG)
                    message("[CHECKOUT GIT] ${PROJECT}/${GIT_ARGS_TAG}")
                    execute_process(COMMAND git checkout ${GIT_ARGS_TAG} WORKING_DIRECTORY ${GIT_FOLDER}/)
                endif()
            endif()
            if ((DEFINED GIT_ARGS_SUBMODULES) AND (${GIT_ARGS_SUBMODULES}))
            execute_process(COMMAND git submodule update --init --recursive WORKING_DIRECTORY ${GIT_FOLDER}/)
        endif()
    else()
            if ((NOT DEFINED GIT_ARGS_FREEZE) OR (NOT ${GIT_ARGS_FREEZE}))
                set(SUBMODULE_ARG "")
                if ((DEFINED GIT_ARGS_SUBMODULES) AND (${GIT_ARGS_SUBMODULES}))
                    set(SUBMODULE_ARG "--recurse-submodules=on-demand")
                endif()

                if (NOT ("${ABS_GIT_URL}" STREQUAL "${GIT_FOLDER}"))
                    if ((DEFINED GIT_ARGS_PULL) AND (${GIT_ARGS_PULL}))
                        message("[PULL GIT] ${FULL_PROJECT_NAME} : ${GIT_URL}")
                        execute_process(COMMAND git pull ${SUBMODULE_ARG} WORKING_DIRECTORY ${GIT_FOLDER}/)
                    endif()
                endif()
            else()
                message("[FREEZE GIT] ${PROJECT}/${GIT_ARGS_TAG}")
                execute_process(COMMAND  git status -s
                                WORKING_DIRECTORY ${GIT_FOLDER}/
                                OUTPUT_VARIABLE result_var)
                string(COMPARE EQUAL "${result_var}" "" result)
                if(NOT result)
                execute_process(COMMAND git add . --all
                                WORKING_DIRECTORY ${GIT_FOLDER}/)
                execute_process(COMMAND git stash
                                WORKING_DIRECTORY ${GIT_FOLDER}/)
                endif()
            endif()
        endif()

        get_filename_component(ABS_CURRENT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
        if (NOT ("${ABS_CURRENT_SOURCE_DIR}" STREQUAL "${GIT_FOLDER}"))
            if ((EXISTS ${GIT_FOLDER}/CMakeLists.txt) AND ((NOT DEFINED GIT_ARGS_NO_SUBMAKE) OR (NOT ${GIT_ARGS_NO_SUBMAKE})))
                if (DEFINED GIT_ARGS_BUILD)
                    add_subdirectory(${GIT_FOLDER}/ ${GIT_ARGS_BUILD})
                else()
                    add_subdirectory(${GIT_FOLDER}/ ${GIT_FOLDER}/build)
                endif()
            endif()
        endif()

        set(SEARCH_INCLUDE "")
        if (DEFINED GIT_ARGS_INCLUDE)
            list(APPEND SEARCH_INCLUDE ${GIT_ARGS_INCLUDE})
        endif()
        list(APPEND SEARCH_INCLUDE include src source Src Source)
        foreach(INCLUDE_DIR ${SEARCH_INCLUDE})
            if (EXISTS ${GIT_FOLDER}/${INCLUDE_DIR}/)
                __GitUtils_AppendIncludeMapItem(${PROJECT} ${GIT_FOLDER}/${INCLUDE_DIR}/)
                break()
            endif()
        endforeach()

        set_property(GLOBAL APPEND PROPERTY GLOBAL_GIT_UTILS_PROJECTS_LIST ${FULL_PROJECT_NAME})
    endif()

    set(${NAME}_SOURCE_DIR "${GIT_FOLDER}" CACHE PATH
        "Path to ${GIT_FOLDER} source tree.")

    if(NOT ${NAME}_SOURCE_DIR)
        message(FATAL_ERROR
            "Please specify a path to the ${NAME} source code "
            "checkout, using the ${NAME}_SOURCE_DIR option.")
    endif()

    if(NOT IS_ABSOLUTE ${${NAME}_SOURCE_DIR})
        get_filename_component(${NAME}_SOURCE_DIR ${${NAME}_SOURCE_DIR} ABSOLUTE)
    endif()

    if(NOT IS_DIRECTORY ${${NAME}_SOURCE_DIR})
        message(FATAL_ERROR
            "${NAME} source code checkout was not found at "
            "${${NAME}_SOURCE_DIR}. Please clone the ${PROJECT} Git repo to that "
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

    message(STATUS "Using ${PROJECT} branch ${${NAME}_BRANCH_NAME}")
    message(STATUS "  (commit ${${NAME}_COMMIT_SHA1})")

endfunction()


function(GitUtils_Depends PROJECT)
    set(ARGS_OPT "")
    set(ARGS_ONE "")
    set(ARGS_LIST DEPENDS)
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGN})

    message("[DEPENDENCY GIT] ${PROJECT}: ${GIT_ARGS_DEPENDS}")

    foreach(DEPEND ${GIT_ARGS_DEPENDS})
        __GitUtils_AppendDependencyMapItem(${PROJECT} ${DEPEND})
    endforeach()
endfunction()


function(GitUtils_TargetInclude TARGET)
    set(ARGS_OPT "")
    set(ARGS_ONE "")
    set(ARGS_LIST DEPENDS)
    cmake_parse_arguments(GIT_ARGS "${ARGS_OPT}" "${ARGS_ONE}" "${ARGS_LIST}" ${ARGN})

    set(TARGET_DEPENDS "")
    foreach(DEPEND ${GIT_ARGS_DEPENDS})
        __GitUtils_RecurciveDependency(${DEPEND} TARGET_DEPENDS)
    endforeach()

    message("[TARGET GIT INCLUDES] ${TARGET}")

    foreach(DEPEND ${TARGET_DEPENDS})
        message("    ${DEPEND}")
    endforeach()
    message("[END TARGET GIT INCLUDES] ${TARGET}")
    target_include_directories(${TARGET} PRIVATE ${TARGET_DEPENDS})
endfunction()
