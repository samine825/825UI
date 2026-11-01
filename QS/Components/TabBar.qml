import QtQuick
import QtQuick.Shapes
import ".."

// Канонический таб-бар из настроек: гранёный контур с выемками
// (контур цифры 8 инфекса), чёрная подложка-обводка, активный
// индикатор с анимацией, перегородки с изломом к активному табу.
// Владеет только визуалом и сигналами: состояние хранит потребитель
// через current + onActivated.
Item {
    id: tabBar

    property var names: []
    property int current: 0

    signal activated(int index)

    implicitWidth: 300
    implicitHeight: Settings.barHeight - Settings.line

    readonly property real point: height * InfexGeometry.notchFrac
    readonly property real tabWidth: width / Math.max(1, names.length)

    function cycle(delta) {
        const n = Math.max(1, names.length)

        activated((current + delta % n + n) % n)
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                tabBar.cycle(-1)
            else if (event.angleDelta.y < 0)
                tabBar.cycle(1)
        }
    }

    // черная подложка-обводка
    Shape {
        id: tabOuterOutline

        anchors.fill: parent
        z: -1
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            strokeColor: Settings.c2
            strokeWidth: Settings.line * 3

            fillColor: "transparent"

            startX: 0
            startY: 0

            PathLine { x: tabBar.width;                y: 0 }
            PathLine { x: tabBar.width - tabBar.point; y: tabBar.height / 2 }
            PathLine { x: tabBar.width;                y: tabBar.height }
            PathLine { x: 0;                           y: tabBar.height }
            PathLine { x: tabBar.point;                y: tabBar.height / 2 }
            PathLine { x: 0;                           y: 0 }
        }
    }

    // основной контур
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

            PathLine { x: tabBar.width;                y: 0 }
            PathLine { x: tabBar.width - tabBar.point; y: tabBar.height / 2 }
            PathLine { x: tabBar.width;                y: tabBar.height }
            PathLine { x: 0;                           y: tabBar.height }
            PathLine { x: tabBar.point;                y: tabBar.height / 2 }
            PathLine { x: 0;                           y: 0 }
        }
    }

    // активный индикатор
    Shape {
        id: activeIndicator

        preferredRendererType: Shape.CurveRenderer

        property real indH: tabBar.height - Settings.line * 3
        property real indPoint: indH * InfexGeometry.notchFrac

        width: tabBar.tabWidth - Settings.line * 6
        height: indH
        y: (tabBar.height - indH) / 2
        x: tabBar.current * tabBar.tabWidth + Settings.line * 3

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

            startX: 0
            startY: 0

            PathLine { x: activeIndicator.width;                       y: 0 }
            PathLine { x: activeIndicator.width - activeIndicator.indPoint; y: activeIndicator.height / 2 }
            PathLine { x: activeIndicator.width;                       y: activeIndicator.height }
            PathLine { x: 0;                                           y: activeIndicator.height }
            PathLine { x: activeIndicator.indPoint;                    y: activeIndicator.height / 2 }
            PathLine { x: 0;                                           y: 0 }
        }
    }

    // перегородки: вертикали с изломом к выемке активного таба
    Repeater {
        model: tabBar.names.length - 1

        delegate: Shape {
            id: dividerShape

            preferredRendererType: Shape.CurveRenderer
            anchors.fill: parent
            z: 2

            property real xPos: (index + 1) * tabBar.tabWidth

            SShapePath {
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap
                strokeColor: Settings.c1
                strokeWidth: Settings.line
                fillColor: "transparent"

                startX: dividerShape.xPos
                startY: 0

                PathLine {
                    x: tabBar.current <= index
                        ? dividerShape.xPos - tabBar.point
                        : dividerShape.xPos + tabBar.point
                    y: tabBar.height / 2

                    Behavior on x {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                PathLine {
                    x: dividerShape.xPos
                    y: tabBar.height
                }
            }
        }
    }

    // подписи
    Row {
        anchors.fill: parent
        z: 3

        Repeater {
            model: tabBar.names

            delegate: Item {
                width: tabBar.tabWidth
                height: tabBar.height

                property real textOffset: {
                    var i = index
                    var last = tabBar.names.length - 1

                    var leftNotch = (i === 0) || (tabBar.current >= i)
                    var rightNotch = (i === last) || (tabBar.current <= i)

                    // крайние подписи сдвинуты от выемок контура бара
                    var edge = (i === 0 ? tabBar.point / 2 : 0)
                        + (i === last ? -tabBar.point / 2 : 0)

                    if (leftNotch && !rightNotch)
                        return tabBar.point / 2 + edge

                    if (rightNotch && !leftNotch)
                        return -tabBar.point / 2 + edge

                    return edge
                }

                SText {
                    text: modelData
                    color: tabBar.current === index
                        ? Settings.c2 : Settings.c1
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: parent.textOffset
                    font.pixelSize: Settings.textXs
                    font.bold: true

                    Behavior on anchors.horizontalCenterOffset {
                        NumberAnimation {
                            duration: 300
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor

                    onClicked: tabBar.activated(index)
                }
            }
        }
    }
}
