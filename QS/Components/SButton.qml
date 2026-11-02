import QtQuick
import ".."

// Широкая кликабельная кнопка: панель со срезом, текст и/или иконка.
// Активная (active) и нажатая — заливка c1 с внутренней тенью c2,
// рецепт STile: контур c1, внутри тень c2, поверх заливка c1.
// Просто включённая — без заливки, контент c1.
SPanel {
    id: btn

    property string label: ""
    property string icon: ""
    property bool active: false
    property real iconSize: Settings.textSm
    property int textSize: Settings.textSm

    // удержание — activated() повторяется (степперы часов)
    property bool holdRepeat: false

    signal activated()

    // сколько повторов случилось за текущее удержание
    property int holds: 0

    cornerCut: Settings.line * 2
    strokeColor: Settings.c1
    fillColor: btn.active || press.pressed ? Settings.c1 : "transparent"
    shadow: btn.active || press.pressed ? "inside" : "none"
    shadowColor: Settings.c2

    Row {
        anchors.centerIn: parent
        spacing: Settings.line * 2

        VIcon {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.icon !== ""
            width: btn.iconSize
            height: width
            strokePath: btn.icon
            lineColor: btn.active || press.pressed
                ? Settings.c2 : Settings.c1
        }

        SText {
            anchors.verticalCenter: parent.verticalCenter
            visible: btn.label !== ""
            text: btn.label
            color: btn.active || press.pressed
                ? Settings.c2 : Settings.c1
            font.pixelSize: btn.textSize
            font.bold: true
        }
    }

    Timer {
        id: holdDelay

        interval: 350

        onTriggered: holdTick.start()
    }

    Timer {
        id: holdTick

        interval: 90
        repeat: true

        onTriggered: {
            btn.holds++
            btn.activated()
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPressed: {
            btn.holds = 0

            if (btn.holdRepeat)
                holdDelay.restart()
        }

        onReleased: {
            holdDelay.stop()
            holdTick.stop()
        }

        onCanceled: {
            holdDelay.stop()
            holdTick.stop()
        }

        onClicked: {
            // удержание уже наделало шагов — одиночный клик лишний
            if (btn.holds === 0)
                btn.activated()
        }
    }
}
