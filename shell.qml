import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window
import QtQuick.Shapes

import "./Apps"
import "./Bar"
import "./3D"
// =^..^=
ShellRoot {

    PanelWindow {
        id: shellRoot

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight:
            Settings.barGap * 2 +
            Settings.barHeight

        color: "transparent"

        Item {
            id: bar

            anchors.verticalCenter:
                parent.verticalCenter

            width: shellRoot.width
            height: parent.height

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.left:
                    parent.left

                height: parent.height
                
                SystemStats {
                    id: systemStats
                    height: parent.height
                }
            }

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.horizontalCenter:
                    parent.horizontalCenter

                height: parent.height

                Clock {
                    id: clock

                    height: parent.height

                    MouseArea {
                        anchors.fill: clock

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            widgetPanel.show()
                    }
                }
            }

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.right:
                    parent.right

                height: parent.height

                WorkspaceBar {
                    id: workspaceBar
                    height: parent.height
                }
            }
        }

        IpcHandler {
            target: "main"

            function forceReload(): void {
                Quickshell.reload(true)
            }

            function toggleSettings(): void {
                settingsMenu.visible
                    ? settingsMenu.hide()
                    : settingsMenu.show()
            }

            function togglePanel(): void {
                widgetPanel.visible
                    ? widgetPanel.hide()
                    : widgetPanel.show()
            }

            function toggleLauncher(): void {
                appLauncher.visible
                    ? appLauncher.hide()
                    : appLauncher.show()
            }

            function spawnCube(): void {
                physicsScene.addCube({
                    x: (Math.random() - 0.5) * 600,
                    y: 200 + Math.random() * 200,
                    size: 10 + Math.random() * 200
                })
            }
            function clearCubes(): void {
                physicsScene.clearCubes()
            }
        }
    }

    Scene {
        id: physicsScene
        Component.onCompleted: {
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
        property var notificationRegions: []

        // Упорядоченный стек активных уведомлений
        property var activeStack: []

        function pushToStack(popup) {
            var newStack = notificationScreen.activeStack.concat([popup])
            notificationScreen.activeStack = newStack
            popup.slotIndex = newStack.length - 1
        }

        function removeFromStack(popup) {
            var idx = notificationScreen.activeStack.indexOf(popup)
            if (idx === -1)
                return
            var newStack = notificationScreen.activeStack.slice()
            newStack.splice(idx, 1)
            notificationScreen.activeStack = newStack
            for (var i = 0; i < newStack.length; i++) {
                newStack[i].slotIndex = i
            }
        }

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
            console.error(
                "Failed to load NotificationPopup.qml:",
                component.errorString()
            )
            return
        }

        var popup = component.createObject(columnRef)

        if (!popup) {
            console.error("Failed to create NotificationPopup")
            return
        }

        popup.screenX = notificationScreen.width
        popup.currentNotification = notification
        popup.visible = true

        notificationScreen.pushToStack(popup)

        var hitbox = Qt.createQmlObject(
            'import QtQuick;

            Item {
                property var popup: null

                x: popup ? popup.x : 0
                y: popup ? popup.y : 0

                width: popup ? popup.width : 0
                height: popup ? popup.height : 0

                MouseArea {
                    anchors.fill: parent

                    onClicked: {
                        if (parent.popup) {
                            parent.popup.closeClicked = true
                        }
                    }
                }
            }',
            columnRef,
            "NotificationHitbox"
        )

        if (!hitbox) {
            console.error("Failed to create NotificationHitbox")
            popup.destroy()
            return
        }

        hitbox.popup = popup
        hitbox.z = 100000

        var region = Qt.createQmlObject(
            'import Quickshell;

            Region {}',
            notificationScreen,
            "NotificationRegion"
        )

        if (!region) {
            console.error("Failed to create NotificationRegion")

            hitbox.popup = null
            hitbox.destroy()

            popup.destroy()

            return
        }

        region.item = hitbox

        notificationScreen.notificationRegions =
            notificationScreen.notificationRegions.concat([region])

        popup.popupClosed.connect(function() {
            notificationScreen.removeFromStack(popup)

            var regions =
                notificationScreen.notificationRegions.slice()

            var index = regions.indexOf(region)

            if (index !== -1) {
                regions.splice(index, 1)

                notificationScreen.notificationRegions =
                    regions
            }

            if (region) {
                region.item = null
                region.destroy()
            }

            if (hitbox) {
                hitbox.popup = null
                hitbox.destroy()
            }
        })
    }

    function onAllCleared() {
        notificationScreen.activeStack = []
        notificationScreen.notificationRegions = []
    }
}

    SettingsMenu {id: settingsMenu}

    WidgetPanel {id: widgetPanel}
    AppLauncher {id: appLauncher}
}


