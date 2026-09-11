import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    readonly property int workspaceCount: 10
    readonly property real cellWidth: Settings.barHeight + (313.857/150) * 6

    width: workspaceCount * cellWidth + Settings.line * (313.857/150) + Settings.barGap * 2
    height: Settings.barHeight

    // Индекс сфокусированного рабочего стола.
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

        anchors.centerIn: parent

        width: root.workspaceCount * root.cellWidth
        height: Math.max(1, root.height - Settings.line)

        readonly property real point: height * (403.16 / 1000)
        readonly property real cellWidth: width / root.workspaceCount

        // Внешняя чёрная обводка.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap

                strokeColor: Settings.c2
                strokeWidth: Settings.line * 3
                fillColor: Settings.c2

                startX: 0
                startY: 0

                PathLine {x: workspaceBar.width;                      y: 0}
                PathLine {x: workspaceBar.width - workspaceBar.point; y: workspaceBar.height / 2}
                PathLine {x: workspaceBar.width;                      y: workspaceBar.height}
                PathLine {x: 0;                                       y: workspaceBar.height}
                PathLine {x: workspaceBar.point;                      y: workspaceBar.height / 2}
                PathLine {x: 0;                                       y: 0}
            }
        }

        // Основная рамка.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap

                strokeColor: Settings.c1
                strokeWidth: Settings.line
                fillColor: Settings.c2

                startX: 0
                startY: 0

                PathLine {x: workspaceBar.width;                      y: 0}
                PathLine {x: workspaceBar.width - workspaceBar.point; y: workspaceBar.height / 2}
                PathLine {x: workspaceBar.width;                      y: workspaceBar.height}
                PathLine {x: 0;                                       y: workspaceBar.height}
                PathLine {x: workspaceBar.point;                      y: workspaceBar.height / 2}
                PathLine {x: 0;                                       y: 0}
            }
        }

        // Подвижная подсветка текущего рабочего стола.
        Shape {
            id: activeIndicator

            preferredRendererType: Shape.CurveRenderer
            visible: root.currentIndex >= 0

            readonly property real inset: Settings.line * (313.857/150) * 1.5
            readonly property real point: height * (403.16 / 1000)

            width: Math.max(1, workspaceBar.cellWidth - inset * 2)
            height: Math.max(1, workspaceBar.height - Settings.line * 3)

            x: Math.max(0, root.currentIndex) * workspaceBar.cellWidth + inset
            y: (workspaceBar.height - height) / 2

            Behavior on x {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }

            ShapePath {
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap

                fillColor: Settings.c1
                strokeColor: "transparent"
                strokeWidth: 0

                startX: 0
                startY: 0

                PathLine { x: activeIndicator.width;                            y: 0 }
                PathLine { x: activeIndicator.width - activeIndicator.point;    y: activeIndicator.height / 2 }
                PathLine { x: activeIndicator.width;                            y: activeIndicator.height }
                PathLine { x: 0;                                                y: activeIndicator.height }
                PathLine { x: activeIndicator.point;                            y: activeIndicator.height / 2 }
                PathLine { x: 0;                                                y: 0 }
            }
        }

        // Разделители меняют направление относительно активной ячейки.
        Repeater {
            model: root.workspaceCount - 1

            delegate: Shape {
                id: divider

                required property int index

                anchors.fill: parent
                z: 2

                preferredRendererType: Shape.CurveRenderer

                readonly property real xPos:
                    (index + 1) * workspaceBar.cellWidth

                ShapePath {
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

        Row {
            anchors.fill: parent
            z: 3

            Repeater {
                model: root.workspaceCount

                delegate: Item {
                    id: workspaceCell

                    required property int index

                    width: workspaceBar.cellWidth
                    height: workspaceBar.height

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

                    // Аналог смещения текста во вкладках settings.
                    readonly property real textOffset: {
                        const leftNotch =
                            index === 0 || root.currentIndex >= index

                        const rightNotch =
                            index === root.workspaceCount - 1
                            || root.currentIndex <= index

                        if (leftNotch && !rightNotch)
                            return workspaceBar.point / 2

                        if (rightNotch && !leftNotch)
                            return -workspaceBar.point / 2

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

                        // Text {
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

                        //     Behavior on color {
                        //         ColorAnimation { duration: 200 }
                        //     }

                        //     Behavior on opacity {
                        //         NumberAnimation { duration: 200 }
                        //     }
                        // }

                        Rectangle {
                            visible: workspaceCell.occupied

                            width: 3
                            height: 3
                            radius: width / 2

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: Settings.line * 1.5 + 1

                            color: workspaceCell.isFocused
                                ? Settings.c2
                                : Settings.c1

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
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