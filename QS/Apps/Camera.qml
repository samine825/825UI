import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"
import "../"
import "."

// Камера: тонкая обведка-PanelWindow над CameraContent. Каркас —
// как в ControlPanel. Камера активна, только пока панель открыта.
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

    function show() {
        root.visible = true
        content.ensureDir()
        content.active = true
        content.forceActiveFocus()
    }

    function hide() {
        root.visible = false
        content.active = false
    }

    // клик мимо панели — закрыть
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    MouseFollow {
        id: tilt

        width: content.width
        height: content.height
        x: (Screen.width - width) / 2
        y: Settings.barGap * 2 + Settings.barHeight

        CameraContent {
            id: content

            anchors.fill: parent
            picturesDir: Quickshell.env("HOME")
                + "/Pictures/825UI"

            onCloseRequested: root.hide()
        }
    }
}
