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
        y: Settings.barGap*2 + Settings.barHeight
        Item {
            anchors.fill: parent
            anchors.margins: Settings.line/2
            Column {
                anchors.margins: Settings.line / 2
                anchors.fill: parent

                SText {
                    id: date
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "null"
                    color: Settings.c1
                    font.pixelSize: Math.max(11, Settings.barHeight * 0.4)
                    font.bold: true
                }

                Shape {
                    id: shp
                    width: parent.width
                    height: Settings.line
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        strokeColor: Settings.c1
                        strokeWidth: Settings.line
                        startX: 0
                        startY: Settings.line/2
                        PathLine { x: shp.width; y: Settings.line/2}
                    }
                }

                Item {
                    width: parent.width
                    height: parent.height - date.height - shp.height - parent.spacing
                    Panel {
                        anchors.fill: parent
                        Row {
                            anchors.fill: parent
                            SRectangle {
                                width: (parent.width - Settings.line)/2
                                height: parent.height
                                color: "#33333333"
                                SText {
                                    anchors.centerIn: parent
                                    text: "widgets"
                                    color: Settings.c1
                                    font.pixelSize: Math.max(11, Settings.barHeight * 0.4)
                                    font.bold: true
                                }
                            }
                            Shape {
                                id: shp2
                                width: Settings.line
                                height: parent.height
                                preferredRendererType: Shape.CurveRenderer

                                SShapePath {
                                    joinStyle: ShapePath.MiterJoin
                                    capStyle: ShapePath.FlatCap
                                    strokeColor: Settings.c1
                                    strokeWidth: Settings.line
                                    startX: Settings.line/2
                                    startY: 0
                                    PathLine { x: Settings.line/2; y: shp2.height}
                                }
                            }
                            SRectangle {
                                width: (parent.width - Settings.line)/2
                                height: parent.height
                                color: "#33333333"
                                SText {
                                    anchors.centerIn: parent
                                    text: "notifs"
                                    color: Settings.c1
                                    font.pixelSize: Math.max(11, Settings.barHeight * 0.4)
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

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