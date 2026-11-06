import QtQuick
import QtQuick.Controls
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"

// Медиа без окна: камера и диктофон в одной панели на каноническом
// таб-баре. Camera — превью (QtMultimedia CaptureSession), снимки
// ImageCapture, видео MediaRecorder (MP4/MPEG4 — у FFmpeg-бэкенда
// Qt не открываются ни libvpx, ни h264_nvenc), выбор устройства —
// явным списком строк, как список bluetooth-устройств в панели
// управления: активная строка инвертируется. Audio — запись
// микрофона Ogg/Opus, пульс вокруг кнопки, длительность на инфексе,
// список записей сканом find -printf, воспроизведение MediaPlayer
// с заливкой позиции. Каталог создаётся mkdir-ом до записи — без
// него QImageWriter отвечает «Cannot open device for writing».
// Камера активна, только пока открыта панель и виден таб камеры.
Item {
    id: root

    implicitWidth: 720
    implicitHeight: 620

    signal closeRequested()

    property int currentTab: 0
    readonly property var tabNames: ["Camera", "Audio"]

    // каталог файлов (обёртка: ~/Pictures/825UI)
    property string picturesDir: ""

    // камера включена, только пока панель открыта на её табе
    property bool active: false

    readonly property bool cameraLive: active && currentTab === 0

    Component.onCompleted: ensureDir()

    function ensureDir() {
        if (picturesDir !== "")
            mkdirProc.running = true
    }

    Process {
        id: mkdirProc

        command: ["mkdir", "-p", picturesDir]
    }

    // === камера ===
    property int camIndex: 0
    property string camStatus: ""
    property bool recording: false
    property real recMs: 0

    readonly property var cams: camDevices.videoInputs
    readonly property var currentCam:
        cams.length ? cams[Math.min(camIndex, cams.length - 1)]
        : null

    readonly property bool hasCam: currentCam !== null

    MediaDevices {
        id: camDevices
    }

    CaptureSession {
        camera: Camera {
            cameraDevice: root.currentCam
            active: root.cameraLive && root.hasCam

            onErrorOccurred: (error, errorString) =>
                root.camStatus = errorString
        }

        imageCapture: ImageCapture {
            id: stills

            onImageSaved: (id, fileName) => {
                root.camStatus = "Saved " + root.fileNameBase(fileName)
            }

            onErrorOccurred: (id, error, errorString) =>
                root.camStatus = errorString
        }

        recorder: MediaRecorder {
            id: videoRec

            // MPEG4 Part 2: у FFmpeg-бэкенда Qt не открываются ни
            // libvpx, ни h264_nvenc, отката на программный энкодер нет
            mediaFormat {
                fileFormat: MediaFormat.FileFormat.MPEG4
                videoCodec: MediaFormat.VideoCodec.MPEG4
                audioCodec: MediaFormat.AudioCodec.AAC
            }

            onRecorderStateChanged: (state) =>
                root.recording = state
                    === MediaRecorder.RecorderState.RecordingState

            onErrorOccurred: (error, errorString) => {
                root.recording = false
                root.camStatus = errorString
            }
        }

        videoOutput: viewfinder
    }

    // === диктофон ===
    readonly property bool hasMic: audioDevices.defaultAudioInput !== null

    MediaDevices {
        id: audioDevices
    }

    CaptureSession {
        audioInput: AudioInput {}

        recorder: MediaRecorder {
            id: audioRec

            mediaFormat {
                fileFormat: MediaFormat.FileFormat.Ogg
                audioCodec: MediaFormat.AudioCodec.Opus
            }

            onRecorderStateChanged: (state) => {
                audioRecording = state
                    === MediaRecorder.RecorderState.RecordingState

                if (!audioRecording)
                    rescanSoon.restart()
            }

            onErrorOccurred: (error, errorString) => {
                audioRecording = false
                audioStatus = errorString
            }
        }
    }

    property bool audioRecording: false
    property string audioStatus: ""
    property var recordings: []
    property string playingFile: ""
    property bool playing: false

    MediaPlayer {
        id: player

        audioOutput: AudioOutput {}

        onPlaybackStateChanged: (state) =>
            root.playing = state === MediaPlayer.PlayingState

        onErrorOccurred: (error, errorString) =>
            root.audioStatus = errorString
    }

    // === общие функции ===
    function stamp() {
        const d = new Date()

        return d.getFullYear() + (d.getMonth() + 1 < 10 ? "0" : "")
            + (d.getMonth() + 1) + (d.getDate() < 10 ? "0" : "")
            + d.getDate() + "_" + (d.getHours() < 10 ? "0" : "")
            + d.getHours() + (d.getMinutes() < 10 ? "0" : "")
            + d.getMinutes() + (d.getSeconds() < 10 ? "0" : "")
            + d.getSeconds()
    }

    function fileNameBase(path) {
        const s = path ? path.toString() : ""

        return s.slice(s.lastIndexOf("/") + 1)
    }

    function takePhoto() {
        if (!hasCam || recording)
            return

        ensureDir()
        stills.captureToFile(picturesDir + "/Photo_" + stamp() + ".jpg")
    }

    function toggleVideo() {
        if (!hasCam)
            return

        ensureDir()

        if (!recording) {
            videoRec.outputLocation = "file://" + picturesDir
                + "/Video_" + stamp() + ".mp4"
            videoRec.record()
        } else {
            videoRec.stop()
        }
    }

    Timer {
        interval: 200
        running: root.recording
        repeat: true

        onTriggered: root.recMs = videoRec.duration
    }

    // === диктофон: скан каталога ===
    Process {
        id: scanProc

        command: ["sh", "-c",
            "find '" + root.picturesDir + "' -maxdepth 1 -name 'Rec_*.ogg'"
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
        if (picturesDir !== "")
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

    function toggleAudioRecord() {
        if (!hasMic)
            return

        ensureDir()

        if (!audioRecording) {
            audioRec.outputLocation = "file://" + picturesDir
                + "/Rec_" + stamp() + ".ogg"
            audioRec.record()
        } else {
            audioRec.stop()
        }
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

    function pad2(n) {
        return (n < 10 ? "0" : "") + n
    }

    function recFormat(ms) {
        const total = Math.floor(ms / 1000)

        return pad2(Math.floor(total / 60)) + ":" + pad2(total % 60)
    }

    function timeLabel(ts) {
        const d = new Date(ts)

        return pad2(d.getHours()) + ":" + pad2(d.getMinutes())
    }

    function padStopSec(ms) {
        const total = Math.floor(ms / 1000)

        return Math.floor(total / 60) + ":"
            + (total % 60 < 10 ? "0" : "") + total % 60
    }

    // === каркас: табы + контент ===
    Column {
        anchors.fill: parent
        spacing: Settings.line * 4

        TabBar {
            id: tabBar

            width: parent.width
                - InfexGeometry.tipMult * Settings.line / 2
            anchors.horizontalCenter: parent.horizontalCenter
            names: root.tabNames
            current: root.currentTab

            onActivated: (index) => root.currentTab = index
        }

        SPanel {
            id: contentArea

            width: parent.width
            height: parent.height - tabBar.height
                - Settings.line * 4
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: Settings.c2
            shadow: "outside"
            shadowColor: Settings.c2

            // === таб 0: камера ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 0

                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 2
                    spacing: Settings.line * 2

                    // --- превью ---
                    SPanel {
                        id: previewPanel

                        width: parent.width
                        height: width * 0.56
                        cornerCut: Settings.line * 2
                        strokeColor: Settings.c1
                        fillColor: Settings.c2

                        // видеоноды не участвуют в слое-маске:
                        // от переполнения спасает clip-контейнер
                        contentMasked: false

                        Item {
                            anchors.fill: parent
                            anchors.margins: Settings.line
                            clip: true

                            // единственный VideoOutput, подключённый
                            // к сессии; без явного размера он
                            // авторазмеривается под разрешение камеры
                            VideoOutput {
                                id: viewfinder

                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectFit
                                visible: root.hasCam
                            }
                        }

                        SText {
                            anchors.centerIn: parent
                            visible: !root.hasCam
                            text: "No camera found"
                            color: Settings.c1
                            font.pixelSize: Settings.textSm
                            font.bold: true
                        }

                        // индикатор записи
                        SRectangle {
                            visible: root.recording
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.margins: Settings.line * 3
                            width: Settings.line * 3
                            height: width
                            radius: width / 2
                            color: Settings.c1

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite

                                NumberAnimation {
                                    from: 1; to: 0.2; duration: 600
                                }
                                NumberAnimation {
                                    from: 0.2; to: 1; duration: 600
                                }
                            }
                        }
                    }

                    // --- устройства: явный список, как bluetooth
                    // в панели управления; активная строка инвертируется
                    Column {
                        width: parent.width
                        spacing: Settings.line

                        Repeater {
                            model: root.cams

                            delegate: SPanel {
                                id: devRow

                                required property var modelData
                                required property int index

                                readonly property bool selected:
                                    root.camIndex === devRow.index

                                width: parent.width
                                height: Settings.barHeight
                                    - Settings.line
                                cornerCut: Settings.line
                                strokeColor: Settings.c1
                                fillColor: selected
                                    ? Settings.c1 : Settings.c2
                                shadow: selected ? "inside" : "none"
                                shadowColor: Settings.c2

                                SText {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Settings.line * 3
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    width: parent.width
                                        - Settings.line * 12
                                    text: devRow.modelData.description
                                    color: devRow.selected
                                        ? Settings.c2 : Settings.c1
                                    elide: Text.ElideMiddle
                                    font.pixelSize: Settings.textSm
                                    font.bold: true
                                }

                                SText {
                                    anchors.right: parent.right
                                    anchors.rightMargin:
                                        Settings.line * 3
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    visible: devRow.selected
                                    text: "Active"
                                    color: Settings.c2
                                    font.pixelSize: Settings.textXs
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor

                                    onClicked: {
                                        root.camIndex = devRow.index
                                        root.camStatus = ""
                                    }
                                }
                            }
                        }

                        SText {
                            visible: root.cams.length === 0
                            text: "No camera found"
                            color: Settings.c1
                            font.pixelSize: Settings.textXs
                        }
                    }

                    // --- кнопки ---
                    Row {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        spacing: Settings.line * 3

                        SButton {
                            width: Settings.line * 26
                            height: Settings.line * 9
                            icon: Glyphs.iconCamera
                            label: "Photo"
                            enabled: root.hasCam && !root.recording

                            onActivated: root.takePhoto()
                        }

                        SButton {
                            width: Settings.line * 26
                            height: Settings.line * 9
                            icon: root.recording
                                ? Glyphs.iconStop : Glyphs.iconRecord
                            label: root.recording
                                ? root.padStopSec(root.recMs)
                                  + " — Stop" : "Record"
                            active: root.recording
                            enabled: root.hasCam

                            onActivated: root.toggleVideo()
                        }
                    }

                    // --- статус ---
                    SText {
                        width: parent.width
                        height: Settings.line * 4
                        text: root.camStatus
                        color: Settings.c1
                        elide: Text.ElideMiddle
                        font.pixelSize: Settings.textXs
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // === таб 1: диктофон ===
            Item {
                anchors.fill: parent
                visible: root.currentTab === 1

                Column {
                    anchors.fill: parent
                    anchors.margins: Settings.line * 2
                    spacing: Settings.line * 2

                    // --- блок записи ---
                    Item {
                        width: parent.width
                        height: Settings.line * 16
                        visible: root.hasMic

                        // пульс вокруг кнопки
                        SRectangle {
                            anchors.centerIn: recBtn
                            width: recBtn.width + Settings.line * 4
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.color: Settings.c1
                            border.width: Settings.line
                            visible: root.audioRecording

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

                        SButton {
                            id: recBtn

                            anchors.centerIn: parent
                            width: Settings.line * 11
                            height: width
                            icon: root.audioRecording
                                ? Glyphs.iconStop : Glyphs.iconRecord
                            iconSize: Settings.textMd
                            active: root.audioRecording

                            onActivated: root.toggleAudioRecord()
                        }

                        // длительность записи на инфексе
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: recBtn.right
                            anchors.leftMargin: Settings.line * 7
                            spacing: Settings.line

                            Repeater {
                                model: 5

                                delegate: Infex {
                                    property string tStr:
                                        root.recFormat(
                                            root.audioRecording
                                                ? audioRec.duration : 0)

                                    ch: tStr.length > index
                                        ? tStr[index] : "0"
                                    pixelSize: Settings.line * 8
                                    referencePixelSize:
                                        Settings.line * 8
                                    line: Settings.line
                                    color: Settings.c1
                                    mirrorX: true
                                }
                            }
                        }
                    }

                    // --- нет микрофона ---
                    SText {
                        width: parent.width
                        height: root.hasMic
                            ? 0 : Settings.line * 14
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        visible: !root.hasMic
                        text: "No microphone"
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                    }

                    // --- статус ---
                    SText {
                        width: parent.width
                        height: visible ? Settings.line * 4 : 0
                        visible: text !== ""
                        text: root.audioStatus
                        color: Settings.c1
                        elide: Text.ElideMiddle
                        font.pixelSize: Settings.textXs
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // --- список записей: карточки как в истории
                    // уведомлений ---
                    Flickable {
                        width: parent.width
                        height: parent.height - Settings.line * 16
                            - Settings.line * 2 * 2
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
                            spacing: Settings.line

                            Repeater {
                                model: root.recordings

                                delegate: SPanel {
                                    id: recCard

                                    required property var modelData

                                    readonly property bool isPlaying:
                                        root.playingFile
                                            === recCard.modelData.file

                                    width: recCol.width
                                    height: Settings.barHeight
                                    cornerCut: Settings.line * 2
                                    strokeColor: Settings.c1
                                    fillColor: Settings.c2

                                    Item {
                                        anchors.fill: parent
                                        anchors.margins:
                                            Settings.line * 2

                                        STile {
                                            anchors.left: parent.left
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
                                            anchors.left: parent.left
                                            anchors.leftMargin:
                                                Settings.line * 8
                                            anchors.right: timeLabel.left
                                            anchors.rightMargin:
                                                Settings.line * 2
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            spacing: Settings.line / 2

                                            SText {
                                                width: parent.width
                                                text: root.fileNameBase(
                                                    recCard.modelData.file)
                                                color: Settings.c1
                                                elide: Text.ElideMiddle
                                                font.pixelSize:
                                                    Settings.textSm
                                                font.bold: true
                                            }

                                            // позиция — заливка
                                            Item {
                                                width: parent.width
                                                height: Settings.line / 2

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
                                            id: timeLabel

                                            anchors.right: delTile.left
                                            anchors.rightMargin:
                                                Settings.line * 2
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            text: root.timeLabel(
                                                recCard.modelData.mtime)
                                            color: Settings.c1
                                            font.pixelSize:
                                                Settings.textXs
                                        }

                                        STile {
                                            id: delTile

                                            anchors.right: parent.right
                                            anchors.verticalCenter:
                                                parent.verticalCenter
                                            width: Settings.line * 5.5
                                            height: width
                                            iconStroke: "M 7,7 L 17,17"
                                                + " M 17,7 L 7,17"

                                            onActivated: root
                                                .removeRecording(
                                                    recCard.modelData.file)
                                        }
                                    }
                                }
                            }

                            SText {
                                anchors.horizontalCenter:
                                    parent.horizontalCenter
                                visible: root.recordings.length === 0
                                text: "No recordings yet"
                                color: Settings.c1
                                font.pixelSize: Settings.textSm
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
