import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"
import "../"
import "."

// Буфер обмена: тонкая обведка-PanelWindow над ClipboardContent.
// Каркас — как в ControlPanel. Состояние персистится в ~/.825UI.
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
        content.forceActiveFocus()
    }

    function hide() {
        root.visible = false
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

        ClipboardContent {
            id: content

            anchors.fill: parent
            stateFile: Quickshell.env("HOME")
                + "/.825UI/state/clipboard.json"
            imagesDir: Quickshell.env("HOME")
                + "/.825UI/state/clipboard"

            onCloseRequested: root.hide()
        }
    }
}
