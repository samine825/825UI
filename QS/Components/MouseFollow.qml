import QtQuick
import ".."
Item {
    id: tiltContainer

    readonly property real mouseXFactor: tracker.hovered
        ? -(tracker.point.position.x - (tiltContainer.width / 2))
            / (tiltContainer.width + Screen.width / 2)
        : 0

    readonly property real mouseYFactor: tracker.hovered
        ? -(tracker.point.position.y - (tiltContainer.height / 2))
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
                    duration: Settings.animBase
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
                    duration: Settings.animBase
                    easing.type: Easing.OutQuad
                }
            }
        }
    ]

    // слежение за мышью — пассивный HoverHandler: он сосуществует
    // с любыми хэндлерами и MouseArea внутри контейнера и никогда
    // не перехватывает ховер на себя, поэтому 3D-тилт не сбрасывается,
    // когда курсор проходит над интерактивными детьми
    HoverHandler {
        id: tracker
    }
}
