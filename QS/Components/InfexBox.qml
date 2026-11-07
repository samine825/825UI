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
// Внутренняя тень — тонкое кольцо c2: истинный параллельный сдвиг
// контура внутрь на линию (та же семантика shift, что у HexContour
// SFrame: косые грани смещаются по перпендикуляру через
// shift·√(1+k²)), поэтому кольцо повторяет шевроны рёбер, а не
// сползает в прямоугольник. На стыке кольца соседей идут параллельно
// диагонали стыка на линию с каждой стороны — c1 поверх c2 всегда
// сверху порядком отрисовки вагонов. Слои — 1:1 со SFrame: фон,
// базовый контент, заливка, полосовой контент, кольцо, обводка.
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

    // контур бокса, смещённый внутрь на shift: истинный параллельный
    // сдвиг, как HexContour у SFrame. Прямые кромки (верх, низ,
    // Flat-рёбра) сдвигаются на shift по нормали; косые грани
    // выемок/наростов имеют наклон k, их перпендикулярному сдвигу на
    // shift соответствует горизонтальный shift·√(1+k²) — вершина
    // ребра уходит вглубь на shift·√(1+k²), угол перестыковывается
    // на пересечении сдвинутых граней (shift·(k±√(1+k²))). Только так
    // кольцо внутренней тени повторяет шевроны рёбер с одинаковой
    // шириной band'ы на прямых и косых участках; пересчёт глубины от
    // уменьшенной высоты дал бы на диагоналях почти нулевую тень.
    // shift 0 — сам контур (фон, обводка), shift = line — кольцо.
    // edgeL/edgeR — переопределение типов рёбер
    function offsetPoints(shift, edgeL, edgeR) {
        const o = Settings.line / 2
        const k = 2 * InfexGeometry.notchFrac
        const sq = Math.sqrt(1 + k * k)
        const n = notchFor(o)
        const t = o + shift
        const b = height - o - shift
        const mid = height / 2

        let lx, lTip
        if (edgeL === "Notch") {
            lx = o + shift * (k + sq)
            lTip = o + n + shift * sq
        } else if (edgeL === "Tab") {
            lx = o + shift * (sq - k)
            lTip = o - n + shift * sq
        } else {
            lx = o + shift
            lTip = o + shift
        }

        let rx, rTip
        if (edgeR === "Notch") {
            rx = width - o - shift * (k + sq)
            rTip = width - o - n - shift * sq
        } else if (edgeR === "Tab") {
            rx = width - o - shift * (sq - k)
            rTip = width - o + n - shift * sq
        } else {
            rx = width - o - shift
            rTip = width - o - shift
        }

        return [
            Qt.point(lx, t),
            Qt.point(width / 2, t),
            Qt.point(rx, t),
            Qt.point(rTip, mid),
            Qt.point(rx, b),
            Qt.point(width / 2, b),
            Qt.point(lx, b),
            Qt.point(lTip, mid)
        ]
    }

    function offsetContour(shift, edgeL, edgeR) {
        const pts = offsetPoints(shift, edgeL, edgeR)
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

            PathPolyline { path: box.offsetContour(0,
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

    // внутренняя тень: тонкое кольцо c2 шириной в линию — истинный
    // параллельный сдвиг контура внутрь на линию (как shadowOverContent
    // у SFrame), с настоящими рёбрами: повторяет шевроны, лежит на
    // заливке по всем сторонам. У стыков кольцо идёт параллельно
    // диагонали на линию внутрь своего вагона — обводка соседа (c1,
    // позже по отрисовке) всегда поверх него
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            strokeColor: Settings.c2
            strokeWidth: Settings.line

            PathPolyline { path: box.offsetContour(Settings.line,
                box.edgeLeft, box.edgeRight) }
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

            PathPolyline { path: box.offsetContour(0,
                box.edgeLeft, box.edgeRight) }
        }
    }
}
