import QtQuick
import QtQuick.Shapes
ShapePath {
    Behavior on fillColor {
        ColorAnimation { duration: 250 }
    }
    Behavior on strokeColor {
        ColorAnimation { duration: 250 }
    }
}
