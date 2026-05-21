# SPDX-License-Identifier: GPL-3.0-or-later
#
# HarnessHooks.cmake - optional integration of the TimeArc harness with
# the main CMake build. The build MUST keep working when this file is
# absent; do not make the harness a hard build dependency.
#
# Opt in from the root CMakeLists.txt with:
#
#   if(EXISTS ${CMAKE_SOURCE_DIR}/.harness/tools/cmake/HarnessHooks.cmake)
#     include(${CMAKE_SOURCE_DIR}/.harness/tools/cmake/HarnessHooks.cmake)
#     timearc_harness_enable()
#   endif()

include_guard(GLOBAL)

set(TIMEARC_HARNESS_ROOT "${CMAKE_SOURCE_DIR}/.harness"
    CACHE PATH "Path to the TimeArc harness root")


# timearc_harness_enable()
#   Master switch. Finds Python and wires the check target. Safe to call
#   even if Python is missing (prints a warning and skips hooks).
function(timearc_harness_enable)
    set(_timearc_python "")
    if(DEFINED ENV{TIMEARC_PYTHON} AND NOT "$ENV{TIMEARC_PYTHON}" STREQUAL "")
        if(EXISTS "$ENV{TIMEARC_PYTHON}")
            set(_timearc_python "$ENV{TIMEARC_PYTHON}")
        else()
            message(WARNING
                "TimeArc harness: TIMEARC_PYTHON is set but not found: $ENV{TIMEARC_PYTHON}")
        endif()
    endif()
    if(NOT _timearc_python)
        find_package(Python3 COMPONENTS Interpreter QUIET)
        if(Python3_Interpreter_FOUND)
            set(_timearc_python "${Python3_EXECUTABLE}")
        endif()
    endif()
    if(NOT _timearc_python)
        message(WARNING
            "TimeArc harness: Python3 not found; set TIMEARC_PYTHON to enable hooks.")
        return()
    endif()
    message(STATUS
        "TimeArc harness: enabled (python=${_timearc_python})")
    set(TIMEARC_HARNESS_PYTHON "${_timearc_python}"
        CACHE INTERNAL "Python used by TimeArc harness")
    timearc_harness_add_check_target()
endfunction()


# timearc_harness_add_check_target()
#   Adds a `harness-check` target that runs harness_check.py at the
#   project root. Not in ALL; run explicitly with `cmake --build . --target
#   harness-check`. Fails the command if drift is detected.
function(timearc_harness_add_check_target)
    if(NOT DEFINED TIMEARC_HARNESS_PYTHON)
        return()
    endif()
    if(TARGET harness-check)
        return()
    endif()
    add_custom_target(harness-check
        COMMAND ${TIMEARC_HARNESS_PYTHON}
                ${TIMEARC_HARNESS_ROOT}/tools/harness_check.py
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "TimeArc harness: running full audit"
        VERBATIM)
    message(STATUS
        "TimeArc harness: added target 'harness-check' (not in ALL)")
endfunction()


# timearc_harness_record_build_target(<target> <track> <topic>)
#   Attach a POST_BUILD command that records a journal entry if the given
#   target's build completed. Intended for tracking successful rebuilds
#   during long refactors; failures are captured by build.py, not here
#   (POST_BUILD only fires on success).
function(timearc_harness_record_build_target target track topic)
    if(NOT DEFINED TIMEARC_HARNESS_PYTHON)
        return()
    endif()
    if(NOT TARGET ${target})
        message(WARNING "TimeArc harness: no such target '${target}'")
        return()
    endif()
    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E echo
            "TimeArc harness: ${target} built (${track}/${topic})"
        VERBATIM)
endfunction()
