set(TIME_ARC_DATABASE_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/services/AppRepository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/AppRepository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/DailyCardService.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/DailyCardService.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/DatabaseManager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/DatabaseManager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/FrontmostSessionRepository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/FrontmostSessionRepository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/ManualProjectRepository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/ManualProjectRepository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/MediaSessionRepository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/MediaSessionRepository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/SettingsRepository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/SettingsRepository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/StatsService.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/StatsService.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/calendarmanager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/calendarmanager.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/projectmanager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/projectmanager.h
)

set(TIME_ARC_APP_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/main.cpp
    ${TIME_ARC_DATABASE_SOURCES}
    ${CMAKE_CURRENT_SOURCE_DIR}/services/TagRepository.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/TagRepository.h
    ${CMAKE_CURRENT_SOURCE_DIR}/services/timermanager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/usagestatmanager.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/appiconimageprovider.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/services/harnesslogger.cpp
)

set(TIME_ARC_INCLUDE_DIRS
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/services
)

add_subdirectory(service)

set(TIME_ARC_APP_SOURCES ${TIME_ARC_APP_SOURCES} PARENT_SCOPE)
set(TIME_ARC_DATABASE_SOURCES ${TIME_ARC_DATABASE_SOURCES} PARENT_SCOPE)
set(TIME_ARC_INCLUDE_DIRS ${TIME_ARC_INCLUDE_DIRS} PARENT_SCOPE)
