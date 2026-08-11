import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window

PanelWindow {
    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Settings.barGap + Settings.barHeight

    color: "transparent"

    Bar {
        id: bar

        x: clock.x
        width: clock.width
        height: parent.height

        z: 0
    }

    Clock {
        id: clock
//192.77
        property int fontsize: Math.round(Settings.barHeight / (2*(150/1000)+1))
        property int hvost: Math.round((((313.856) / 1000)) * fontsize)
        
        width: Math.round((fontsize * (Settings.isSeconds ? 8 : 5)) + (hvost * 2))

        x: Math.round((parent.width - width) / 2)
        y: Math.round(Settings.barGap  + Settings.barHeight * 0.5)

        z: 1
    }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true)
        }
    }
}