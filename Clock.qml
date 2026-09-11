import QtQuick
import QtQuick.Shapes
import Quickshell
import "./Fonts" 
Item {
    id: clockRoot

    property bool isHovered: false
    property bool showSeconds: Settings.secondsMode === 2 || (Settings.secondsMode === 1 && isHovered)

    property date currentTime: new Date()

    property real fontsize: Settings.barHeight / (2*(150/1000)+1) 
    property real hvost: (313.856/1000) * fontsize

    width: textContainer.width + (hvost * 2)
    height: Settings.barHeight + Settings.barGap * 2


    Item {
        id: textContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

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
                    pixelSize: clockRoot.fontsize
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
                        pixelSize: clockRoot.fontsize
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