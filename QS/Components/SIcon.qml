import QtQuick
import ".."

// Векторная иконка 24x24 или индикатор статуса. Пока status пуст —
// рисуется глиф (fillPath/strokePath как у VIcon); непустой статус
// ("connecting" | "connected" | "failed") рисует статус-глиф вместо
// иконки. Нет ни глифа, ни статуса — не рисуется ничего.
Item {
    id: sIcon

    property string status: ""
    property string fillPath: ""
    property string strokePath: ""
    property color lineColor: Settings.c1

    // спиннер «подключается»: вращающаяся дуга
    Item {
        anchors.fill: parent
        visible: sIcon.status === "connecting"

        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: sIcon.visible && sIcon.status === "connecting"
        }

        VIcon {
            anchors.fill: parent
            lineColor: sIcon.lineColor
            strokePath: "M 12,2 A 10,10 0 1,1 2,12"
        }
    }

    // «подключено»: галочка в кружке
    VIcon {
        anchors.fill: parent
        visible: sIcon.status === "connected"
        lineColor: sIcon.lineColor
        strokePath: "M 12,2 A 10,10 0 0,1 12,22 A 10,10 0 0,1 12,2"
            + " M 7.5,12.5 L 10.8,15.8 L 16.5,9.3"
    }

    // «не удалось»: восклицательный знак в кружке
    VIcon {
        anchors.fill: parent
        visible: sIcon.status === "failed"
        lineColor: sIcon.lineColor
        strokePath: "M 12,2 A 10,10 0 0,1 12,22 A 10,10 0 0,1 12,2"
            + " M 12,6.8 L 12,13.2 M 12,16.5 L 12,16.6"
    }

    // обычный глиф
    VIcon {
        anchors.fill: parent
        visible: sIcon.status === ""
            && (sIcon.fillPath !== "" || sIcon.strokePath !== "")
        lineColor: sIcon.lineColor
        fillPath: sIcon.fillPath
        strokePath: sIcon.strokePath
    }
}
