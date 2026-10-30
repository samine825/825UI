import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window
import QtQuick.Shapes

import "./3D"
import "./Apps"
import "./Bar"
import "./Cat"
import "./Components"

// =^..^=
ShellRoot {

    // === меню сохранённых чатов ===
    // Дочернее окно ShellRoot: занимает место у окон (exclusive zone),
    // бар укорачивается, окно кота уезжает влево. Скосы только
    // со стороны окон — правая кромка у края экрана прямая.
    PanelWindow {
        id: chatMenu

        readonly property int menuWidth: 340
        property bool open: false
        // резерв места под панель: сдвигает бар и кота
        property real shift: open ? menuWidth : 0

        // высота строки — как у заголовка из ControlPanel
        readonly property real rowHeight: Settings.barHeight - Settings.line
        readonly property real rowPoint: rowHeight * (403.16 / 1000)

        // всплывающие действия над чатом
        property string actionId: ""
        property real actionY: 0
        property string renameId: ""
        readonly property real actionsW: 176
        readonly property real actionsH: 3 * 28 + 8

        function openActions(id, y) {
            renameId = ""
            actionId = id
            actionY = Math.max(58, Math.min(y - actionsH / 2,
                menuPanel.height - actionsH - 18))
        }

        function commitRename(id, text) {
            if (renameId === "" || id !== renameId)
                return

            cat.setChatTitle(id, text)
            renameId = ""
        }

        anchors {
            top: true
            bottom: true
            right: true
        }

        implicitWidth: Math.round(shift)
        exclusiveZone: Math.round(shift)
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Top
        // нужно для переименования: клавиатура по требованию
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // панель прижата к правой кромке и стоит во всю высоту экрана
        Item {
            id: menuPanel

            x: parent.width - width
            y: 0
            width: chatMenu.menuWidth - Settings.barGap
            height: parent.height

            // вторая, тёмная обводка: её внешние кромки лежат
            // ровно на краях экрана и не обрезаются
            Panel {
                x: Settings.line / 2
                y: Settings.line / 2
                width: parent.width - Settings.line
                height: parent.height - Settings.line
                cornerCut: Settings.line * (2 + Math.sqrt(2) / 2)
                flatRight: true
                strokeColor: Settings.c2
                fillColor: Settings.c2
                strokeWidth: Settings.line
            }

            Panel {
                x: Settings.line * 1.5
                y: Settings.line * 1.5
                width: parent.width - Settings.line * 3
                height: parent.height - Settings.line * 3
                cornerCut: Settings.line * 2
                flatRight: true
                strokeColor: Settings.c1
                fillColor: Settings.c2
                strokeWidth: Settings.line
            }

            // новый чат — голый плюс в углу
            Item {
                id: newChatBtn

                x: menuPanel.width - width - 18
                y: 18
                width: 28
                height: 28

                readonly property bool hovered: newChatHover.containsMouse

                Shape {
                    x: 4
                    y: 4
                    width: 20
                    height: 20
                    preferredRendererType: Shape.CurveRenderer
                    opacity: newChatBtn.hovered ? 1 : 0.75

                    SShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        strokeColor: Settings.c1
                        strokeWidth: Settings.line / 2
                        startX: 10
                        startY: 1
                        PathLine {
                            x: 10
                            y: 19
                        }
                    }

                    SShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.RoundCap
                        fillColor: "transparent"
                        strokeColor: Settings.c1
                        strokeWidth: Settings.line / 2
                        startX: 1
                        startY: 10
                        PathLine {
                            x: 19
                            y: 10
                        }
                    }
                }

                MouseArea {
                    id: newChatHover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: cat.newChat()
                }
            }

            Flickable {
                id: chatList

                x: 18
                y: 58
                width: menuPanel.width - 36
                height: menuPanel.height - 58 - 18
                contentWidth: width
                contentHeight: chatRows.height
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                Column {
                    id: chatRows

                    width: chatList.width
                    spacing: 6

                    Repeater {
                        model: cat.chats

                        delegate: Item {
                            id: chatRow

                            required property var modelData
                            required property int index

                            readonly property bool active:
                                modelData.id === cat.currentChatKey
                            readonly property bool renaming:
                                chatMenu.renameId === modelData.id
                            readonly property bool hot:
                                active || renaming || rowHover.containsMouse

                            width: chatRows.width
                            height: chatMenu.rowHeight

                            // внешняя тёмная обводка — как у заголовка
                            Shape {
                                anchors.fill: parent
                                z: -1
                                preferredRendererType: Shape.CurveRenderer

                                SShapePath {
                                    joinStyle: ShapePath.MiterJoin
                                    capStyle: ShapePath.FlatCap
                                    strokeColor: Settings.c2
                                    strokeWidth: Settings.line * 3
                                    fillColor: "transparent"

                                    startX: 0
                                    startY: 0
                                    PathLine { x: chatRow.width;                    y: 0 }
                                    PathLine { x: chatRow.width - chatMenu.rowPoint; y: chatRow.height / 2 }
                                    PathLine { x: chatRow.width;                    y: chatRow.height }
                                    PathLine { x: 0;                                 y: chatRow.height }
                                    PathLine { x: chatMenu.rowPoint;                  y: chatRow.height / 2 }
                                    PathLine { x: 0; y: 0 }
                                }
                            }

                            Shape {
                                anchors.fill: parent
                                preferredRendererType: Shape.CurveRenderer

                                SShapePath {
                                    joinStyle: ShapePath.MiterJoin
                                    capStyle: ShapePath.FlatCap
                                    strokeColor: Settings.c1
                                    strokeWidth: Settings.line
                                    fillColor: chatRow.hot
                                        ? Settings.c1 : Settings.c2

                                    startX: 0
                                    startY: 0
                                    PathLine { x: chatRow.width;                    y: 0 }
                                    PathLine { x: chatRow.width - chatMenu.rowPoint; y: chatRow.height / 2 }
                                    PathLine { x: chatRow.width;                    y: chatRow.height }
                                    PathLine { x: 0;                                 y: chatRow.height }
                                    PathLine { x: chatMenu.rowPoint;                  y: chatRow.height / 2 }
                                    PathLine { x: 0; y: 0 }
                                }
                            }

                            SText {
                                visible: !chatRow.renaming

                                x: chatMenu.rowPoint + 10
                                y: 0
                                width: parent.width - chatMenu.rowPoint - 52
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: cat.chatTitle(chatRow.modelData)
                                color: chatRow.hot ? Settings.c2 : Settings.c1
                                font.pixelSize: 12
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            TextInput {
                                id: renameInput

                                visible: chatRow.renaming
                                x: chatMenu.rowPoint + 10
                                y: 0
                                width: parent.width - chatMenu.rowPoint - 52
                                height: parent.height
                                verticalAlignment: TextInput.AlignVCenter
                                color: Settings.c2
                                selectionColor: Settings.c1
                                selectedTextColor: Settings.c2
                                font.pixelSize: 12
                                font.bold: true
                                clip: true

                                onVisibleChanged: {
                                    if (!visible)
                                        return

                                    const chat = cat.findChat(
                                        chatRow.modelData.id)

                                    text = chat ? chat.title : ""
                                    forceActiveFocus()
                                    selectAll()
                                }
                                onAccepted: chatMenu.commitRename(
                                    chatRow.modelData.id, text)
                                onEditingFinished: chatMenu.commitRename(
                                    chatRow.modelData.id, text)

                                Keys.onEscapePressed: chatMenu.renameId = ""
                            }

                            MouseArea {
                                id: rowHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: cat.showChat(
                                    chatRow.modelData.id)
                            }

                            // троеточие: действия над чатом
                            Item {
                                id: dotsBtn

                                visible: !chatRow.renaming
                                x: chatRow.width - 12 - width
                                y: (chatRow.height - height) / 2
                                width: 24
                                height: 24

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 3

                                    Repeater {
                                        model: 3

                                        delegate: Rectangle {
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            color: chatRow.hot
                                                ? Settings.c2 : Settings.c1
                                        }
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: chatMenu.openActions(
                                        chatRow.modelData.id,
                                        chatList.y + chatRow.y
                                            + chatRow.height / 2)
                                }
                            }
                        }
                    }
                }
            }

            // закрытие меню действий кликом мимо
            MouseArea {
                visible: chatMenu.actionId !== ""
                z: 25
                anchors.fill: parent
                onClicked: chatMenu.actionId = ""
            }

            // меню действий над чатом
            Panel {
                id: actionsPanel

                visible: chatMenu.actionId !== ""
                z: 30
                x: menuPanel.width - width - 18
                y: chatMenu.actionY
                width: chatMenu.actionsW
                height: chatMenu.actionsH
                cornerCut: Settings.line * 2
                strokeColor: Settings.c1
                fillColor: Settings.c2
                strokeWidth: Settings.line

                readonly property var target: cat.findChat(
                    chatMenu.actionId)

                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    x: 4
                    y: 4
                    width: parent.width - 8

                    Repeater {
                        model: [
                            {
                                action: "rename",
                                label: "переименовать"
                            },
                            {
                                action: "pin",
                                label: actionsPanel.target
                                    && actionsPanel.target.pinned
                                    ? "открепить" : "закрепить"
                            },
                            {
                                action: "delete",
                                label: "удалить"
                            }
                        ]

                        delegate: Item {
                            id: actionRow

                            required property var modelData

                            width: parent.width
                            height: 28

                            readonly property bool hovered:
                                actionHover.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                color: Settings.c1
                                opacity: actionRow.hovered ? 1 : 0
                            }

                            SText {
                                x: 8
                                y: 0
                                width: parent.width - 16
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: actionRow.modelData.label
                                color: actionRow.hovered
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: actionHover

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    const id = chatMenu.actionId

                                    if (actionRow.modelData.action
                                            === "rename") {
                                        chatMenu.actionId = ""
                                        chatMenu.renameId = id
                                    } else if (actionRow.modelData.action
                                            === "pin") {
                                        cat.togglePin(id)
                                        chatMenu.actionId = ""
                                    } else {
                                        cat.deleteChat(id)
                                        chatMenu.actionId = ""
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    PanelWindow {
        id: shellRoot

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight:
            Settings.barGap * 2 +
            Settings.barHeight

        color: "transparent"

        Item {
            id: bar

            anchors.verticalCenter:
                parent.verticalCenter

            width: shellRoot.width
            height: parent.height

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.left:
                    parent.left

                height: parent.height
                
                SystemStats {
                    id: systemStats
                    height: parent.height
                }
            }

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.horizontalCenter:
                    parent.horizontalCenter

                height: parent.height

                Clock {
                    id: clock

                    height: parent.height

                    MouseArea {
                        anchors.fill: clock

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            appLauncher.show()
                    }
                }
            }

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.right:
                    parent.right

                height: parent.height

                WorkspaceBar {
                    id: workspaceBar
                    height: parent.height
                }
            }
        }

        IpcHandler {
            target: "main"

            function forceReload(): void {
                Quickshell.reload(true)
            }
            //APPS
            function toggleCat(): void {
                cat.toggle()
            }

            function toggleSettings(): void {
                settingsMenu.visible
                    ? settingsMenu.hide()
                    : settingsMenu.show()
            }

            function toggleControl(): void {
                controlPanel.visible
                    ? controlPanel.hide()
                    : controlPanel.show()
            }

            function toggleLauncher(): void {
                appLauncher.visible
                    ? appLauncher.hide()
                    : appLauncher.show()
            }
            // 3D
            function spawnCube(): void {
                physicsScene.addCube({
                    x: (Math.random() - 0.5) * 600,
                    y: 200 + Math.random() * 200,
                    size: 10 + Math.random() * 200
                })
            }
            function clearCubes(): void {
                physicsScene.clearCubes()
            }
            // LIFE
            function toggleConwayPause(): void {
                conwayGame.running = !conwayGame.running
            }

            function clearConway(): void {
                conwayGame.clearGrid()
            }
        }
    }


    PanelWindow {
        id: gameWindow
        anchors {
            top: true
            bottom: true
            right: true
            left: true
        }
        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Background
        color: "transparent"

        ConwayLife {
            id: conwayGame
            anchors.fill: parent
            cellSize: 20
            interval: 300
            color: Settings.c1
        }
    }

    Scene {
        id: physicsScene
        Component.onCompleted: {
        }
    }


    PanelWindow {
        id: notificationScreen

        anchors {
            top: true
            bottom: true
            right: true
            left: true
        }

        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        // Только hitbox'ы уведомлений входят в Wayland input region.
        property var notificationRegions: []

        // Упорядоченный стек активных уведомлений
        property var activeStack: []

        function pushToStack(popup) {
            var newStack = notificationScreen.activeStack.concat([popup])
            notificationScreen.activeStack = newStack
            popup.slotIndex = newStack.length - 1
        }

        function removeFromStack(popup) {
            var idx = notificationScreen.activeStack.indexOf(popup)
            if (idx === -1)
                return
            var newStack = notificationScreen.activeStack.slice()
            newStack.splice(idx, 1)
            notificationScreen.activeStack = newStack
            for (var i = 0; i < newStack.length; i++) {
                newStack[i].slotIndex = i
            }
        }

        mask: Region {
            regions: notificationScreen.notificationRegions
        }

        Item {
            id: columnRef
            anchors.fill: parent
        }
    }

    Connections {
        target: Notifications
//watch -n 1 "ls -l /proc/$(pidof qs)/fd | wc -l"
//
        function onNotificationAdded(notification) {
            var component = Qt.createComponent("NotificationPopup.qml")

            if (component.status !== Component.Ready) {
                console.error(
                    "Failed to load NotificationPopup.qml:",
                    component.errorString()
                )
                return
            }

            var popup = component.createObject(columnRef)

            if (!popup) {
                console.error("Failed to create NotificationPopup")
                return
            }

            popup.screenX = notificationScreen.width
            popup.currentNotification = notification
            popup.visible = true

            notificationScreen.pushToStack(popup)

            var hitbox = Qt.createQmlObject(
                'import QtQuick;

                Item {
                    property var popup: null

                    x: popup ? popup.x : 0
                    y: popup ? popup.y : 0

                    width: popup ? popup.width : 0
                    height: popup ? popup.height : 0

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            if (parent.popup) {
                                parent.popup.closeClicked = true
                            }
                        }
                    }
                }',
                columnRef,
                "NotificationHitbox"
            )

            if (!hitbox) {
                console.error("Failed to create NotificationHitbox")
                popup.destroy()
                return
            }

            hitbox.popup = popup
            hitbox.z = 100000

            var region = Qt.createQmlObject(
                'import Quickshell;

                Region {}',
                notificationScreen,
                "NotificationRegion"
            )

            if (!region) {
                console.error("Failed to create NotificationRegion")

                hitbox.popup = null
                hitbox.destroy()

                popup.destroy()

                return
            }

            region.item = hitbox

            notificationScreen.notificationRegions =
                notificationScreen.notificationRegions.concat([region])

            popup.popupClosed.connect(function() {
                notificationScreen.removeFromStack(popup)

                var regions =
                    notificationScreen.notificationRegions.slice()

                var index = regions.indexOf(region)

                if (index !== -1) {
                    regions.splice(index, 1)

                    notificationScreen.notificationRegions =
                        regions
                }

                if (region) {
                    region.item = null
                    region.destroy()
                }

                if (hitbox) {
                    hitbox.popup = null
                    hitbox.destroy()
                }
            })
        }

        function onAllCleared() {
            notificationScreen.activeStack = []
            notificationScreen.notificationRegions = []
        }
    }

    SettingsMenu {id: settingsMenu}

    ControlPanel {id: controlPanel}
    AppLauncher {id: appLauncher}
    Cat {
        id: cat

        menuShift: chatMenu.shift
        menuOpen: chatMenu.open

        onMenuToggled: chatMenu.open = !chatMenu.open
        onMenuCloseRequested: chatMenu.open = false
    }
}
