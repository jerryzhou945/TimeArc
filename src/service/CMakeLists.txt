set(TIME_ARC_SERVICE_SHARED_COMMON_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/data_bridge.h
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/database_storage.h
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/database_path.h
)

set(TIME_ARC_SERVICE_SHARED_COMMON_C_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/data_bridge.c
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/database_storage.c
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/database_path.c
)

set(TIME_ARC_SERVICE_SHARED_WINLINUX_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/app_info.h
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/app_env.h
)

set(TIME_ARC_SERVICE_SHARED_WINLINUX_C_SOURCES
)

if(WIN32 OR (UNIX AND NOT APPLE))
    set(TIME_ARC_SERVICE_SHARED_HEADERS
        ${TIME_ARC_SERVICE_SHARED_COMMON_HEADERS}
        ${TIME_ARC_SERVICE_SHARED_WINLINUX_HEADERS}
    )

    set(TIME_ARC_SERVICE_SHARED_C_SOURCES
        ${TIME_ARC_SERVICE_SHARED_COMMON_C_SOURCES}
        ${TIME_ARC_SERVICE_SHARED_WINLINUX_C_SOURCES}
    )
else()
    set(TIME_ARC_SERVICE_SHARED_HEADERS
        ${TIME_ARC_SERVICE_SHARED_COMMON_HEADERS}
    )

    set(TIME_ARC_SERVICE_SHARED_C_SOURCES
        ${TIME_ARC_SERVICE_SHARED_COMMON_C_SOURCES}
    )
endif()

if(APPLE)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/TimeArcService.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/TrackingPorts.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/AccessibilityRequest.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/ApplicationProbe.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/AudioProcessProbe.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/InputActionProbe.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/SleepAssertionProbe.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/TitleProbe.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/FrontmostStateMachine.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/MediaStateMachine.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/DataBridge.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/Tracking/TrackingCoordinator.swift
    )
elseif(WIN32)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/main.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/service_config.h
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/service_config.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/tracker/usage_tracker.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/tracker/audio_tracker.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/platform/active_app_win.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/platform/audio_win.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/platform/idle_win.c
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/service/win_service.c
    )
elseif(UNIX)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/linux/main.c)
else()
    message(FATAL_ERROR "Unsupported platform for time-arc-service")
endif()

set(TIME_ARC_SERVICE_SOURCES
    ${TIME_ARC_SERVICE_PLATFORM_SOURCES}
    ${TIME_ARC_SERVICE_SHARED_C_SOURCES}
    ${TIME_ARC_SERVICE_SHARED_HEADERS}
)

add_executable(time_arc_service
    ${TIME_ARC_SERVICE_SOURCES}
)

target_compile_definitions(time_arc_service PRIVATE
    "$<$<CONFIG:Debug>:TIMEARC_DEBUG>"
)

target_include_directories(time_arc_service PRIVATE
    ${PROJECT_SOURCE_DIR}/src/include
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
    ${CMAKE_CURRENT_SOURCE_DIR}/windows
    ${CMAKE_CURRENT_SOURCE_DIR}/windows/tracker
    ${CMAKE_CURRENT_SOURCE_DIR}/windows/platform
    ${CMAKE_CURRENT_SOURCE_DIR}/windows/service
)

target_link_libraries(time_arc_service PRIVATE
    ${TIME_ARC_THIRDPARTY_LIBS}
)

if(WIN32)
    target_link_libraries(time_arc_service PRIVATE
        user32
        psapi
        ole32
        uuid
    )
elseif(APPLE)
    find_library(TIMEARC_APPKIT_FRAMEWORK AppKit REQUIRED)
    find_library(TIMEARC_APPLICATIONSERVICES_FRAMEWORK ApplicationServices REQUIRED)
    find_library(TIMEARC_COREAUDIO_FRAMEWORK CoreAudio REQUIRED)
    find_library(TIMEARC_COREGRAPHICS_FRAMEWORK CoreGraphics REQUIRED)
    find_library(TIMEARC_IOKIT_FRAMEWORK IOKit REQUIRED)

    target_link_libraries(time_arc_service PRIVATE
        ${TIMEARC_APPKIT_FRAMEWORK}
        ${TIMEARC_APPLICATIONSERVICES_FRAMEWORK}
        ${TIMEARC_COREAUDIO_FRAMEWORK}
        ${TIMEARC_COREGRAPHICS_FRAMEWORK}
        ${TIMEARC_IOKIT_FRAMEWORK}
    )
else()
    target_link_libraries(time_arc_service PRIVATE
    )
endif()

if(APPLE)
    target_compile_options(time_arc_service PRIVATE
        $<$<COMPILE_LANGUAGE:Swift>:-import-objc-header>
        $<$<COMPILE_LANGUAGE:Swift>:${CMAKE_CURRENT_SOURCE_DIR}/shared/data_bridge.h>
        $<$<COMPILE_LANGUAGE:Swift>:-Xcc>
        $<$<COMPILE_LANGUAGE:Swift>:-I${PROJECT_SOURCE_DIR}/src/include>
        $<$<COMPILE_LANGUAGE:Swift>:-Xcc>
        $<$<COMPILE_LANGUAGE:Swift>:-I${CMAKE_CURRENT_SOURCE_DIR}/shared>
    )
endif()

set_target_properties(time_arc_service PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
    OUTPUT_NAME "time-arc-service"
)
