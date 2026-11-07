import QtQuick
import QtQuick.Shapes
import ".."

// Карточка, морфящаяся из шестигранника-попапа (талия, как у шапки
// и слайдеров) в восьмиугольник при развороте. Оба состояния —
// один 8-точечный контур: у шестигранника две точки вырождены в
// серединах прямых рёбер, у восьмиугольника на их местах встают
// настоящие углы. Контент (default property) живёт в contentHolder:
// бока разъезжаются от талии, текст и миниатюры всегда внутри
// контура.
Item {
    id: morphCard

    default property alias content: contentHolder.data

    // 0 — шестигранник (свёрнута), 1 — восьмиугольник (развёрнута)
    property real morph: 0
    property color fillColor: Settings.c2
    property color strokeColor: Settings.c1
    property real cornerCut: Settings.line * 2

    readonly property real padX:
        0.5 * InfexGeometry.tipMult * Settings.line
    readonly property real padY: Settings.line / 2

    // точка контура i: интерполяция шестигранник → восьмиугольник
    function point(i) {
        const w = width
        const h = height
        const t = morph
        const px = padX
        const py = padY
        const c = cornerCut
        const rw = w - h / 2
        const lw = h / 2

        const hex = [
            Qt.point(px, py),
            Qt.point(w - px, py),
            Qt.point((w - px + rw) / 2, (py + h / 2) / 2),
            Qt.point(rw, h / 2),
            Qt.point((rw + w - px) / 2, (h / 2 + h - py) / 2),
            Qt.point(w - px, h - py),
            Qt.point(px, h - py),
            Qt.point((px + lw) / 2, (h - py + h / 2) / 2)
        ]
        const oct = [
            Qt.point(c, 0),
            Qt.point(w - c, 0),
            Qt.point(w, c),
            Qt.point(w, h - c),
            Qt.point(w - c, h),
            Qt.point(c, h),
            Qt.point(0, h - c),
            Qt.point(0, c)
        ]

        const a = hex[i]
        const b = oct[i]

        return Qt.point(a.x + (b.x - a.x) * t,
            a.y + (b.y - a.y) * t)
    }

    // заливка — под контентом
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: morphCard.fillColor
            strokeColor: "transparent"
            strokeWidth: 0

            startX: morphCard.point(0).x
            startY: morphCard.point(0).y

            PathLine { x: morphCard.point(1).x; y: morphCard.point(1).y }
            PathLine { x: morphCard.point(2).x; y: morphCard.point(2).y }
            PathLine { x: morphCard.point(3).x; y: morphCard.point(3).y }
            PathLine { x: morphCard.point(4).x; y: morphCard.point(4).y }
            PathLine { x: morphCard.point(5).x; y: morphCard.point(5).y }
            PathLine { x: morphCard.point(6).x; y: morphCard.point(6).y }
            PathLine { x: morphCard.point(7).x; y: morphCard.point(7).y }
            PathLine { x: morphCard.point(0).x; y: morphCard.point(0).y }
        }
    }

    // контент: над заливкой; бока разъезжаются от талии
    Item {
        id: contentHolder

        anchors.fill: parent
        anchors.leftMargin: morphCard.height / 2
            * (1 - morphCard.morph)
        anchors.rightMargin: morphCard.height / 2
            * (1 - morphCard.morph)
    }

    // обводка — поверх контента
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            strokeColor: morphCard.strokeColor
            strokeWidth: Settings.line

            startX: morphCard.point(0).x
            startY: morphCard.point(0).y

            PathLine { x: morphCard.point(1).x; y: morphCard.point(1).y }
            PathLine { x: morphCard.point(2).x; y: morphCard.point(2).y }
            PathLine { x: morphCard.point(3).x; y: morphCard.point(3).y }
            PathLine { x: morphCard.point(4).x; y: morphCard.point(4).y }
            PathLine { x: morphCard.point(5).x; y: morphCard.point(5).y }
            PathLine { x: morphCard.point(6).x; y: morphCard.point(6).y }
            PathLine { x: morphCard.point(7).x; y: morphCard.point(7).y }
            PathLine { x: morphCard.point(0).x; y: morphCard.point(0).y }
        }
    }
}
