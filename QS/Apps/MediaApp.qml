import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Components"
import "../"
import "."

// Медиа (камера + диктофон): тонкая обведка-PanelWindow над
// MediaContent. Каркас — как в ControlPanel. openTab — какой таб
// открыть при следующем показе (камера или аудио; -1 — не менять).
// Камера активна, только пока панель открыта.
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

    property int openTab: -1

    function show() {
        if (openTab >= 0) {
            content.currentTab = openTab
            openTab = -1
        }

        root.visible = true
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

        MediaContent {
            id: content

            anchors.fill: parent
            picturesDir: Quickshell.env("HOME")
                + "/Pictures/825UI"

            onCloseRequested: root.hide()
        }
    }
}
