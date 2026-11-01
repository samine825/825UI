import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick.Window
import QtQuick.Shapes

import "./3D"
import "./Apps"
import "./Bar"
import "./Cat"
import "./Components"

// =^..^=
ShellRoot {
    id: shell

    // одновременное открытие только одной панели приложения:
    // открывая одну, закрываем остальные (кот и его меню не в счёте)
    function showOnly(panel) {
        const panels = {
            "launcher": appLauncher,
            "control": controlPanel,
            "settings": settingsMenu
        }

        for (const key in panels) {
            if (key === panel)
                panels[key].show()
            else if (panels[key].visible)
                panels[key].hide()
        }
    }

    // уведомление как обратная связь команд 825ctl
    function notify(summary, body) {
        notifyCmd.summary = summary
        notifyCmd.body = body
        notifyCmd.running = true
    }

    // === тоглы железа: дублируют клетки панели управления ===

    function toggleWifi(): void {
        Networking.wifiEnabled = !Networking.wifiEnabled
        notify("Wi-Fi", Networking.wifiEnabled ? "включён" : "выключен")
    }

    function toggleBluetooth(): void {
        const adapter = Bluetooth.defaultAdapter

        if (!adapter) {
            notify("Bluetooth", "адаптер не найден")
            return
        }

        if (adapter.enabled) {
            adapter.enabled = false
            notify("Bluetooth", "выключен")
        } else {
            // rfkill софт-блок не даёт включить адаптер —
            // снять его и включить в onExited
            btUnblock.running = true
        }
    }

    // следующее устройство вывода (sink) или ввода по кругу —
    // тот же список, что в колесе панели управления
    function cycleAudio(sink): void {
        const nodes = Pipewire.nodes.values
        const arr = []

        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]

            if (!n || !n.audio || n.isStream)
                continue

            if (sink ? !n.isSink : n.isSink)
                continue

            arr.push({
                label: (n.description !== ""
                    ? n.description : n.nickname),
                node: n
            })
        }

        if (arr.length === 0) {
            notify("825ctl audio", sink
                ? "устройства вывода не найдены"
                : "устройства ввода не найдены")
            return
        }

        arr.sort((a, b) => a.label.localeCompare(b.label))

        const cur = sink
            ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource
        let idx = -1

        for (let i = 0; i < arr.length; i++) {
            if (arr[i].node === cur) {
                idx = i
                break
            }
        }

        // не найден в списке — берём первый
        const next = arr[(idx + 1) % arr.length]

        if (sink)
            Pipewire.preferredDefaultAudioSink = next.node
        else
            Pipewire.preferredDefaultAudioSource = next.node

        notify(sink ? "Вывод" : "Ввод", next.label)
    }

    // rfkill софт-блок не даёт включить Bluetooth (PowerState:
    // off-blocked) — снимаем его и только потом включаем адаптер
    Process {
        id: btUnblock

        command: ["rfkill", "unblock", "bluetooth"]

        onExited: {
            if (Bluetooth.defaultAdapter) {
                Bluetooth.defaultAdapter.enabled = true
                shell.notify("Bluetooth", "включён")
            }
        }
    }

    Process {
        id: notifyCmd

        property string summary: ""
        property string body: ""

        command: ["notify-send", "-a", "825", "-t", "3000",
                  "-i", Quickshell.env("HOME") + "/.825UI/Textures/4.jpg",
                  summary, body]
    }

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
        readonly property real rowPoint: rowHeight * InfexGeometry.notchFrac

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

            // границы = видимому внешнему краю обводки, тень лежит
            // ровно в линию и достаёт до края экрана
            SPanel {
                x: Settings.line
                y: Settings.line
                width: parent.width - Settings.line * 2
                height: parent.height - Settings.line * 2
                cornerCut: Settings.line * 2
                flatRight: true
                strokeColor: Settings.c1
                fillColor: Settings.c2
                shadow: "outside"
                shadowColor: Settings.c2
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
                    // строки выросли на line (рамка = видимым границам):
                    // видимый зазор остаётся как был
                    spacing: Settings.line / 2

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

                            // рамка = старым видимым границам: рост на line
                            x: -Settings.line / 2
                            width: chatRows.width + Settings.line
                            height: chatMenu.rowHeight + Settings.line

                            // гранёный фрейм строки: активная заливается
                            SFrame {
                                anchors.fill: parent
                                z: -1
                                fillColor: chatRow.hot
                                    ? Settings.c1 : Settings.c2
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

                                        delegate: SRectangle {
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
            SPanel {
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

                            SText {
                                x: 8
                                y: 0
                                width: parent.width - 16
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: actionRow.modelData.label
                                color: Settings.c1
                                font.pixelSize: Settings.textXs
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                anchors.fill: parent
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
                            showOnly("launcher")
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
                    : showOnly("settings")
            }

            function toggleControl(): void {
                controlPanel.visible
                    ? controlPanel.hide()
                    : showOnly("control")
            }

            function toggleLauncher(): void {
                appLauncher.visible
                    ? appLauncher.hide()
                    : showOnly("launcher")
            }

            // === железо ===
            function toggleWifi(): void {
                shell.toggleWifi()
            }

            function toggleBluetooth(): void {
                shell.toggleBluetooth()
            }

            function cycleAudioOutput(): void {
                shell.cycleAudio(true)
            }

            function cycleAudioInput(): void {
                shell.cycleAudio(false)
            }

            function lock(): void {
                lockScreen.lock()
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
    LockScreen {id: lockScreen}
    Cat {
        id: cat

        menuShift: chatMenu.shift
        menuOpen: chatMenu.open

        onMenuToggled: chatMenu.open = !chatMenu.open
        onMenuCloseRequested: chatMenu.open = false
    }
}
