import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

Item {
    anchors.fill: parent

    property color bgTop: "#FCF8F3"
    property color bgBottom: "#F3ECE4"
    property color panelColor: "#FFFDF9"
    property color borderColor: "#E8DDD1"
    property color textPrimary: "#4E342E"
    property color textSecondary: "#9C806C"
    property color accentBrown: "#D8B38A"
    property color accentBrownDeep: "#A96F46"
    property color bubbleMine: "#EFD8BF"
    property color bubbleOther: "#FFF8F0"

    property string pendingImagePath: ""
    property string previewImagePath: ""

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
        chatList.positionViewAtEnd()
    }

    Component.onCompleted: {
        loadChats()
        chatList.positionViewAtEnd()
    }

    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            GradientStop { position: 0.0; color: bgTop }
            GradientStop { position: 1.0; color: bgBottom }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 84
            radius: 28
            color: panelColor
            border.width: 1
            border.color: borderColor

            Row {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                Rectangle {
                    width: 42
                    height: 42
                    radius: 21
                    color: "#E9D4BF"
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✦"
                        color: accentBrownDeep
                        font.pixelSize: 18
                        font.bold: true
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Text {
                        text: "聊天页"
                        color: textPrimary
                        font.pixelSize: 28
                        font.bold: true
                    }

                    Text {
                        text: "记录想法、图片和每天的片段。"
                        color: textSecondary
                        font.pixelSize: 14
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 30
            color: panelColor
            border.width: 1
            border.color: borderColor

            ListView {
                id: chatList
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16
                clip: true
                model: chatModel
                rightMargin: 26

                delegate: Item {
                  width: chatList.width - 26

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

                  property real bubbleMaxWidth: chatList.width * 0.38
                  property real bubbleMinWidth: imageValue !== "" ? 260 : 78

                  height: messageColumn.implicitHeight + 6

                  Column {
                      id: messageColumn
                      width: parent.width
                      spacing: 6

                      Rectangle {
                          visible: showTime
                          width: 180
                          height: 28
                          radius: 14
                          color: "#F2E7DA"
                          border.width: 1
                          border.color: "#E6D7C7"
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
                              id: textBubble
                              visible: imageValue === ""

                              property real naturalTextWidth: Math.min(textMeasure.implicitWidth, bubbleMaxWidth - 28)
                              width: Math.max(bubbleMinWidth, naturalTextWidth + 28)
                              x: isMine ? parent.width - width - 24 : 8

                              radius: 20
                              color: isMine ? bubbleMine : bubbleOther
                              border.width: 1
                              border.color: isMine ? "#D9BEA0" : "#E9DED2"

                              implicitHeight: visibleText.paintedHeight + 16

                              Text {
                                  id: textMeasure
                                  visible: false
                                  text: messageText
                                  font.pixelSize: 17
                                  wrapMode: Text.NoWrap
                              }

                              Text {
                                  id: visibleText
                                  anchors.left: parent.left
                                  anchors.leftMargin: 14
                                  anchors.right: parent.right
                                  anchors.rightMargin: 14
                                  anchors.top: parent.top
                                  anchors.topMargin: 8

                                  text: messageText
                                  wrapMode: Text.Wrap
                                  color: textPrimary
                                  font.pixelSize: 17
                                  lineHeight: 1.15
                              }
                          }

                          Rectangle {
                              id: imageBubble
                              visible: imageValue !== ""
                              width: 280
                              height: 210
                              x: isMine ? parent.width - width - 24 : 8

                              radius: 18
                              color: "#F7EFE6"
                              border.width: 1
                              border.color: "#E4D3C1"
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
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                      previewImagePath = imageValue
                                      previewPopup.open()
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
            Layout.preferredHeight: pendingImagePath === "" ? 124 : 168
            radius: 28
            border.width: 1
            border.color: borderColor

            gradient: Gradient {
                GradientStop { position: 0.0; color: "#FFFDF9" }
                GradientStop { position: 1.0; color: "#F8F1E8" }
            }

            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    visible: pendingImagePath !== ""
                    width: parent.width
                    height: 38
                    radius: 14
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
                    height: 88
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 54
                        radius: 18
                        color: "#F2E4D4"
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
                        Layout.preferredHeight: 88
                        radius: 22
                        color: "#FFFDF9"
                        border.width: 1
                        border.color: "#E8DDD1"

                        TextArea {
                            id: inputField
                            anchors.fill: parent
                            anchors.margins: 12
                            placeholderText: "写点什么，或者配一张图片..."
                            wrapMode: TextEdit.Wrap
                            color: textPrimary
                            font.pixelSize: 16
                            background: null

                            Keys.onReturnPressed: function(event) {
                                if (!(event.modifiers & Qt.ShiftModifier)) {
                                    sendMessage()
                                    event.accepted = true
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        radius: 20
                        color: "#E7C29D"
                        border.width: 1
                        border.color: "#D5AE86"

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
