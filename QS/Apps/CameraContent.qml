import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"

// Камера без окна: превью с вебкамеры (QtMultimedia CaptureSession),
// снимки и видео через ImageCapture / MediaRecorder (WebM+VP8+Opus —
// кодеки из gstreamer-plugins-good). Файлы — в picturesDir, каталог
// создаётся mkdir-ом до первого снимка: без него QImageWriter
// отвечает «Cannot open device for writing». Превью живёт в clip-
// контейнере без маски панели: видеоноды не рендерятся в слой
// OpacityMask и вылезают за силуэт. Выбор устройства — стрелками,
// с именем камеры. Камера активна, только пока панель открыта
// (property active). Без камеры или при ошибке — честное empty-state.
Item {
    id: root

    implicitWidth: 640
    implicitHeight: 512

    signal closeRequested()

    // камера включена, только пока панель открыта
    property bool active: false

    // каталог для файлов (обёртка: ~/Pictures/825UI)
    property string picturesDir: ""

    property int camIndex: 0
    property string status: ""
    property bool recording: false
    property real recMs: 0

    readonly property var cams: devices.videoInputs
    readonly property var currentCam:
        cams.length ? cams[Math.min(camIndex, cams.length - 1)]
        : null

    readonly property bool hasCam: currentCam !== null

    onHasCamChanged: {
        if (!hasCam)
            status = "No camera found"
    }

    MediaDevices {
        id: devices
    }

    CaptureSession {
        camera: Camera {
            id: cam

            cameraDevice: root.currentCam
            active: root.active && root.hasCam

            onErrorOccurred: (error, errorString) =>
                root.status = errorString
        }

        imageCapture: ImageCapture {
            id: stills

            onImageSaved: (id, fileName) => {
                root.status = "Saved " + fileNameBase(fileName)
            }

            onErrorOccurred: (id, error, errorString) =>
                root.status = errorString
        }

        recorder: MediaRecorder {
            id: rec

            mediaFormat {
                fileFormat: MediaFormat.FileFormat.WebM
                videoCodec: MediaFormat.VideoCodec.VP8
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

        videoOutput: viewfinder
    }

    VideoOutput {
        id: viewfinder
    }

    function fileNameBase(path) {
        const s = path ? path.toString() : ""

        return s.slice(s.lastIndexOf("/") + 1)
    }

    function stamp() {
        const d = new Date()

        return d.getFullYear() + (d.getMonth() + 1 < 10 ? "0" : "")
            + (d.getMonth() + 1) + (d.getDate() < 10 ? "0" : "")
            + d.getDate() + "_" + (d.getHours() < 10 ? "0" : "")
            + d.getHours() + (d.getMinutes() < 10 ? "0" : "")
            + d.getMinutes() + (d.getSeconds() < 10 ? "0" : "")
            + d.getSeconds()
    }

    function ensureDir() {
        if (picturesDir !== "")
            mkdirProc.running = true
    }

    Component.onCompleted: ensureDir()

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
            rec.outputLocation = "file://" + picturesDir
                + "/Video_" + stamp() + ".webm"
            rec.record()
        } else {
            rec.stop()
        }
    }

    // длительность записи
    Timer {
        interval: 200
        running: root.recording
        repeat: true

        onTriggered: root.recMs = rec.duration
    }

    Process {
        id: mkdirProc

        command: ["mkdir", "-p", picturesDir]
    }

    Column {
        anchors.fill: parent
        spacing: Settings.line * 2

        // --- превью ---
        SPanel {
            id: previewPanel

            width: parent.width
            height: width * 0.62
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: Settings.c2
            shadow: "outside"
            shadowColor: Settings.c2

            // видеоноды не участвуют в слое-маске: маску выключаем,
            // от переполнения спасает clip-контейнер
            contentMasked: false

            Item {
                anchors.fill: parent
                anchors.margins: Settings.line
                clip: true

                VideoOutput {
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                    visible: root.hasCam
                }
            }

            // пустое состояние поверх превью
            SText {
                anchors.centerIn: parent
                visible: !root.hasCam
                text: "No camera found"
                color: Settings.c1
                font.pixelSize: Settings.textSm
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

        // --- выбор устройства ---
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Settings.line * 2
            visible: root.cams.length > 1

            SButton {
                width: Settings.line * 8
                height: Settings.line * 7
                icon: Glyphs.iconPrev

                onActivated: root.camIndex =
                    (root.camIndex + root.cams.length - 1)
                        % root.cams.length
            }

            Item {
                width: Settings.line * 60
                height: Settings.line * 7

                SText {
                    anchors.centerIn: parent
                    width: parent.width
                    text: root.currentCam
                        ? root.currentCam.description : ""
                    color: Settings.c1
                    elide: Text.ElideMiddle
                    font.pixelSize: Settings.textXs
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            SButton {
                width: Settings.line * 8
                height: Settings.line * 7
                icon: Glyphs.iconNext

                onActivated: root.camIndex =
                    (root.camIndex + 1) % root.cams.length
            }
        }

        // --- кнопки ---
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
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
                    ? padStopSec(root.recMs) + " — Stop" : "Record"
                active: root.recording
                enabled: root.hasCam

                onActivated: root.toggleVideo()
            }
        }

        // --- статус ---
        SText {
            width: parent.width - Settings.line * 6
            anchors.horizontalCenter: parent.horizontalCenter
            height: Settings.line * 4
            text: root.status
            color: Settings.c1
            elide: Text.ElideMiddle
            font.pixelSize: Settings.textXs
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    function padStopSec(ms) {
        const total = Math.floor(ms / 1000)

        return Math.floor(total / 60) + ":"
            + (total % 60 < 10 ? "0" : "") + total % 60
    }
}
