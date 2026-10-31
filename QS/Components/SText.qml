import QtQuick
import ".."
Text {
    Behavior on color {
        ColorAnimation { duration: Settings.animBase }
    }
}