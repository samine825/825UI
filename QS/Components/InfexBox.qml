import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import ".."

// Пилот универсального инфекс-элемента: форма с типами рёбер,
// срезами углов и заливкой (снизу вверх или слева направо) с
// инверсией контента. Проверен на SystemStats (паровозик из трёх
// машин), раскатывается на виджеты панели управления.
//
// Рёбра: "Notch" — впуклое (выемка внутрь на notch, как у SFrame),
// "Tab" — выпуклое (выступ наружу на notch), "Flat" — прямое.
// wallLeft/wallRight (−1..1) — знаковая глубина стенок, перекрывает
// строковые рёбра: 1 — Notch, −1 — Tab, 0 — Flat; в отличие от строк
// анимируется непрерывно — при смене знака стенка проезжает плоское
// положение (стыки таб-бара настроек указывают выемкой на активный
// таб, как разделители старого бара). Смещённый контур обобщён:
// диагональ ребра глубиной sig наклонена на κ = k·sig/notch, её
// сдвиг на shift даёт вершину верха shift·(sqrt(1+κ²)+κ) и кончик
// sig + shift·sqrt(1+κ²) — на ±notch и 0 совпадает с дискретными
// ветками поточечно.
// cornerCut > 0 срезает углы по смежным рёбрам (октагон, как
// CutContour у SPanel; при параллельном сдвиге контура срез меняется
// на shift·(√2 − 2)). Глубина выемки — чистая функция высоты,
// поэтому стык двух машин (Notch правого ребра левой + Tab левого
// ребра правой) совпадает поточечно без ручной подгонки: боксы
// соседей перекрываются на line (потребитель расширяет каждый бокс
// на line и сдвигает на пол-линии), и обводки стыка ложатся на одну
// линию.
//
// Контент — Component: он инстанцируется дважды. Базовый экземпляр
// (inverted: false) лежит под заливкой, полосовой экземпляр
// (inverted: true) — над ней в клип-полосе заливки (при
// fillAxis "vertical" — от уровня до дна, при "horizontal" — полоса
// между ребром заливки и кромкой, сторона заливки — fillFrom);
// корень компонента обязан объявить
// property bool inverted и собственные width/height. Полосовой
// экземпляр создаётся только при непустой заливке. Заливка —
// аналитический многоугольник: при срезах и горизонтальной оси —
// отсечение контура полуплоскостью кромки, при вертикальной оси без
// срезов — явный построитель (пиксельно свернён со старым блоком
// SystemStats, включая шевронные зазоры fillGap*).
//
// Тени: внутреннее кольцо c2 (линия, истинный параллельный сдвиг
// контура на линию — семантика HexContour SFrame) поверх заливки и
// контента; внешний нарост 3 линии по силуэтным рёбрам под фоном
// (внешние полторы линии видны, внутренняя половина маскируется
// фоном). На стыках нароста нет (shadowOuter*), кольца соседей идут
// параллельно диагонали стыка; c1 поверх любого c2 обеспечивает
// порядок отрисовки вагонов.
//
// Дети-контейнер (контейнерный режим): элементы, объявленные прямо
// в боксе, идут в contentHolder — над фоном и базовым контентом,
// под заливкой и обводкой, маскируются силуэтом бокса (1:1 со
// SPanel). У боксов без детей (вагоны бара, тайлы с Component)
// маска не создаётся.
Item {
    id: box

    // дети-контейнер: маскируются по силуэту бокса
    default property alias container: contentHolder.data

    // маскировать ли детей по силуэту; тестовый хук
    // Settings.unmaskedTest снимает маску для снимков в софтверном
    // рендере
    property bool contentMasked: true

    // контент: Component с корнем, объявляющим property bool inverted
    property Component content: null

    property string edgeLeft: "Notch"    // Notch | Tab | Flat
    property string edgeRight: "Notch"

    // знаковая глубина стенок −1..1: 1 — Notch, −1 — Tab, 0 — Flat.
    // Значение в диапазоне перекрывает строковое ребро; NaN (по
    // умолчанию) — глубина берётся из edgeLeft/edgeRight. В отличие
    // от строк анимируется: стенка непрерывно проезжает Flat при
    // смене знака
    property real wallLeft: NaN
    property real wallRight: NaN

    // узкость: видимая рамка уже бокса на line/2 слева и справа
    // (единый дефолт для всех боксов — рамка не доходит до границ
    // бокса, потребители раздают боксы с запасом на пол-линии с
    // боков, как тайлы грида). Ноль — рамка до края бокса: ставится
    // только там, где рамка обязана доходить до границы — вагоны
    // паровозика (стыки поточечно) и контейнеры, чьи дети привязаны
    // к границам бокса
    property real sideInset: Settings.line / 2

    // x левой/правой грани видимой рамки
    readonly property real x0: sideInset
    readonly property real x1: width - sideInset

    // ширина видимой рамки
    readonly property real innerWidth: x1 - x0

    // срез углов: 0 — чистое шестигранное семейство, > 0 — октагон
    property real cornerCut: 0

    // морф шестигранник → восьмиугольник: 0 — талия на рёбрах на
    // полную глубину notch, углы острые; 1 — рёбра плоские, углы
    // срезаны на cornerCut. Глубина талии масштабируется на (1−morph),
    // срез — на morph: обе границы едут монотонно, контур не волнуется,
    // конечные состояния совпадают с отдельными cornerCut/талией
    property real morph: 0

    // ось заливки: "vertical" — снизу вверх, "horizontal" — слева
    // направо (зазоры fillGap* поддерживаются только на вертикальной)
    property string fillAxis: "vertical"

    // сторона, от которой растёт горизонтальная заливка: "left" — от
    // левого ребра (кромка едет вправо), "right" — от правого (кромка
    // едет влево). Вертикальная заливка всегда снизу
    property string fillFrom: "left"

    // заливка: доля между внутренними гранями обводок (0 — пусто,
    // 1 — до кромки кольца)
    property real fillFraction: 0

    // горизонтальный отступ кромки заливки от левого/правого ребра
    // (шевронный зазор у стыков паровозика)
    property real fillGapLeft: 0
    property real fillGapRight: 0

    property color fillColor: Settings.c1
    property color strokeColor: Settings.c1

    // внешняя тень (нарост) вообще и на боковых рёбрах: у одиночного
    // бокса пояс идёт по всему контуру; у вагонов паровозика
    // shadowOuterLeft/Right выключаются — пояс силуэтного торца
    // заканчивается в углу стыка, пояса соседей стыкуются там встык,
    // как у цельного SFrame-фрейма (у него стыки внутренние)
    property bool shadowOuter: true
    property bool shadowOuterLeft: true
    property bool shadowOuterRight: true

    function notchFor(inset) {
        return (height - 2 * inset) * InfexGeometry.notchFrac
    }

    readonly property real notch: notchFor(Settings.line / 2)

    // знаковая глубина стенки в пикселях: +notch — Notch (внутрь),
    // −notch — Tab (наружу), 0 — Flat
    function sigmaLeft() {
        if (wallLeft >= -1 && wallLeft <= 1)
            return wallLeft * notch
        return edgeLeft === "Notch" ? notch
            : edgeLeft === "Tab" ? -notch : 0
    }

    function sigmaRight() {
        if (wallRight >= -1 && wallRight <= 1)
            return wallRight * notch
        return edgeRight === "Notch" ? notch
            : edgeRight === "Tab" ? -notch : 0
    }

    // y верхней кромки заливки (вертикальная ось)
    readonly property real fillLevel:
        height - Settings.line
        - Math.max(0, Math.min(1, fillFraction))
            * (height - 2 * Settings.line)

    // x кромки заливки (горизонтальная ось). Границы адаптированы к
    // стенкам: при полном заполнении кромка доходит до края контура
    // противоположной стороны (оба направления при frac=1 покрывают
    // весь контур — смена направления без скачка), пустое — кромка
    // кольца своей стороны, а при выпуклой стенке (Tab, σ < 0) —
    // кончик выпуклости: заливка дренирует расширенную зону и
    // исчезает без остатка, а не обрывается на её начале
    readonly property real fillX: {
        const f = Math.max(0, Math.min(1, fillFraction))
        const o = Settings.line / 2

        if (fillFrom === "right") {
            const full = x0 + o + Math.min(0, sigmaLeft())
            const empty = sigmaRight() < 0
                ? x1 - o - sigmaRight()
                : x1 - Settings.line
            return empty + f * (full - empty)
        }

        const full = x1 - o - Math.min(0, sigmaRight())
        const empty = sigmaLeft() < 0
            ? x0 + o + sigmaLeft()
            : x0 + Settings.line
        return empty + f * (full - empty)
    }

    // x бокового ребра на высоте y (в координатах бокса): линейно от
    // нуля в углах до знаковой глубины sig на середине высоты
    function sideX(sig, y, atLeft) {
        const o = Settings.line / 2
        const h = height - Settings.line
        const top = o
        const mid = o + h / 2

        const base = atLeft ? x0 + o : x1 - o
        const tri = y <= mid
            ? (y - top) / (mid - top)
            : (top + h - y) / (mid - top)

        return atLeft ? base + sig * tri : base - sig * tri
    }

    // заливка на вертикальной оси без срезов: явный построитель —
    // верхняя кромка — уровень с отступами fillGap*, бока — рёбра с
    // теми же отступами (шевронный зазор), низ — по внутреннему
    // прямоугольнику. Пиксельно сверен со старым блоком SystemStats
    function fillPointsPlain() {
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
            sideX(sigmaLeft(), lv, true) + fillGapLeft, lv))

        if (lv < mid)
            pts.push(Qt.point(
                sideX(sigmaLeft(), mid, true) + fillGapLeft, mid))

        pts.push(Qt.point(x0 + o + fillGapLeft, o + h))
        pts.push(Qt.point(x1 - o - fillGapRight, o + h))

        if (lv < mid)
            pts.push(Qt.point(
                sideX(sigmaRight(), mid, false) - fillGapRight, mid))

        pts.push(Qt.point(
            sideX(sigmaRight(), lv, false) - fillGapRight, lv))

        return pts
    }

    // отсечение полигона полуплоскостью plane = [a, b, c]:
    // остаются точки с a·x + b·y >= c
    function clipPlane(pts, plane) {
        const a = plane[0]
        const b = plane[1]
        const c = plane[2]
        const out = []
        const n = pts.length

        for (let i = 0; i < n; i++) {
            const p = pts[i]
            const q = pts[(i + 1) % n]
            const dp = a * p.x + b * p.y - c
            const dq = a * q.x + b * q.y - c

            if (dp >= 0)
                out.push(p)

            if ((dp >= 0) !== (dq >= 0)) {
                const t = dp / (dp - dq)
                out.push(Qt.point(
                    p.x + (q.x - p.x) * t,
                    p.y + (q.y - p.y) * t))
            }
        }

        return out
    }

    // полуплоскость с границей через прямую p→q, содержащая inside
    function planeAt(p, q, inside) {
        const a = q.y - p.y
        const b = p.x - q.x
        const c = a * p.x + b * p.y

        if (a * inside.x + b * inside.y >= c)
            return [a, b, c]

        return [-a, -b, -c]
    }

    // многоугольник заливки: контур бокса, отсечённый кромкой уровня.
    // Горизонтальная ось и срезы углов — общее отсечение; вертикальная
    // без срезов — явный построитель выше (шевронные зазоры fillGap*)
    function fillPoints() {
        if (fillFraction <= 0)
            return []

        if (fillAxis === "horizontal")
            return clipPlane(offsetPoints(0),
                fillFrom === "right"
                    ? [1, 0, fillX]
                    : [-1, 0, -fillX])

        if (cornerCut > 0) {
            // срезы + зазоры не сочетаются (зазоры нужны только
            // паровозику, срезы — статичным виджетам)
            return clipPlane(offsetPoints(0),
                [0, 1, fillLevel])
        }

        return fillPointsPlain()
    }

    // точка на ребре a→b: fromA — на cut от a, иначе — на cut от b
    function edgePoint(a, b, fromA, cut) {
        const dx = b.x - a.x
        const dy = b.y - a.y
        const len = Math.hypot(dx, dy)
        const r = len > 0 ? Math.min(cut, len) / len : 0

        return fromA
            ? Qt.point(a.x + dx * r, a.y + dy * r)
            : Qt.point(b.x - dx * r, b.y - dy * r)
    }

    // контур бокса, смещённый внутрь на shift: истинный параллельный
    // сдвиг, как HexContour у SFrame. Прямые кромки (верх, низ,
    // Flat-рёбра) сдвигаются на shift по нормали; косые грани
    // выемок/наростов имеют наклон k, их перпендикулярному сдвигу на
    // shift соответствует горизонтальный shift·√(1+k²) — вершина
    // ребра уходит вглубь на shift·√(1+k²), угол перестыковывается
    // на пересечении сдвинутых граней (shift·(k±√(1+k²))). Только так
    // кольцо внутренней тени повторяет шевроны рёбер с одинаковой
    // шириной band'ы на прямых и косых участках.
    // shift 0 — сам контур (фон, обводка), shift = line — кольцо.
    // Без срезов — 8 точек: [0..2] верх, [3] право, [4..6] низ,
    // [7] лево; со срезами каждый угол расходится в две точки на
    // смежных рёбрах — 12 точек: [0..2] верх, [3..5] право,
    // [6..8] низ, [9..11] лево
    function offsetPoints(shift) {
        const o = Settings.line / 2
        const k = 2 * InfexGeometry.notchFrac
        const sq = Math.sqrt(1 + k * k)
        const n = notchFor(o)
        const t = o + shift
        const b = height - o - shift
        const mid = height / 2

        const sigL = sigmaLeft()
        const sigR = sigmaRight()

        // морф (талия → октагон): восьмиточечный контур в семантике
        // бывшего MorphCard — линейная интерполяция hex ↔ oct по тем
        // же слотам. Вершины едут по своим рёбрам: середины верха/низа
        // съезжают к срезанным углам, сами углы сползают по боковым
        // рёбрам, кончики талии уходят по диагонали в углы октагона.
        // Вырождающихся рёбер нет — острые углы нарастают непрерывно
        // до последнего кадра. Ветка действует на полных выемках
        // обоих рёбер (hex построен под них; срезы и морф с
        // частичными стенками не сочетаются), срез масштабируется
        // морфом
        if ((morph > 0 || cornerCut > 0) && sigL > 0 && sigR > 0) {
            const tm = Math.max(0, Math.min(1, morph))
            const c = Math.max(0, cornerCut * tm
                + shift * (Math.sqrt(2) - 2))
            const xL = x0 + o + shift * (k + sq)
            const xR = x1 - o - shift * (k + sq)
            // сдвиг уже вошёл в xL/xR; кончик отстоит от угла на
            // n − s·k (иначе сдвиг применялся бы дважды и кольцо
            // уезжало)
            const nS = n - shift * k
            const w = xR - xL

            const hex = [
                Qt.point(xL, t),
                Qt.point(xL + w / 2, t),
                Qt.point(xR, t),
                Qt.point(xR - nS, mid),
                Qt.point(xR, b),
                Qt.point(xL + w / 2, b),
                Qt.point(xL, b),
                Qt.point(xL + nS, mid)
            ]
            const oct = [
                Qt.point(xL + c, t),
                Qt.point(xR - c, t),
                Qt.point(xR, t + c),
                Qt.point(xR, b - c),
                Qt.point(xR - c, b),
                Qt.point(xL + c, b),
                Qt.point(xL, b - c),
                Qt.point(xL, t + c)
            ]

            const pts = []
            for (let i = 0; i < 8; i++)
                pts.push(Qt.point(
                    hex[i].x + (oct[i].x - hex[i].x) * tm,
                    hex[i].y + (oct[i].y - hex[i].y) * tm))

            return pts
        }

        // обобщённое ребро со знаковой глубиной sig: диагональ
        // наклонена на κ = k·(sig/n), её параллельный сдвиг на shift
        // даёт вершину верха shift·(sq_κ + κ) и кончик
        // sig + shift·sq_κ. На sig = ±n и 0 совпадает с дискретными
        // ветками (Notch/Tab/Flat) поточечно; при смене знака стенка
        // непрерывно проезжает плоское положение
        const kl = k * (n > 0 ? sigL / n : 0)
        const sql = Math.sqrt(1 + kl * kl)
        const lx = x0 + o + shift * (sql + kl)
        const lTip = x0 + o + sigL + shift * sql

        const kr = k * (n > 0 ? sigR / n : 0)
        const sqr = Math.sqrt(1 + kr * kr)
        const rx = x1 - o - shift * (sqr + kr)
        const rTip = x1 - o - sigR - shift * sqr

        const pts = [
            Qt.point(lx, t),
            Qt.point(width / 2, t),
            Qt.point(rx, t),
            Qt.point(rTip, mid),
            Qt.point(rx, b),
            Qt.point(width / 2, b),
            Qt.point(lx, b),
            Qt.point(lTip, mid)
        ]

        // срез угла на текущем сдвиге: как у CutContour SPanel, фаска
        // 45° — параллельный перенос меняет срез на shift·(√2 − 2).
        // Статичные элементы (morph = 0) получают срез всегда
        const c = Math.max(0, cornerCut + shift * (Math.sqrt(2) - 2))
        if (c <= 0)
            return pts

        return [
            edgePoint(pts[0], pts[1], true, c),
            pts[1],
            edgePoint(pts[1], pts[2], false, c),
            edgePoint(pts[2], pts[3], true, c),
            pts[3],
            edgePoint(pts[3], pts[4], false, c),
            edgePoint(pts[4], pts[5], true, c),
            pts[5],
            edgePoint(pts[5], pts[6], false, c),
            edgePoint(pts[6], pts[7], true, c),
            pts[7],
            edgePoint(pts[7], pts[0], false, c)
        ]
    }

    function offsetContour(shift) {
        const pts = offsetPoints(shift)
        return pts.concat([pts[0]])
    }

    // маршруты пояса внешней тени: шапка и дно — всегда, боковые
    // рёбра по флагам (включённое ребро сцепляет верх и низ в один
    // открытый маршрут через торец; оба выключены — два отдельных
    // маршрута с плоскими торцами в углах стыков)
    readonly property var outerShadowRuns: {
        const pts = offsetPoints(0)

        if (!shadowOuter)
            return [[], []]

        if (shadowOuterLeft && shadowOuterRight)
            return [pts.concat([pts[0]]), []]

        // морф-раскладка 8 точек: [0] срез верх-лево, [1] верх-право,
        // [2..4] право (срез, кончик, срез), [5..6] низ, [7] лево
        if ((morph > 0 || cornerCut > 0)
                && sigmaLeft() > 0 && sigmaRight() > 0) {
            if (shadowOuterLeft)
                return [[pts[4], pts[5], pts[6], pts[7],
                    pts[0], pts[1]], []]
            if (shadowOuterRight)
                return [[pts[0], pts[1], pts[2], pts[3],
                    pts[4], pts[5]], []]
            return [[pts[0], pts[1]], [pts[5], pts[6]]]
        }

        if (pts.length === 12) {
            if (shadowOuterLeft)
                return [[pts[6], pts[7], pts[8], pts[9], pts[10],
                    pts[11], pts[0], pts[1], pts[2]], []]
            if (shadowOuterRight)
                return [[pts[0], pts[1], pts[2], pts[3], pts[4],
                    pts[5], pts[6], pts[7], pts[8]], []]
            return [[pts[0], pts[1], pts[2]],
                [pts[6], pts[7], pts[8]]]
        }

        if (shadowOuterLeft)
            return [[pts[4], pts[5], pts[6], pts[7],
                pts[0], pts[1], pts[2]], []]
        if (shadowOuterRight)
            return [[pts[0], pts[1], pts[2], pts[3],
                pts[4], pts[5], pts[6]], []]
        return [[pts[0], pts[1], pts[2]], [pts[4], pts[5], pts[6]]]
    }

    // внешняя тень: нарост 3 линии по силуэтным рёбрам (как
    // shadow: "both" у SFrame) — внешние полторы линии остаются
    // видны (линия вылезает за границы бокса), внутренняя половина
    // маскируется фоном ниже. Открытые маршруты с FlatCap: на
    // стыках пояс заканчивается ровно в углу контура, пояс соседа
    // начинается там же — лента без зазора и без наезда на c1
    // (перекрытия в углу накрывает собственная обводка вагона,
    // последний слой)
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            strokeColor: Settings.c2
            strokeWidth: Settings.line * 3

            PathPolyline { path: box.outerShadowRuns[0] }
        }

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "transparent"
            strokeColor: Settings.c2
            strokeWidth: Settings.line * 3

            PathPolyline { path: box.outerShadowRuns[1] }
        }
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

            PathPolyline { path: box.offsetContour(0) }
        }
    }

    // базовый контент (c1) — под заливкой; размеры контент задаёт
    // сам (Loader без явных размеров не перекрывает его биндинги).
    // x — за левой вершиной ребра: у Notch она врезается внутрь на
    // notch, у Tab торчит наружу (контент в самом боксе)
    Loader {
        x: box.x0 + Settings.line / 2
            + Math.max(0, box.sigmaLeft())
        y: Settings.line / 2
        sourceComponent: box.content

        onLoaded: if (item.inverted !== undefined)
            item.inverted = false
    }

    // дети-контейнер: режутся по силуэту бокса, не перекрывают
    // обводку; без детей маска не создаётся
    Item {
        id: contentHolder

        anchors.fill: parent
        layer.enabled: box.contentMasked
            && !Settings.unmaskedTest
            && contentHolder.children.length > 0
        layer.effect: OpacityMask {
            maskSource: silhouetteSource
        }
    }

    // силуэт бокса для маски контента
    ShaderEffectSource {
        id: silhouetteSource

        sourceItem: silhouette
        hideSource: true
        enabled: box.contentMasked
            && !Settings.unmaskedTest
            && contentHolder.children.length > 0
    }

    Shape {
        id: silhouette

        visible: silhouetteSource.enabled
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            fillColor: "white"
            strokeColor: "transparent"
            strokeWidth: 0

            PathPolyline { path: box.offsetContour(0) }
        }
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

    // полосовой контент (c2) — над заливкой, виден только в заливке:
    // вертикальная ось — полоса от уровня до дна; горизонтальная —
    // от ребра заливки до кромки (fillFrom "left": от левого ребра,
    // "right": от кромки до правого ребра)
    Item {
        x: box.fillAxis === "horizontal" && box.fillFrom === "right"
            ? box.fillX : 0
        width: box.fillAxis === "horizontal"
            ? (box.fillFrom === "right"
                ? box.width - box.fillX : box.fillX)
            : box.width
        y: box.fillAxis === "horizontal" ? 0 : box.fillLevel
        height: box.fillAxis === "horizontal"
            ? box.height : box.height - box.fillLevel
        clip: true

        // полосовой контент живёт всегда (создаётся на старте): если
        // инстанцировать его при fill > 0, копия рождается с цветом c1
        // (inverted=false до onLoaded) и SShapePath/SText своим
        // ColorAnimation плавно перекрашивают её в c2 — инверсия
        // превращается в кроссфейд. Всегда существующая копия уже c2,
        // заливка просто открывает её клипом — инверсия чёткая
        Loader {
            x: box.x0 + Settings.line / 2
                + Math.max(0, box.sigmaLeft())
                - (box.fillAxis === "horizontal"
                    && box.fillFrom === "right" ? box.fillX : 0)
            y: box.fillAxis === "horizontal"
                ? Settings.line / 2
                : Settings.line / 2 - box.fillLevel
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

            PathPolyline { path: box.offsetContour(Settings.line) }
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

            PathPolyline { path: box.offsetContour(0) }
        }
    }
}
