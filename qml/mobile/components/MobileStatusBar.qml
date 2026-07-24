import QtQuick

Item {
    id: root

    required property var theme

    // Android renders its real system status area. This zero-height item keeps
    // existing page layouts source-compatible without drawing simulated state.
    height: 0
}
