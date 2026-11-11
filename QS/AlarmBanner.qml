import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "Components"
import "Fonts"

// Баннер будильника и таймера: окно Overlay (над всеми панелями),
// невидимое вне показов, маска только на самом баннере — мимо
// клик проходит насквозь. Очередь сообщений: будильник не глушит
// таймер — показываются по очереди. Визуал — попап 1:1 с LockScreen:
// контур NotifContour (padX = 0.5·tipMult·line, кончики выемок на
// height/2), нарост c2 на 3 линии + обводка c1; приезд — каноническая
// тройка (полёт из-за верхней кромки OutCubic 600 + полуоборот
// OutSine 600 + прояв контента InCubic 1500), уход — реверс.
// Полуобороту соответствует поворот 180°→360°: баннер приземляется
// читаемым (у ленскрина контент — точки, им поворот не важен).
// Звук ленивый: создание SoundEffect на системах без аудиосервера
// виснет, поэтому эффекты создаются при первом показе.
PanelWindow {
    id: banner

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: false
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"

    signal alarmStopped(var payload)
    signal snoozed(var payload)
    signal timerStopped(var payload)

    // === очередь: [{kind, title, subtitle, payload}] ===
    property var queue: []
    property var current: null

    // фазы: 0 — скрыт, 1 — показывается/показан, 2 — уходит
    property int phase: 0

    readonly property real finalY:
        Settings.barHeight + Settings.line * 4

    readonly property real padX:
        0.5 * InfexGeometry.tipMult * Settings.line
    readonly property real padY: Settings.line / 2

    // === API ===
    function push(payload) {
        queue = queue.concat([payload])

        if (phase === 0)
            showNext()
    }

    function showNext() {
        if (queue.length === 0)
            return

        current = queue[0]
        queue = queue.slice(1)
        visible = true
        phase = 1

        box.y = -box.height
        box.rotation = 180
        content.opacity = 0
        arriveAnim.restart()

        if (current.kind === "alarm")
            playAlarm()
        else
            playTimer()
    }

    // snoozeRequested — только у будильника: «Отложить 5 минут»
    function stopCurrent(snoozeRequested) {
        if (phase !== 1 || !current)
            return

        phase = 2
        stopSounds()

        const payload = current.payload || {}

        if (current.kind === "alarm") {
            if (snoozeRequested)
                banner.snoozed(payload)
            else
                banner.alarmStopped(payload)
        } else {
            banner.timerStopped(payload)
        }

        content.opacity = 0
        leaveAnim.restart()
    }

    // === приезд: полёт сверху + полуоборот + прояв контента ===
    ParallelAnimation {
        id: arriveAnim

        PropertyAnimation {
            target: box; property: "y"
            from: -box.height; to: banner.finalY
            duration: 600; easing.type: Easing.OutCubic
        }

        PropertyAnimation {
            target: box; property: "rotation"
            from: 180; to: 360
            duration: 600; easing.type: Easing.OutSine
        }

        PropertyAnimation {
            target: content; property: "opacity"
            from: 0; to: 1
            duration: 1500; easing.type: Easing.InCubic
        }
    }

    // === уход — реверс приезда ===
    ParallelAnimation {
        id: leaveAnim

        PropertyAnimation {
            target: box; property: "y"
            to: -box.height
            duration: 600; easing.type: Easing.InCubic
        }

        PropertyAnimation {
            target: box; property: "rotation"
            from: 360; to: 180
            duration: 600; easing.type: Easing.OutSine
        }

        onFinished: {
            if (banner.queue.length > 0) {
                banner.showNext()
            } else {
                banner.current = null
                banner.visible = false
                banner.phase = 0
            }
        }
    }

    // === ленивые звуки ===
    property var alarmSound: null
    property var timerSound: null

    // будильник не звонит вечно: потолок 60 секунд
    Timer {
        id: soundCap

        interval: 60000

        onTriggered: banner.stopSounds()
    }

    function playAlarm() {
        if (!alarmSound) {
            try {
                alarmSound = Qt.createQmlObject(
                    "import QtMultimedia; SoundEffect {}",
                    banner, "AlarmBannerAlarmSound")
                alarmSound.source =
                    Qt.resolvedUrl("Sounds/alarm-loop.wav")
                // QSoundEffect.Infinite
                alarmSound.loops = -2
            } catch (e) {
                alarmSound = null
                return
            }
        }

        soundCap.restart()

        if (alarmSound)
            alarmSound.play()
    }

    function playTimer() {
        if (!timerSound) {
            try {
                timerSound = Qt.createQmlObject(
                    "import QtMultimedia; SoundEffect {}",
                    banner, "AlarmBannerTimerSound")
                timerSound.source =
                    Qt.resolvedUrl("Sounds/timer-beep.wav")
                timerSound.loops = 1
            } catch (e) {
                timerSound = null
                return
            }
        }

        if (timerSound)
            timerSound.play()
    }

    function stopSounds() {
        soundCap.stop()

        if (alarmSound)
            alarmSound.stop()

        if (timerSound)
            timerSound.stop()
    }

    // маска: события мыши только на баннере
    mask: banner.visible && banner.current ? boxMask : null

    Region {
        id: boxMask

        item: box
    }

    component NotifContour: SShapePath {
        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap

        startX: banner.padX
        startY: banner.padY

        PathLine { x: box.width - banner.padX; y: banner.padY }
        // правый кончик зажат к центру: без клампа узкий контур
        // пересекается сам на себе
        PathLine {
            x: Math.max(box.height / 2,
                box.width - box.height / 2)
            y: box.height / 2
        }
        PathLine { x: box.width - banner.padX; y: box.height - banner.padY }
        PathLine { x: banner.padX; y: box.height - banner.padY }
        PathLine { x: box.height / 2; y: box.height / 2 }
        PathLine { x: banner.padX; y: banner.padY }
    }

    // === сам баннер ===
    Item {
        id: box

        width: Settings.line * 110
        height: Settings.line * 34
        x: Math.round((banner.width - width) / 2)
        y: -height
        rotation: 180

        // тело: InfexBox — фон c2, нарост-тень снаружи, обводка c1
        InfexBox {
            id: bannerBox

            anchors.fill: parent
            edgeLeft: "Notch"
            edgeRight: "Notch"
            sideInset: 0
            shadowOuter: true
            shadowInner: false

            // контент: между кончиками выемок (талия на серединах
            // боковых сторон)
            Item {
                id: content

                x: bannerBox.x0 + Settings.line / 2
                    + bannerBox.notch + Settings.line
                width: bannerBox.width
                    - 2 * (bannerBox.x0 + Settings.line / 2
                        + bannerBox.notch + Settings.line)
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: Settings.line * 2
                anchors.bottomMargin: Settings.line * 2
                opacity: 0

            Column {
                width: parent.width
                spacing: Settings.line

                SText {
                    width: parent.width
                    text: banner.current
                        ? (banner.current.kind === "alarm"
                            ? "Alarm" : "Timer") : ""
                    color: Settings.c1
                    font.pixelSize: Settings.textXs
                    font.bold: true
                }

                SText {
                    width: parent.width
                    text: banner.current ? banner.current.title : ""
                    color: Settings.c1
                    elide: Text.ElideRight
                    font.pixelSize: Settings.textLg
                    font.bold: true
                }

                SText {
                    width: parent.width
                    text: banner.current ? banner.current.subtitle : ""
                    color: Settings.c1
                    elide: Text.ElideRight
                    font.pixelSize: Settings.textSm
                }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Settings.line * 3

                SButton {
                    width: Settings.line * 20
                    height: Settings.line * 8
                    label: "Stop"

                    onActivated: banner.stopCurrent(false)
                }

                SButton {
                    width: Settings.line * 26
                    height: Settings.line * 8
                    label: "Snooze 5m"
                    visible: banner.current
                        && banner.current.kind === "alarm"

                    onActivated: banner.stopCurrent(true)
                }
            }
        }
        }
    }
}
