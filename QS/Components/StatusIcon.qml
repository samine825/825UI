import QtQuick
import ".."

// Статус подключения для клеток колеса устройств: «connected» —
// галочка в кружке, «connecting» — вращающаяся дуга, «failed» —
// восклицательный знак в кружке, пустая строка ничего не рисует.
// Поле рисунка 24x24, как у VIcon.
Item {
    id: statusIcon

    property string status: ""
    property color lineColor: Settings.c1

    // вращающаяся дуга «подключается»
    Item {
        anchors.fill: parent
        visible: statusIcon.status === "connecting"

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: statusIcon.visible
                && statusIcon.status === "connecting"
        }

        VIcon {
            anchors.fill: parent
            lineColor: statusIcon.lineColor
            strokePath: "M 12,2 A 10,10 0 1,1 2,12"
        }
    }

    VIcon {
        anchors.fill: parent
        visible: statusIcon.status === "connected"
        lineColor: statusIcon.lineColor
        strokePath: "M 12,2 A 10,10 0 0,1 12,22 A 10,10 0 0,1 12,2"
            + " M 7.5,12.5 L 10.8,15.8 L 16.5,9.3"
    }

    VIcon {
        anchors.fill: parent
        visible: statusIcon.status === "failed"
        lineColor: statusIcon.lineColor
        strokePath: "M 12,2 A 10,10 0 0,1 12,22 A 10,10 0 0,1 12,2"
            + " M 12,6.8 L 12,13.2 M 12,16.5 L 12,16.6"
    }
}
