import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"
import "TimeMath.js" as TimeMath

// Содержимое приложения Часы без окна: четыре таба на каноническом
// таб-баре. Clock — большие инфекс-цифры; Alarm — карточки с
// включением/редактированием, редактор с горизонтальными степперами
// (кнопки SButton с автоповтором при удержании) и подсказкой
// следующего срабатывания; Stopwatch — мм:сс:цц и круги; Timer —
// обратный отсчёт с заливкой-инверсией (SystemStats). Активные
// кнопки — канонический SButton (заливка c1 с тенью c2).
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

    // тик: время, будильники, таймер, секундомер-дисплей
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

    // === операции будильников ===
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

    function nextRunLabel() {
        if (!editing)
            return ""

        const occ = TimeMath.nextOccurrence(now, {
            hours: editing.hours,
            minutes: editing.minutes,
            days: editing.days,
            enabled: true,
            snoozeUntil: null
        })

        if (!occ)
            return ""

        return "Next: " + TimeMath.daysLabel(editing.days)
            + ", " + TimeMath.pad2(occ.getHours()) + ":"
            + TimeMath.pad2(occ.getMinutes())
    }

    // === каркас: Esc, табы, контент ===
    Item {
        id: keysItem

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: (event) => {
            if (root.editing) {
                root.editing = null
            } else {
                root.closeRequested()
            }

            event.accepted = true
        }
    }

    Column {
        anchors.fill: parent
        spacing: Settings.line * 2

        // --- табы (заголовок панели — они же навигация) ---
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
            height: parent.height - tabBar.height
                - Settings.line * 2
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
                        font.pixelSize: Settings.textSm
                    }
                }
            }

            // === таб 1: будильники ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 1

                // --- список ---
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

                        ScrollBar.vertical: ScrollBar {
                            policy: alarmColumn.height > height
                                ? ScrollBar.AsNeeded
                                : ScrollBar.AlwaysOff
                        }

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
                                    height: Settings.line * 11
                                    cornerCut: Settings.line * 2
                                    strokeColor: Settings.c1
                                    fillColor: Settings.c2

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin:
                                            Settings.line * 4
                                        anchors.rightMargin:
                                            Settings.line * 3
                                        spacing: Settings.line * 3

                                        SText {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: Settings.line * 12
                                            text: TimeMath
                                                .formatAlarmTime(
                                                    alarmCard
                                                    .modelData)
                                            color: Settings.c1
                                            font.pixelSize:
                                                Settings.textLg
                                            font.bold: true
                                        }

                                        Column {
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: parent.width
                                                - Settings.line * 12
                                                - Settings.line * 17
                                            spacing: Settings.line

                                            SText {
                                                width: parent.width
                                                text: alarmCard
                                                    .modelData.label
                                                    || "Alarm"
                                                color: Settings.c1
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
                                                elide: Text.ElideRight
                                                font.pixelSize:
                                                    Settings.textXs
                                            }
                                        }

                                        Item {
                                            width: Settings.line * 14
                                            anchors.top: parent.top
                                            anchors.bottom:
                                                parent.bottom

                                            STile {
                                                anchors.left: parent.left
                                                anchors.leftMargin:
                                                    Settings.line
                                                anchors.verticalCenter:
                                                    parent.verticalCenter
                                                width:
                                                    Settings.line * 6.5
                                                height: width
                                                iconStroke:
                                                    Glyphs.iconCheck
                                                active: alarmCard
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
                                            }

                                            MouseArea {
                                                anchors.right: parent
                                                    .right
                                                anchors.rightMargin:
                                                    Settings.line / 2
                                                anchors.verticalCenter:
                                                    parent
                                                    .verticalCenter
                                                width: Settings.line * 6
                                                height: Settings.line * 6
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
                                font.pixelSize: Settings.textSm
                            }
                        }
                    }

                    // добавить
                    SButton {
                        id: addButton

                        width: parent.width
                        height: Settings.line * 8
                        icon: Glyphs.iconPlus
                        label: "Add alarm"

                        onActivated: root.editing = {
                            hours: 7, minutes: 0, days: [],
                            label: "", enabled: true
                        }
                    }
                }

                // --- редактор будильника ---
                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 4
                    spacing: Settings.line * 3
                    visible: root.editing !== null

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 3

                        Stepper {
                            value: root.editing
                                ? root.editing.hours : 0
                            maxValue: 23
                            stepBy: 1

                            onCommitted: (v) => {
                                if (root.editing)
                                    root.editing.hours = v
                            }
                        }

                        SText {
                            anchors.verticalCenter:
                                parent.verticalCenter
                            text: ":"
                            color: Settings.c1
                            font.pixelSize: Settings.textLg
                            font.bold: true
                        }

                        Stepper {
                            value: root.editing
                                ? root.editing.minutes : 0
                            maxValue: 59
                            stepBy: 5

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
                            text: root.editing
                                ? root.editing.label : ""
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

                                readonly property bool on:
                                    root.editing
                                    && root.editing.days.indexOf(
                                        dayChip.modelData.day) !== -1

                                width: Settings.line * 8
                                height: width
                                cornerCut: Settings.line * 2
                                strokeColor: Settings.c1
                                fillColor: dayChip.on
                                    ? Settings.c1 : "transparent"
                                shadow: dayChip.on ? "inside" : "none"
                                shadowColor: Settings.c2

                                SText {
                                    anchors.centerIn: parent
                                    text: dayChip.modelData.label
                                    color: dayChip.on
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

                    // следующее срабатывание
                    SText {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        text: root.nextRunLabel()
                        color: Settings.c1
                        font.pixelSize: Settings.textXs
                    }

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 3

                        SButton {
                            width: Settings.line * 18
                            height: Settings.line * 9
                            label: "Save"
                            active: true

                            onActivated: root.saveEditing()
                        }

                        SButton {
                            width: Settings.line * 18
                            height: Settings.line * 9
                            label: "Cancel"

                            onActivated: root.editing = null
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
                    anchors.margins: Settings.line * 4
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
                                pixelSize: 56
                                referencePixelSize: 56
                                line: Settings.line
                                color: Settings.c1
                                mirrorX: true
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 3

                        SButton {
                            width: Settings.line * 20
                            height: Settings.line * 9
                            icon: root.swRunning
                                ? Glyphs.iconPause : Glyphs.iconPlay
                            label: root.swRunning
                                ? "Pause" : "Start"
                            active: root.swRunning

                            onActivated: {
                                if (root.swRunning) {
                                    root.swAccum = root.swMs
                                    root.swRunning = false
                                } else {
                                    root.swBase = new Date()
                                    root.swRunning = true
                                }
                            }
                        }

                        SButton {
                            width: Settings.line * 14
                            height: Settings.line * 9
                            label: "Lap"
                            visible: root.swRunning
                                || root.swLaps.length > 0

                            onActivated: {
                                const prev = root.swLaps.length
                                    ? root.swLaps[0].total : 0

                                root.swLaps = [{
                                    lap: root.swMs - prev,
                                    total: root.swMs
                                }].concat(root.swLaps)
                            }
                        }

                        SButton {
                            width: Settings.line * 14
                            height: Settings.line * 9
                            label: "Reset"
                            visible: root.swRunning
                                || root.swLaps.length > 0
                                || root.swAccum > 0

                            onActivated: {
                                root.swRunning = false
                                root.swAccum = 0
                                root.swLaps = []
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

                        ScrollBar.vertical: ScrollBar {
                            policy: lapColumn.height > height
                                ? ScrollBar.AsNeeded
                                : ScrollBar.AlwaysOff
                        }

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
                                                - Settings.line * 20
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
                                            width: Settings.line * 16
                                            anchors.right: parent.right
                                            text: TimeMath
                                                .formatHMSCC(
                                                    lapCard
                                                    .modelData
                                                    .total)
                                            color: Settings.c1
                                            font.pixelSize:
                                                Settings.textXs
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
                    anchors.centerIn: parent
                    spacing: Settings.line * 3

                    // дисплей с заливкой-инверсией (SystemStats)
                    Item {
                        id: timerDisplay

                        width: contentArea.width
                            - Settings.line * 8
                        height: Settings.line * 26
                        anchors.horizontalCenter:
                            parent.horizontalCenter

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
                                    pixelSize: Settings.line * 14
                                    referencePixelSize:
                                        Settings.line * 14
                                    line: Settings.line
                                    color: Settings.c1
                                    mirrorX: true
                                }
                            }
                        }

                        // слой заливки: c1 снизу вверх
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: parent.height
                                - timerDisplay.level
                            color: Settings.c1
                        }

                        // копии цифр c2: видны только под заливкой,
                        // выровнены по базовому ряду (level — верх
                        // заливки, ряд начинается на digitsRow.y)
                        Item {
                            x: digitsRow.x
                            y: timerDisplay.level
                            width: digitsRow.width
                            height: timerDisplay.height
                                - timerDisplay.level
                            clip: true

                            Row {
                                x: 0
                                y: digitsRow.y - timerDisplay.level
                                spacing: Settings.line

                                Repeater {
                                    model: 5

                                    delegate: Infex {
                                        property string tStr:
                                            TimeMath.formatMS(
                                                root.timerLeftMs)

                                        ch: tStr.length > index
                                            ? tStr[index] : "0"
                                        pixelSize: Settings.line * 14
                                        referencePixelSize:
                                            Settings.line * 14
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

                            delegate: SButton {
                                id: presetBtn

                                required property int modelData

                                width: Settings.line * 10
                                height: Settings.line * 8
                                label: presetBtn.modelData + "m"
                                textSize: Settings.textXs

                                onActivated: {
                                    root.timerRunning = false
                                    root.startTimer(
                                        presetBtn.modelData * 60000)
                                }
                            }
                        }
                    }

                    // произвольные минуты
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 2

                        SButton {
                            width: Settings.line * 8
                            height: Settings.line * 8
                            label: "−"
                            holdRepeat: true

                            onActivated: {
                                root.timerRunning = false
                                root.startTimer(Math.max(
                                    60000,
                                    root.timerTotalMs - 60000))
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

                        SButton {
                            width: Settings.line * 8
                            height: Settings.line * 8
                            label: "+"
                            holdRepeat: true

                            onActivated: {
                                root.timerRunning = false
                                root.startTimer(Math.min(
                                    999 * 60000,
                                    root.timerTotalMs + 60000))
                            }
                        }
                    }

                    // пуск/пауза/сброс
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 3

                        SButton {
                            width: Settings.line * 20
                            height: Settings.line * 9
                            label: root.timerRunning
                                ? "Pause" : "Start"
                            active: root.timerRunning

                            onActivated: {
                                if (root.timerLeftMs <= 0)
                                    root.startTimer(root.timerTotalMs)
                                else
                                    root.timerRunning =
                                        !root.timerRunning
                            }
                        }

                        SButton {
                            width: Settings.line * 14
                            height: Settings.line * 9
                            label: "Reset"

                            onActivated: {
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

    // === горизонтальный степпер: [−] значение [+] ===
    component Stepper: Row {
        id: step

        property int value: 0
        property int maxValue: 59
        property int stepBy: 1

        signal committed(int newValue)

        function bump(delta) {
            const span = maxValue + 1

            let v = (value + delta) % span

            if (v < 0)
                v += span

            value = v
            committed(v)
        }

        SButton {
            width: Settings.line * 10
            height: Settings.line * 10
            label: "−"
            textSize: Settings.textMd
            holdRepeat: true

            onActivated: step.bump(-step.stepBy)
        }

        SText {
            anchors.verticalCenter: parent.verticalCenter
            width: Settings.line * 12
            text: TimeMath.pad2(step.value)
            color: Settings.c1
            font.pixelSize: Settings.textLg
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        SButton {
            width: Settings.line * 10
            height: Settings.line * 10
            label: "+"
            textSize: Settings.textMd
            holdRepeat: true

            onActivated: step.bump(step.stepBy)
        }
    }
}
