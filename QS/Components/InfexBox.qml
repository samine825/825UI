import QtQuick
import QtQuick.Shapes
import ".."

// Пилот универсального инфекс-элемента: форма с типами рёбер и
// заливкой снизу вверх с инверсией контента. Проверяется на
// SystemStats (паровозик из трёх машин), прежде чем раскатывать
// на слайдеры и тайлы.
//
// Рёбра: "Notch" — впуклое (выемка внутрь на notch, как у SFrame),
// "Tab" — выпуклое (выступ наружу на notch), "Flat" — прямое.
// Глубина — чистая функция высоты, поэтому стык двух машин
// (Notch правого ребра левой + Tab левого ребра правой) совпадает
// поточечно без ручной подгонки: боксы соседей перекрываются на
// line (потребитель расширяет каждый бокс на line и сдвигает на
// пол-линии), и обводки стыка ложатся на одну линию.
//
// Контент — Component: он инстанцируется дважды. Базовый экземпляр
// (inverted: false) лежит под заливкой, полосовой экземпляр
// (inverted: true) — над ней в клип-полосе от уровня заливки до
// дна; корень компонента обязан объявить property bool inverted
// и собственные width/height (Loader позиционирует контент на
// пол-линии от угла и не перекрывает его размеры). Заливка —
// аналитический многоугольник по боковым рёбрам (маски и шейдеры
// не нужны — рендерится и в софтверном бэкенде).
//
// Тень (нарост + внутреннее кольцо) на стыковых рёбрах — плоская
// (shadowFlat*): не вылезает за бокс на соседа и не перекрывает
// его c1. Слои — 1:1 со SFrame: нарост под фоном (внешний пояс
// уходит на фон бара, внутренний маскируется фоном), фон, базовый
// контент, кольцо, заливка, полосовой контент, обводка.
Item {
    id: box

    // контент: Component с корнем, объявляющим property bool inverted
    property Component content: null

    property string edgeLeft: "Notch"    // Notch | Tab | Flat
    property string edgeRight: "Notch"

    // заливка снизу вверх: доля видимой высоты между внутренними
    // гранями обводок (0 — пусто, 1 — до внутренней грани верхней)
    property real fillFraction: 0

    // горизонтальный отступ кромки заливки от левого/правого ребра
    property real fillGapLeft: 0
    property real fillGapRight: 0

    property color fillColor: Settings.c1
    property color strokeColor: Settings.c1

    // тень (нарост + кольцо) на этих рёбрах — плоская (без вершины
    // Tab): у стыков тень не вылезает за бокс на соседа и не
    // перекрывает его c1-обводку
    property bool shadowFlatLeft: false
    property bool shadowFlatRight: false

    function notchFor(inset) {
        return (height - 2 * inset) * InfexGeometry.notchFrac
    }

    readonly property real notch: notchFor(Settings.line / 2)

    // y верхней кромки заливки
    readonly property real fillLevel:
        height - Settings.line
        - Math.max(0, Math.min(1, fillFraction))
            * (height - 2 * Settings.line)

    // x бокового ребра на высоте y (в координатах бокса):
    // линейно от нуля в углах до ±notch на середине высоты
    function sideX(edge, y, atLeft) {
        const o = Settings.line / 2
        const h = height - Settings.line
        const top = o
        const mid = o + h / 2

        const base = atLeft ? o : width - o
        const k = edge === "Notch" ? (atLeft ? notch : -notch)
            : edge === "Tab" ? (atLeft ? -notch : notch) : 0

        if (y <= mid)
            return base + k * (y - top) / (mid - top)

        return base + k * (top + h - y) / (mid - top)
    }

    // многоугольник заливки ниже уровня: верхняя кромка — уровень
    // с отступами fillGap*, бока — рёбра с теми же отступами,
    // низ — по внутреннему прямоугольнику
    function fillPoints() {
        if (fillFraction <= 0)
            return []

        const o = Settings.line / 2
        const h = height - Settings.line
        const mid = o + h / 2
        const lv = Math.max(fillLevel, o)

        if (lv >= o + h - 0.5)
            return []

        const pts = []

        pts.push(Qt.point(
            sideX(edgeLeft, lv, true) + fillGapLeft, lv))

        if (lv < mid)
            pts.push(Qt.point(
                sideX(edgeLeft, mid, true) + fillGapLeft, mid))

        pts.push(Qt.point(o + fillGapLeft, o + h))
        pts.push(Qt.point(width - o - fillGapRight, o + h))

        if (lv < mid)
            pts.push(Qt.point(
                sideX(edgeRight, mid, false) - fillGapRight, mid))

        pts.push(Qt.point(
            sideX(edgeRight, lv, false) - fillGapRight, lv))

        return pts
    }

    // контур бокса с произвольным инсетом: 8 точек — углы, середины
    // верха/низа и вершины боковых рёбер (у Flat вершина вырождена
    // в середину ребра). edgeL/edgeR — переопределение типов рёбер
    function contourPoints(inset, edgeL, edgeR) {
        const n = notchFor(inset)
        const w = width - 2 * inset
        const h = height - 2 * inset
        const mid = inset + h / 2
        const rx = edgeR === "Notch" ? inset + w - n
            : edgeR === "Tab" ? inset + w + n : inset + w
        const lx = edgeL === "Notch" ? inset + n
            : edgeL === "Tab" ? inset - n : inset

        return [
            Qt.point(inset, inset),
            Qt.point(inset + w / 2, inset),
            Qt.point(inset + w, inset),
            Qt.point(rx, mid),
            Qt.point(inset + w, inset + h),
            Qt.point(inset + w / 2, inset + h),
            Qt.point(inset, inset + h),
            Qt.point(lx, mid)
        ]
    }

    function closedContour(inset, edgeL, edgeR) {
        const pts = contourPoints(inset, edgeL, edgeR)
        return pts.concat([pts[0]])
    }

    // фон: заливка c2 по контуру (край под обводкой)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: Settings.c2
            strokeColor: "transparent"
            strokeWidth: 0

            PathPolyline { path: box.closedContour(Settings.line / 2,
                box.edgeLeft, box.edgeRight) }
        }
    }

    // базовый контент (c1) — под заливкой; размеры контент задаёт
    // сам (Loader без явных размеров не перекрывает его биндинги).
    // x — за левой вершиной ребра: у Notch она врезается внутрь на
    // notch, у Tab торчит наружу (контент в самом боксе)
    Loader {
        x: Settings.line / 2
            + (box.edgeLeft === "Notch" ? box.notch : 0)
        y: Settings.line / 2
        sourceComponent: box.content

        onLoaded: if (item.inverted !== undefined)
            item.inverted = false
    }

    // заливка (c1)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            fillColor: box.fillColor
            strokeColor: "transparent"
            strokeWidth: 0

            PathPolyline { path: box.fillPoints() }
        }
    }

    // полосовой контент (c2) — над заливкой, виден только в заливке
    Item {
        width: box.width
        y: box.fillLevel
        height: box.height - box.fillLevel
        clip: true

        Loader {
            x: Settings.line / 2
                + (box.edgeLeft === "Notch" ? box.notch : 0)
            y: Settings.line / 2 - box.fillLevel
            sourceComponent: box.content

            onLoaded: if (item.inverted !== undefined)
                item.inverted = true
        }
    }

    // внутренняя тень: тонкое кольцо c2 шириной в линию, в линию
    // внутрь от обводки (как shadowOverContent у SFrame), с плоскими
    // стыковыми рёбрами — лежит на заливке по всем сторонам
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            strokeColor: Settings.c2
            strokeWidth: Settings.line

            PathPolyline { path: box.closedContour(Settings.line * 1.5,
                box.shadowFlatLeft ? "Flat" : box.edgeLeft,
                box.shadowFlatRight ? "Flat" : box.edgeRight) }
        }
    }

    // обводка — поверх всего, с реальными рёбрами
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            strokeColor: box.strokeColor
            strokeWidth: Settings.line

            PathPolyline { path: box.closedContour(Settings.line / 2,
                box.edgeLeft, box.edgeRight) }
        }
    }
}
