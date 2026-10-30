import QtQuick
import QtQuick.Shapes
import ".."

// Векторная иконка: PathSvg в поле 24x24, масштабируется в размер.
Shape {
    id: vIcon

    property color lineColor: Settings.c1
    property real strokeWidth: Settings.line
    property string fillPath: ""
    property string strokePath: ""

    preferredRendererType: Shape.CurveRenderer

    transform: Scale {
        xScale: vIcon.width / 24
        yScale: vIcon.height / 24
    }

    SShapePath {
        fillColor: vIcon.lineColor
        strokeColor: "transparent"

        PathSvg { path: vIcon.fillPath }
    }

    SShapePath {
        fillColor: "transparent"
        strokeColor: vIcon.lineColor
        strokeWidth: vIcon.strokeWidth * 24 / Math.max(1, vIcon.width)
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        PathSvg { path: vIcon.strokePath }
    }
}
