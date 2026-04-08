set(TIME_ARC_SERVICE_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/main.c
)

add_executable(time-arc-service
    ${TIME_ARC_SERVICE_SOURCES}
)

target_include_directories(time-arc-service PRIVATE
    ${PROJECT_SOURCE_DIR}/src/include
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
)

set_target_properties(time-arc-service PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
    OUTPUT_NAME "time-arc-service"
)
