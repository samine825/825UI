import QtQuick
import QtQuick.Shapes
import ".."

// Векторная иконка: PathSvg в поле 24x24, масштабируется в размер.
// Толщина штриха задана В ЕДИНИЦАХ ГЛИФА (2/24) и масштабируется
// вместе с иконкой — как у иконочного шрифта: глиф выглядит
// одинаково в любом месте и любом размере, вес не скачет.
Shape {
    id: vIcon

    property color lineColor: Settings.c1
    property real strokeWidth: 2
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
        strokeWidth: vIcon.strokeWidth
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin

        PathSvg { path: vIcon.strokePath }
    }
}
