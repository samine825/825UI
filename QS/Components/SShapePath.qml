import QtQuick
import QtQuick.Shapes
import ".."
ShapePath {
    Behavior on fillColor {
        ColorAnimation { duration: Settings.animBase }
    }
    Behavior on strokeColor {
        ColorAnimation { duration: Settings.animBase }
    }
}
