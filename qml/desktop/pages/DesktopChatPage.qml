import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

Item {
    anchors.fill: parent

    // =========================
    // 从 AppShell 传进来的主题参数
    // 如果没传，就先用白天默认值
    // =========================
    property bool nightMode: false
    property color themeTextPrimary: "#2D2724"
    property color themeTextSecondary: "#7C746D"
    property color themePanelColor: "#FFFDF9"
    property color themeBorderColor: "#E8E0D8"
    property color themeAccentColor: "#CFE8D8"

    // =========================
    // 页面内部颜色
    // 白天：米色暖棕
    // 夜晚：淡蓝紫、雾感灰紫
    // =========================
    property color bgTop: nightMode ? "#30364D" : "#F7F3EE"
    property color bgBottom: nightMode ? "#424865" : "#FBF8F4"

    property color panelColor: themePanelColor
    property color borderColor: themeBorderColor
    property color softBorder: nightMode ? "#757CA6" : "#E6D6C5"

    property color textPrimary: themeTextPrimary
    property color textSecondary: themeTextSecondary

    property color accentBrown: themeAccentColor
    property color accentBrownDeep: nightMode ? "#D8D9FF" : "#2F7A5B"

    property color bubbleMine: nightMode ? "#6A72A8" : "#DDF1E5"
    property color bubbleOther: nightMode ? "#565E86" : "#FFFDF9"

    property color topLightCard: nightMode ? "#59608A" : "#DDF1E5"
    property color topButtonBg: nightMode ? "#59608A" : "#F4E8C8"
    property color topButtonBorder: nightMode ? "#7A82B0" : "#E8E0D8"

    property color inputPanelColor: nightMode ? "#4D5478" : "#FBF8F4"
    property color inputFieldColor: nightMode ? "#525A82" : "#FFFDF9"
    property color inputFieldBorder: nightMode ? "#757CA6" : "#E8E0D8"

    property color sendButtonColor: nightMode ? "#8E93D8" : "#1F1A17"
    property color sendButtonBorder: nightMode ? "#757ED0" : "#2D2724"

    property color pendingImageBar: nightMode ? "#586083" : "#F4E8C8"
    property color pendingImageBorder: nightMode ? "#7A82B0" : "#E8E0D8"

    property color timeChipColor: nightMode ? "#59608A" : "#F7F3EE"
    property color timeChipBorder: nightMode ? "#7A82B0" : "#E8E0D8"

    property string pendingImagePath: ""
    property string previewImagePath: ""
    property int contextMessageIndex: -1

    Settings {
        id: chatSettings
        category: "DesktopChatPageData"
        property string savedChats: ""
    }

    ListModel {
        id: chatModel
    }

    function currentTimeString() {
        var now = new Date()
        var y = now.getFullYear()
        var mon = (now.getMonth() + 1).toString().padStart(2, "0")
        var d = now.getDate().toString().padStart(2, "0")
        var h = now.getHours().toString().padStart(2, "0")
        var m = now.getMinutes().toString().padStart(2, "0")
        return y + "-" + mon + "-" + d + " " + h + ":" + m
    }

    function saveChats() {
        var arr = []
        for (var i = 0; i < chatModel.count; i++) {
            var item = chatModel.get(i)
            arr.push({
                sender: item.sender,
                message: item.message,
                imagePath: item.imagePath,
                timeText: item.timeText
            })
        }
        chatSettings.savedChats = JSON.stringify(arr)
    }

    function loadChats() {
        if (!chatSettings.savedChats || chatSettings.savedChats === "") {
            chatModel.clear()
            return
        }

        try {
            var arr = JSON.parse(chatSettings.savedChats)
            chatModel.clear()

            if (!arr || arr.length === 0)
                return

            for (var i = 0; i < arr.length; i++) {
                chatModel.append(arr[i])
            }
        } catch (e) {
            console.log("读取聊天记录失败:", e)
            chatModel.clear()
        }
    }

    function sendMessage() {
        var messageText = inputField.text.trim()
        var imageValue = pendingImagePath

        if (messageText.length === 0 && imageValue.length === 0)
            return

        chatModel.append({
            sender: "me",
            message: messageText,
            imagePath: imageValue,
            timeText: currentTimeString()
        })

        inputField.text = ""
        pendingImagePath = ""
        saveChats()

        Qt.callLater(function() {
            chatList.positionViewAtEnd()
        })
    }

    function deleteMessageAt(index) {
        if (index < 0 || index >= chatModel.count)
            return
        chatModel.remove(index)
        saveChats()
    }

    function clearAllChats() {
        chatModel.clear()
        saveChats()
    }

    Component.onCompleted: {
        loadChats()
        Qt.callLater(function() {
            chatList.positionViewAtEnd()
        })
    }

    // =========================
    // 页面背景
    // =========================
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: bgTop }
            GradientStop { position: 1.0; color: bgBottom }
        }
        opacity: nightMode ? 0.24 : 0.18
    }

    Rectangle {
        width: 320
        height: 320
        radius: 160
        x: -90
        y: -60
        color: "#FFFFFF"
        opacity: nightMode ? 0.05 : 0.10
        visible: false
    }

    Rectangle {
        width: 220
        height: 220
        radius: 110
        x: parent.width - width - 60
        y: 90
        color: nightMode ? "#7A80B4" : "#F6EBDD"
        opacity: nightMode ? 0.08 : 0.14
        visible: false
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        // =========================
        // 顶部标题区域
        // =========================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: 28
            color: "transparent"
            border.width: 1
            border.color: borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 27
                color: panelColor
                opacity: nightMode ? 0.78 : 0.82
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 27
                color: "transparent"

                Rectangle {
                    width: parent.width * 0.42
                    height: parent.height
                    radius: 27
                    color: nightMode ? "#6670A6" : topLightCard
                    opacity: nightMode ? 0.14 : 0.32
                }
            }

            Row {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Rectangle {
                    width: 46
                    height: 46
                    radius: 23
                    color: nightMode ? "#6C75AE" : "#EED9C4"
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        radius: 16
                        color: nightMode ? "#56608A" : "#FFFDF9"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "✦"
                        color: accentBrownDeep
                        font.pixelSize: 17
                        font.bold: true
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: "记忆聊天"
                        color: textPrimary
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Text {
                        text: "记录想法、图片和每天的片段"
                        color: textSecondary
                        font.pixelSize: 14
                    }
                }

                Item {
                    width: 1
                    height: 1
                }

                Rectangle {
                    width: 118
                    height: 42
                    radius: 16
                    color: topButtonBg
                    border.width: 1
                    border.color: topButtonBorder
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "清空聊天记录"
                        color: accentBrownDeep
                        font.pixelSize: 13
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearAllDialog.open()
                    }
                }
            }
        }

        // =========================
        // 聊天消息区域
        // =========================
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 30
            color: "transparent"
            border.width: 1
            border.color: borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: panelColor
                opacity: nightMode ? 0.74 : 0.80
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: 24
                color: "#FFFFFF"
                opacity: nightMode ? 0.04 : 0.18
            }

            ListView {
                id: chatList
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14
                clip: true
                model: chatModel
                rightMargin: 16
                bottomMargin: 8

                delegate: Item {
                    width: chatList.width - 16

                    property bool isMine: model.sender === "me"
                    property string messageText: model.message ? model.message : ""
                    property string imageValue: model.imagePath ? model.imagePath : ""
                    property string timeValue: model.timeText ? model.timeText : ""

                    property bool showTime: {
                        if (index === 0)
                            return true
                        var prev = chatModel.get(index - 1)
                        return prev.timeText !== timeValue
                    }

                    property real bubbleMaxWidth: chatList.width * 0.52
                    property real bubbleMinWidth: imageValue !== "" ? 260 : 84

                    height: messageColumn.implicitHeight + 4

                    Column {
                        id: messageColumn
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            visible: showTime
                            width: 174
                            height: 28
                            radius: 14
                            color: timeChipColor
                            border.width: 1
                            border.color: timeChipBorder
                            opacity: 0.84
                            anchors.horizontalCenter: parent.horizontalCenter

                            Text {
                                anchors.centerIn: parent
                                text: timeValue
                                color: textSecondary
                                font.pixelSize: 12
                            }
                        }

                        Item {
                            width: parent.width
                            height: imageValue !== "" ? imageBubble.implicitHeight : textBubble.implicitHeight

                            Rectangle {
                                id: bubbleShadow
                                visible: imageValue === ""
                                width: textBubble.width
                                height: textBubble.height
                                x: textBubble.x
                                y: textBubble.y + 3
                            color: nightMode ? "#000000" : "#BFAE9D"
                            opacity: nightMode ? 0.10 : 0.06

                                topLeftRadius: 22
                                topRightRadius: 22
                                bottomLeftRadius: isMine ? 22 : 6
                                bottomRightRadius: isMine ? 6 : 22
                            }

                            Rectangle {
                                id: textBubble
                                visible: imageValue === ""

                                property real naturalTextWidth: Math.min(textMeasure.implicitWidth, bubbleMaxWidth - 28)
                                width: Math.max(bubbleMinWidth, naturalTextWidth + 30)
                                x: isMine ? parent.width - width - 18 : 6
                                y: 0

                                color: isMine ? bubbleMine : bubbleOther
                                border.width: 1
                                border.color: isMine
                                              ? (nightMode ? "#8A92C5" : "#BFDCCB")
                                              : (nightMode ? "#6E76A4" : "#E8E0D8")

                                topLeftRadius: 22
                                topRightRadius: 22
                                bottomLeftRadius: isMine ? 22 : 6
                                bottomRightRadius: isMine ? 6 : 22

                                implicitHeight: visibleText.implicitHeight + 18

                                Text {
                                    id: textMeasure
                                    visible: false
                                    text: messageText
                                    font.pixelSize: 16
                                    wrapMode: Text.NoWrap
                                }

                                Text {
                                    id: visibleText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 15
                                    anchors.right: parent.right
                                    anchors.rightMargin: 15
                                    anchors.top: parent.top
                                    anchors.topMargin: 9

                                    text: messageText
                                    wrapMode: Text.WrapAnywhere
                                    color: textPrimary
                                    font.pixelSize: 16
                                    lineHeight: 1.12
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onPressed: function(mouse) {
                                        if (mouse.button === Qt.RightButton) {
                                            contextMessageIndex = index
                                            messageMenu.popup()
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: imageShadow
                                visible: imageValue !== ""
                                width: imageBubble.width
                                height: imageBubble.height
                                x: imageBubble.x
                                y: imageBubble.y + 4
                                radius: imageBubble.radius
                                color: nightMode ? "#000000" : "#BFAE9D"
                                opacity: nightMode ? 0.12 : 0.05
                            }

                            Rectangle {
                                id: imageBubble
                                visible: imageValue !== ""
                                width: 286
                                height: 214
                                x: isMine ? parent.width - width - 18 : 6

                                radius: 22
                                color: nightMode ? "#5A628B" : "#FBF8F4"
                                border.width: 1
                                border.color: nightMode ? "#7A82B0" : "#E8E0D8"
                                clip: true

                                implicitHeight: height

                                Image {
                                    anchors.fill: parent
                                    source: imageValue
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        if (mouse.button === Qt.LeftButton) {
                                            previewImagePath = imageValue
                                            previewPopup.open()
                                        } else if (mouse.button === Qt.RightButton) {
                                            contextMessageIndex = index
                                            messageMenu.popup()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }
            }

            Text {
                visible: chatModel.count === 0
                anchors.centerIn: parent
                text: "还没有聊天记录，发出第一条消息吧。"
                color: textSecondary
                font.pixelSize: 16
            }
        }

        // =========================
        // 输入区
        // =========================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: pendingImagePath === "" ? inputPanel.implicitHeight + 20
                                                           : inputPanel.implicitHeight + 68
            radius: 28
            color: "transparent"
            border.width: 1
            border.color: borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 27
                color: inputPanelColor
                opacity: nightMode ? 0.78 : 0.88
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 27
                color: "transparent"

                Rectangle {
                    x: 12
                    y: 10
                    width: parent.width * 0.5
                    height: parent.height * 0.7
                    radius: 24
                    color: "#FFFFFF"
                    opacity: nightMode ? 0.04 : 0.16
                }
            }

            Column {
                id: inputPanel
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    visible: pendingImagePath !== ""
                    width: parent.width
                    height: 40
                    radius: 15
                    color: pendingImageBar
                    border.width: 1
                    border.color: pendingImageBorder

                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Text {
                            text: "已选择图片"
                            color: accentBrownDeep
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: pendingImagePath
                            color: textSecondary
                            font.pixelSize: 12
                            elide: Text.ElideMiddle
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "×"
                            color: accentBrownDeep
                            font.pixelSize: 16
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pendingImagePath = ""
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 56
                        Layout.preferredHeight: 56
                        radius: 18
                        color: topButtonBg
                        border.width: 1
                        border.color: topButtonBorder

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: imagePicker.open()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: accentBrownDeep
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(180, Math.max(104, inputField.contentHeight + 24))
                        radius: 24
                        color: inputFieldColor
                        border.width: 1
                        border.color: inputFieldBorder

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 23
                            color: "#FFFFFF"
                            opacity: nightMode ? 0.04 : 0.10
                        }

                        TextArea {
                            id: inputField
                            anchors.fill: parent
                            anchors.margins: 12

                            placeholderText: "写点什么，或者配一张图片..."
                            placeholderTextColor: textSecondary
                            wrapMode: TextEdit.WrapAnywhere
                            color: textPrimary
                            font.pixelSize: 16
                            background: null
                            selectByMouse: true
                            persistentSelection: true
                            topPadding: 2
                            bottomPadding: 2
                            leftPadding: 0
                            rightPadding: 0
                            textMargin: 0

                            onTextChanged: {
                                Qt.callLater(function() {
                                    chatList.positionViewAtEnd()
                                })
                            }

                            Keys.onReturnPressed: function(event) {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    sendMessage()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 60
                        Layout.preferredHeight: 60
                        radius: 21
                        color: sendButtonColor
                        border.width: 1
                        border.color: sendButtonBorder

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 20
                            color: "#FFFFFF"
                            opacity: nightMode ? 0.08 : 0.22
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: sendMessage()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "➤"
                            color: "#FFFDF9"
                            font.pixelSize: 22
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    // =========================
    // 右键菜单
    // =========================
    Menu {
        id: messageMenu

        MenuItem {
            text: "删除这条聊天记录"
            onTriggered: {
                deleteMessageAt(contextMessageIndex)
                contextMessageIndex = -1
            }
        }
    }

    // =========================
    // 清空聊天弹窗
    // =========================
    Dialog {
        id: clearAllDialog
        modal: true
        x: Math.round(((parent ? parent.width : 0) - width) / 2)
        y: Math.round(((parent ? parent.height : 0) - height) / 2)
        width: 360
        height: 180
        padding: 20

        background: Rectangle {
            radius: 24
            color: nightMode ? "#4A506F" : "#FBF7F2"
            border.width: 1
            border.color: borderColor
        }

        contentItem: Column {
            width: clearAllDialog.availableWidth
            spacing: 16

            Text {
                text: "确认清空全部聊天记录？"
                color: textPrimary
                font.pixelSize: 24
                font.bold: true
            }

            Text {
                text: "清空后无法恢复。"
                color: textSecondary
                font.pixelSize: 14
            }

            Item {
                width: 1
                height: 8
            }

            Row {
                spacing: 12

                Button {
                    text: "取消"
                    onClicked: clearAllDialog.close()
                }

                Button {
                    text: "确认清空"
                    onClicked: {
                        clearAllChats()
                        clearAllDialog.close()
                    }
                }
            }
        }
    }

    // =========================
    // 选图
    // =========================
    FileDialog {
        id: imagePicker
        title: "选择图片"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp *.webp)"]

        onAccepted: {
            pendingImagePath = selectedFile.toString()
        }
    }

    // =========================
    // 图片预览弹窗
    // =========================
    Popup {
        id: previewPopup
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        width: parent ? parent.width * 0.82 : 1000
        height: parent ? parent.height * 0.82 : 700
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: nightMode ? "#DD111827" : "#CC000000"
            radius: 24
        }

        Item {
            anchors.fill: parent

            Image {
                anchors.centerIn: parent
                width: parent.width * 0.92
                height: parent.height * 0.92
                source: previewImagePath
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            MouseArea {
                anchors.fill: parent
                onClicked: previewPopup.close()
            }
        }
    }
}
