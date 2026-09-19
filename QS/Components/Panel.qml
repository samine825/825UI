import QtQuick
import QtQuick.Shapes
Shape {
    id: root
    property real cornerCut: 0
    property color strokeColor: "white"
    property color fillColor: "white"
    property real strokeWidth: 0
    preferredRendererType: Shape.CurveRenderer

    SShapePath {
        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap
        strokeColor: root.strokeColor
        strokeWidth: root.strokeWidth
        fillColor: root.fillColor

        startX: root.cornerCut
        startY: 0
        PathLine { x: root.width - root.cornerCut; y: 0 }
        PathLine { x: root.width; y: root.cornerCut }
        PathLine { x: root.width; y: root.height - root.cornerCut }
        PathLine { x: root.width - root.cornerCut; y: root.height }
        PathLine { x: root.cornerCut; y: root.height }
        PathLine { x: 0; y: root.height - root.cornerCut }
        PathLine { x: 0; y: root.cornerCut }
        PathLine { x: root.cornerCut; y: 0 }
    }
    Behavior on width {
        NumberAnimation { duration: 250 }
    }
    Behavior on height {
        NumberAnimation { duration: 250 }
    }
    Behavior on strokeWidth {
        NumberAnimation { duration: 250 }
    }
}