import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window

ShellRoot {
    // Основное окно бара
    PanelWindow {
        id: shellRoot
        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: Settings.barGap * 2 + Settings.barHeight
        color: "transparent"

        Bar {
            id: bar
            x: clock.x
            width: clock.width
            height: parent.height
            fontLineWidth: clock.fontsize * (150/1000) * 2
            z: 0
        }

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            y: Settings.barGap 
            z: 1
        }

        IpcHandler {
            target: "main"

            function forceReload(): void {
                Quickshell.reload(true)
            }

            function toggleSettings(): void {
                settingsMenu.visible = !settingsMenu.visible
            }
        }
    }

    // Окно настроек
    SettingsMenu {
        id: settingsMenu
    }
}