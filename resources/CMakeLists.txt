set(TIME_ARC_APP_RESOURCES
    resources/app/TimeArc.svg
    resources/app/icons/navigation/home.svg
    resources/app/icons/navigation/home_white.svg
    resources/app/icons/navigation/calendar.svg
    resources/app/icons/navigation/calendar_white.svg
    resources/app/icons/navigation/stats.svg
    resources/app/icons/navigation/stats_white.svg
    resources/app/icons/navigation/settings.svg
    resources/app/icons/navigation/settings_white.svg
    resources/app/icons/navigation/note.svg
    resources/app/icons/navigation/note_white.svg
    resources/app/icons/navigation/recap.svg
    resources/app/icons/navigation/recap_white.svg
    resources/app/icons/mobile/download.svg
    resources/app/icons/mobile/group.svg
    resources/app/icons/mobile/star.svg
    resources/app/icons/mobile/more.svg
    resources/app/icons/mobile/shield.svg
    resources/app/icons/mobile/sync.svg
    resources/app/icons/mobile/clock.svg
    resources/app/icons/mobile/image.svg
    resources/app/icons/mobile/clear.svg
    resources/app/icons/mobile/sun.svg
    resources/app/icons/mobile/motion.svg
    resources/app/icons/mobile/mask.svg
    resources/app/icons/mobile/lock.svg
    resources/app/icons/mobile/home.svg
    resources/app/icons/mobile/close.svg
)

set(TIME_ARC_LICENSES_RESOURCES
    resources/licenses/qt-lgpl-3.0.txt
    resources/licenses/qt-gpl-3.0.txt
    resources/licenses/sqlite-public-domain.txt
    resources/licenses/parson-mit.txt
    resources/licenses/timearc-gpl-3.0.txt
    resources/licenses/material-symbols-apache-2.0.txt
)

# Native bundle inputs under resources/bundle/ are consumed by platform
# packaging and are intentionally not embedded in the Qt resource collection.
set(TIME_ARC_RESOURCE_FILES
    ${TIME_ARC_APP_RESOURCES}
    ${TIME_ARC_LICENSES_RESOURCES}
    PARENT_SCOPE
)

# Large, content-like GUI assets are functional external RCCs on desktop.
# Android embeds these same QRCs because its package is already a single
# application archive. Unreferenced legacy art stays out of release inputs.
set(TIME_ARC_BUNDLED_RESOURCE_QRCS
    "${CMAKE_CURRENT_SOURCE_DIR}/backgrounds.qrc"
    "${CMAKE_CURRENT_SOURCE_DIR}/site-icons.qrc"
    "${CMAKE_CURRENT_SOURCE_DIR}/monthly-recap.qrc"
    PARENT_SCOPE
)
