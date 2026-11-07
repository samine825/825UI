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

    // глубина талии — как у шапки и слайдеров (SFrame)
    readonly property real notch:
        (height - Settings.line) * InfexGeometry.notchFrac

    // точка контура i: интерполяция шестигранник → восьмиугольник.
    // Обе формы считаются во внутреннем прямоугольнике, инсечённом
    // на пол-линии (как baseInset у SPanel): обводка шириной line
    // ровно заполняет бокс элемента и никуда не вылезает.
    // Шестигранник — острые углы и малые выемки-талии на боках
    // (слоты 4 и 8); восьмиугольник — квадрат со срезами.
    // Вырожденные слоты 2 и 6 лежат на верхнем/нижнем рёбрах
    // шестигранника и становятся углами восьмиугольника — каждая
    // точка скользит монотонно вдоль своего конечного ребра, и
    // граница не волнуется при морфе
    function point(i) {
        const o = Settings.line / 2
        const w = width - 2 * o
        const h = height - 2 * o
        const t = morph
        const c = cornerCut
        const n = notch

        const hex = [
            Qt.point(o, o),
            Qt.point(o + w / 2, o),
            Qt.point(o + w, o),
            Qt.point(o + w - n, o + h / 2),
            Qt.point(o + w, o + h),
            Qt.point(o + w / 2, o + h),
            Qt.point(o, o + h),
            Qt.point(o + n, o + h / 2)
        ]
        const oct = [
            Qt.point(o + c, o),
            Qt.point(o + w - c, o),
            Qt.point(o + w, o + c),
            Qt.point(o + w, o + h - c),
            Qt.point(o + w - c, o + h),
            Qt.point(o + c, o + h),
            Qt.point(o, o + h - c),
            Qt.point(o, o + c)
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

    // контент: над заливкой; бока разъезжаются от выемки
    Item {
        id: contentHolder

        anchors.fill: parent
        anchors.leftMargin: Settings.line / 2 + morphCard.notch
            * (1 - morphCard.morph)
        anchors.rightMargin: Settings.line / 2 + morphCard.notch
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
