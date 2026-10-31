import QtQuick
import QtQuick.Shapes
import ".."

// Гранёный фрейм — шестиугольник с выемками на серединах боковых
// сторон (контур цифры 8 инфекса, масштабированный до своих границ).
// Границы элемента = видимому внешнему краю обводки c1: контур
// инсетнут на пол-линии, тень лежит ровно в одну линию от обводки.
//
// shadow: "both"    — снаружи и внутри (нарост 3 линии по общему
//                     контуру; внутренняя полоса — зазор до инфекса)
//         "outside" — только снаружи (смещённый контур)
//         "inside"  — только внутри (смещённый контур)
//         "none"    — без тени
//
// Геометрия анимирует сам потребитель; цвета анимируют SShapePath.
Item {
    id: frame

    property string shadow: "both"
    property color fillColor: Settings.c2
    property color strokeColor: Settings.c1
    property color shadowColor: Settings.c2

    // сдвиг заливки относительно базового контура: отрицательный
    // заполняет до границ (слой заливки слайдера)
    property real fillInset: 0

    // отступ базового контура от границ (обводка не выпирает)
    readonly property real baseInset: Settings.line / 2

    // наклон косых граней: константа контура, d-независимая
    readonly property real slopeK: 2 * InfexGeometry.notchFrac

    // контур: прямоугольник с отступом inset от границ, поверх него —
    // параллельный сдвиг косых и кромок на shift (внутрь положительный).
    // Выемка принадлежит самому прямоугольнику (глубина k·h/2), сдвиг
    // двигает её пересечение на shift·k.
    component HexContour: SShapePath {
        id: hex

        property real inset: 0
        property real shift: 0

        readonly property real k: frame.slopeK
        readonly property real sq: Math.sqrt(1 + k * k)
        readonly property real t: hex.inset + hex.shift
        readonly property real b: frame.height - hex.inset - hex.shift
        readonly property real xL: hex.inset + hex.shift * (k + sq)
        readonly property real xR: frame.width - hex.inset
            - hex.shift * (k + sq)
        readonly property real tipX:
            k * (frame.height / 2 - hex.inset) - hex.shift * k

        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap

        startX: hex.xL
        startY: hex.t

        PathLine { x: hex.xR; y: hex.t }
        PathLine { x: hex.xR - hex.tipX; y: frame.height / 2 }
        PathLine { x: hex.xR; y: hex.b }
        PathLine { x: hex.xL; y: hex.b }
        PathLine { x: hex.xL + hex.tipX; y: frame.height / 2 }
        PathLine { x: hex.xL; y: hex.t }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // тень-нарост: внешний пояс останется виден, внутренняя
        // половина вместе с шипами масок ниже заливкой
        HexContour {
            inset: frame.baseInset
            fillColor: "transparent"
            strokeColor: frame.shadow === "both"
                ? frame.shadowColor : "transparent"
            strokeWidth: frame.shadow === "both"
                ? Settings.line * 3 : 0
        }

        // внешняя тень отдельным контуром
        HexContour {
            inset: frame.baseInset
            shift: -Settings.line
            fillColor: "transparent"
            strokeColor: frame.shadow === "outside"
                ? frame.shadowColor : "transparent"
            strokeWidth: frame.shadow === "outside"
                ? Settings.line : 0
        }

        // заливка: маскирует внутреннюю половину нароста
        HexContour {
            inset: frame.baseInset + frame.fillInset
            fillColor: frame.fillColor
            strokeColor: "transparent"
            strokeWidth: 0
        }

        // внутренняя тень — параллельный сдвиг заливки внутрь на линию
        HexContour {
            inset: frame.baseInset + frame.fillInset
            shift: Settings.line
            fillColor: "transparent"
            strokeColor: frame.shadow === "inside"
                ? frame.shadowColor : "transparent"
            strokeWidth: frame.shadow === "inside"
                ? Settings.line : 0
        }

        // основная обводка
        HexContour {
            inset: frame.baseInset
            fillColor: "transparent"
            strokeColor: frame.strokeColor
            strokeWidth: Settings.line
        }
    }
}
