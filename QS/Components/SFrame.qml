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

    // контур с отступом inset от границ и перпендикулярным сдвигом o
    // (внутрь положительный): горизонтальный сдвиг косых — o·√(1+k²)
    component HexContour: SShapePath {
        id: hex

        property real o: 0

        readonly property real k: frame.slopeK
        readonly property real s: o * Math.sqrt(1 + k * k)
        readonly property real t: frame.baseInset + o
        readonly property real b: frame.height - frame.baseInset - o
        readonly property real xL: frame.baseInset + o * k + s
        readonly property real xR: frame.width - frame.baseInset
            - o * k - s
        readonly property real tipX:
            k * (frame.height / 2 - frame.baseInset) + s

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
            o: 0
            fillColor: "transparent"
            strokeColor: frame.shadow === "both"
                ? frame.shadowColor : "transparent"
            strokeWidth: frame.shadow === "both"
                ? Settings.line * 3 : 0
        }

        // внешняя тень отдельным контуром
        HexContour {
            o: -Settings.line
            fillColor: "transparent"
            strokeColor: frame.shadow === "outside"
                ? frame.shadowColor : "transparent"
            strokeWidth: frame.shadow === "outside"
                ? Settings.line : 0
        }

        // заливка: маскирует внутреннюю половину нароста
        HexContour {
            o: frame.fillInset
            fillColor: frame.fillColor
            strokeColor: "transparent"
            strokeWidth: 0
        }

        // внутренняя тень — поверх заливки
        HexContour {
            o: Settings.line
            fillColor: "transparent"
            strokeColor: frame.shadow === "inside"
                ? frame.shadowColor : "transparent"
            strokeWidth: frame.shadow === "inside"
                ? Settings.line : 0
        }

        // основная обводка
        HexContour {
            o: 0
            fillColor: "transparent"
            strokeColor: frame.strokeColor
            strokeWidth: Settings.line
        }
    }
}
