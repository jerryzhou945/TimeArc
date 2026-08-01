import QtQuick
import Qt.labs.platform as Platform
import "../components/I18n.js" as I18n

// 系统托盘与通知载体。Loader 加载失败时由调用方容错；本组件不引入新的 C++/CMake 依赖。
Item {
    id: notifier

    property bool notifyOn: false
    property bool stayResident: true
    property url iconSource
    property string languageMode: "en"
    property string pomodoroTimeText: "00:00"
    property bool pomodoroRunning: false
    property bool pomodoroPaused: false
    property bool pomodoroCanStart: false
    readonly property bool usesNativeMacOsStatusItem:
        Qt.platform.os === "osx" && macStatusBarController !== null

    signal showRequested()
    signal quitRequested()
    signal pomodoroShowRequested()
    signal pomodoroPrimaryRequested()
    signal pomodoroResetRequested()

    function menuText(source) {
        return I18n.menu(languageMode, source);
    }

    Platform.SystemTrayIcon {
        id: tray
        visible: !notifier.usesNativeMacOsStatusItem
                 && (notifier.stayResident || notifier.notifyOn)
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
            text: notifier.menuText("打开 TimeArc")
            onTriggered: notifier.showRequested()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: notifier.menuText("番茄钟") + " " + notifier.pomodoroTimeText
            onTriggered: notifier.pomodoroShowRequested()
        }
        Platform.MenuItem {
            text: notifier.menuText(notifier.pomodoroRunning
                                    ? "暂停计时"
                                    : (notifier.pomodoroPaused
                                       ? "继续计时" : "开始计时"))
            enabled: notifier.pomodoroRunning || notifier.pomodoroCanStart
            onTriggered: notifier.pomodoroPrimaryRequested()
        }
        Platform.MenuItem {
            text: notifier.menuText("重置计时")
            onTriggered: notifier.pomodoroResetRequested()
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: notifier.menuText("后台采集继续运行")
            enabled: false
        }
        Platform.MenuSeparator {}
        Platform.MenuItem {
            text: notifier.menuText("退出 TimeArc")
            onTriggered: notifier.quitRequested()
        }
    }

    Component.onCompleted: syncNativeVisibility()
    onNotifyOnChanged: syncNativeVisibility()
    onStayResidentChanged: syncNativeVisibility()

    function syncNativeVisibility() {
        if (usesNativeMacOsStatusItem)
            macStatusBarController.setVisible(stayResident || notifyOn);
    }

    function notify(title, message) {
        if (!notifier.notifyOn) return;
        if (usesNativeMacOsStatusItem)
            macStatusBarController.showMessage(title, message);
        else
            tray.showMessage(title, message);
    }
}
