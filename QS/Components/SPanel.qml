import QtQuick
import QtQuick.Shapes
import ".."

// Прямоугольник со срезанными углами. Границы элемента = видимому
// внешнему краю обводки c1 (контур инсетнут на пол-линии), тень
// лежит ровно в одну линию от обводки. Для фаски 45° параллельный
// перенос контура на o меняет срез на o·(√2 − 2).
//
// shadow: "both"    — снаружи и внутри (нарост 3 линии по контуру)
//         "outside" — только снаружи (смещённый контур)
//         "inside"  — только внутри (смещённый контур)
//         "none"    — без тени
//
// flatLeft/flatRight — кромки без среза (у края экрана). Дети рисуются
// поверх панели.
Item {
    id: panel

    property string shadow: "none"
    property real cornerCut: Settings.line * 2
    property bool flatLeft: false
    property bool flatRight: false
    property color fillColor: Settings.c2
    property color strokeColor: Settings.c1
    property color shadowColor: Settings.c2

    // сдвиг заливки относительно базового контура: отрицательный
    // заполняет до границ (слой заливки слайдера)
    property real fillInset: 0

    // отступ базового контура от границ (обводка не выпирает)
    readonly property real baseInset: Settings.line / 2

    component CutContour: SShapePath {
        id: cut

        property real o: 0

        readonly property real inset: panel.baseInset + cut.o
        readonly property real w: panel.width - 2 * inset
        readonly property real h: panel.height - 2 * inset
        readonly property real cutL: panel.flatLeft ? 0
            : Math.max(0, panel.cornerCut + cut.o * (Math.sqrt(2) - 2))
        readonly property real cutR: panel.flatRight ? 0
            : Math.max(0, panel.cornerCut + cut.o * (Math.sqrt(2) - 2))

        joinStyle: ShapePath.MiterJoin
        capStyle: ShapePath.FlatCap

        startX: cut.inset + cut.cutL
        startY: cut.inset

        PathLine { x: cut.inset + cut.w - cut.cutR; y: cut.inset }
        PathLine { x: cut.inset + cut.w; y: cut.inset + cut.cutR }
        PathLine { x: cut.inset + cut.w; y: cut.inset + cut.h - cut.cutR }
        PathLine { x: cut.inset + cut.w - cut.cutR; y: cut.inset + cut.h }
        PathLine { x: cut.inset + cut.cutL; y: cut.inset + cut.h }
        PathLine { x: cut.inset; y: cut.inset + cut.h - cut.cutL }
        PathLine { x: cut.inset; y: cut.inset + cut.cutL }
        PathLine { x: cut.inset + cut.cutL; y: cut.inset }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // тень-нарост: внешний пояс останется виден, внутренняя
        // половина вместе с шипами маскируется заливкой ниже
        CutContour {
            o: 0
            fillColor: "transparent"
            strokeColor: panel.shadow === "both"
                ? panel.shadowColor : "transparent"
            strokeWidth: panel.shadow === "both"
                ? Settings.line * 3 : 0
        }

        // внешняя тень отдельным контуром
        CutContour {
            o: -Settings.line
            fillColor: "transparent"
            strokeColor: panel.shadow === "outside"
                ? panel.shadowColor : "transparent"
            strokeWidth: panel.shadow === "outside"
                ? Settings.line : 0
        }

        // заливка: маскирует внутреннюю половину нароста
        CutContour {
            o: panel.fillInset
            fillColor: panel.fillColor
            strokeColor: "transparent"
            strokeWidth: 0
        }

        // внутренняя тень — поверх заливки
        CutContour {
            o: Settings.line
            fillColor: "transparent"
            strokeColor: panel.shadow === "inside"
                ? panel.shadowColor : "transparent"
            strokeWidth: panel.shadow === "inside"
                ? Settings.line : 0
        }

        // основная обводка
        CutContour {
            o: 0
            fillColor: "transparent"
            strokeColor: panel.strokeColor
            strokeWidth: Settings.line
        }
    }
}
