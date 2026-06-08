import QtQuick
import Qt.labs.platform as Platform

// 系统通知（G-NOTIFY）：用 Qt.labs.platform 的 SystemTrayIcon（QGuiApplication 即可，纯 QML，
// 不新建 C++ 源 / 不动冻结构建文件）。独立文件 + 命名空间导入，避免与 QtQuick.Controls 的
// Menu/MenuItem 命名冲突；由 Shell 经 Loader 加载，平台无此插件时 Loader 静默失败、不拖垮整页。
// 托盘图标仅在 notify_enabled 时显示，是 showMessage 的必要载体（Windows 原生气泡通知）。
Item {
    id: notifier
    property bool notifyOn: false   // 不用 enabled：会遮蔽 Item.enabled（基类成员）触发告警
    property url iconSource

    Platform.SystemTrayIcon {
        id: tray
        visible: notifier.notifyOn
        icon.source: notifier.iconSource
        tooltip: "TimeArc"
    }

    // 发一条系统通知（关 / 无托盘则静默跳过）。
    function notify(title, message) {
        if (!notifier.notifyOn) return;
        tray.showMessage(title, message);
    }
}
