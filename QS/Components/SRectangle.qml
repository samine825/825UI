import QtQuick
import ".."
Rectangle {
    Behavior on color {
        ColorAnimation { duration: Settings.animBase }
    }
    Behavior on border.color {
        ColorAnimation { duration: Settings.animBase }
    }
}