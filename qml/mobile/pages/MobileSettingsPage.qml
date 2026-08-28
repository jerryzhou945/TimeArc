import QtQuick
import QtQuick.Dialogs
import "../components"
import "../../shared/I18n.js" as I18n

Item {
    id: root


    // Pushed down by MobileAppShell; the default keeps standalone
    // previews of this component legible.
    property string languageMode: "en"
    function tr(source) { return I18n.t(languageMode, source) }

    signal languageChanged(string mode)
    required property var theme
    property bool wallpaperActive: false
    property bool autoSync: true
    property bool anonymousShare: false
    property bool reducedMotion: false
    property url avatarSource: ""
    property string avatarMessage: ""
    property var profileDashboard: ({
        "firstDateLocal": "",
        "activeDays": 0,
        "empty": true
    })

    signal darkModeChanged(bool enabled)

    function hasUsageService() {
        return typeof mobileUsageService !== "undefined" && mobileUsageService
    }

    function hasUiService() {
        return typeof mobileUiService !== "undefined" && mobileUiService
    }

    function hasSettings() {
        return typeof settingsRepository !== "undefined" && settingsRepository
    }

    function loadPreferences() {
        if (!hasSettings())
            return
        autoSync = settingsRepository.getBool("mobile_auto_sync", true)
        anonymousShare = settingsRepository.getBool(
                    "mobile_anonymous_share", false)
        reducedMotion = settingsRepository.getBool(
                    "mobile_reduced_motion", false)
        theme.reducedMotion = reducedMotion
    }

    function isPreviewMode() {
        return Qt.application.arguments.indexOf("--mobile-preview") >= 0
    }

    function reloadProfileDashboard() {
        var dashboard = hasUsageService()
                ? mobileUsageService.getDashboardForRange("all")
                : ({ "firstDateLocal": "", "activeDays": 0, "empty": true })
        profileDashboard = isPreviewMode() && dashboard.empty
                ? ({
                    "firstDateLocal": "2025.03.13",
                    "activeDays": 168,
                    "empty": false
                }) : dashboard
    }

    function companionshipDays() {
        var raw = (profileDashboard.firstDateLocal || "").toString()
        var parts = raw.replace(/\./g, "-").split("-")
        if (parts.length < 3)
            return 0
        var first = new Date(Number(parts[0]), Number(parts[1]) - 1,
                             Number(parts[2]))
        if (isNaN(first.getTime()))
            return 0
        var today = new Date()
        first.setHours(0, 0, 0, 0)
        today.setHours(0, 0, 0, 0)
        return Math.max(1, Math.floor(
                            (today.getTime() - first.getTime())
                            / 86400000) + 1)
    }

    function refreshAvatarSource() {
        var nextSource = root.hasUiService()
                ? mobileUiService.avatarUrl : ""
        root.avatarSource = ""
        Qt.callLater(function() {
            root.avatarSource = nextSource
        })
    }

    function usageStatusText() {
        if (!hasUsageService())
            return "Desktop preview mode"
        return mobileUsageService.syncStatusText
    }

    function usageAccessText() {
        if (!hasUsageService())
            return "Android only"
        return mobileUsageService.usageAccessGranted ? "On" : "Off"
    }

    function wallpaperStateText() {
        if (!hasUiService())
            return "Preview unavailable"
        return wallpaperActive ? "Using a custom wallpaper" : "Follow the solid colour theme"
    }

    function openWallpaperDialog() {
        wallpaperDialog.open()
    }

    function socialStatusText(channel) {
        if (!hasUiService())
            return "Waiting for platform approval"
        var configuredId = channel === "moments"
                ? mobileUiService.wechatAppId : mobileUiService.qqAppId
        if (configuredId.length === 0)
            return "Waiting for platform approval"
        var status = mobileUiService.socialShareStatus(channel)
        return status.label || "Waiting for platform approval"
    }

    function checkedFor(key) {
        if (key === "lightMode")
            return !theme.isDark
        if (key === "autoSync")
            return autoSync
        if (key === "anonymousShare")
            return anonymousShare
        if (key === "reducedMotion")
            return reducedMotion
        return false
    }

    function settingsKey(key) {
        if (key === "autoSync")
            return "mobile_auto_sync"
        if (key === "anonymousShare")
            return "mobile_anonymous_share"
        if (key === "reducedMotion")
            return "mobile_reduced_motion"
        return "mobile_" + key
    }

    function setChecked(key, value) {
        if (key === "lightMode") {
            darkModeChanged(!value)
            return
        }
        if (key === "autoSync")
            autoSync = value
        else if (key === "anonymousShare")
            anonymousShare = value
        else if (key === "reducedMotion") {
            reducedMotion = value
            theme.reducedMotion = value
        }
        if (hasSettings())
            settingsRepository.setBool(settingsKey(key), value)
    }

    function runAction(action) {
        if (action === "usageAccess" && hasUsageService()) {
            mobileUsageService.openUsageAccessSettings()
        } else if (action === "syncNow" && hasUsageService()) {
            mobileUsageService.requestImmediateSync()
        } else if (action === "wallpaper") {
            wallpaperDialog.open()
        } else if (action === "clearWallpaper" && hasUiService()) {
            mobileUiService.clearWallpaper()
        } else if (action === "cycleLanguage") {
            cycleLanguage()
        }
    }

    // Mobile has no room for a dropdown in this row layout, so the row cycles
    // through the three shipped languages and shows the current one in its own
    // script — a user who cannot read the current UI language can still tell
    // which is selected and step to theirs.
    readonly property var languageOrder: ["zh", "en", "ja"]
    readonly property var languageNames: ({"zh": "简体中文", "en": "English", "ja": "日本語"})

    function cycleLanguage() {
        var i = languageOrder.indexOf(root.languageMode)
        var next = languageOrder[(i + 1) % languageOrder.length]
        root.languageMode = next
        if (typeof settingsRepository !== "undefined" && settingsRepository)
            settingsRepository.setValue("language_mode", next)
        root.languageChanged(next)
    }

    Component.onCompleted: {
        loadPreferences()
        reloadProfileDashboard()
        refreshAvatarSource()
    }

    Connections {
        target: root.hasUsageService() ? mobileUsageService : null
        function onDataChanged() { root.reloadProfileDashboard() }
        function onStatusChanged() { root.reloadProfileDashboard() }
    }

    Connections {
        target: root.hasUiService() ? mobileUiService : null
        function onAvatarChanged() {
            root.refreshAvatarSource()
        }
    }

    FileDialog {
        id: wallpaperDialog
        title: "Choose a wallpaper"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)"]

        onAccepted: {
            if (root.hasUiService())
                mobileUiService.importWallpaper(selectedFile)
        }
    }

    FileDialog {
        id: avatarDialog
        title: "Choose a local picture"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.webp)"]

        onAccepted: {
            if (!root.hasUiService()) {
                root.avatarMessage = "Profile pictures cannot be saved in this environment"
                return
            }
            if (mobileUiService.importAvatar(selectedFile)) {
                root.avatarMessage = "Profile picture updated"
                root.refreshAvatarSource()
            } else {
                root.avatarMessage = mobileUiService.lastError
            }
        }
    }

    Column {
        anchors.fill: parent

        MobileStatusBar {

            languageMode: root.languageMode
            width: parent.width
            theme: root.theme
        }

        Flickable {
            id: flick
            width: parent.width
            height: parent.height - y
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentHeight: content.implicitHeight + 34

            Column {
                id: content
                width: flick.width - 32
                x: 16
                spacing: 18

                Item {
                    width: parent.width
                    height: 58

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: "Me"
                            color: root.theme.textPrimary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 27
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Make the way you record feel more like you"
                            color: root.theme.textSecondary
                            font.family: root.theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                }

                MobileGlassPanel {

                    languageMode: root.languageMode
                    id: profileArchive
                    width: parent.width
                    height: 214
                    theme: root.theme
                    wallpaperActive: root.wallpaperActive
                    strong: false

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Row {
                            width: parent.width
                            height: 92
                            spacing: 14

                            Item {
                                width: 88
                                height: 88

                                MobileRoundedFrame {
                                    id: avatarFrame
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: 80
                                    height: 80
                                    radius: 40
                                    border.width: 1
                                    border.color: root.theme.withAlpha(
                                                      root.theme.textPrimary,
                                                      0.18)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: root.theme.accentSoft
                                    }

                                    Image {
                                        id: profileAvatar
                                        anchors.fill: parent
                                        source: root.avatarSource
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        visible: source.toString().length > 0
                                                 && status !== Image.Error
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !profileAvatar.visible
                                        text: "T"
                                        color: root.theme.accentBright
                                        font.family: root.theme.fontFamily
                                        font.pixelSize: 30
                                        font.weight: Font.Black
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: avatarDialog.open()
                                    }
                                }

                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    width: 30
                                    height: 30
                                    radius: 15
                                    color: root.theme.accent
                                    border.width: 2
                                    border.color: root.theme.surface

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: "white"
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: avatarDialog.open()
                                    }
                                }
                            }

                            Column {
                                width: parent.width - 102
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Text {
                                    width: parent.width
                                    text: "My time archive"
                                    color: root.theme.textPrimary
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 20
                                    font.weight: Font.Bold
                                }

                                Text {
                                    width: parent.width
                                    text: "Tap the picture to choose a photo"
                                    color: root.theme.accentBright
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    width: parent.width
                                    text: "Your picture and records stay on this device only"
                                    color: root.theme.textMuted
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 10
                                    wrapMode: Text.WordWrap
                                }

                                Text {
                                    id: avatarFeedback
                                    width: parent.width
                                    visible: root.avatarMessage.length > 0
                                    text: root.avatarMessage
                                    color: root.avatarMessage === "Profile picture updated"
                                           ? root.theme.success
                                           : root.theme.error
                                    font.family: root.theme.fontFamily
                                    font.pixelSize: 10
                                    elide: Text.ElideRight
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: 1
                            color: root.theme.withAlpha(root.theme.line, 0.72)
                        }

                        Row {
                            width: parent.width
                            height: 64

                            Repeater {
                                model: [
                                    {
                                        "label": "Start recording",
                                        "value": root.profileDashboard.firstDateLocal
                                                 || "Not started yet"
                                    },
                                    {
                                        "label": "Together for",
                                        "value": I18n.sentence(root.languageMode, "dayCount", {count: root.companionshipDays()})
                                    },
                                    {
                                        "label": "Actually recorded",
                                        "value": I18n.sentence(root.languageMode, "dayCount",
                                                               {count: root.profileDashboard.activeDays || 0})
                                    }
                                ]

                                Item {
                                    required property var modelData
                                    required property int index
                                    width: parent.width / 3
                                    height: parent.height

                                    Rectangle {
                                        visible: index > 0
                                        anchors.left: parent.left
                                        anchors.verticalCenter:
                                            parent.verticalCenter
                                        width: 1
                                        height: 34
                                        color: root.theme.withAlpha(
                                                   root.theme.line, 0.72)
                                    }

                                    Column {
                                        anchors.centerIn: parent
                                        width: parent.width - 8
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: modelData.value
                                            color: root.theme.textPrimary
                                            font.family:
                                                root.theme.numberFontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Bold
                                            horizontalAlignment:
                                                Text.AlignHCenter
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            width: parent.width
                                            text: modelData.label
                                            color: root.theme.textMuted
                                            font.family: root.theme.fontFamily
                                            font.pixelSize: 10
                                            horizontalAlignment:
                                                Text.AlignHCenter
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                SettingsGroup {
                    width: parent.width
                    title: "Recording and sync"
                    rows: [
                        {
                            "icon": "shield",
                            "label": "Usage access",
                            "desc": "Reads app-level durations only, never chat or browsing content",
                            "value": root.usageAccessText(),
                            "action": "usageAccess"
                        },
                        {
                            "icon": "sync",
                            "label": "Sync now",
                            "desc": root.usageStatusText(),
                            "value": "Sync",
                            "action": "syncNow"
                        },
                        {
                            "icon": "clock",
                            "label": "Sync automatically on open",
                            "desc": "Fills in recent records each time you return to TimeArc",
                            "toggleKey": "autoSync"
                        }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    title: "Appearance"
                    rows: [
                        {
                            "icon": "sun",
                            "label": "Interface language",
                            "desc": "Applies to every screen straight away.",
                            "value": root.languageNames[root.languageMode]
                                     || "English",
                            "action": "cycleLanguage"
                        },
                        {
                            "icon": "image",
                            "label": "Custom wallpaper",
                            "desc": root.wallpaperStateText(),
                            "value": root.wallpaperActive ? "Change" : "Select",
                            "action": "wallpaper"
                        },
                        {
                            "icon": "clear",
                            "label": "Restore solid background",
                            "desc": "Keeps your data, removes only the current wallpaper",
                            "value": root.wallpaperActive ? "Restore" : "Not in use",
                            "action": root.wallpaperActive
                                      ? "clearWallpaper" : ""
                        },
                        {
                            "icon": "sun",
                            "label": "Light mode",
                            "desc": "Wallpaper and translucent panels adjust for readability",
                            "toggleKey": "lightMode"
                        },
                        {
                            "icon": "motion",
                            "label": "Reduce motion",
                            "desc": "Turns off flip and page transition animations",
                            "toggleKey": "reducedMotion"
                        }
                    ]
                }

                SettingsGroup {
                    width: parent.width
                    title: "Sharing and privacy"
                    rows: [
                        {
                            "icon": "mask",
                            "label": "Share anonymously by default",
                            "desc": "Shared images omit your name, keeping only apps and the time story",
                            "toggleKey": "anonymousShare"
                        },
                        {
                            "icon": "lock",
                            "label": "Data stays on this device",
                            "desc": "Wallpapers, durations and share images are kept on the device by default",
                            "value": "Local first"
                        }
                    ]
                }

                Column {
                    width: parent.width
                    spacing: 9

                    Text {
                        width: parent.width
                        leftPadding: 2
                        text: "Social platform access"
                        color: root.theme.textPrimary
                        font.family: root.theme.fontFamily
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    MobileGlassPanel {

                        languageMode: root.languageMode
                        width: parent.width
                        height: socialFields.implicitHeight + 28
                        theme: root.theme
                        wallpaperActive: root.wallpaperActive
                        strong: false

                        Column {
                            id: socialFields
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 14

                            SocialAppIdField {
                                width: parent.width
                                label: "WeChat AppID"
                                channel: "moments"
                                value: root.hasUiService()
                                       ? mobileUiService.wechatAppId : ""
                                status: root.socialStatusText("moments")
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: root.theme.withAlpha(
                                           root.theme.line, 0.72)
                            }

                            SocialAppIdField {
                                width: parent.width
                                label: "QQ AppID"
                                channel: "qzone"
                                value: root.hasUiService()
                                       ? mobileUiService.qqAppId : ""
                                status: root.socialStatusText("qzone")
                            }

                            Text {
                                width: parent.width
                                text: "You must still register com.timearc.app and the release signature with the platform. Until then, shared images are saved to your gallery instead."
                                color: root.theme.textMuted
                                font.family: root.theme.fontFamily
                                font.pixelSize: 10
                                lineHeight: 1.45
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    topPadding: 2
                    text: root.hasUiService() && mobileUiService.lastError.length > 0
                          ? mobileUiService.lastError
                          : "TimeArc · keeping every stretch of time with care"
                    color: root.hasUiService()
                           && mobileUiService.lastError.length > 0
                           ? root.theme.error : root.theme.textMuted
                    font.family: root.theme.fontFamily
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component SettingsGroup: Column {
        id: group

        property string title: ""
        property var rows: []

        spacing: 9

        Text {
            width: parent.width
            leftPadding: 2
            text: group.title
            color: root.theme.textPrimary
            font.family: root.theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }

        MobileGlassPanel {

            languageMode: root.languageMode
            width: parent.width
            height: rowsColumn.implicitHeight
            theme: root.theme
            wallpaperActive: root.wallpaperActive
            strong: false

            Column {
                id: rowsColumn
                width: parent.width

                Repeater {
                    model: group.rows

                    SettingRow {
                        required property var modelData
                        required property int index

                        width: rowsColumn.width
                        iconName: modelData.icon || ""
                        label: modelData.label || ""
                        desc: modelData.desc || ""
                        value: modelData.value || ""
                        toggleKey: modelData.toggleKey || ""
                        action: modelData.action || ""
                        dividerVisible: index < group.rows.length - 1
                    }
                }
            }
        }
    }

    component SocialAppIdField: Column {
        id: socialField

        property string label: ""
        property string channel: ""
        property string value: ""
        property string status: "Waiting for platform approval"

        spacing: 7

        Row {
            width: parent.width
            height: 20

            Text {
                width: parent.width - 110
                text: socialField.label
                color: root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Text {
                width: 110
                text: socialField.status
                color: socialField.status === "Ready"
                       ? root.theme.success : root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 10
                horizontalAlignment: Text.AlignRight
            }
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 11
            color: root.theme.withAlpha(root.theme.surface, 0.28)
            border.width: 1
            border.color: root.theme.withAlpha(root.theme.line, 0.82)

            TextInput {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: socialField.value
                color: root.theme.textPrimary
                selectionColor: root.theme.accent
                selectedTextColor: "white"
                font.family: root.theme.numberFontFamily
                font.pixelSize: 12
                clip: true
                onEditingFinished: {
                    if (root.hasUiService())
                        mobileUiService.setSocialAppId(
                                    socialField.channel, text)
                }
            }
        }
    }

    component SettingRow: Item {
        id: settingRow

        property string iconName: ""
        property string label: ""
        property string desc: ""
        property string value: ""
        property string toggleKey: ""
        property string action: ""
        property bool dividerVisible: false

        height: 74

        Rectangle {
            width: 36
            height: 36
            radius: 11
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: root.theme.withAlpha(root.theme.accent, 0.18)

            MobileSymbolIcon {

                languageMode: root.languageMode
                anchors.centerIn: parent
                name: settingRow.iconName.length > 0
                      ? settingRow.iconName : "lock"
                color: root.theme.accentBright
                iconSize: 20
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 62
            anchors.right: control.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                text: settingRow.label
                color: root.theme.textPrimary
                font.family: root.theme.fontFamily
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: settingRow.desc
                color: root.theme.textMuted
                font.family: root.theme.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        Item {
            id: control
            width: settingRow.toggleKey.length > 0 ? 48 : 64
            height: parent.height
            anchors.right: parent.right
            anchors.rightMargin: 12

            MobileSwitch {

                languageMode: root.languageMode
                anchors.centerIn: parent
                visible: settingRow.toggleKey.length > 0
                theme: root.theme
                checked: root.checkedFor(settingRow.toggleKey)
                onToggled: function(value) {
                    root.setChecked(settingRow.toggleKey, value)
                }
            }

            Text {
                anchors.fill: parent
                visible: settingRow.toggleKey.length === 0
                text: settingRow.value
                color: settingRow.action.length > 0
                       ? root.theme.accentBright : root.theme.textSecondary
                font.family: root.theme.fontFamily
                font.pixelSize: 12
                font.weight: settingRow.action.length > 0
                             ? Font.DemiBold : Font.Normal
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }

        Rectangle {
            visible: settingRow.dividerVisible
            anchors.left: parent.left
            anchors.leftMargin: 62
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.theme.withAlpha(root.theme.line, 0.72)
        }

        MouseArea {
            anchors.fill: parent
            enabled: settingRow.action.length > 0
            onClicked: root.runAction(settingRow.action)
        }
    }
}
