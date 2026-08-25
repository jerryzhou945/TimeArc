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
    enable_language(OBJCXX)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Quick Svg Sql Widgets)

qt_standard_project_setup(REQUIRES 6.8)

add_subdirectory(thirdparty)
add_subdirectory(src)
add_subdirectory(qml)
add_subdirectory(resources)

if(APPLE)
    set(TIME_ARC_MACOS_BUNDLE_ICON
        "${CMAKE_CURRENT_SOURCE_DIR}/resources/bundle/macos/TimeArc.icns")
    set(TIME_ARC_MACOS_LAUNCH_AGENT
        "${CMAKE_CURRENT_SOURCE_DIR}/resources/bundle/macos/com.timearc.service.plist")
    set_source_files_properties(${TIME_ARC_MACOS_BUNDLE_ICON} PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources"
    )
    set_source_files_properties(${TIME_ARC_MACOS_LAUNCH_AGENT} PROPERTIES
        MACOSX_PACKAGE_LOCATION "Library/LaunchAgents"
    )
    # The launch agent template is still bundled, but the UI no longer registers
    # it: the service owns that (CHARTER v0.14) through `time-arc-service enable`.
    list(APPEND TIME_ARC_APP_SOURCES
        ${TIME_ARC_MACOS_BUNDLE_ICON}
        ${TIME_ARC_MACOS_LAUNCH_AGENT}
    )
    set(MACOSX_BUNDLE_ICON_FILE "TimeArc.icns")
endif()

if(WIN32)
    list(APPEND TIME_ARC_APP_SOURCES
        "${CMAKE_CURRENT_SOURCE_DIR}/resources/bundle/windows/TimeArc.rc"
    )
endif()

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

if(ANDROID)
    qt_add_resources(TIME_ARC_ANDROID_GUI_ASSETS
        ${TIME_ARC_BUNDLED_RESOURCE_QRCS}
    )
    target_sources(time-arc PRIVATE ${TIME_ARC_ANDROID_GUI_ASSETS})
else()
    if(APPLE)
        set(TIME_ARC_GUI_ASSET_OUTPUT_DIR
            "$<TARGET_BUNDLE_DIR:time-arc>/Contents/Resources/assets")
    else()
        set(TIME_ARC_GUI_ASSET_OUTPUT_DIR
            "$<TARGET_FILE_DIR:time-arc>/assets")
    endif()

    add_custom_command(TARGET time-arc POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
            "${TIME_ARC_GUI_ASSET_OUTPUT_DIR}"
        COMMAND ${CMAKE_COMMAND} -E remove -f
            "${TIME_ARC_GUI_ASSET_OUTPUT_DIR}/timearc-gui-assets.rcc"
        VERBATIM
    )

    set(TIME_ARC_GUI_ASSET_RCCS)
    set(TIME_ARC_GUI_ASSET_TARGETS)
    foreach(TIME_ARC_GUI_ASSET_QRC IN LISTS TIME_ARC_BUNDLED_RESOURCE_QRCS)
        get_filename_component(TIME_ARC_GUI_ASSET_NAME
            "${TIME_ARC_GUI_ASSET_QRC}" NAME_WE)
        string(REPLACE "-" "_" TIME_ARC_GUI_ASSET_TARGET_SUFFIX
            "${TIME_ARC_GUI_ASSET_NAME}")
        set(TIME_ARC_GUI_ASSET_TARGET
            "time_arc_${TIME_ARC_GUI_ASSET_TARGET_SUFFIX}_assets")
        set(TIME_ARC_GUI_ASSET_RCC
            "${CMAKE_CURRENT_BINARY_DIR}/timearc-${TIME_ARC_GUI_ASSET_NAME}.rcc")

        qt_add_binary_resources(${TIME_ARC_GUI_ASSET_TARGET}
            "${TIME_ARC_GUI_ASSET_QRC}"
            DESTINATION "${TIME_ARC_GUI_ASSET_RCC}"
            OPTIONS --no-compress
        )
        add_dependencies(time-arc ${TIME_ARC_GUI_ASSET_TARGET})
        list(APPEND TIME_ARC_GUI_ASSET_TARGETS ${TIME_ARC_GUI_ASSET_TARGET})
        list(APPEND TIME_ARC_GUI_ASSET_RCCS "${TIME_ARC_GUI_ASSET_RCC}")

        add_custom_command(TARGET time-arc POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${TIME_ARC_GUI_ASSET_RCC}"
                "${TIME_ARC_GUI_ASSET_OUTPUT_DIR}/timearc-${TIME_ARC_GUI_ASSET_NAME}.rcc"
            VERBATIM
        )
    endforeach()
