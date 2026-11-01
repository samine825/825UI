import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"

// Диктофон без окна. Запись микрофона (QtMultimedia CaptureSession,
// Ogg/Opus — кодеки из gst-plugins-base/good) в recordingsDir, пульс
// вокруг кнопки записи, длительность на инфекс-цифрах. Список
// записей — скан каталога (find -printf, паттерн SettingsMenu),
// воспроизведение одним MediaPlayer, позиция — инверсией в строке.
// Удаление — файл и запись.
Item {
    id: root

    implicitWidth: 560
    implicitHeight: 520

    signal closeRequested()

    // каталог записей (обёртка: ~/Pictures/825UI)
    property string recordingsDir: ""

    property bool recording: false
    property var recordings: []
    property string playingFile: ""
    property bool playing: false

    readonly property bool hasMic: devices.defaultAudioInput !== null

    MediaDevices {
        id: devices
    }

    CaptureSession {
        audioInput: AudioInput {}

        recorder: MediaRecorder {
            id: rec

            mediaFormat {
                fileFormat: MediaFormat.FileFormat.Ogg
                audioCodec: MediaFormat.AudioCodec.Opus
            }

            onRecorderStateChanged: (state) =>
                root.recording = state
                    === MediaRecorder.RecorderState.RecordingState

            onErrorOccurred: (error, errorString) => {
                root.recording = false
                root.status = errorString
            }
        }
    }

    MediaPlayer {
        id: player

        audioOutput: AudioOutput {}

        onPlaybackStateChanged: (state) =>
            root.playing = state === MediaPlayer.PlayingState

        onErrorOccurred: (error, errorString) =>
            root.status = errorString
    }

    property string status: ""

    function stamp() {
        const d = new Date()

        return (d.getHours() < 10 ? "0" : "") + d.getHours()
            + (d.getMinutes() < 10 ? "0" : "") + d.getMinutes()
            + (d.getSeconds() < 10 ? "0" : "") + d.getSeconds()
    }

    function toggleRecord() {
        if (!hasMic)
            return

        if (!recording) {
            rec.outputLocation = "file://" + recordingsDir
                + "/Rec_" + stamp() + ".ogg"
            rec.record()
        } else {
            rec.stop()
            rescanSoon.restart()
        }
    }

    // скан каталога записей
    Process {
        id: scanProc

        command: ["sh", "-c",
            "find '" + root.recordingsDir + "' -maxdepth 1 -name 'Rec_*.ogg'"
            + " -printf '%T@ %p\\n' 2>/dev/null | sort -rn"]

        stdout: StdioCollector {
            onStreamFinished: root.onScan(this.text)
        }
    }

    Timer {
        id: rescanSoon

        interval: 400

        onTriggered: root.rescan()
    }

    function rescan() {
        if (recordingsDir !== "")
            scanProc.running = true
    }

    function onScan(text) {
        const list = []

        text.trim().split("\n").forEach(line => {
            const sp = line.indexOf(" ")

            if (sp === -1)
                return

            list.push({
                mtime: Math.floor(Number(line.slice(0, sp))) * 1000,
                file: line.slice(sp + 1)
            })
        })

        recordings = list
    }

    function fileNameBase(path) {
        const s = path ? path.toString() : ""

        return s.slice(s.lastIndexOf("/") + 1)
    }

    function timeLabel(ts) {
        const d = new Date(ts)

        return pad2(d.getHours()) + ":" + pad2(d.getMinutes())
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n
    }

    function togglePlay(file) {
        if (playingFile === file && playing) {
            player.pause()
            return
        }

        if (playingFile !== file) {
            playingFile = file
            player.source = "file://" + file
        }

        player.play()
    }

    function removeRecording(file) {
        if (playingFile === file) {
            player.stop()
            playingFile = ""
        }

        rmProc.command = ["rm", "-f", file]
        rmProc.running = true
        rescanSoon.restart()
    }

    Process {
        id: rmProc
    }

    Component.onCompleted: rescan()

    // === интерфейс ===
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
                text: "Recorder"
                color: Settings.c1
                font.pixelSize: Settings.textSm
                font.bold: true
            }
        }

        // --- блок записи ---
        Item {
            width: parent.width
            height: Settings.line * 20

            // пульс вокруг кнопки
            SRectangle {
                anchors.centerIn: recBtn
                width: recBtn.width + Settings.line * 4
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Settings.c1
                border.width: Settings.line
                visible: root.recording

                SequentialAnimation on scale {
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1; to: 1.12; duration: 600
                    }
                    NumberAnimation {
                        from: 1.12; to: 1; duration: 600
                    }
                }
            }

            SPanel {
                id: recBtn

                anchors.centerIn: parent
                width: Settings.line * 12
                height: width
                cornerCut: Settings.line * 3
                strokeColor: Settings.c1
                fillColor: root.recording || recMouse.pressed
                    ? Settings.c1 : "transparent"
                opacity: root.hasMic ? 1 : 0.4

                VIcon {
                    anchors.centerIn: parent
                    width: parent.width * 0.4
                    height: width
                    strokePath: root.recording
                        ? Glyphs.iconStop : Glyphs.iconRecord
                    lineColor: root.recording || recMouse.pressed
                        ? Settings.c2 : Settings.c1
                }

                MouseArea {
                    id: recMouse

                    anchors.fill: parent
                    enabled: root.hasMic
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.toggleRecord()
                }
            }

            // таймер записи на инфексе
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: recBtn.right
                anchors.leftMargin: Settings.line * 8
                spacing: Settings.line

                Repeater {
                    model: 5

                    delegate: Infex {
                        property string tStr: recFormat(
                            root.recording ? rec.duration : 0)

                        ch: tStr.length > index ? tStr[index] : "0"
                        pixelSize: Settings.line * 8
                        referencePixelSize: Settings.line * 8
                        line: Settings.line
                        color: Settings.c1
                        opacity: root.recording ? 1 : 0.4
                        mirrorX: true
                    }
                }
            }

            SText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Settings.line * 4
                visible: !root.hasMic
                text: "No microphone"
                color: Settings.c1
                opacity: 0.45
                font.pixelSize: Settings.textXs
            }
        }

        // --- статус ---
        SText {
            width: parent.width - Settings.line * 6
            anchors.horizontalCenter: parent.horizontalCenter
            height: visible ? Settings.line * 4 : 0
            visible: text !== ""
            text: root.status
            color: Settings.c1
            opacity: 0.6
            elide: Text.ElideMiddle
            font.pixelSize: Settings.textXs
            horizontalAlignment: Text.AlignHCenter
        }

        // --- список записей ---
        Flickable {
            width: parent.width
            height: parent.height - headerBar.height
                - Settings.line * 20 - Settings.line * 2 * 2
            clip: true
            contentWidth: width
            contentHeight: recCol.height
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: recCol.height > height
                    ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }

            Column {
                id: recCol

                width: parent.width
                spacing: Settings.line * 2

                Repeater {
                    model: root.recordings

                    delegate: SPanel {
                        id: recCard

                        required property var modelData

                        width: recCol.width
                        height: Settings.line * 10
                        cornerCut: Settings.line * 2
                        strokeColor: Settings.c1
                        fillColor: Settings.c2

                        readonly property bool isPlaying:
                            root.playingFile
                                === recCard.modelData.file

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: Settings.line * 3
                            anchors.rightMargin: Settings.line * 3
                            spacing: Settings.line * 3

                            STile {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                width: Settings.line * 6
                                height: width
                                iconStroke: recCard.isPlaying
                                    && root.playing
                                    ? Glyphs.iconPause
                                    : Glyphs.iconPlay
                                active: recCard.isPlaying

                                onActivated: root.togglePlay(
                                    recCard.modelData.file)
                            }

                            Column {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                width: parent.width
                                    - Settings.line * 34
                                spacing: Settings.line

                                SText {
                                    width: parent.width
                                    text: root.fileNameBase(
                                        recCard.modelData.file)
                                    color: Settings.c1
                                    elide: Text.ElideMiddle
                                    font.pixelSize: Settings.textSm
                                    font.bold: true
                                }

                                // позиция воспроизведения — инверсия
                                Item {
                                    width: parent.width
                                    height: Settings.line * 2

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Settings.c1
                                        opacity: 0.15
                                    }

                                    Rectangle {
                                        width: parent.width
                                            * (recCard.isPlaying
                                               ? player.position
                                                 / Math.max(1,
                                                   player.duration)
                                               : 0)
                                        height: parent.height
                                        color: Settings.c1
                                    }
                                }
                            }

                            SText {
                                anchors.verticalCenter:
                                    parent.verticalCenter
                                width: Settings.line * 8
                                text: root.timeLabel(
                                    recCard.modelData.mtime)
                                color: Settings.c1
                                opacity: 0.5
                                font.pixelSize: Settings.textXs
                                horizontalAlignment: Text.AlignRight
                            }

                            Item {
                                width: Settings.line * 5
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                VIcon {
                                    anchors.centerIn: parent
                                    width: Settings.textSm
                                    height: width
                                    strokePath: "M 7,7 L 17,17"
                                        + " M 17,7 L 7,17"
                                    lineColor: Settings.c1
                                    opacity: recCloseMouse
                                        .containsMouse ? 1 : 0.55
                                }

                                MouseArea {
                                    id: recCloseMouse

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape:
                                        Qt.PointingHandCursor

                                    onClicked: root.removeRecording(
                                        recCard.modelData.file)
                                }
                            }
                        }
                    }
                }

                SText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.recordings.length === 0
                    text: "No recordings yet"
                    color: Settings.c1
                    opacity: 0.45
                    font.pixelSize: Settings.textSm
                }
            }
        }
    }

    function recFormat(ms) {
        const total = Math.floor(ms / 1000)

        return pad2(Math.floor(total / 60)) + ":"
            + pad2(total % 60)
    }
}
