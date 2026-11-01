import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"
import "../"
import "."

// Пикер эмодзи: тонкая обведка-PanelWindow над EmojiPickerContent.
// Клик по эмодзи копирует его в буфер и закрывает панель. Недавние
// персистятся в ~/.825UI/state/emoji.json.
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

        EmojiPickerContent {
            id: content

            anchors.fill: parent
            stateFile: Quickshell.env("HOME")
                + "/.825UI/state/emoji.json"

            onCloseRequested: root.hide()

            onEmojiPicked: (ch) => {
                copyProc.command = ["wl-copy", ch]
                copyProc.running = true
            }
        }
    }

    Process {
        id: copyProc
    }
}
