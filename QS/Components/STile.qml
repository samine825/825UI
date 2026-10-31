import QtQuick
import ".."

// Кликабельная клетка: панель со срезом и иконкой. active — заливка
// c1, иконка c2 и внутренний зазор (тень inside). Выключенная
// (enabled: false) прячется целиком. Левый клик — activated,
// правый — secondaryActivated (например колесо устройств).
SPanel {
    id: tile

    property string iconFill: ""
    property string iconStroke: ""
    property bool active: false
    property real iconScale: 0.55

    signal activated()
    signal secondaryActivated()

    cornerCut: Settings.line * 2
    strokeColor: Settings.c1
    fillColor: tile.active ? Settings.c1 : "transparent"
    shadow: tile.active ? "inside" : "none"
    shadowColor: Settings.c2

    visible: enabled

    VIcon {
        anchors.centerIn: parent
        width: parent.height * tile.iconScale
        height: width
        fillPath: tile.iconFill
        strokePath: tile.iconStroke
        lineColor: tile.active ? Settings.c2 : Settings.c1
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton)
                tile.secondaryActivated()
            else
                tile.activated()
        }
    }
}
