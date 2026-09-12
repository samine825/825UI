import QtQuick
import QtQuick.Shapes
import Quickshell
import "../Fonts" 
import "../SmoothColorElements"
import "../"
Item {
    id: clockRoot

    property bool isHovered: false
    property bool showSeconds: Settings.secondsMode === 2 || (Settings.secondsMode === 1 && isHovered)

    property date currentTime: new Date()

    // Рассчитываем ширину с учетом размеров боковых стрелок
    width: textContainer.width + Settings.line * (313.857/150) * 3
    height: Settings.barHeight

    // Вычисляем размер "хвоста" (точки шеврона) аналогично воркспейсам
    readonly property real workspaceBarPoint: backgroundContainer.height * (403.16 / 1000)

    Item {
        id: backgroundContainer
        anchors.centerIn: parent
        width: clockRoot.width
        height: Math.max(1, clockRoot.height - Settings.line)

        // Нижний слой: Заливка и толстая обводка (c2)
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

                PathLine { x: backgroundContainer.width; y: 0 }
                PathLine { x: backgroundContainer.width - clockRoot.workspaceBarPoint; y: backgroundContainer.height / 2 }
                PathLine { x: backgroundContainer.width; y: backgroundContainer.height }
                PathLine { x: 0; y: backgroundContainer.height }
                PathLine { x: clockRoot.workspaceBarPoint; y: backgroundContainer.height / 2 }
                PathLine { x: 0; y: 0 }
            }
        }

        // Верхний слой: Основная тонкая обводка (c1)
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

                PathLine { x: backgroundContainer.width; y: 0 }
                PathLine { x: backgroundContainer.width - clockRoot.workspaceBarPoint; y: backgroundContainer.height / 2 }
                PathLine { x: backgroundContainer.width; y: backgroundContainer.height }
                PathLine { x: 0; y: backgroundContainer.height }
                PathLine { x: clockRoot.workspaceBarPoint; y: backgroundContainer.height / 2 }
                PathLine { x: 0; y: 0 }
            }
        }
    }

    Item {
        id: textContainer
        anchors.centerIn: parent

        property string mainStr: Qt.formatTime(clockRoot.currentTime, "HH:mm")
        property string secStr: Qt.formatTime(clockRoot.currentTime, ":ss")

        width: mainRow.implicitWidth + secWrapper.width
        height: parent.height

        Row {
            id: mainRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: textContainer.mainStr.split("")
                delegate: Infex {
                    ch: modelData
                    pixelSize: Settings.barHeight - Settings.line * 4
                    referencePixelSize: Settings.barHeight - Settings.line * 4
                    line: Settings.line
                    color: Settings.c1
                    mirrorX: true
                }
            }
        }

        Item {
            id: secWrapper
            anchors.left: mainRow.right
            anchors.verticalCenter: parent.verticalCenter

            height: secRow.implicitHeight
            width: clockRoot.showSeconds ? secRow.implicitWidth : 0
            clip: true

            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            Row {
                id: secRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: textContainer.secStr.split("")
                    delegate: Infex {
                        ch: modelData
                        pixelSize: Settings.barHeight - Settings.line * 4
                        referencePixelSize: Settings.barHeight - Settings.line * 4
                        line: Settings.line
                        color: Settings.c1
                        mirrorX: true
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: clockRoot.isHovered = true
        onExited: clockRoot.isHovered = false
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockRoot.currentTime = new Date()
    }
}
