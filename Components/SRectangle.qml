import QtQuick
Rectangle {
    Behavior on color {
        ColorAnimation { duration: 250 }
    }
    Behavior on border.color {
        ColorAnimation { duration: 250 }
    }
}