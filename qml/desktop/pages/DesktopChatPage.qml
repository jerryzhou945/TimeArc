import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

Item {
    anchors.fill: parent

    property color bgTop: "#FBF7F2"
    property color bgBottom: "#F2E8DE"
    property color panelColor: "#FFFDF9"
    property color borderColor: "#DDC9B5"
    property color softBorder: "#E6D6C5"
    property color textPrimary: "#4C342C"
    property color textSecondary: "#9E8471"
    property color accentBrown: "#DDB892"
    property color accentBrownDeep: "#A56D46"
    property color bubbleMine: "#EFD9C1"
    property color bubbleOther: "#FFF9F2"

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

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: bgTop }
            GradientStop { position: 1.0; color: bgBottom }
        }
        opacity: 0.18
    }

    Rectangle {
        width: 320
        height: 320
        radius: 160
        x: -90
        y: -60
        color: "#FFFFFF"
        opacity: 0.10
    }

    Rectangle {
        width: 220
        height: 220
        radius: 110
        x: parent.width - width - 60
        y: 90
        color: "#F6EBDD"
        opacity: 0.14
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 92
            radius: 30
            color: "transparent"
            border.width: 2
            border.color: borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: panelColor
                opacity: 0.56
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: "transparent"

                Rectangle {
                    width: parent.width * 0.42
                    height: parent.height
                    radius: 29
                    color: "#FFF6EC"
                    opacity: 0.30
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
                    color: "#EED9C4"
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        radius: 16
                        color: "#F8EFE5"
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
                    color: "#F3E5D6"
                    border.width: 1
                    border.color: "#DEC9B2"
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

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 32
            color: "transparent"
            border.width: 2
            border.color: borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 31
                color: panelColor
                opacity: 0.48
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                radius: 26
                color: "#FFFFFF"
                opacity: 0.08
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
                            color: "#F4E9DC"
                            border.width: 1
                            border.color: "#E7D8C7"
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
                                color: "#A67C52"
                                opacity: 0.04

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
                                border.color: isMine ? "#D8B99A" : "#E8DDD1"

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
                                color: "#A67C52"
                                opacity: 0.05
                            }

                            Rectangle {
                                id: imageBubble
                                visible: imageValue !== ""
                                width: 286
                                height: 214
                                x: isMine ? parent.width - width - 18 : 6

                                radius: 22
                                color: "#F8F1E8"
                                border.width: 1
                                border.color: "#E5D4C2"
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: pendingImagePath === "" ? inputPanel.implicitHeight + 20
                                                           : inputPanel.implicitHeight + 68
            radius: 30
            color: "transparent"
            border.width: 2
            border.color: borderColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: "#FFFDF9"
                opacity: 0.56
                z: -1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 29
                color: "transparent"

                Rectangle {
                    x: 12
                    y: 10
                    width: parent.width * 0.5
                    height: parent.height * 0.7
                    radius: 26
                    color: "#FFFFFF"
                    opacity: 0.10
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
                    color: "#F4E7D8"
                    border.width: 1
                    border.color: "#E2D0BC"

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
                        color: "#F3E5D6"
                        border.width: 1
                        border.color: "#DEC9B2"

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
                        color: "#FFFDF9"
                        border.width: 1
                        border.color: "#E8DDD1"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 23
                            color: "#FFFFFF"
                            opacity: 0.10
                        }

                        TextArea {
                            id: inputField
                            anchors.fill: parent
                            anchors.margins: 12

                            placeholderText: "写点什么，或者配一张图片..."
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
                        color: "#E7C29D"
                        border.width: 1
                        border.color: "#D5AE86"

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 20
                            color: "#F0D0AE"
                            opacity: 0.22
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

    Dialog {
        id: clearAllDialog
        modal: true
        anchors.centerIn: parent
        width: 360
        height: 180
        padding: 20

        background: Rectangle {
            radius: 24
            color: "#FBF7F2"
            border.width: 1
            border.color: borderColor
        }

        Column {
            anchors.fill: parent
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

    FileDialog {
        id: imagePicker
        title: "选择图片"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp *.webp)"]

        onAccepted: {
            pendingImagePath = selectedFile.toString()
        }
    }

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
            color: "#CC000000"
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
