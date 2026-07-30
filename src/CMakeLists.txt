set(TIME_ARC_DATABASE_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/services/app_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/app_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/daily_card_service.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/daily_card_service.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/database_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/database_manager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/frontmost_session_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/frontmost_session_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/manual_project_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/manual_project_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/media_session_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/media_session_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/mobile_usage_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/mobile_usage_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/android_usage_jni_bridge.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/mobile_usage_service.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/mobile_usage_service.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/settings_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/settings_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/stats_service.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/stats_service.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/calendar_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/calendar_manager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/project_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/project_manager.h
)

set(TIME_ARC_APP_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
    ${TIME_ARC_DATABASE_SOURCES}
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/mobile_ui_service.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/mobile/mobile_ui_service.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/tag_repository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/tag_repository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/pomodoro_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/pomodoro_manager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/timer_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/usage_stat_manager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/app_icon_image_provider.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/harness_logger.cpp
)

if(APPLE)
    list(APPEND TIME_ARC_APP_SOURCES
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_app_lifecycle.h
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_app_lifecycle.mm
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_menu_localizer.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_menu_localizer.h
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_status_bar_icon.cpp
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_status_bar_icon.h
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_traffic_lights.h
        ${CMAKE_CURRENT_SOURCE_DIR}/services/macos/macos_traffic_lights.mm
    )
endif()

set(TIME_ARC_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/services
)

add_subdirectory(service)

set(TIME_ARC_APP_SOURCES ${TIME_ARC_APP_SOURCES} PARENT_SCOPE)
set(TIME_ARC_DATABASE_SOURCES ${TIME_ARC_DATABASE_SOURCES} PARENT_SCOPE)
set(TIME_ARC_INCLUDE_DIRS ${TIME_ARC_INCLUDE_DIRS} PARENT_SCOPE)
