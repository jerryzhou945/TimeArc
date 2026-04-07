add_library(time-arc-sqlite3 STATIC
    sqlite3.c
)

target_include_directories(time-arc-sqlite3
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)

set_target_properties(time-arc-sqlite3 PROPERTIES
    AUTOMOC OFF
    AUTOUIC OFF
    AUTORCC OFF
    POSITION_INDEPENDENT_CODE ON
)
