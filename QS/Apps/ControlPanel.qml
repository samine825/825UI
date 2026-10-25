import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects
import "../Components"
import "../"

PanelWindow {
    id: root
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    focusable: true
    exclusiveZone: -1
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }

    function show() {
        root.visible = true
    }

    function hide() {
        root.visible = false
    }
    
    MouseFollow {
        id: tiltContainer

        width: 800
        height: 500

        x: (Screen.width - width) / 2
        y: Settings.barGap * 2 + Settings.barHeight

        Item {
            id: windowFrame
            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: Settings.line * 4

                // --- Большой бар с датой (в стиле табов из настроек, но без табов) ---
                Item {
                    id: dateBar
                    width: parent.width - ((313.856 / 150) * Settings.line / 2)
                    height: Settings.barHeight - Settings.line
                    anchors.horizontalCenter: parent.horizontalCenter

                    property real point: height * (403.16 / 1000)
                    property real tabBorderWidth: Settings.line
                    property real blackOutlineWidth: Settings.line

                    // Внешняя черная обводка со скошенными краями
                    Shape {
                        id: tabOuterOutline
                        anchors.fill: parent
                        z: -1
                        preferredRendererType: Shape.CurveRenderer

                        SShapePath {
                            joinStyle: ShapePath.MiterJoin
                            capStyle: ShapePath.FlatCap
                            strokeColor: Settings.c2
                            strokeWidth: dateBar.tabBorderWidth + dateBar.blackOutlineWidth * 2
                            fillColor: "transparent"

                            startX: 0
                            startY: 0
                            PathLine { x: dateBar.width;                y: 0 }
                            PathLine { x: dateBar.width - dateBar.point; y: dateBar.height / 2 }
                            PathLine { x: dateBar.width;                y: dateBar.height }
                            PathLine { x: 0;                             y: dateBar.height }
                            PathLine { x: dateBar.point;                  y: dateBar.height / 2 }
                            PathLine { x: 0;                             y: 0 }
                        }
                    }

                    // Основное тело бара со скошенными краями
                    Shape {
                        id: tabShape
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
                            PathLine { x: dateBar.width;                y: 0 }
                            PathLine { x: dateBar.width - dateBar.point; y: dateBar.height / 2 }
                            PathLine { x: dateBar.width;                y: dateBar.height }
                            PathLine { x: 0;                             y: dateBar.height }
                            PathLine { x: dateBar.point;                  y: dateBar.height / 2 }
                            PathLine { x: 0;                             y: 0 }
                        }
                    }

                    // Текст даты внутри бара
                    SText {
                        id: date
                        anchors.centerIn: parent
                        text: "null"
                        color: Settings.c1
                        font.bold: true
                    }
                }

                // --- Контентная область: разделена на две части ---
                Item {
                    id: contentArea
                    width: parent.width
                    height: parent.height - dateBar.height - Settings.line * 3.5

                    // Задняя черная обводка главного окна контента
                    Panel {
                        x: -Settings.line
                        y: -Settings.line
                        width: parent.width + Settings.line * 2
                        height: parent.height + Settings.line * 2
                        cornerCut: Settings.line * (2 + Math.sqrt(2)/2)
                        strokeColor: Settings.c2
                        fillColor: Settings.c2
                        strokeWidth: Settings.line
                    }

                    // Передняя панель основного контента
                    Panel {
                        anchors.fill: parent
                        cornerCut: Settings.line * 2
                        strokeColor: Settings.c1
                        fillColor: Settings.c2
                        strokeWidth: Settings.line

                        Row {
                            anchors.fill: parent

                            // Левая часть: Виджеты
                            Item {
                                width: (parent.width - Settings.line) / 2
                                height: parent.height

                                Column {
                                    x: Settings.line*1.5
                                    y: Settings.line*1.5
                                    width: parent.width
                                    height: parent.height
                                    spacing: Settings.line
                                    Row {
                                        width: parent.width
                                        height: parent.width/2
                                        spacing: Settings.line
                                        Column {
                                            width: parent.width/2
                                            height: parent.width/2
                                            spacing: Settings.line
                                            SRectangle{
                                                width: parent.width
                                                height: parent.width/2
                                                color:"#33ffffff"
                                            }
                                            SRectangle{
                                                width: parent.width
                                                height: parent.width/2
                                                color:"#33ffffff"
                                            }
                                        }
                                        SRectangle{
                                            width: parent.width/2
                                            height: parent.width/2
                                            color:"#33ffffff"
                                        }
                                    }
                                }
                            }

                            // Вертикальный разделитель с обводкой по центру
                            Shape {
                                id: separator
                                width: Settings.line
                                height: parent.height
                                preferredRendererType: Shape.CurveRenderer

                                SShapePath {
                                    joinStyle: ShapePath.MiterJoin
                                    capStyle: ShapePath.FlatCap
                                    strokeColor: Settings.c1
                                    strokeWidth: Settings.line
                                    startX: Settings.line / 2
                                    startY: 0
                                    PathLine { x: Settings.line / 2; y: separator.height }
                                }
                            }

                            // Правая часть: Уведомления
                            Item {
                                width: (parent.width - Settings.line) / 2
                                height: parent.height

                                SText {
                                    anchors.centerIn: parent
                                    text: "Notifications"
                                    color: Settings.c1
                                    font.pixelSize: Math.max(14, Settings.barHeight * 0.4)
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            // Чорн обводка окна контента (как в настройках)
            SRectangle {
                id: contentBlackOutline
                anchors.fill: contentArea
                anchors.margins: -Settings.line
                z: -1
                color: Settings.c2
            }

            // Логика обновления даты
            Process {
                id: statsProcess
                command: ["bash", "-c", "date '+%A, %d %B'"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        date.text = this.text.trim()
                    }
                }
            }

            Timer {
                interval: 1000; repeat: true; running: true; triggeredOnStart: true
                onTriggered: if (!statsProcess.running) statsProcess.running = true
            }
        }
    }
}
