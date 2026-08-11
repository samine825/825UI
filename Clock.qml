import QtQuick

Item {
    FontLoader {
        id: clockFont
        source: "fonts/infex-main-150.ttf"
    }

    Text {
        id: clock

        anchors.fill: parent

        text: Qt.formatTime(new Date(), Settings.isSeconds ? "HH:mm:ss" : "HH:mm")

        font.family: clockFont.name
        font.pixelSize: Math.round(Settings.barHeight / (2*(150/1000)+1))
        //40 = x + (x 0.1) * 2 
        //0.1x = (40/2)0.1
        color: "#000000"

        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Timer {
        interval: 1000
        running: true
        repeat: true

        onTriggered: {
            clock.text = Qt.formatTime(new Date(), Settings.isSeconds ? "HH:mm:ss" : "HH:mm")
        }
    }
}