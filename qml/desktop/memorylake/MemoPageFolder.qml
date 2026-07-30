import QtQuick
import "../components/I18n.js" as I18n
import "../components/PlatformCursor.js" as Cursor

// 右上「档案袋」多页切换器（v88 .memo-page-control）。前盖玻璃卡显示当前页名 + 雪佛龙；
// 点击展开抽屉（长高 + 后仰 + 厚度层扇开 + 雪佛龙 180°），列出各页行（点切页 / × 删页）+ 新建页。
// 每页 owns 自己的画布+对象（数据在 MemoOverlay 持有；本组件只发信号）。
// 详见 docs/memory-lake-memo-render-pipeline-replication.md §1.5 / 功能文 §2.6。
Item {
    id: folder

    property MemoryLakeStyle style
    property string languageMode: "zh"
    property var pageLabels: ["Page 1"]
    property var pageThumbs: [""]          // gap #8：每页墨迹 PNG dataURL（行内缩略图）
    property int currentIndex: 0
    property bool openState: false
    property int maxPages: 10
    // 正在重命名的页行下标（-1 = 无）。点行内 ✎ 进入；提交/取消归 -1。
    property int editingIndex: -1

    signal switchTo(int i)
    signal addPageRequested()
    signal deletePageRequested(int i)
    signal renamePageRequested(int i, string name)
    signal movePageRequested(int from, int to)   // gap #6：拖拽重排页

    // 重命名当前编辑文本（输入框实时回传），便于「点别处也提交」——MouseArea 不抢键焦点，
    // 不能靠输入框自身失焦，故由前盖/行/新建等点击主动调 commitEdit()。
    property string _editText: ""
    function commitEdit() {
        if (editingIndex < 0) return;
        var i = editingIndex;
        editingIndex = -1;                 // 先收态再发信号（避免重入）
        renamePageRequested(i, _editText);
    }

    readonly property int pageCount: pageLabels ? pageLabels.length : 1
    readonly property string currentLabel: (pageLabels && currentIndex >= 0 && currentIndex < pageLabels.length)
                                           ? pageLabels[currentIndex] : "Page 1"

    width: 252
    height: front.height + (openState ? tray.height + 8 : 0)
    Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.Bezier
        easing.bezierCurve: folder.style ? folder.style.easeSnappy : [0.18, 0.9, 0.2, 1, 1, 1] } }

    // 厚度层：每多一页加一片，向上/后扇开（3D 近似：阶梯上移 + 内缩 + 渐暗）。
    Repeater {
        model: Math.max(0, folder.pageCount - 1)
        delegate: Rectangle {
            required property int index
            readonly property int up: index + 1
            width: front.width - up * 6
            height: 36
            x: up * 3
            y: -up * 4
            radius: 10
            color: Qt.rgba(34 / 255, 39 / 255, 50 / 255, 0.96 - up * 0.06)
            border.width: 1
            border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10)
            opacity: folder.openState ? 1 : 0.0
            Behavior on opacity { NumberAnimation { duration: 220 } }
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }
    }

    // 前盖玻璃卡（当前页名 + 页数 + 雪佛龙）。
    Rectangle {
        id: front
        width: parent.width
        height: 48
        radius: 12
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(34 / 255, 39 / 255, 50 / 255, 0.96) }
            GradientStop { position: 1; color: Qt.rgba(19 / 255, 23 / 255, 33 / 255, 0.94) }
        }
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
        antialiasing: true

        Row {
            anchors.fill: parent
            anchors.leftMargin: 14; anchors.rightMargin: 12
            spacing: 8
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 28
                Text { text: folder.currentLabel; color: Qt.rgba(245 / 255, 250 / 255, 255 / 255, 0.92)
                       font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                Text { text: I18n.sentence(folder.languageMode, "memoPageCount", {count: folder.pageCount}, folder.pageCount + " 页 · 备忘"); color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.45)
                       font.pixelSize: 11 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "⌄"
                color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.8)
                font.pixelSize: 18
                rotation: folder.openState ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 220 } }
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Cursor.button()
            onClicked: { folder.commitEdit(); folder.openState = !folder.openState }
        }
    }

    // 展开托盘：页面行列表 + 新建页。
    Rectangle {
        id: tray
        anchors.top: front.bottom
        anchors.topMargin: 8
        width: parent.width
        height: list.height + addRow.height + 12
        radius: 12
        visible: folder.openState && opacity > 0.01
        opacity: folder.openState ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(28 / 255, 32 / 255, 42 / 255, 0.96) }
            GradientStop { position: 1; color: Qt.rgba(16 / 255, 19 / 255, 28 / 255, 0.95) }
        }
        border.width: 1
        border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.14)

        Column {
            id: list
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 6
            Repeater {
                model: folder.pageLabels
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    readonly property bool sel: index === folder.currentIndex
                    width: tray.width - 12
                    x: 6
                    height: 34
                    radius: 8
                    color: sel ? "transparent" : (rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    gradient: sel ? selGrad : null
                    Gradient {
                        id: selGrad
                        GradientStop { position: 0; color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.20) }
                        GradientStop { position: 1; color: Qt.rgba(155 / 255, 139 / 255, 255 / 255, 0.18) }
                    }
                    // 缩略图（gap #8）：本页墨迹 PNG 缩放预览（空页 = 空框）。
                    Rectangle {
                        id: thumb
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 8
                        width: 40; height: 24; radius: 5
                        color: Qt.rgba(1, 1, 1, 0.04)
                        border.width: 1
                        border.color: sel ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.30) : Qt.rgba(1, 1, 1, 0.08)
                        clip: true
                        Image {
                            anchors.fill: parent; anchors.margins: 1
                            source: (folder.pageThumbs && index < folder.pageThumbs.length) ? folder.pageThumbs[index] : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true; cache: false; smooth: true
                            visible: source != ""
                        }
                    }
                    Text {
                        visible: folder.editingIndex !== index
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 56
                        anchors.right: parent.right; anchors.rightMargin: 80
                        text: modelData
                        color: sel ? "#EAF6FF" : Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.78)
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    // 行点击（切页）——必须放在 ✎/× 之前，让它们盖在上面；否则其点击被这层吞掉。
                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Cursor.button()
                        onClicked: { folder.commitEdit(); folder.switchTo(index); folder.openState = false; }
                    }
                    // 重命名输入框（编辑此行时覆盖标题；置于行点击层之上以抢输入）。
                    TextInput {
                        id: nameEdit
                        visible: folder.editingIndex === index
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 56
                        anchors.right: parent.right; anchors.rightMargin: 12
                        color: "#EAF6FF"
                        font.pixelSize: 13
                        selectByMouse: true
                        clip: true
                        maximumLength: 24
                        // 进入编辑：填入当前名、回传、抢焦点、全选。
                        onVisibleChanged: if (visible) { text = modelData; folder._editText = modelData; forceActiveFocus(); selectAll(); }
                        onTextChanged: if (folder.editingIndex === index) folder._editText = text
                        onAccepted: folder.commitEdit()                        // 回车提交（信号路径）
                        // 回车提交（按键路径，兜底 onAccepted）；accept 阻止冒泡到 memo 的全局键处理。
                        Keys.onReturnPressed: function (e) { folder.commitEdit(); e.accepted = true; }
                        Keys.onEnterPressed: function (e) { folder.commitEdit(); e.accepted = true; }
                        // 输入框真失焦也提交（兜底）。
                        onActiveFocusChanged: if (!activeFocus && folder.editingIndex === index) folder.commitEdit()
                        // Esc 取消（不提交）；accept 阻止冒泡，否则 memo 全局 Esc 会顺手关掉黑板。
                        Keys.onEscapePressed: function (e) { folder.editingIndex = -1; e.accepted = true; }
                    }
                    // ✎ 重命名（hover/选中时显示；点开进入编辑态）。
                    Rectangle {
                        visible: folder.editingIndex !== index && (rowHover.containsMouse || editH.containsMouse || sel)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: folder.pageCount > 1 ? 34 : 8
                        width: 20; height: 20; radius: 10
                        color: editH.containsMouse ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.32) : Qt.rgba(0, 0, 0, 0.25)
                        Text { anchors.centerIn: parent; text: "✎"; color: "#EAF2FF"; font.pixelSize: 12 }
                        MouseArea {
                            id: editH
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Cursor.button()
                            onClicked: folder.editingIndex = index
                        }
                    }
                    // × 删页（>1 页时显示；置于行点击层之上，确保能命中删除）。
                    Rectangle {
                        visible: folder.editingIndex !== index && folder.pageCount > 1
                                 && (rowHover.containsMouse || delH.containsMouse || sel)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 8
                        width: 20; height: 20; radius: 10
                        color: delH.containsMouse ? Qt.rgba(255 / 255, 95 / 255, 95 / 255, 0.5) : Qt.rgba(0, 0, 0, 0.25)
                        Text { anchors.centerIn: parent; text: "×"; color: "#EAF2FF"; font.pixelSize: 13 }
                        MouseArea {
                            id: delH
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Cursor.button()
                            onClicked: { folder.commitEdit(); folder.deletePageRequested(index) }
                        }
                    }
                    // 拖拽排序手柄（gap #6）：>1 页 + 非编辑态显示，置于行点击层之上。
                    // 点（不拖）落到下层 rowHover = 切页；拖动越过阈值被 gripDrag 抢走 = 重排。
                    Rectangle {
                        id: dragGrip
                        visible: folder.editingIndex !== index && folder.pageCount > 1
                                 && (rowHover.containsMouse || sel || gripMa.containsMouse || gripMa.pressed)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 58
                        width: 20; height: 24; radius: 5
                        color: gripMa.pressed ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.20)
                              : gripMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Row {
                            anchors.centerIn: parent; spacing: 3
                            Repeater {
                                model: 2
                                delegate: Column {
                                    spacing: 3
                                    Repeater {
                                        model: 3
                                        delegate: Rectangle { width: 2.5; height: 2.5; radius: 1.25
                                            color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.50) }
                                    }
                                }
                            }
                        }
                        // 用 MouseArea（非 DragHandler）：抢住命中(preventStealing)不被行点击吞，
                        // 松手按指针净位移算目标位次。无行内位移反馈（避免命中区随行移动的自激）。
                        MouseArea {
                            id: gripMa
                            anchors.fill: parent
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.SizeVerCursor
                            property real _pressY: 0
                            onPressed: function (m) { gripMa._pressY = gripMa.mapToItem(list, m.x, m.y).y }
                            onReleased: function (m) {
                                var dy = gripMa.mapToItem(list, m.x, m.y).y - gripMa._pressY;
                                var target = Math.max(0, Math.min(folder.pageCount - 1, index + Math.round(dy / 34)));
                                if (target !== index) folder.movePageRequested(index, target);
                            }
                        }
                    }
                }
            }
        }

        // 新建页
        Rectangle {
            id: addRow
            readonly property bool canAdd: folder.pageCount < folder.maxPages
            anchors.top: list.bottom
            anchors.topMargin: 4
            x: 6
            width: tray.width - 12
            height: 32
            radius: 8
            opacity: canAdd ? 1 : 0.45            // 达上限：淡化 + 禁用
            color: (addH.containsMouse && canAdd) ? Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.10) : "transparent"
            border.width: 1
            border.color: Qt.rgba(142 / 255, 223 / 255, 255 / 255, 0.16)
            Text { anchors.centerIn: parent
                   text: addRow.canAdd ? ("＋ " + I18n.t(folder.languageMode, "新建页")) : I18n.sentence(folder.languageMode, "memoPageLimit", {count: folder.maxPages}, "已达 " + folder.maxPages + " 页上限")
                   color: Qt.rgba(235 / 255, 245 / 255, 255 / 255, 0.82); font.pixelSize: 13 }
            MouseArea {
                id: addH
                anchors.fill: parent
                enabled: addRow.canAdd
                hoverEnabled: true
                cursorShape: Cursor.button()
                onClicked: { folder.commitEdit(); folder.addPageRequested() }
            }
        }
    }
}
