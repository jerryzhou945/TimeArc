add_library(time-arc-parson STATIC
    parson.c
)

target_include_directories(time-arc-parson
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)

set_target_properties(time-arc-parson PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
    POSITION_INDEPENDENT_CODE ON
)
