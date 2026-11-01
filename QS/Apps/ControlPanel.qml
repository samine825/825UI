import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Bluetooth
import Qt5Compat.GraphicalEffects
import "../Components"
import "../"

PanelWindow {
    id: root
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    focusable: true
    exclusiveZone: -1
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    // === АУДИО (PipeWire) ===
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property var sinkAudio:
        Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.ready
            ? Pipewire.defaultAudioSink.audio : null

    readonly property real volumeLevel: sinkAudio ? sinkAudio.volume : 0
    readonly property bool volumeMuted: sinkAudio ? sinkAudio.muted : false

    readonly property var sourceAudio:
        Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.ready
            ? Pipewire.defaultAudioSource.audio : null

    readonly property real micLevel: sourceAudio ? sourceAudio.volume : 0
    readonly property bool micMuted: sourceAudio ? sourceAudio.muted : false

    function setVolume(v) {
        if (sinkAudio)
            sinkAudio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMute() {
        if (sinkAudio)
            sinkAudio.muted = !sinkAudio.muted
    }

    function setMicVolume(v) {
        if (sourceAudio)
            sourceAudio.volume = Math.max(0, Math.min(1, v))
    }

    function toggleMicMute() {
        if (sourceAudio)
            sourceAudio.muted = !sourceAudio.muted
    }

    // === ЯРКОСТЬ (brightnessctl, fallback — ddcutil) ===
    QtObject {
        id: brightnessCtl

        // 0 — недоступно, 1 — brightnessctl, 2 — ddcutil
        property int mode: 0
        property string device: ""
        property real max: 1
        property real current: 1
        property real hold: -1
        property real pending: -1

        readonly property bool available: mode > 0
        readonly property real ratio: hold >= 0
            ? hold
            : (max > 0 ? current / max : 0)

        function refresh() {
            brightGet.running = false
            brightGet.running = true
        }

        function request(v) {
            hold = v
            pending = Math.max(0, Math.min(1, v))
            brightThrottle.restart()
        }
    }

    Process {
        id: brightGet
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n")
                let dev = null

                for (let i = 0; i < lines.length; i++) {
                    const f = lines[i].split(",")

                    if (f.length >= 5 && f[1] === "backlight") {
                        dev = f
                        break
                    }
                }

                if (dev) {
                    brightnessCtl.mode = 1
                    brightnessCtl.device = dev[0]
                    brightnessCtl.current = parseFloat(dev[2]) || 0
                    brightnessCtl.max = parseFloat(dev[4]) || 1
                    brightnessCtl.hold = -1
                    return
                }

                // Нет backlight — пробуем ddcutil (внешние мониторы).
                brightProbe.running = true
            }
        }
    }

    Process {
        id: brightProbe
        command: ["sh", "-c", "command -v ddcutil"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "") {
                    brightnessCtl.mode = 2
                    brightDdcGet.running = true
                } else {
                    brightnessCtl.mode = 0
                }
            }
        }
    }

    Process {
        id: brightDdcGet
        command: ["ddcutil", "getvcp", "10", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim().split(/\s+/)
                const cur = parseFloat(t[t.length - 2])
                const max = parseFloat(t[t.length - 1])

                if (!isNaN(cur) && !isNaN(max) && max > 0) {
                    brightnessCtl.current = cur
                    brightnessCtl.max = max
                    brightnessCtl.hold = -1
                }
            }
        }
    }

    Timer {
        id: brightThrottle
        interval: 150
        onTriggered: {
            const v = brightnessCtl.pending

            if (v < 0 || brightnessCtl.mode === 0)
                return

            // ddcutil медленный: не наслаиваем процессы при драге
            if (brightSet.running) {
                brightThrottle.restart()
                return
            }

            const abs = String(Math.round(v * brightnessCtl.max))

            if (brightnessCtl.mode === 1)
                brightSet.command = ["brightnessctl", "-q", "-d",
                    brightnessCtl.device, "set", abs]
            else
                brightSet.command = ["ddcutil", "setvcp", "10", abs]

            brightSet.running = true
        }
    }

    Process {
        id: brightSet
        onExited: if (brightnessCtl.mode === 1) brightnessCtl.refresh()
    }

    // === МЕДИА (MPRIS) ===
    readonly property var mprisPlayer: {
        const list = Mpris.players.values

        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i]
        }

        return list.length > 0 ? list[0] : null
    }

    // === WI-FI / BLUETOOTH ===
    readonly property var wifiDevice: {
        const list = Networking.devices.values

        for (let i = 0; i < list.length; i++) {
            if (list[i].type === DeviceType.Wifi)
                return list[i]
        }

        return null
    }

    // элементы колеса: сети, отсортированные по уровню сигнала
    readonly property var wifiItems: {
        const tick = root.statusTick // пересчёт по истечении меток failed
        const dev = root.wifiDevice
        if (!dev || !dev.networks)
            return []

        const nets = dev.networks.values || []
        const arr = []

        for (let i = 0; i < nets.length; i++) {
            const n = nets[i]
            if (!n || n.name === "")
                continue

            arr.push({
                label: n.name,
                status: root.wifiStatus(n),
                net: n
            })
        }

        arr.sort((a, b) => b.net.signalStrength - a.net.signalStrength)
        return arr
    }

    // элементы колеса: спаренные и обнаруженные Bluetooth-устройства
    readonly property var btItems: {
        const tick = root.statusTick // пересчёт по истечении меток failed
        const adapter = Bluetooth.defaultAdapter
        if (!adapter || !adapter.devices)
            return []

        const devs = adapter.devices.values || []
        const arr = []

        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]
            if (!d)
                continue

            arr.push({
                label: (d.name !== "" ? d.name : d.address),
                status: root.btStatus(d),
                dev: d
            })
        }

        arr.sort((a, b) => (b.dev.connected - a.dev.connected)
            || a.label.localeCompare(b.label))
        return arr
    }

    // элементы колеса: устройства вывода (приёмники PipeWire)
    readonly property var sinkItems: {
        const arr = []
        const nodes = Pipewire.nodes.values

        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!n || !n.audio || n.isStream || !n.isSink)
                continue

            arr.push({
                label: (n.description !== "" ? n.description : n.nickname),
                status: n === Pipewire.defaultAudioSink
                    ? "connected" : "",
                node: n
            })
        }

        arr.sort((a, b) => a.label.localeCompare(b.label))
        return arr
    }

    // элементы колеса: устройства ввода (источники)
    readonly property var sourceItems: {
        const arr = []
        const nodes = Pipewire.nodes.values

        for (let i = 0; i < nodes.length; i++) {
            const n = nodes[i]
            if (!n || !n.audio || n.isStream || n.isSink)
                continue

            arr.push({
                label: (n.description !== "" ? n.description : n.nickname),
                status: n === Pipewire.defaultAudioSource
                    ? "connected" : "",
                node: n
            })
        }

        arr.sort((a, b) => a.label.localeCompare(b.label))
        return arr
    }

    // === СТАТУСЫ ПОДКЛЮЧЕНИЯ ===
    // У модуля Quickshell.Networking подключённая сеть не помечается
    // (connected=false, state=Disconnected), поэтому статус wifi берём
    // из nmcli. Переход «подключается» -> «отключено» без успеха считается
    // ошибкой: ключ (имя сети / адрес устройства) хранит, был ли он в
    // процессе подключения, и метку времени, до которой показывается
    // значок ошибки. Разрыв связи ошибкой не считается.
    property var wifiWasBusy: ({})
    property var btWasBusy: ({})
    property var wifiFailUntil: ({})
    property var btFailUntil: ({})
    property int statusTick: 0

    property string nmWifiRaw: ""

    Process {
        id: nmWifiProcess

        command: ["nmcli", "-t", "-f", "DEVICE,STATE,CONNECTION", "device", "status"]

        stdout: StdioCollector {
            onStreamFinished: root.nmWifiRaw = this.text
        }
    }

    Timer {
        interval: 1000; repeat: true; running: true
        onTriggered: if (!nmWifiProcess.running) nmWifiProcess.running = true
    }

    Timer {
        id: statusFailTimer
        interval: 3000
        onTriggered: root.statusTick++
    }

    // активное подключение wifi-устройства: {name, busy};
    // busy — «connecting (… nmcli)», деактивация ошибкой не считается
    function nmWifiActive() {
        const dev = root.wifiDevice
        if (!dev)
            return { name: "", busy: false }

        const lines = root.nmWifiRaw.split("\n")

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":")

            if (parts.length < 3 || parts[0] !== dev.name)
                continue

            // в -t режиме значения экранированы: "\:" -> ":"
            const name = parts.slice(2).join(":").replace(/\\:/g, ":")

            if (name === "")
                return { name: "", busy: false }

            if (parts[1] === "connected")
                return { name: name, busy: false }

            if (parts[1].startsWith("connecting"))
                return { name: name, busy: true }
        }

        return { name: "", busy: false }
    }

    function applyFailMark(wasBusy, failUntil, key, s) {
        if (s === "connecting") {
            wasBusy[key] = true
        } else if (s === "connected") {
            delete wasBusy[key]
            delete failUntil[key]
        } else if (wasBusy[key]) {
            wasBusy[key] = false
            failUntil[key] = Date.now() + 3000
            statusFailTimer.restart()
        }

        if (s === "" && failUntil[key] > Date.now())
            return "failed"

        return s
    }

    function wifiStatus(n) {
        const act = root.nmWifiActive()

        let s = ""
        if (act.name === n.name)
            s = act.busy ? "connecting" : "connected"

        return applyFailMark(wifiWasBusy, wifiFailUntil, n.name, s)
    }

    function btStatus(d) {
        let s = ""
        if (d.connected || d.state === BluetoothDeviceState.Connected)
            s = "connected"
        else if (d.pairing || d.state === BluetoothDeviceState.Connecting)
            s = "connecting"

        return applyFailMark(btWasBusy, btFailUntil, d.address, s)
    }

    // === ПИТАНИЕ ===
    Process {
        id: powerProcess
    }    function powerAction(action) {
        if (action === "")
            return

        root.hide()
        powerProcess.command = ["systemctl", action]
        powerProcess.running = true
    }

    onVisibleChanged: if (visible) brightnessCtl.refresh()

    // === ИНЛАЙН-КОМПОНЕНТЫ ===

    // Слайдр в стиле уведомлений: два слоя одного контента, верхний
    // обрезан по уровню заполнения, цвета внутри заполнения инвертированы.
    component SliderTile: Item {
        id: sliderTile

        property real value: 1
        property bool available: true
        property string iconFill: ""
        property string iconStroke: ""
        property bool showIcon: true
        property real iconScale: 0.5

        signal valueRequested(real v)
        signal dragEnded()
        signal iconActivated()
        signal wheelRequested()

        // выключенный слайдер прячется целиком
        visible: available

        // базовый слой: заливка — ребёнок рамки, обводка z1 всегда поверх
        SFrame {
            anchors.fill: parent
            fillColor: Settings.c2
            strokeColor: Settings.c1

            VIcon {
                visible: sliderTile.showIcon
                anchors.centerIn: parent
                width: parent.height * sliderTile.iconScale
                height: width
                lineColor: Settings.c1
                fillPath: sliderTile.iconFill
                strokePath: sliderTile.iconStroke
            }

            // слой заполнения (клип по уровню, инвертированные цвета)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                height: parent.height
                width: parent.width * Math.max(0, Math.min(1, sliderTile.value))
                clip: true

                Behavior on width {
                    NumberAnimation { duration: Settings.animInstant }
                }

                Item {
                    width: sliderTile.width
                    height: sliderTile.height

                    // заливка c1 с зазором-тенью внутри: отделяет заливку
                    // от обводки слайдера ровно одной линией и на прямых,
                    // и на косых гранях
                    SFrame {
                        anchors.fill: parent
                        fillColor: Settings.c1
                        strokeColor: "transparent"
                        shadow: "inside"
                        shadowColor: Settings.c2
                        fillInset: -Settings.line / 2
                    }

                    VIcon {
                        visible: sliderTile.showIcon
                        anchors.centerIn: parent
                        width: parent.height * sliderTile.iconScale
                        height: width
                        lineColor: Settings.c2
                        fillPath: sliderTile.iconFill
                        strokePath: sliderTile.iconStroke
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            // левый — выставление значения, правый — колесо устройств
            function apply(mouse) {
                if (mouse.button !== Qt.LeftButton)
                    return

                sliderTile.valueRequested(
                    Math.max(0, Math.min(1, mouse.x / sliderTile.width)))
            }

            onPressed: (mouse) => {
                if (mouse.button === Qt.RightButton) {
                    sliderTile.wheelRequested()
                    return
                }

                apply(mouse)
            }
            onPositionChanged: (mouse) => apply(mouse)
            onReleased: (mouse) => {
                if (mouse.button === Qt.LeftButton)
                    sliderTile.dragEnded()
            }
        }

        // клик по зоне иконки — доп. действие (например mute)
        MouseArea {
            anchors.centerIn: parent
            width: parent.height * 0.7
            height: parent.height * 0.7
            z: 2
            cursorShape: Qt.PointingHandCursor

            onClicked: sliderTile.iconActivated()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    function show() {
        root.visible = true
    }

    function hide() {
        root.visible = false
    }

    MouseFollow {
        id: tiltContainer

        width: 800
        height: 560

        x: (Screen.width - width) / 2
        y: Settings.barGap * 2 + Settings.barHeight

        Item {
            id: windowFrame
            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: Settings.line * 4

                // --- Большой бар с датой (в стиле табов из настроек, но без табов) ---
                Item {
                    id: dateBar
                    width: parent.width - (InfexGeometry.tipMult * Settings.line / 2)
                    height: Settings.barHeight
                    anchors.horizontalCenter: parent.horizontalCenter

                    property real point: height * InfexGeometry.notchFrac
                    property real tabBorderWidth: Settings.line
                    property real blackOutlineWidth: Settings.line

                    // тело бара: гранёный фрейм с тенью
                    SFrame {
                        anchors.fill: parent
                    }

                    // Текст даты внутри бара
                    SText {
                        id: date
                        anchors.centerIn: parent
                        text: "null"
                        color: Settings.c1
                        font.bold: true
                    }
                }

                // --- Контентная область: разделена на две части ---
                Item {
                    id: contentArea
                    width: parent.width
                    height: parent.height - dateBar.height - Settings.line * 3

                    // Панель основного контента, тень ровно в линию
                    SPanel {
                        anchors.fill: parent
                        cornerCut: Settings.line * 2
                        strokeColor: Settings.c1
                        fillColor: Settings.c2
                        shadow: "outside"
                        shadowColor: Settings.c2

                        Row {
                            anchors.fill: parent

                            // Левая часть: грид 6xN виджетов. Ширина — ровно
                            // на 6 клеток с gaps, клетка квадратная с высотой
                            // заголовка/бара из конфига. Отступы ровные:
                            // margin = gap = line * 2.
                            Item {
                                id: leftPart
                                width: margin * 2
                                    + columns * cell + (columns - 1) * gap
                                    // пояс разделителя — в 1 line от
                                    // кромки плиток и powerRow
                                    // (центр штриха на +1.5 линии от кромки)
                                    - Settings.line * 0.75
                                height: parent.height

                                // плитки выросли на line (рамка = старым
                                // видимым границам), поле — на пол-линии
                                // с каждой стороны: зазор кольцо->плитка = 1 line
                                property real margin: Settings.line * 2.5
                                property real gap: Settings.line * 2

                                property int columns: 6

                                property real cell:
                                    Settings.barHeight - Settings.line

                                function cellX(col) {
                                    return margin + col * (cell + gap)
                                }

                                function cellY(row) {
                                    return margin + row * (cell + gap)
                                }

                                // Громкость 0x0, размер 3x1
                                SliderTile {
                                    // отступы по 2 линии от зоны плиток: кромки c1 слайдера
                                    // совпадают с кромками плиток (у них срез углов)
                                    // слайдер занимает свою зону целиком
                                    // (3 клетки + 2 зазора), рамка = зоне
                                    x: leftPart.cellX(0)
                                    y: leftPart.cellY(0) - Settings.line / 2
                                    width: leftPart.cell * 3 + leftPart.gap * 2
                                    height: leftPart.cell + Settings.line

                                    value: root.volumeMuted
                                        ? 0 : root.volumeLevel
                                    iconFill: Glyphs.iconVolumeBody
                                    iconStroke: root.volumeMuted
                                        ? Glyphs.iconVolumeMuted
                                        : Glyphs.iconVolumeWaves

                                    onValueRequested: (v) => root.setVolume(v)
                                    onIconActivated: root.toggleMute()

                                    onWheelRequested: {
                                        root.hide()
                                        sinkWheel.show()
                                    }
                                }

                                // Яркость 0x1, размер 3x1
                                SliderTile {
                                    // отступы по 2 линии от зоны плиток: кромки c1 слайдера
                                    // совпадают с кромками плиток (у них срез углов)
                                    // слайдер занимает свою зону целиком
                                    // (3 клетки + 2 зазора), рамка = зоне
                                    x: leftPart.cellX(0)
                                    y: leftPart.cellY(1) - Settings.line / 2
                                    width: leftPart.cell * 3 + leftPart.gap * 2
                                    height: leftPart.cell + Settings.line

                                    available: brightnessCtl.available
                                    value: brightnessCtl.ratio
                                    iconFill: ""
                                    iconStroke: Glyphs.iconBrightness

                                    onValueRequested: (v) => brightnessCtl.request(v)
                                    onIconActivated: brightnessCtl.refresh()
                                }

                                // Микрофон 2x0, размер 3x1
                                SliderTile {
                                    // отступы по 2 линии от зоны плиток: кромки c1 слайдера
                                    // совпадают с кромками плиток (у них срез углов)
                                    // слайдер занимает свою зону целиком
                                    // (3 клетки + 2 зазора), рамка = зоне
                                    x: leftPart.cellX(0)
                                    y: leftPart.cellY(2) - Settings.line / 2
                                    width: leftPart.cell * 3 + leftPart.gap * 2
                                    height: leftPart.cell + Settings.line

                                    available: root.sourceAudio !== null
                                    value: root.micMuted
                                        ? 0 : root.micLevel
                                    iconFill: ""
                                    iconStroke: root.micMuted
                                        ? Glyphs.iconMicMuted
                                        : Glyphs.iconMic

                                    onValueRequested: (v) => root.setMicVolume(v)
                                    onIconActivated: root.toggleMicMute()

                                    onWheelRequested: {
                                        root.hide()
                                        sourceWheel.show()
                                    }
                                }

                                // Плеер 3x3 у правого края верхней зоны
                                Item {
                                    id: playerTile
                                    x: leftPart.cellX(3) - Settings.line / 2
                                    y: leftPart.cellY(0) - Settings.line / 2
                                    width: leftPart.cell * 3 + leftPart.gap * 2 + Settings.line
                                    height: leftPart.cell * 3 + leftPart.gap * 2 + Settings.line
                                    
                                    property var player: root.mprisPlayer
                                    property bool hasTrack:
                                        player !== null && player.trackTitle !== ""
                                    property real polledPos: 0
                                    readonly property real cornerCut: Settings.line * 2
                                    
                                    // опрос позиции трека
                                    Timer {
                                        interval: 500
                                        repeat: true
                                        running: playerTile.player !== null
                                            && playerTile.player.positionSupported
                                        onTriggered: {
                                            if (playerTile.player)
                                                playerTile.polledPos =
                                                    playerTile.player.position
                                        }
                                    }
                                    
                                    // фон и рамка карточки; обложка и полоса — контент
                                    // панели: режутся по силуэту и остаются под обводкой
                                    SPanel {
                                        anchors.fill: parent
                                        cornerCut: playerTile.cornerCut
                                        shadow: "inside"
                                        shadowColor: Settings.c2
                                        strokeColor: Settings.c1
                                        fillColor: Settings.c2

                                        Image {
                                            anchors.fill: parent
                                            asynchronous: true
                                            cache: false
                                            smooth: true
                                            fillMode: Image.PreserveAspectCrop
                                            visible: playerTile.hasTrack
                                                && playerTile.player.trackArtUrl !== ""

                                            source: {
                                                const p = playerTile.player
                                                if (!p)
                                                    return ""

                                                const u = p.trackArtUrl
                                                if (u === "")
                                                    return ""

                                                return (u.startsWith("file://")
                                                        || u.startsWith("http"))
                                                    ? u : "file://" + u
                                            }
                                        }
                                    // нижняя полоса: прогресс — фон под
                                    // бегущим текстом. Чёрное — не пройдено,
                                    // белое — пройдено, текст инвертируется
                                    // над белой частью.
                                    Item {
                                        id: captionStrip
                                        z: 4
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: Settings.line / 2
                                        height: 20
                                        clip: true

                                        // удержание позиции при перемотке
                                        property real seekHold: -1

                                        // медиа нельзя пролистать — белая
                                        // заливка прогресса плавно исчезает
                                        // (ширина к нулю), полоса остаётся
                                        // фоном под текстом
                                        readonly property bool seekable:
                                            playerTile.hasTrack
                                            && playerTile.player
                                            && playerTile.player.canSeek

                                        readonly property real ratio: seekHold >= 0 ? seekHold : (seekable && playerTile.player.length > 0 ? Math.max(0, Math.min(1, playerTile.polledPos / playerTile.player.length)) : 0)

                                        readonly property string caption: playerTile.hasTrack ? (playerTile.player.trackArtist !== "" ? playerTile.player.trackArtist + " — " + playerTile.player.trackTitle : playerTile.player.trackTitle) : "Нет медиа"

                                        // бегущая строка: текст листается
                                        // вправо бесконечно, между
                                        // повторами зазор marqueeGap
                                        readonly property real marqueeGap: 40
                                        readonly property real marqueePeriod: captionMetrics.width + marqueeGap
                                        readonly property bool scrolling: captionMetrics.width > width - 20
                                        property real marqueePhase: 0

                                        TextMetrics {
                                            id: captionMetrics
                                            text: captionStrip.caption
                                            font.pixelSize: Settings.textXs
                                        }

                                        NumberAnimation {
                                            id: marqueeAnim
                                            target: captionStrip
                                            property: "marqueePhase"
                                            loops: Animation.Infinite
                                            from: 0
                                            to: captionStrip.marqueePeriod
                                            duration: captionStrip.marqueePeriod / 26 * 1000
                                            running: captionStrip.scrolling
                                        }

                                        Connections {
                                            target: captionMetrics
                                            function onTextChanged() {
                                                captionStrip.marqueePhase = 0
                                                marqueeAnim.restart()
                                            }
                                        }

                                        // чёрное — отсутствие прогресса
                                        SRectangle {
                                            anchors.fill: parent
                                            color: Settings.c2
                                        }

                                        // белое — пройденная часть
                                        SRectangle {
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            width: parent.width * captionStrip.ratio
                                            color: Settings.c1

                                            Behavior on width {
                                                NumberAnimation { duration: Settings.animBase }
                                            }
                                        }

                                        // бегущий текст: белый по чёрному,
                                        // две копии для бесшовного цикла
                                        SText {
                                            y: (parent.height - height) / 2
                                            x: captionStrip.scrolling
                                                ? -captionStrip.marqueePhase
                                                : (captionStrip.width - captionMetrics.width) / 2
                                            text: captionStrip.caption
                                            color: Settings.c1
                                            font.pixelSize: Settings.textXs
                                        }

                                        SText {
                                            visible: captionStrip.scrolling
                                            y: (parent.height - height) / 2
                                            x: captionStrip.marqueePeriod
                                                - captionStrip.marqueePhase
                                            text: captionStrip.caption
                                            color: Settings.c1
                                            font.pixelSize: Settings.textXs
                                        }

                                        // чёрные копии, обрезанные до
                                        // пройденной части
                                        Item {
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            width: parent.width * captionStrip.ratio
                                            clip: true

                                            Behavior on width {
                                                NumberAnimation { duration: Settings.animBase }
                                            }

                                            SText {
                                                y: (parent.height - height) / 2
                                                x: captionStrip.scrolling
                                                    ? -captionStrip.marqueePhase
                                                    : (captionStrip.width - captionMetrics.width) / 2
                                                text: captionStrip.caption
                                                color: Settings.c2
                                                font.pixelSize: Settings.textXs
                                            }

                                            SText {
                                                visible: captionStrip.scrolling
                                                y: (parent.height - height) / 2
                                                x: captionStrip.marqueePeriod
                                                    - captionStrip.marqueePhase
                                                text: captionStrip.caption
                                                color: Settings.c2
                                                font.pixelSize: Settings.textXs
                                            }
                                        }

                                        // перемотка: клик и драг по полосе
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: captionStrip.seekable
                                            cursorShape: Qt.PointingHandCursor

                                            function apply(mouse) {
                                                captionStrip.seekHold =
                                                    Math.max(0, Math.min(1,
                                                        mouse.x / width))
                                            }

                                            onPressed: (mouse) => apply(mouse)
                                            onPositionChanged: (mouse) => {
                                                if (pressed)
                                                    apply(mouse)
                                            }
                                            onReleased: {
                                                if (captionStrip.seekHold >= 0
                                                        && playerTile.player)
                                                    playerTile.player.position =
                                                        captionStrip.seekHold
                                                            * playerTile.player.length

                                                seekHoldReset.restart()
                                            }
                                        }

                                        Timer {
                                            id: seekHoldReset
                                            interval: 500
                                            onTriggered: captionStrip.seekHold = -1
                                        }
                                    }
                                    }
                                    
                                    // иконка-заглушка без обложки — в зоне над кнопками
                                    VIcon {
                                        anchors.centerIn: fallbackArea
                                        visible: !playerTile.hasTrack
                                            || playerTile.player.trackArtUrl === ""
                                        width: playerTile.width * 0.26
                                        height: width
                                        fillPath: Glyphs.iconNote
                                        lineColor: Settings.c1
                                    }
                                    
                                    Item {
                                        id: fallbackArea
                                        x: 0
                                        y: 0
                                        width: parent.width
                                        height: controls.y
                                    }
                                    
                                    // кнопки: prev / play-pause / next —
                                    // только иконки, без плошек
                                    Item {
                                        id: controls
                                        z: 3
                                        width: btnPrev.width + btnPlay.width
                                            + btnNext.width + Settings.line * 4
                                        height: Math.max(
                                            btnPrev.height, btnPlay.height,
                                            btnNext.height)
                                        x: (parent.width - width) / 2
                                        y: captionStrip.y - height
                                            - Settings.line * 2

                                        component PlayerButton: Item {
                                            id: playerButton

                                            property string iconFill: ""
                                            property bool btnEnabled: true

                                            signal activated()

        // недоступная кнопка плавно исчезает целиком: в теме только два
        // цвета, полупрозрачных состояний нет
        opacity: btnEnabled ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.animBase
            }
        }

                                            VIcon {
                                                anchors.centerIn: parent
                                                width: parent.width
                                                height: parent.height
                                                fillPath: playerButton.iconFill
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins:
                                                    -Settings.line * 2
                                                cursorShape:
                                                    Qt.PointingHandCursor
                                                enabled:
                                                    playerButton.btnEnabled

                                                onClicked:
                                                    playerButton.activated()
                                            }
                                        }

                                        PlayerButton {
                                            id: btnPrev
                                            x: 0
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: playerTile.width * 0.13
                                            height: playerTile.width * 0.13
                                            iconFill: Glyphs.iconPrev
                                            btnEnabled: playerTile.hasTrack
                                                && playerTile.player.canGoPrevious

                                            onActivated: {
                                                if (playerTile.player)
                                                    playerTile.player.previous()
                                            }
                                        }

                                        PlayerButton {
                                            id: btnPlay
                                            x: btnPrev.width
                                                + Settings.line * 2
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: playerTile.width * 0.16
                                            height: playerTile.width * 0.16
                                            iconFill: playerTile.hasTrack
                                                && playerTile.player.isPlaying
                                                ? Glyphs.iconPause : Glyphs.iconPlay
                                            btnEnabled: playerTile.hasTrack
                                                && playerTile.player.canTogglePlaying

                                            onActivated: {
                                                if (playerTile.player)
                                                    playerTile.player.togglePlaying()
                                            }
                                        }

                                        PlayerButton {
                                            id: btnNext
                                            x: btnPrev.width + btnPlay.width
                                                + Settings.line * 4
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: playerTile.width * 0.13
                                            height: playerTile.width * 0.13
                                            iconFill: Glyphs.iconNext
                                            btnEnabled: playerTile.hasTrack
                                                && playerTile.player.canGoNext

                                            onActivated: {
                                                if (playerTile.player)
                                                    playerTile.player.next()
                                            }
                                        }
                                    }
                                }

                                    // Wi-Fi и Bluetooth 1x1 — первые клетки
                                    // ряда пустышек, открывают свои колёса
                                    STile {
                                        x: leftPart.cellX(0) - Settings.line / 2
                                        y: leftPart.cellY(3) - Settings.line / 2
                                        width: leftPart.cell + Settings.line
                                        height: leftPart.cell + Settings.line
                                        iconFill: Glyphs.iconWifiDot
                                        iconStroke: Glyphs.iconWifi

                                        active: Networking.wifiEnabled

                                        onActivated: Networking.wifiEnabled =
                                            !Networking.wifiEnabled

                                        onSecondaryActivated: {
                                            if (!active)
                                                return

                                            root.hide()
                                            wifiWheel.show()
                                        }
                                    }

                                    STile {
                                        x: leftPart.cellX(1) - Settings.line / 2
                                        y: leftPart.cellY(3) - Settings.line / 2
                                        width: leftPart.cell + Settings.line
                                        height: leftPart.cell + Settings.line
                                        iconStroke: Glyphs.iconBluetooth

                                        active: Bluetooth.defaultAdapter !== null
                                            && Bluetooth.defaultAdapter.enabled

                                        onActivated: {
                                            const adapter = Bluetooth.defaultAdapter

                                            if (!adapter)
                                                return

                                            if (adapter.enabled)
                                                adapter.enabled = false
                                            else
                                                btUnblock.running = true
                                        }

                                        onSecondaryActivated: {
                                            if (!active)
                                                return

                                            root.hide()
                                            btWheel.show()
                                        }
                                    }

                                    // Пустышки 1x1 (стиль плиток обоев), ниже
                                    // плеера — первые две клетки ряда заняты
                                    // Wi-Fi и Bluetooth
                                    Repeater {
                                        model: [
                                            Qt.point(2, 3), Qt.point(3, 3),
                                            Qt.point(4, 3), Qt.point(5, 3),
                                            Qt.point(0, 4), Qt.point(1, 4)
                                        ]

                                        delegate: SPanel {
                                            property int tileCol: modelData.x
                                            property int tileRow: modelData.y

                                            x: leftPart.cellX(tileCol) - Settings.line / 2
                                            y: leftPart.cellY(tileRow) - Settings.line / 2
                                            width: leftPart.cell + Settings.line
                                            height: leftPart.cell + Settings.line

                                            cornerCut: Settings.line * 2
                                            strokeColor: Settings.c1
                                            fillColor: "transparent"
                                        }
                                    }

                                    // Нижняя панель питания: скосы, разбита
                                    // перегородками на 5 секторов
                                    Item {
                                        id: powerRow
                                        x: leftPart.margin - Settings.line / 2
                                        y: leftPart.height - leftPart.margin
                                            - leftPart.cell - Settings.line / 2
                                        width: leftPart.columns * leftPart.cell
                                            + (leftPart.columns - 1) * leftPart.gap
                                            + Settings.line
                                        height: leftPart.cell + Settings.line

                                        readonly property int btnCount: 5
                                        readonly property real btnW: width / btnCount

                                        // коробка секции
                                        SPanel {
                                            anchors.fill: parent
                                            cornerCut: Settings.line * 2
                                            strokeColor: Settings.c1
                                            fillColor: Settings.c2
                                        }

                                        // вертикальные перегородки между секторами
                                        Repeater {
                                            model: powerRow.btnCount - 1

                                            delegate: Shape {
                                                x: (index + 1)
                                                    * powerRow.btnW
                                                    - Settings.line / 2
                                                width: Settings.line
                                                height: parent.height

                                                preferredRendererType: Shape.CurveRenderer

                                                SShapePath {
                                                    joinStyle: ShapePath.MiterJoin
                                                    capStyle: ShapePath.FlatCap
                                                    strokeColor: Settings.c1
                                                    strokeWidth: Settings.line
                                                    startX: Settings.line / 2
                                                    startY: 0
                                                    PathLine {
                                                        x: Settings.line / 2
                                                        y: parent.height
                                                    }
                                                }
                                            }
                                        }

                                        // иконки и клики по секциям
                                        Repeater {
                                            model: [
                                                { fill: "", stroke: Glyphs.iconPowerStroke, cmd: "poweroff" },
                                                { fill: "", stroke: Glyphs.iconRebootStroke, cmd: "reboot" },
                                                { fill: Glyphs.iconMoonFill, stroke: "", cmd: "suspend" },
                                                { fill: "", stroke: Glyphs.iconHibernateStroke, cmd: "hibernate" },
                                                { fill: Glyphs.iconLockFill, stroke: Glyphs.iconLockStroke, cmd: "" }
                                            ]

                                            delegate: Item {
                                                x: index * powerRow.btnW
                                                width: powerRow.btnW
                                                height: parent.height

                                                VIcon {
                                                    anchors.centerIn: parent
                                                    width: parent.height * 0.55
                                                    height: width
                                                    fillPath: modelData.fill
                                                    strokePath: modelData.stroke
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor

                                                    onClicked: root.powerAction(modelData.cmd)
                                                }
                                            }
                                        }
                                    }
                                }

                                    // иконка-заглушка без обложки —
                                    // в зоне над кнопками



                            // Вертикальный разделитель между зонами.
                            // Штрих от левой кромки элемента: элемент
                            // стоит на границе после поля грида, и зазор
                            // от плиток до линии равен зазорам сетки
                            Shape {
                                id: separator
                                width: Settings.line
                                height: parent.height
                                preferredRendererType: Shape.CurveRenderer

                                SShapePath {
                                    joinStyle: ShapePath.MiterJoin
                                    capStyle: ShapePath.FlatCap
                                    strokeColor: Settings.c1
                                    strokeWidth: Settings.line
                                    startX: 0
                                    startY: 0
                                    PathLine { x: Settings.line / 2; y: separator.height }
                                }
                            }

                            // Правая часть: Уведомления (остаток ширины)
                            Item {
                                width: parent.width - leftPart.width
                                    - Settings.line
                                height: parent.height

                                SText {
                                    anchors.centerIn: parent
                                    text: "Notifications"
                                    color: Settings.c1
                                    font.pixelSize: Settings.textLg
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // Чорн обводка окна контента (как в настройках)
            SRectangle {
                id: contentBlackOutline
                anchors.fill: contentArea
                anchors.margins: -Settings.line
                z: -1
                color: Settings.c2
            }

            // Логика обновления даты
            Process {
                id: statsProcess
                command: ["bash", "-c", "date '+%A, %d %B'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        date.text = this.text.trim()
                    }
                }
            }

            Timer {
                interval: 1000; repeat: true; running: true; triggeredOnStart: true
                onTriggered: if (!statsProcess.running) statsProcess.running = true
            }
        }
    }

    // === КОЛЁСА УСТРОЙСТВ ===
    RadialWheel {
        id: wifiWheel

        model: root.wifiItems

        onActivated: (item) => {
            if (item.net.connected)
                item.net.disconnect()
            else
                item.net.connect()
        }
    }

    RadialWheel {
        id: btWheel

        model: root.btItems

        onActivated: (item) => {
            const d = item.dev

            if (d.connected)
                d.disconnect()
            else if (d.paired) {
                d.trusted = true
                d.connect()
            } else
                d.pair()
        }
    }

    RadialWheel {
        id: sinkWheel

        model: root.sinkItems

        onActivated: (item) =>
            Pipewire.preferredDefaultAudioSink = item.node
    }

    RadialWheel {
        id: sourceWheel

        model: root.sourceItems

        onActivated: (item) =>
            Pipewire.preferredDefaultAudioSource = item.node
    }

    // колёса устройств: открыто максимум одно; 825ctl toggle_app
    // тоглит их так же, как клетки панели. Возвращает true, если
    // колесо в итоге открыто (заголовок выше прячет из-за этого панели)
    function toggleWheel(name) {
        const wheels = {
            "wifi": wifiWheel,
            "bluetooth": btWheel,
            "output": sinkWheel,
            "input": sourceWheel
        }

        const target = wheels[name]

        if (!target)
            return false

        for (const key in wheels) {
            if (key !== name && wheels[key].visible)
                wheels[key].hide()
        }

        if (target.visible) {
            target.hide()
            return false
        }

        // клетки отказываются открывать колесо выключенного модуля —
        // CLI вместо молчания отвечает уведомлением
        if (name === "wifi" && !Networking.wifiEnabled) {
            shellNotify("Wi-Fi", "выключен — колесо не открыть")
            return false
        }

        if (name === "bluetooth"
                && (Bluetooth.defaultAdapter === null
                    || !Bluetooth.defaultAdapter.enabled)) {
            shellNotify("Bluetooth", "выключен — колесо не открыть")
            return false
        }

        // как у клеток: панель прячется, колесо открывается
        root.hide()
        target.show()
        return true
    }

    // колёса закрываются при открытии любой панели приложения
    function hideWheels() {
        wifiWheel.hide()
        btWheel.hide()
        sinkWheel.hide()
        sourceWheel.hide()
    }

    // уведомление как обратная связь команд 825ctl
    function shellNotify(summary, body) {
        notifyCmd.summary = summary
        notifyCmd.body = body
        notifyCmd.running = true
    }

    Process {
        id: notifyCmd

        property string summary: ""
        property string body: ""

        command: ["notify-send", "-a", "825", "-t", "3000",
                  "-i", Quickshell.env("HOME") + "/.825UI/Textures/4.jpg",
                  summary, body]
    }

    // сканирование активно, только пока открыто колесо
    Connections {
        target: wifiWheel

        function onVisibleChanged() {
            if (root.wifiDevice)
                root.wifiDevice.scannerEnabled = wifiWheel.visible
        }
    }

    // rfkill софт-блок не даёт включить Bluetooth (PowerState:
    // off-blocked) — снимаем его и только потом включаем адаптер
    Process {
        id: btUnblock
        command: ["rfkill", "unblock", "bluetooth"]

        onExited: {
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.enabled = true
        }
    }

    Connections {
        target: btWheel

        function onVisibleChanged() {
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.discovering = btWheel.visible
        }
    }

    // если при открытии колеса устройство ещё не успело появиться или
    // старт сканирования упал (Not Ready) — выставляем повторно, когда
    // оно найдётся, и ретраим по таймеру
    onWifiDeviceChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = wifiWheel.visible
    }

    Connections {
        target: Bluetooth

        function onDefaultAdapterChanged() {
            if (Bluetooth.defaultAdapter)
                Bluetooth.defaultAdapter.discovering = btWheel.visible
        }
    }

    Timer {
        interval: 1500
        repeat: true
        running: wifiWheel.visible || btWheel.visible

        onTriggered: {
            if (root.wifiDevice && !root.wifiDevice.scannerEnabled)
                root.wifiDevice.scannerEnabled = true

            const adapter = Bluetooth.defaultAdapter

            if (adapter && !adapter.discovering)
                adapter.discovering = true
        }
    }
}