endif()

set_target_properties(time-arc PROPERTIES
    OUTPUT_NAME "TimeArc"
    MACOSX_BUNDLE_BUNDLE_NAME "TimeArc"
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.timearc.TimeArcDesktop"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

if(ANDROID)
    set_property(TARGET time-arc PROPERTY
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_SOURCE_DIR}/android")
endif()

target_link_libraries(time-arc
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::Svg
        Qt6::Sql
        Qt6::Widgets
    ${TIME_ARC_THIRDPARTY_LIBS}
)

if(APPLE)
    add_dependencies(time-arc time_arc_service)
    add_custom_command(TARGET time-arc POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E remove -f
            "$<TARGET_BUNDLE_DIR:time-arc>/Contents/Resources/com.timearc.service.plist"
        COMMAND ${CMAKE_COMMAND} -E remove -f
            "$<TARGET_BUNDLE_DIR:time-arc>/Contents/Helpers/timearc-service"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:time_arc_service>"
            "$<TARGET_BUNDLE_DIR:time-arc>/Contents/MacOS/time-arc-service"
        VERBATIM
    )
endif()

enable_testing()

if(NOT ANDROID)
    add_executable(timearc_resource_bundle_smoke
        tests/resource_bundle_smoke.cpp
    )
    target_link_libraries(timearc_resource_bundle_smoke PRIVATE Qt6::Core)
    add_dependencies(timearc_resource_bundle_smoke
        ${TIME_ARC_GUI_ASSET_TARGETS}
    )
    add_test(
        NAME timearc_resource_bundle_smoke
        COMMAND timearc_resource_bundle_smoke ${TIME_ARC_GUI_ASSET_RCCS}
    )
endif()

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

# 计时引擎的状态机 + 墙钟行为（两个管理器都留了可注入的 currentMs()）。
add_executable(timearc_pomodoro_test
    tests/pomodoro_manager_test.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/services/pomodoro_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/src/services/timer_manager.cpp
    ${TIME_ARC_DATABASE_SOURCES}
)

target_include_directories(timearc_pomodoro_test PRIVATE
    ${TIME_ARC_INCLUDE_DIRS}
)

target_link_libraries(timearc_pomodoro_test
    PRIVATE
        Qt6::Core
        Qt6::Sql
)

add_test(NAME timearc_pomodoro_test COMMAND timearc_pomodoro_test)

if(WIN32)
    add_executable(timearc_windows_foreground_state_test
        tests/windows_foreground_state_test.c
        src/service/windows/platform/app_identity.c
        src/service/windows/tracker/foreground_state.c
        src/service/windows/platform/idle_win.c
        src/service/windows/platform/process_activity_win.c
    )
    target_include_directories(timearc_windows_foreground_state_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/include
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/shared
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/windows/tracker
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/windows/platform
    )
    target_link_libraries(timearc_windows_foreground_state_test PRIVATE user32)
    add_test(
        NAME timearc_windows_foreground_state_test
        COMMAND timearc_windows_foreground_state_test
    )

    add_executable(timearc_windows_audio_tracker_test
        tests/windows_audio_tracker_test.c
        src/service/windows/tracker/audio_tracker.c
        src/service/windows/platform/app_identity.c
    )
    target_include_directories(timearc_windows_audio_tracker_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/include
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/shared
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/windows/tracker
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/windows/platform
    )
    add_test(
        NAME timearc_windows_audio_tracker_test
        COMMAND timearc_windows_audio_tracker_test
    )

    add_executable(timearc_windows_audio_title_policy_test
        tests/windows_audio_title_policy_test.c
        src/service/windows/platform/audio_win.c
        src/service/windows/platform/active_app_win.c
        src/service/windows/platform/app_identity.c
    )
    target_include_directories(timearc_windows_audio_title_policy_test PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src/include
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/shared
        ${CMAKE_CURRENT_SOURCE_DIR}/src/service/windows/platform
    )
    target_link_libraries(timearc_windows_audio_title_policy_test PRIVATE
        user32 psapi ole32 uuid
    )
    add_test(
        NAME timearc_windows_audio_title_policy_test
        COMMAND timearc_windows_audio_title_policy_test
    )
endif()

include(GNUInstallDirs)
install(TARGETS time-arc
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(NOT APPLE)
    install(TARGETS time_arc_service
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
    if(NOT ANDROID)
        install(FILES ${TIME_ARC_GUI_ASSET_RCCS}
            DESTINATION "${CMAKE_INSTALL_BINDIR}/assets"
        )
    endif()
endif()
