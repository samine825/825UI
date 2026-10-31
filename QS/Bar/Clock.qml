import QtQuick
import QtQuick.Shapes
import Quickshell
import "../Fonts" 
import "../Components"
import "../"
Item {
    id: r
    width: textContainer.width
        + Settings.line * (InfexGeometry.tipMult * 3 + 1)
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: clockRoot.isHovered = true
        onExited: clockRoot.isHovered = false
    }
    Item {
        id: clockRoot
        anchors.verticalCenter: parent.verticalCenter
        height: Settings.barHeight
        width: parent.width

        property bool isHovered: false
        property bool showSeconds: Settings.secondsMode === 2 || (Settings.secondsMode === 1 && isHovered)

        property date currentTime: new Date()

        // границы фрейма = видимому внешнему краю обводки
        SFrame {
            anchors.fill: parent
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
                    // Делегаты создаются один раз и живут постоянно:
                    // смена цифры меняет ch на месте, Infex морфит форму.
                    model: 5
                    delegate: Infex {
                        ch: textContainer.mainStr.length > index
                            ? textContainer.mainStr[index] : "0"
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
                    NumberAnimation { duration: Settings.animBase; easing.type: Easing.InOutQuad }
                }

                Row {
                    id: secRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: 3
                        delegate: Infex {
                            ch: textContainer.secStr.length > index
                                ? textContainer.secStr[index] : "0"
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

        

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockRoot.currentTime = new Date()
        }
    }
}