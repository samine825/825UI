import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window
import QtQuick.Shapes

ShellRoot {
    // бар
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
            z: 1
        }

        // Счётчик уведомлений (красный бейдж)
        Item {
            id: notifBadge
            anchors {
                right: clock.left
                rightMargin: 8
                verticalCenter: parent.verticalCenter
            }
            z: 2
            width: Notifications.notifications.length > 0 ? badgeRect.width : 0
            height: parent.height
            visible: Notifications.notifications.length > 0
            
            Behavior on width {
                NumberAnimation { duration: 200 }
            }
            
            Rectangle {
                id: badgeRect
                anchors.centerIn: parent
                width: badgeText.implicitWidth + 14
                height: badgeText.implicitHeight + 6
                color: "#ff4444"
            }
            
            Text {
                id: badgeText
                anchors.centerIn: parent
                text: Notifications.notifications.length.toString()
                font.pixelSize: 12
                font.bold: true
                color: "white"
            }
            
            MouseArea {
                anchors.fill: parent
                onClicked: Notifications.dismissAll()
            }
        }

        IpcHandler {
            target: "main"

            function forceReload(): void {
                Quickshell.reload(true)
            }

            function toggleSettings(): void {
                settingsMenu.visible = !settingsMenu.visible
            }

            function testNotification(): void {
                Quickshell.execDetached([
                    "notify-send",
                    "-a", "Test",
                    "Test Notification",
                    "Это тестовое уведомление"
                ])
            }
        }
    }

    PanelWindow {
        id: notificationScreen

        anchors {
            top: true
            bottom: true
            right: true
            left: true
        }

        exclusiveZone: -1
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        // Только hitbox'ы уведомлений входят в Wayland input region.
        // Сам popup может вращаться/анимироваться сколько угодно.
        property var notificationRegions: []

        mask: Region {
            regions: notificationScreen.notificationRegions
        }

        Item {
            id: columnRef
            anchors.fill: parent
        }
    }

    Connections {
        target: Notifications

        function onNotificationAdded(notification) {
            var component = Qt.createComponent("NotificationPopup.qml")

            if (component.status !== Component.Ready) {
                console.error("Failed to load NotificationPopup.qml:", component.errorString())
                return
            }

            // ВАЖНО: popup и hitbox создаются непосредственно в columnRef.
            // Никаких дополнительных динамических parent-объектов.
            var popup = component.createObject(columnRef)
            if (!popup) {
                console.error("Failed to create NotificationPopup")
                return
            }

            popup.screenX = notificationScreen.width
            popup.currentNotification = notification
            popup.visible = true

            // Это НЕ визуальный элемент popup.
            // Это отдельная невращаемая прямоугольная область клика.
            var hitbox = Qt.createQmlObject(
                'import QtQuick; Item {\n                    property var popup: null\n                    x: popup ? popup.x : 0\n                    y: popup ? popup.y : 0\n                    width: popup ? popup.width : 0\n                    height: popup ? popup.height : 0\n                    MouseArea {\n                        anchors.fill: parent\n                        onClicked: {\n                            if (parent.popup)\n                                parent.popup.closeClicked = true\n                        }\n                    }\n                }',
                columnRef,
                "NotificationHitbox"
            )

            hitbox.popup = popup
            hitbox.z = 100000

            // Region следит за hitbox, а hitbox следит за x/y/width/height popup.
            var region = Qt.createQmlObject(
                'import Quickshell; Region {}',
                notificationScreen,
                "NotificationRegion"
            )
            region.item = hitbox

            notificationScreen.notificationRegions =
                notificationScreen.notificationRegions.concat([region])

            popup.destroyed.connect(function() {
                var regions = notificationScreen.notificationRegions.slice()
                var index = regions.indexOf(region)
                if (index !== -1) {
                    regions.splice(index, 1)
                    notificationScreen.notificationRegions = regions
                }
                if (region)
                    region.destroy()
                if (hitbox)
                    hitbox.destroy()
            })
        }

        function onAllCleared() {
            // Не обращаемся к несуществующему notifPopup.
        }
    }

    // ─── ОКНО НАСТРОЕК ──────────────────────────────────────────
    SettingsMenu {
        id: settingsMenu
    }
}
