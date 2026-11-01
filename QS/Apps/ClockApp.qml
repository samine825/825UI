import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"
import "../"
import "."

// Часы: тонкая обведка-PanelWindow над ClockContent. Каркас — как
// в ControlPanel: окно на весь экран, клик мимо — закрыть,
// Exclusive-фокус, контент в MouseFollow ниже бара.
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

    // баннер будильников/таймера прокидывается из shell
    property alias banner: content.banner

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

        ClockContent {
            id: content

            anchors.fill: parent
            stateFile: Quickshell.env("HOME")
                + "/.825UI/state/alarms.json"

            onCloseRequested: root.hide()
        }
    }
}
