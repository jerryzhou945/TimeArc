set(TIME_ARC_SERVICE_SHARED_COMMON_HEADERS
    ${CMAKE_CURRENT_SOURCE_DIR}/shared/data_bridge.h
)

set(TIME_ARC_SERVICE_SHARED_COMMON_C_SOURCES
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
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/AppEnv.swift
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/AppInfo.swift
    )
elseif(WIN32)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/windows/main.c)
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

target_include_directories(time_arc_service PRIVATE
    ${PROJECT_SOURCE_DIR}/src/include
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
)

target_link_libraries(time_arc_service
    PRIVATE
        ${TIME_ARC_THIRDPARTY_LIBS}
)

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
