import QtQuick

Item {
    FontLoader {
        id: clockFont
        source: "fonts/infex-main-150.ttf"
    }

    Text {
        id: clock

        anchors.fill: parent

        text: Qt.formatTime(new Date(), "HH:mm")

        font.family: clockFont.name
        font.pixelSize: ((1000.0-(150.0*2.0))/1000.0)*Settings.barHeight

        color: "#000000"

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            clock.text = Qt.formatTime(new Date(), "HH:mm")
        }
    }
}