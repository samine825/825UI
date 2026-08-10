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
        anchors.fill: parent
    }
    Clock {
        anchors {
            
            top: parent.top
        }


        property int fontsize: ((1000.0-(150.0*2.0))/1000.0) * Settings.barHeight
        property int hvost: ((192.77/1000)*2) * fontsize

        x: Settings.leftMargin + hvost
        width: fontsize * 5
        height: (Settings.barGap * 2) + Settings.barHeight
    } 
    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true)
        }
    }
}