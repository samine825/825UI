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
    id: shell

    // одновременное открытие только одной панели приложения:
    // открывая одну, закрываем остальные (кот и его меню не в счёте)
    function showOnly(panel) {
        // колёса устройств — в той же семье: панель открывается
        // на чистом экране
        controlPanel.hideWheels()

        // камера и диктофон — одна панель с табами: recorder
        // открывает её на табе аудио
        if (panel === "camera" || panel === "recorder") {
            mediaPanel.openTab = panel === "recorder" ? 1 : 0
            panel = "camera"
        }

        const panels = {
            "launcher": appLauncher,
            "control": controlPanel,
            "settings": settingsMenu,
            "clipboard": clipboardPanel,
            "calculator": calculatorPanel,
            "emoji": emojiPickerPanel,
            "clock": clockApp,
            "camera": mediaPanel
        }

        for (const key in panels) {
            if (key === panel)
                panels[key].show()
            else if (panels[key].visible)
                panels[key].hide()
        }
    }

    // тогл колеса устройства: открытое колесо закрывает панели
    // приложений — колёса в одной семье с панелями
    function toggleWheel(name) {
        if (controlPanel.toggleWheel(name)) {
            if (appLauncher.visible)
                appLauncher.hide()

            if (settingsMenu.visible)
                settingsMenu.hide()
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

            // === приложения ===
            function toggleClipboard(): void {
                clipboardPanel.visible
                    ? clipboardPanel.hide()
                    : showOnly("clipboard")
            }

            function toggleCalculator(): void {
                calculatorPanel.visible
                    ? calculatorPanel.hide()
                    : showOnly("calculator")
            }

            function toggleEmoji(): void {
                emojiPickerPanel.visible
                    ? emojiPickerPanel.hide()
                    : showOnly("emoji")
            }

            function toggleClock(): void {
                clockApp.visible
                    ? clockApp.hide()
                    : showOnly("clock")
            }

            function toggleCamera(): void {
                mediaPanel.visible
                    ? mediaPanel.hide()
                    : showOnly("camera")
            }

            function toggleRecorder(): void {
                mediaPanel.visible
                    ? mediaPanel.hide()
                    : showOnly("recorder")
            }

            // === колёса устройств ===
            function toggleWifiWheel(): void {
                toggleWheel("wifi")
            }

            function toggleBtWheel(): void {
                toggleWheel("bluetooth")
            }

            function toggleSinkWheel(): void {
                toggleWheel("output")
            }

            function toggleSourceWheel(): void {
                toggleWheel("input")
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
            // режим без уведомлений: попап не создаётся, уведомление
            // проходит конвейер сервера (таймаут-закрытие) и попадает
            // в архив панели управления
            if (Settings.dnd)
                return

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

    // включение режима без уведомлений мягко закрывает уже висящие
    // попапы — штатным closeClicked с анимацией ухода
    Connections {
        target: Settings

        function onDndChanged() {
            if (!Settings.dnd)
                return

            const stack = notificationScreen.activeStack

            for (let i = 0; i < stack.length; i++)
                stack[i].closeClicked = true
        }
    }

    SettingsMenu {id: settingsMenu}

    ControlPanel {
        id: controlPanel

        onAppRequested: (app) => showOnly(app)
    }
    AppLauncher {id: appLauncher}
    LockScreen {id: lockScreen}

    // === приложения ===
    AlarmBanner { id: alarmBanner }

    // каталоги состояния приложений: FileView каталоги сам не создаёт,
    // без них каждая запись падает с ошибкой записи
    Process {
        id: bootstrapDirs

        command: ["sh", "-c",
            "mkdir -p \"$HOME/.825UI/state/clipboard\""
            + " \"$HOME/Pictures/825UI\""]
    }

    Component.onCompleted: bootstrapDirs.running = true

    Clipboard { id: clipboardPanel }
    Calculator { id: calculatorPanel }
    EmojiPicker { id: emojiPickerPanel }
    ClockApp {
        id: clockApp

        banner: alarmBanner
    }
    MediaApp { id: mediaPanel }

    // панель чатов — часть кота: шелл больше не резервирует место
    // и не двигает бар
    Cat {
        id: cat
    }
}
