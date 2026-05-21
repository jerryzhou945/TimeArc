cmake_minimum_required(VERSION 3.16)

project(time-arc VERSION 0.1 LANGUAGES C CXX)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

if(APPLE)
    if(POLICY CMP0157)
        cmake_policy(SET CMP0157 NEW)
    endif()
    enable_language(Swift)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Svg Sql Widgets)

qt_standard_project_setup(REQUIRES 6.8)

add_subdirectory(thirdparty)
add_subdirectory(src)
add_subdirectory(qml)
add_subdirectory(resources)

qt_add_executable(time-arc ${TIME_ARC_APP_SOURCES})

target_include_directories(time-arc PRIVATE
    ${TIME_ARC_INCLUDE_DIRS}
)

qt_add_qml_module(time-arc
    URI time_arc
    VERSION 1.0

    QML_FILES
        ${TIME_ARC_QML_FILES}

    RESOURCES
        ${TIME_ARC_RESOURCE_FILES}
)

set_target_properties(time-arc PROPERTIES
    OUTPUT_NAME "TimeArc"
    MACOSX_BUNDLE_BUNDLE_NAME "TimeArc"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(time-arc
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::Svg
        Qt6::Sql
        Qt6::Widgets
    ${TIME_ARC_THIRDPARTY_LIBS}
)

enable_testing()

add_executable(timearc_db_smoke
    tests/db_smoke.cpp
    ${TIME_ARC_DATABASE_SOURCES}
)

target_include_directories(timearc_db_smoke PRIVATE
    ${TIME_ARC_INCLUDE_DIRS}
)

target_link_libraries(timearc_db_smoke
    PRIVATE
        Qt6::Core
        Qt6::Sql
)

add_test(NAME timearc_db_smoke COMMAND timearc_db_smoke)

include(GNUInstallDirs)
install(TARGETS time-arc
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(TARGETS time_arc_service
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
