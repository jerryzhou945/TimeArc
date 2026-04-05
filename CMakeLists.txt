cmake_minimum_required(VERSION 3.16)

project(time-arc VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Svg)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(apptime-arc
    src/main.cpp
    src/services/timermanager.cpp
    src/services/projectmanager.cpp
)

target_include_directories(apptime-arc PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/src/services
)

qt_add_qml_module(apptime-arc
    URI time_arc
    VERSION 1.0

    QML_FILES
        qml/Main.qml
        qml/desktop/DesktopAppShell.qml
        qml/desktop/pages/DesktopHomePage.qml
        qml/desktop/pages/DesktopChatPage.qml
        qml/desktop/pages/DesktopTimerPage.qml

    RESOURCES
        qml/assets/icons/home.svg
        qml/assets/icons/chat.svg
        qml/assets/icons/calendar.svg
        qml/assets/icons/stats.svg
        qml/assets/icons/user.svg
)

set_target_properties(apptime-arc PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(apptime-arc
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::Svg
)

include(GNUInstallDirs)
install(TARGETS apptime-arc
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
