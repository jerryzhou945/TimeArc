import QtQuick
import Qt.labs.platform as Platform

// 系统托盘与通知载体。Loader 加载失败时由调用方容错；本组件不引入新的 C++/CMake 依赖。
Item {
    id: notifier

    property bool notifyOn: false
    property bool stayResident: true
    property url iconSource

    signal showRequested()
    signal quitRequested()

    Platform.SystemTrayIcon {
        id: tray
        visible: notifier.stayResident || notifier.notifyOn
        icon.source: notifier.iconSource
        tooltip: "TimeArc"
        menu: trayMenu

        onActivated: function (reason) {
            if (reason === Platform.SystemTrayIcon.Trigger
                    || reason === Platform.SystemTrayIcon.DoubleClick)
                notifier.showRequested()
        }
    }

    Platform.Menu {
        id: trayMenu
        Platform.MenuItem {
            text: "打开 TimeArc"
            onTriggered: notifier.showRequested()
        }
        Platform.MenuItem {
            text: "后台采集继续运行"
            enabled: false
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: "退出 TimeArc"
            onTriggered: notifier.quitRequested()
        }
    }

    function notify(title, message) {
        if (!notifier.notifyOn) return;
        tray.showMessage(title, message);
    }
}
