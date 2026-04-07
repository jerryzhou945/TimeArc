set(TIME_ARC_SERVICE_SHARED_SOURCES
)

if(WIN32)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/windows/main.c
    )
elseif(APPLE)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/macos/main.c
    )
elseif(UNIX)
    set(TIME_ARC_SERVICE_PLATFORM_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/linux/main.c
    )
else()
    message(FATAL_ERROR "Unsupported operating system for service target")
endif()

add_executable(time-arc-service
    ${TIME_ARC_SERVICE_SHARED_SOURCES}
    ${TIME_ARC_SERVICE_PLATFORM_SOURCES}
)

target_include_directories(time-arc-service PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
)

set_target_properties(time-arc-service PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
    OUTPUT_NAME "time-arc-service"
)
