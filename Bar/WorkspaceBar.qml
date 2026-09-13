import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import "../Fonts"
import "../SmoothColorElements" 
import "../"
Item {
    id: r
    width: root.workspaceCount * root.cellWidth + Settings.barGap + Settings.line * (192.773/150) * 1.5
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            if (event.angleDelta.y > 0) {
                Hyprland.dispatch(
                    'hl.dsp.focus({ workspace = "'
                    + String((root.currentIndex - 1 + root.workspaceCount) % root.workspaceCount+1)
                    + '" })'
                )
            } else if (event.angleDelta.y < 0) {
                Hyprland.dispatch(
                    'hl.dsp.focus({ workspace = "'
                    + String((root.currentIndex+1) % root.workspaceCount+1)
                    + '" })'
                )
            }
        }
    }
    Item {
        id: root
        anchors.verticalCenter: parent.verticalCenter
        height: Settings.barHeight
        readonly property int workspaceCount: 10
        readonly property real cellWidth: Settings.barHeight - Settings.line * 2 + Settings.line * (192.773/150) * 2


        readonly property int currentIndex: {
            const list = Hyprland.workspaces.values

            for (let i = 0; i < list.length; ++i) {
                const ws = list[i]

                if (ws && ws.focused
                        && ws.id >= 1
                        && ws.id <= workspaceCount) {
                    return ws.id - 1
                }
            }

            return -1
        }
        
        Item {
            id: workspaceBar

            //anchors.centerIn: parent

            width: root.workspaceCount * root.cellWidth
            height: Math.max(1, root.height - Settings.line)

            readonly property real point: height * (403.16 / 1000)

            readonly property real activeExtra:
                root.currentIndex >= 0 ? 2 * point : 0

            readonly property real cellWidth:
                (width - activeExtra) / root.workspaceCount

            function cellX(i) {
                return i * cellWidth
                    + (root.currentIndex >= 0 && i > root.currentIndex
                        ? activeExtra : 0)
            }

            function cellW(i) {
                return cellX(i + 1) - cellX(i)
            }

            property bool animationsEnabled: false
            Component.onCompleted: animationsEnabled = true

            

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                SShapePath {
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap

                    strokeColor: Settings.c2
                    strokeWidth: Settings.line * 3
                    fillColor: Settings.c2

                    startX: 0
                    startY: 0

                    PathLine {
                        x: workspaceBar.width
                        y: 0
                    }
                    PathLine {
                        x: workspaceBar.width - workspaceBar.point
                        y: workspaceBar.height / 2
                    }
                    PathLine {
                        x: workspaceBar.width
                        y: workspaceBar.height
                    }
                    PathLine {
                        x: 0
                        y: workspaceBar.height
                    }
                    PathLine {
                        x: workspaceBar.point
                        y: workspaceBar.height / 2
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                SShapePath {
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap

                    strokeColor: Settings.c1
                    strokeWidth: Settings.line
                    fillColor: Settings.c2

                    startX: 0
                    startY: 0

                    PathLine {
                        x: workspaceBar.width
                        y: 0
                    }
                    PathLine {
                        x: workspaceBar.width - workspaceBar.point
                        y: workspaceBar.height / 2
                    }
                    PathLine {
                        x: workspaceBar.width
                        y: workspaceBar.height
                    }
                    PathLine {
                        x: 0
                        y: workspaceBar.height
                    }
                    PathLine {
                        x: workspaceBar.point
                        y: workspaceBar.height / 2
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }

            Shape {
                id: activeIndicator

                preferredRendererType: Shape.CurveRenderer
                visible: root.currentIndex >= 0

                readonly property real inset: Settings.line * (313.857/150) * 1.5
                readonly property real point: height * (403.16 / 1000)

                width: Math.max(1,
                    workspaceBar.cellWidth + workspaceBar.activeExtra
                    - inset * 2)
                height: Math.max(1, workspaceBar.height - Settings.line * 3)

                x: workspaceBar.cellX(Math.max(0, root.currentIndex)) + inset
                y: (workspaceBar.height - height) / 2

                Behavior on x {
                    NumberAnimation {
                        duration: 300
                        easing.type: Easing.OutQuad
                    }
                }

                SShapePath {
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap

                    fillColor: Settings.c1
                    strokeColor: "transparent"
                    strokeWidth: 0

                    startX: 0
                    startY: 0

                    PathLine {
                        x: activeIndicator.width
                        y: 0
                    }
                    PathLine {
                        x: activeIndicator.width - activeIndicator.point
                        y: activeIndicator.height / 2
                    }
                    PathLine {
                        x: activeIndicator.width
                        y: activeIndicator.height
                    }
                    PathLine {
                        x: 0
                        y: activeIndicator.height
                    }
                    PathLine {
                        x: activeIndicator.point
                        y: activeIndicator.height / 2
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }

            Repeater {
                model: root.workspaceCount - 1

                delegate: Shape {
                    id: divider

                    required property int index

                    anchors.fill: parent
                    z: 2

                    preferredRendererType: Shape.CurveRenderer

                    property real xPos: workspaceBar.cellX(index + 1)

                    Behavior on xPos {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }

                    SShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap

                        strokeColor: Settings.c1
                        strokeWidth: Settings.line
                        fillColor: "transparent"

                        startX: divider.xPos
                        startY: 0

                        PathLine {
                            x: root.currentIndex <= divider.index
                                ? divider.xPos - workspaceBar.point
                                : divider.xPos + workspaceBar.point

                            y: workspaceBar.height / 2

                            Behavior on x {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        PathLine {
                            x: divider.xPos
                            y: workspaceBar.height
                        }
                    }
                }
            }

            Item {
                anchors.fill: parent
                z: 3

                Repeater {
                    model: root.workspaceCount

                    delegate: Item {
                        id: workspaceCell

                        required property int index

                        x: workspaceBar.cellX(index)
                        width: workspaceBar.cellW(index)
                        height: workspaceBar.height

                        Behavior on x {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.InOutQuad
                            }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.InOutQuad
                            }
                        }

                        readonly property int workspaceId: index + 1

                        readonly property var workspaceObject: {
                            const list = Hyprland.workspaces.values

                            for (let i = 0; i < list.length; ++i) {
                                const ws = list[i]

                                if (ws && ws.id === workspaceId)
                                    return ws
                            }

                            return null
                        }

                        readonly property bool isFocused:
                            root.currentIndex === index

                        readonly property bool isActive:
                            workspaceObject !== null && workspaceObject.active

                        readonly property bool occupied:
                            workspaceObject !== null
                            && workspaceObject.toplevels.values.length > 0

                        readonly property real textOffset: {
                            const leftNotch =
                                index === 0 || root.currentIndex >= index

                            const rightNotch =
                                index === root.workspaceCount - 1
                                || root.currentIndex <= index

                            if (leftNotch && !rightNotch)
                                return Settings.line * (192.773/150)

                            if (rightNotch && !leftNotch)
                                return -Settings.line * (192.773/150)

                            return 0
                        }

                        Item {
                            id: labelContainer

                            width: parent.width
                            height: parent.height

                            x: workspaceCell.textOffset

                            Behavior on x {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.InOutQuad
                                }
                            }
                            Infex {
                                anchors.centerIn: parent
                                ch: String(workspaceCell.workspaceId % 10)

                                pixelSize: workspaceCell.isFocused
                                    ? Settings.barHeight - Settings.line * 6
                                    : Settings.barHeight - Settings.line * 4

                                referencePixelSize:
                                    Settings.barHeight - Settings.line * 4

                                color: workspaceCell.isFocused
                                    ? Settings.c2
                                    : Settings.c1

                                line: Settings.line
                            }
                            // SText {
                            //     anchors.centerIn: parent

                            //     text: String(workspaceCell.workspaceId)

                            //     color: workspaceCell.isFocused
                            //         ? Settings.c2
                            //         : Settings.c1

                            //     // Рабочий стол, активный на другом мониторе,
                            //     // остаётся ярким, пустые — немного приглушены.
                            //     opacity: workspaceCell.isFocused
                            //              || workspaceCell.isActive
                            //              || workspaceCell.occupied
                            //         ? 1
                            //         : 0.55

                            //     font.bold: true
                            SRectangle {
                                visible: workspaceCell.occupied
                                width: Settings.line
                                height: Settings.line
                                rotation: 45

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: -Settings.line * 3.5

                                color: workspaceCell.isFocused
                                    ? Settings.c1
                                    : Settings.c2
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor

                            onClicked: {
                                Hyprland.dispatch(
                                    'hl.dsp.focus({ workspace = "'
                                    + String(workspaceCell.workspaceId)
                                    + '" })'
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}