import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtMultimedia
import Quickshell
import "../Components"
import "../Fonts"
import "../"

// Камера без окна: превью с вебкамеры (QtMultimedia CaptureSession),
// снимки и видео через ImageCapture / MediaRecorder (WebM+VP8+Opus —
// кодеки из gstreamer-plugins-good). Файлы — в picturesDir. Камера
// активна, только пока панель открыта (property active). Без камеры
// или при ошибке — честное empty-state. Если устройств несколько —
// переключение кнопкой.
Item {
    id: root

    implicitWidth: 640
    implicitHeight: 580

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

    function takePhoto() {
        if (!hasCam || recording)
            return

        stills.captureToFile(picturesDir + "/Photo_" + stamp() + ".jpg")
    }

    function toggleVideo() {
        if (!hasCam)
            return

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
                text: "Camera"
                color: Settings.c1
                font.pixelSize: Settings.textSm
                font.bold: true
            }

            // счётчик устройств / переключение
            SText {
                anchors.right: parent.right
                anchors.rightMargin: Settings.line * 5
                anchors.verticalCenter: parent.verticalCenter
                visible: root.cams.length > 1
                text: (root.camIndex + 1) + "/" + root.cams.length
                color: Settings.c1
                opacity: 0.6
                font.pixelSize: Settings.textXs
                font.bold: true
            }
        }

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

            VideoOutput {
                anchors.fill: parent
                anchors.margins: Settings.line
                visible: root.hasCam
            }

            // пустое состояние поверх превью
            SText {
                anchors.centerIn: parent
                visible: !root.hasCam
                text: "No camera found"
                color: Settings.c1
                opacity: 0.45
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

        // --- кнопки ---
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Settings.line * 4

            SPanel {
                width: Settings.line * 20
                height: Settings.line * 9
                cornerCut: Settings.line * 2
                strokeColor: Settings.c1
                fillColor: photoMouse.pressed ? Settings.c1
                    : "transparent"
                opacity: root.hasCam && !root.recording ? 1 : 0.4

                Row {
                    anchors.centerIn: parent
                    spacing: Settings.line * 2

                    VIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Settings.textSm
                        height: width
                        strokePath: Glyphs.iconCamera
                        lineColor: photoMouse.pressed
                            ? Settings.c2 : Settings.c1
                    }

                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Photo"
                        color: photoMouse.pressed
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                    }
                }

                MouseArea {
                    id: photoMouse

                    anchors.fill: parent
                    enabled: root.hasCam && !root.recording
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.takePhoto()
                }
            }

            SPanel {
                width: Settings.line * 20
                height: Settings.line * 9
                cornerCut: Settings.line * 2
                strokeColor: Settings.c1
                fillColor: root.recording || videoMouse.pressed
                    ? Settings.c1 : "transparent"
                opacity: root.hasCam ? 1 : 0.4

                Row {
                    anchors.centerIn: parent
                    spacing: Settings.line * 2

                    VIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Settings.textSm
                        height: width
                        strokePath: root.recording
                            ? Glyphs.iconStop : Glyphs.iconRecord
                        lineColor: root.recording || videoMouse.pressed
                            ? Settings.c2 : Settings.c1
                    }

                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.recording
                            ? padStopSec(root.recMs) + "  Stop"
                            : "Record"
                        color: root.recording || videoMouse.pressed
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                    }
                }

                MouseArea {
                    id: videoMouse

                    anchors.fill: parent
                    enabled: root.hasCam
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.toggleVideo()
                }
            }

            SPanel {
                visible: root.cams.length > 1
                width: Settings.line * 14
                height: Settings.line * 9
                cornerCut: Settings.line * 2
                strokeColor: Settings.c1
                fillColor: switchMouse.pressed
                    ? Settings.c1 : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: Settings.line * 2

                    VIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Settings.textSm
                        height: width
                        strokePath: Glyphs.iconNext
                        lineColor: switchMouse.pressed
                            ? Settings.c2 : Settings.c1
                    }

                    SText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Switch"
                        color: switchMouse.pressed
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                    }
                }

                MouseArea {
                    id: switchMouse

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: root.camIndex =
                        (root.camIndex + 1) % root.cams.length
                }
            }
        }

        // --- статус ---
        SText {
            width: parent.width - Settings.line * 6
            anchors.horizontalCenter: parent.horizontalCenter
            height: Settings.line * 4
            text: root.status
            color: Settings.c1
            opacity: 0.6
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
