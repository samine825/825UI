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

        // Бар автоматически следует за позицией и шириной часов
        x: clock.x
        width: clock.width
        height: parent.height

        z: 0
    }

    Clock {
        id: clock
        
        // Жестко центрируем по горизонтали. 
        // При изменении ширины часы будут расширяться симметрично влево и вправо.
        anchors.horizontalCenter: parent.horizontalCenter
        
        // Фиксируем позицию сверху (это выровняет текст по вертикали внутри бара)
        y: Settings.barGap 

        z: 1
    }

    IpcHandler {
        target: "main"

        function forceReload(): void {
            Quickshell.reload(true)
        }
    }
}