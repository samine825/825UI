import QtQuick
Item {
    id: tiltContainer

    readonly property real mouseXFactor: mouseTracker.containsMouse
        ? -(mouseTracker.mouseX - (tiltContainer.width / 2))
            / (tiltContainer.width + Screen.width / 2)
        : 0

    readonly property real mouseYFactor: mouseTracker.containsMouse
        ? -(mouseTracker.mouseY - (tiltContainer.height / 2))
            / (tiltContainer.height + Screen.height / 2 )
        : 0

    readonly property real maxTiltAngle: 40

    transform: [
        Rotation {
            origin.x: tiltContainer.width / 2
            origin.y: tiltContainer.height / 2
            axis { x: 1; y: 0; z: 0 }

            angle: -tiltContainer.mouseYFactor * tiltContainer.maxTiltAngle

            Behavior on angle {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutQuad
                }
            }
        },

        Rotation {
            origin.x: tiltContainer.width / 2
            origin.y: tiltContainer.height / 2
            axis { x: 0; y: 1; z: 0 }

            angle: tiltContainer.mouseXFactor * tiltContainer.maxTiltAngle

            Behavior on angle {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutQuad
                }
            }
        }
    ]

    MouseArea {
        id: mouseTracker

        anchors.fill: parent

        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
    }
}