import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"
import "TimeMath.js" as TimeMath

// Содержимое приложения Часы без окна: четыре таба на каноническом
// таб-баре — Clock (большие инфекс-цифры), Alarm (карточки с
// редактором, персист alarms.json), Stopwatch (мм:сс:цц, круги),
// Timer (обратный отсчёт с заливкой-инверсией как в SystemStats).
// Срабатывания уходят в баннер (property banner — AlarmBanner).
Item {
    id: root

    implicitWidth: 720
    implicitHeight: 560

    signal closeRequested()

    // путь к alarms.json; пусто — состояние только на сессию
    property string stateFile: ""

    // AlarmBanner из shell; пусто — тихий режим (тесты)
    property var banner: null

    property var alarms: []
    property int currentTab: 0
    readonly property var tabNames:
        ["Clock", "Alarm", "Stopwatch", "Timer"]

    property date now: new Date()

    // === секундомер ===
    property bool swRunning: false
    property real swAccum: 0
    property date swBase: new Date()
    property var swLaps: []

    readonly property real swMs:
        swAccum + (swRunning ? now - swBase : 0)

    // === таймер ===
    property bool timerRunning: false
    property real timerTotalMs: 5 * 60000
    property real timerLeftMs: 5 * 60000
    property bool timerDoneShown: false

    // === редактор будильника ===
    // null — список; иначе {id?, hours, minutes, days, label, enabled}
    property var editing: null

    // недавний ключ баннера против повторов
    property bool bannerConnected: false

    Component.onCompleted: connectBanner()

    onBannerChanged: connectBanner()

    function connectBanner() {
        if (!banner || bannerConnected)
            return

        bannerConnected = true
        banner.snoozed.connect(root.onSnoozed)
    }

    function onSnoozed(payload) {
        alarms = alarms.map(a => a.id === payload.id
            ? Object.assign({}, a, {
                snoozeUntil: TimeMath.snoozeFrom(new Date(), 5)
                    .toISOString()
            }) : a)
        saveAlarms()
    }

    // тик секунды: время, будильники, таймер, секундомер-дисплей
    Timer {
        interval: 250
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            root.now = new Date()
            root.checkAlarms()
            root.checkTimer()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: root.now = new Date()
    }

    // === будильники: хранение ===
    FileView {
        id: alarmStore

        path: root.stateFile
        printErrors: false

        onLoaded: root.loadAlarms(this.text())
        onLoadFailed: (error) => {
            // первого запуска файл ещё нет — это норма
        }
    }

    function loadAlarms(text) {
        if (text === "")
            return

        try {
            const data = JSON.parse(text)

            if (data && data.alarms instanceof Array)
                alarms = data.alarms
        } catch (e) {
            // битый файл — начинаем с пустого списка
        }
    }

    function saveAlarms() {
        if (stateFile === "")
            return

        alarmStore.setText(JSON.stringify({ alarms: alarms }))
    }

    function checkAlarms() {
        for (var i = 0; i < alarms.length; i++) {
            const a = alarms[i]
            const occ = TimeMath.nextOccurrence(now, a)

            if (!occ)
                continue

            const key = TimeMath.occurrenceKey(occ)

            if (a.lastFired === key)
                continue

            if (occ <= now && now - occ < 2000) {
                const updated = Object.assign({}, a, {
                    lastFired: key,
                    snoozeUntil: null
                })

                alarms = alarms.map((x, j) =>
                    j === i ? updated : x)
                saveAlarms()

                if (banner)
                    banner.push({
                        kind: "alarm",
                        title: TimeMath.formatAlarmTime(a)
                            + (a.label ? " — " + a.label : ""),
                        subtitle: TimeMath.daysLabel(a.days),
                        payload: updated
                    })

                return
            }
        }
    }

    // === таймер ===
    function startTimer(ms) {
        timerTotalMs = ms
        timerLeftMs = ms
        timerRunning = true
        timerDoneShown = false
    }

    function checkTimer() {
        if (!timerRunning)
            return

        timerLeftMs = Math.max(0, timerLeftMs - 250)

        if (timerLeftMs <= 0 && !timerDoneShown) {
            timerDoneShown = true
            timerRunning = false

            if (banner)
                banner.push({
                    kind: "timer",
                    title: TimeMath.formatMS(timerTotalMs),
                    subtitle: "Time is up",
                    payload: {}
                })
        }
    }

    // === переключение будильника ===
    function toggleAlarm(id) {
        alarms = alarms.map(a => a.id === id
            ? Object.assign({}, a, { enabled: !a.enabled,
                snoozeUntil: null }) : a)
        saveAlarms()
    }

    function deleteAlarm(id) {
        alarms = alarms.filter(a => a.id !== id)
        saveAlarms()
    }

    function saveEditing() {
        if (!editing)
            return

        if (editing.id) {
            alarms = alarms.map(a => a.id === editing.id
                ? Object.assign({}, a, {
                    hours: editing.hours,
                    minutes: editing.minutes,
                    days: editing.days,
                    label: editing.label,
                    enabled: true,
                    snoozeUntil: null
                }) : a)
        } else {
            alarms = [Object.assign({}, editing, {
                id: Date.now() + "" + Math.floor(Math.random() * 1000),
                enabled: true,
                lastFired: null,
                snoozeUntil: null
            })].concat(alarms)
        }

        editing = null
        saveAlarms()
    }

    // === каркас: хедер + табы + контент ===
    Column {
        anchors.fill: parent
        spacing: Settings.line * 2

        // --- хедер-бар ---
        Item {
            id: headerBar

            width: parent.width
                - InfexGeometry.tipMult * Settings.line / 2
            height: Settings.barHeight
            anchors.horizontalCenter: parent.horizontalCenter

            SFrame {
                anchors.fill: parent
            }

            SText {
                anchors.centerIn: parent
                text: "Clock"
                color: Settings.c1
                font.pixelSize: Settings.textSm
                font.bold: true
            }
        }

        // --- табы ---
        TabBar {
            id: tabBar

            width: parent.width
            names: root.tabNames
            current: root.currentTab
            onActivated: (index) => {
                root.currentTab = index
                root.editing = null
            }
        }

        // --- контентная область ---
        SPanel {
            id: contentArea

            width: parent.width
            height: parent.height - headerBar.height
                - tabBar.height - Settings.line * 2 * 2
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: Settings.c2
            shadow: "outside"
            shadowColor: Settings.c2

            // === таб 0: часы ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 0

                Column {
                    anchors.centerIn: parent
                    spacing: Settings.line * 3

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line

                        Repeater {
                            model: 5

                            delegate: Infex {
                                property string timeStr:
                                    TimeMath.pad2(root.now.getHours())
                                    + ":" + TimeMath.pad2(
                                        root.now.getMinutes())

                                ch: timeStr.length > index
                                    ? timeStr[index] : "0"
                                pixelSize: 130
                                referencePixelSize: 130
                                line: Settings.line
                                color: Settings.c1
                                mirrorX: true
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line

                        Repeater {
                            model: 3

                            delegate: Infex {
                                property string secStr:
                                    ":" + TimeMath.pad2(
                                        root.now.getSeconds())

                                ch: secStr.length > index
                                    ? secStr[index] : "0"
                                pixelSize: 52
                                referencePixelSize: 52
                                line: Settings.line
                                color: Settings.c1
                                opacity: 0.75
                                mirrorX: true
                            }
                        }
                    }

                    SText {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        text: Qt.formatDate(root.now,
                            "dddd, d MMMM yyyy")
                        color: Settings.c1
                        opacity: 0.75
                        font.pixelSize: Settings.textSm
                    }
                }
            }

            // === таб 1: будильники ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 1

                // список
                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 3
                    spacing: Settings.line * 2
                    visible: root.editing === null

                    Flickable {
                        width: parent.width
                        height: parent.height - addButton.height
                            - parent.spacing
                        clip: true
                        contentWidth: width
                        contentHeight: alarmColumn.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: alarmColumn

                            width: parent.width
                            spacing: Settings.line * 2

                            Repeater {
                                model: root.alarms

                                delegate: SPanel {
                                    id: alarmCard

                                    required property var modelData

                                    width: alarmColumn.width
                                    height: Settings.line * 10
                                    cornerCut: Settings.line * 2
                                    strokeColor: Settings.c1
                                    fillColor: Settings.c2

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin:
                                            Settings.line * 4
                                        anchors.rightMargin:
                                            Settings.line * 3
                                        spacing: Settings.line * 4

                                        SText {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: Settings.line * 13
                                            text: TimeMath
                                                .formatAlarmTime(
                                                    alarmCard
                                                    .modelData)
                                            color: alarmCard
                                                .modelData.enabled
                                                ? Settings.c1
                                                : Settings.c1
                                            opacity: alarmCard
                                                .modelData.enabled
                                                ? 1 : 0.4
                                            font.pixelSize:
                                                Settings.textLg
                                            font.bold: true
                                        }

                                        Column {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: parent.width
                                                - Settings.line * 13
                                                - Settings.line * 16
                                            spacing: Settings.line

                                            SText {
                                                width: parent.width
                                                text: alarmCard
                                                    .modelData.label
                                                    || "Alarm"
                                                color: Settings.c1
                                                opacity: alarmCard
                                                    .modelData.enabled
                                                    ? 0.85 : 0.4
                                                elide: Text.ElideRight
                                                font.pixelSize:
                                                    Settings.textSm
                                                font.bold: true
                                            }

                                            SText {
                                                width: parent.width
                                                text: TimeMath
                                                    .daysLabel(
                                                        alarmCard
                                                        .modelData
                                                        .days)
                                                color: Settings.c1
                                                opacity: alarmCard
                                                    .modelData.enabled
                                                    ? 0.5 : 0.3
                                                elide: Text.ElideRight
                                                font.pixelSize:
                                                    Settings.textXs
                                            }
                                        }

                                        Item {
                                            width: Settings.line * 8
                                            anchors.top: parent.top
                                            anchors.bottom:
                                                parent.bottom

                                            STile {
                                                anchors.centerIn: parent
                                                width:
                                                    Settings.line * 7
                                                height: width
                                                iconStroke:
                                                    Glyphs.iconCheck
                                                active:
                                                    alarmCard
                                                    .modelData.enabled

                                                onActivated:
                                                    root.toggleAlarm(
                                                        alarmCard
                                                        .modelData
                                                        .id)
                                            }

                                            // ✕ — удаление
                                            VIcon {
                                                anchors.right: parent
                                                    .right
                                                anchors.rightMargin:
                                                    Settings.line
                                                anchors.verticalCenter:
                                                    parent
                                                    .verticalCenter
                                                width:
                                                    Settings.textSm
                                                height: width
                                                strokePath:
                                                    "M 7,7 L 17,17"
                                                    + " M 17,7 L 7,17"
                                                lineColor:
                                                    Settings.c1
                                                opacity:
                                                    closeMouse
                                                    .containsMouse
                                                    ? 1 : 0.6
                                            }

                                            MouseArea {
                                                id: closeMouse

                                                anchors.centerIn: parent
                                                width: parent.height
                                                height: parent.height
                                                hoverEnabled: true
                                                cursorShape:
                                                    Qt
                                                    .PointingHandCursor

                                                onClicked:
                                                    root.deleteAlarm(
                                                        alarmCard
                                                        .modelData
                                                        .id)
                                            }
                                        }
                                    }

                                    // клик по карточке — редактор
                                    MouseArea {
                                        anchors.fill: parent
                                        z: -1
                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked: root.editing =
                                            Object.assign({},
                                                alarmCard.modelData)
                                    }
                                }
                            }

                            SText {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter
                                visible: root.alarms.length === 0
                                text: "No alarms yet"
                                color: Settings.c1
                                opacity: 0.45
                                font.pixelSize: Settings.textSm
                            }
                        }
                    }

                    // добавить
                    SPanel {
                        id: addButton

                        width: parent.width
                        height: Settings.line * 8
                        cornerCut: Settings.line * 2
                        strokeColor: Settings.c1
                        fillColor: addMouse.pressed
                            ? Settings.c1 : "transparent"

                        Row {
                            anchors.centerIn: parent
                            spacing: Settings.line * 2

                            VIcon {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                width: Settings.textSm
                                height: width
                                strokePath: Glyphs.iconPlus
                                lineColor: addMouse.pressed
                                    ? Settings.c2 : Settings.c1
                            }

                            SText {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                text: "Add alarm"
                                color: addMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: addMouse

                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.editing = {
                                hours: 7, minutes: 0, days: [],
                                label: "", enabled: true
                            }
                        }
                    }
                }

                // редактор будильника
                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 3
                    spacing: Settings.line * 3
                    visible: root.editing !== null

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 6

                        // часы
                        Stepper {
                            value: root.editing ? root.editing.hours : 0
                            maxValue: 23

                            onCommitted: (v) => {
                                if (root.editing)
                                    root.editing.hours = v
                            }
                        }

                        SText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ":"
                            color: Settings.c1
                            font.pixelSize: Settings.textLg
                            font.bold: true
                        }

                        // минуты
                        Stepper {
                            value: root.editing
                                ? root.editing.minutes : 0
                            maxValue: 59

                            onCommitted: (v) => {
                                if (root.editing)
                                    root.editing.minutes = v
                            }
                        }
                    }

                    // подпись
                    SPanel {
                        width: parent.width
                        height: Settings.line * 7
                        cornerCut: Settings.line * 2
                        strokeColor: Settings.c1
                        fillColor: Settings.c2

                        TextInput {
                            id: labelInput

                            anchors.fill: parent
                            anchors.leftMargin: Settings.line * 3
                            anchors.rightMargin: Settings.line * 3
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.editing ? root.editing.label : ""
                            onTextChanged: if (root.editing)
                                root.editing.label = text
                            color: Settings.c1
                            font.pixelSize: Settings.textSm
                            cursorVisible: false
                            cursorDelegate: Item {}
                            selectionColor: Settings.c1
                            selectedTextColor: Settings.c2
                            clip: true

                            SText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: labelInput.text === ""
                                text: "Label"
                                color: Settings.c1
                                opacity: 0.45
                                font.pixelSize: Settings.textSm
                            }
                        }
                    }

                    // дни недели
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 2

                        Repeater {
                            model: [
                                { day: 1, label: "M" },
                                { day: 2, label: "T" },
                                { day: 3, label: "W" },
                                { day: 4, label: "T" },
                                { day: 5, label: "F" },
                                { day: 6, label: "S" },
                                { day: 0, label: "S" }
                            ]

                            delegate: SPanel {
                                id: dayChip

                                required property var modelData

                                width: Settings.line * 8
                                height: width
                                cornerCut: Settings.line * 2
                                strokeColor: Settings.c1
                                fillColor: root.editing
                                    && root.editing.days.indexOf(
                                        dayChip.modelData.day) !== -1
                                    ? Settings.c1 : "transparent"

                                SText {
                                    anchors.centerIn: parent
                                    text: dayChip.modelData.label
                                    color: root.editing
                                        && root.editing.days.indexOf(
                                            dayChip.modelData.day) !== -1
                                        ? Settings.c2 : Settings.c1
                                    font.pixelSize: Settings.textSm
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        if (!root.editing)
                                            return

                                        const d = dayChip
                                            .modelData.day
                                        const days = root
                                            .editing.days.slice()
                                        const idx = days.indexOf(d)

                                        if (idx === -1)
                                            days.push(d)
                                        else
                                            days.splice(idx, 1)

                                        root.editing.days = days
                                    }
                                }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 4

                        SPanel {
                            width: Settings.line * 16
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: saveMouse.pressed
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: "Save"
                                color: saveMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: saveMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: root.saveEditing()
                            }
                        }

                        SPanel {
                            width: Settings.line * 16
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: cancelMouse.pressed
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: "Cancel"
                                color: cancelMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: cancelMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: root.editing = null
                            }
                        }
                    }
                }
            }

            // === таб 2: секундомер ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 2

                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 3
                    spacing: Settings.line * 3

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line

                        Repeater {
                            model: 8

                            delegate: Infex {
                                property string swStr:
                                    TimeMath.formatHMSCC(root.swMs)

                                ch: swStr.length > index
                                    ? swStr[index] : "0"
                                pixelSize: 62
                                referencePixelSize: 62
                                line: Settings.line
                                color: Settings.c1
                                mirrorX: true
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 4

                        SPanel {
                            width: Settings.line * 18
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: root.swRunning
                                ? Settings.c1 : "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: Settings.line * 2

                                VIcon {
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    width: Settings.textSm
                                    height: width
                                    strokePath: root.swRunning
                                        ? Glyphs.iconPause
                                        : Glyphs.iconPlay
                                    lineColor: root.swRunning
                                        ? Settings.c2 : Settings.c1
                                }

                                SText {
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    text: root.swRunning
                                        ? "Pause" : "Start"
                                    color: root.swRunning
                                        ? Settings.c2 : Settings.c1
                                    font.pixelSize: Settings.textSm
                                    font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    if (root.swRunning) {
                                        root.swAccum = root.swMs
                                        root.swRunning = false
                                    } else {
                                        root.swBase = new Date()
                                        root.swRunning = true
                                    }
                                }
                            }
                        }

                        SPanel {
                            width: Settings.line * 14
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: lapMouse.pressed
                                ? Settings.c1 : "transparent"
                            opacity: root.swRunning ? 1 : 0.4

                            SText {
                                anchors.centerIn: parent
                                text: "Lap"
                                color: lapMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: lapMouse

                                anchors.fill: parent
                                enabled: root.swRunning
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    const prev = root.swLaps.length
                                        ? root.swLaps[0].total : 0

                                    root.swLaps = [{
                                        lap: root.swMs - prev,
                                        total: root.swMs
                                    }].concat(root.swLaps)
                                }
                            }
                        }

                        SPanel {
                            width: Settings.line * 16
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: resetMouse.pressed
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: "Reset"
                                color: resetMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: resetMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.swRunning = false
                                    root.swAccum = 0
                                    root.swLaps = []
                                }
                            }
                        }
                    }

                    Flickable {
                        width: parent.width
                        height: parent.height - Settings.line * 9
                            - Settings.line * 6 * 2
                        clip: true
                        contentWidth: width
                        contentHeight: lapColumn.height
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: lapColumn

                            width: parent.width
                            spacing: Settings.line

                            Repeater {
                                model: root.swLaps

                                delegate: SPanel {
                                    id: lapCard

                                    required property var modelData
                                    required property int index

                                    width: lapColumn.width
                                    height: Settings.line * 7
                                    cornerCut: Settings.line * 2
                                    strokeColor: Settings.c1
                                    fillColor: Settings.c2

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin:
                                            Settings.line * 4
                                        anchors.rightMargin:
                                            Settings.line * 4

                                        SText {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: Settings.line * 8
                                            text: "#"
                                                + (lapCard.index + 1)
                                            color: Settings.c1
                                            font.pixelSize:
                                                Settings.textSm
                                            font.bold: true
                                        }

                                        SText {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: parent.width
                                                - Settings.line * 8
                                                - Settings.line * 24
                                            text: TimeMath
                                                .formatHMSCC(
                                                    lapCard
                                                    .modelData.lap)
                                            color: Settings.c1
                                            font.pixelSize:
                                                Settings.textSm
                                            horizontalAlignment:
                                                Text.AlignRight
                                        }

                                        SText {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: Settings.line * 20
                                            anchors.right: parent.right
                                            text: TimeMath
                                                .formatHMSCC(
                                                    lapCard
                                                    .modelData
                                                    .total)
                                            color: Settings.c1
                                            opacity: 0.55
                                            font.pixelSize:
                                                Settings.textSm
                                            horizontalAlignment:
                                                Text.AlignRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // === таб 3: таймер ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 3

                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 3
                    spacing: Settings.line * 3

                    // дисплей с заливкой-инверсией (SystemStats)
                    Item {
                        id: timerDisplay

                        width: parent.width
                        height: Settings.line * 20

                        readonly property real frac:
                            root.timerTotalMs > 0
                                ? root.timerLeftMs
                                    / root.timerTotalMs : 0

                        // y верхней кромки заливки, анимируется
                        property real level:
                            height * (1 - frac)

                        Behavior on level {
                            NumberAnimation {
                                duration: Settings.animBase
                                easing.type: Easing.OutQuad
                            }
                        }

                        Row {
                            id: digitsRow

                            anchors.centerIn: parent
                            spacing: Settings.line

                            Repeater {
                                model: 5

                                delegate: Infex {
                                    property string tStr:
                                        TimeMath.formatMS(
                                            root.timerLeftMs)

                                    ch: tStr.length > index
                                        ? tStr[index] : "0"
                                    pixelSize: Settings.line * 16
                                    referencePixelSize:
                                        Settings.line * 16
                                    line: Settings.line
                                    color: Settings.c1
                                    mirrorX: true
                                }
                            }
                        }

                        // слой заливки: c1 снизу вверх
                        Item {
                            anchors.fill: parent

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height
                                    - timerDisplay.level
                                color: Settings.c1
                            }
                        }

                        // копии цифр c2: видны только над заливкой
                        Item {
                            x: digitsRow.x
                            y: timerDisplay.level
                            width: digitsRow.width
                            height: timerDisplay.height
                                - timerDisplay.level
                            clip: true

                            Row {
                                x: 0
                                y: -timerDisplay.level
                                spacing: Settings.line

                                Repeater {
                                    model: 5

                                    delegate: Infex {
                                        property string tStr:
                                            TimeMath.formatMS(
                                                root.timerLeftMs)

                                        ch: tStr.length > index
                                            ? tStr[index] : "0"
                                        pixelSize: Settings.line * 16
                                        referencePixelSize:
                                            Settings.line * 16
                                        line: Settings.line
                                        color: Settings.c2
                                        mirrorX: true
                                    }
                                }
                            }
                        }
                    }

                    // пресеты
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 2

                        Repeater {
                            model: [1, 3, 5, 10, 15, 30]

                            delegate: SPanel {
                                id: presetBtn

                                required property int modelData

                                width: Settings.line * 10
                                height: Settings.line * 8
                                cornerCut: Settings.line * 2
                                strokeColor: Settings.c1
                                fillColor: presetMouse.pressed
                                    ? Settings.c1 : "transparent"

                                SText {
                                    anchors.centerIn: parent
                                    text: presetBtn.modelData
                                    color: presetMouse.pressed
                                        ? Settings.c2 : Settings.c1
                                    font.pixelSize: Settings.textSm
                                    font.bold: true
                                }

                                MouseArea {
                                    id: presetMouse

                                    anchors.fill: parent
                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: {
                                        root.timerRunning = false
                                        root.startTimer(
                                            presetBtn.modelData
                                            * 60000)
                                    }
                                }
                            }
                        }
                    }

                    // произвольные минуты
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 3

                        SPanel {
                            width: Settings.line * 8
                            height: Settings.line * 8
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: minusMouse.pressed
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: "−"
                                color: minusMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: minusMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.timerRunning = false
                                    root.startTimer(Math.max(
                                        60000,
                                        root.timerTotalMs - 60000))
                                }
                            }
                        }

                        SText {
                            anchors.verticalCenter:
                                parent.verticalCenter
                            width: Settings.line * 10
                            text: Math.round(
                                root.timerTotalMs / 60000) + "m"
                            color: Settings.c1
                            font.pixelSize: Settings.textMd
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }

                        SPanel {
                            width: Settings.line * 8
                            height: Settings.line * 8
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: plusMouse.pressed
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: "+"
                                color: plusMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: plusMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.timerRunning = false
                                    root.startTimer(Math.min(
                                        999 * 60000,
                                        root.timerTotalMs + 60000))
                                }
                            }
                        }
                    }

                    // пуск/пауза/сброс
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 4

                        SPanel {
                            width: Settings.line * 18
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: root.timerRunning
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: root.timerRunning
                                    ? "Pause" : "Start"
                                color: root.timerRunning
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: root.timerRunning =
                                    !root.timerRunning
                            }
                        }

                        SPanel {
                            width: Settings.line * 16
                            height: Settings.line * 9
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: tResetMouse.pressed
                                ? Settings.c1 : "transparent"

                            SText {
                                anchors.centerIn: parent
                                text: "Reset"
                                color: tResetMouse.pressed
                                    ? Settings.c2 : Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }

                            MouseArea {
                                id: tResetMouse

                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    root.timerRunning = false
                                    root.timerDoneShown = false
                                    root.timerLeftMs =
                                        root.timerTotalMs
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // === степпер: значение со стрелками (редактор будильника) ===
    component Stepper: Column {
        id: step

        property int value: 0
        property int maxValue: 59

        signal committed(int newValue)

        SPanel {
            width: Settings.line * 12
            height: Settings.line * 7
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: upMouse.pressed ? Settings.c1 : "transparent"

            VIcon {
                anchors.centerIn: parent
                width: Settings.textSm
                height: width
                strokePath: Glyphs.iconChevronUp
                lineColor: upMouse.pressed
                    ? Settings.c2 : Settings.c1
            }

            MouseArea {
                id: upMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    const v = (step.value + 1) % (step.maxValue + 1)

                    step.value = v
                    step.committed(v)
                }
            }
        }

        SText {
            width: parent.width
            height: Settings.line * 8
            text: TimeMath.pad2(step.value)
            color: Settings.c1
            font.pixelSize: Settings.textLg
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        SPanel {
            width: Settings.line * 12
            height: Settings.line * 7
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: downMouse.pressed
                ? Settings.c1 : "transparent"

            VIcon {
                anchors.centerIn: parent
                width: Settings.textSm
                height: width
                strokePath: Glyphs.iconChevronDown
                lineColor: downMouse.pressed
                    ? Settings.c2 : Settings.c1
            }

            MouseArea {
                id: downMouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    const v = (step.value - 1 + step.maxValue + 1)
                        % (step.maxValue + 1)

                    step.value = v
                    step.committed(v)
                }
            }
        }
    }
}
