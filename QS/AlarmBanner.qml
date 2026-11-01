import QtQuick
import Quickshell
import Quickshell.Wayland
import "Components"
import "Fonts"

PanelWindow {
    id: banner

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    visible: false
    exclusiveZone: -1
    anchors { top: true; left: true; right: true; bottom: true }
    color: "transparent"
}
