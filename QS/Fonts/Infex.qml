import QtQuick
import QtQuick.Shapes
import Quickshell

Item {
    id: pc

    property string ch: "0"
    property real pixelSize: 0
    property real referencePixelSize: 0
    property color color: "white"
    property bool mirrorX: true
    property real line: 0
    property int morphDuration: 400
    property real morphRoundness: 1.0

    readonly property real actualReferencePixelSize:
        referencePixelSize > 0 ? referencePixelSize : pixelSize

    readonly property real calculatedWidth:
        glyphGen.width

    implicitHeight: pixelSize
    implicitWidth: calculatedWidth

    onPixelSizeChanged: morph.refresh()
    onReferencePixelSizeChanged: morph.refresh()
    onLineChanged: morph.refresh()
    onChChanged: morph.begin()

    Component.onCompleted: morph.refresh()

    Behavior on pixelSize {
        NumberAnimation {
            duration: 200
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: 200
            easing.type: Easing.InOutQuad
        }
    }

    QtObject {
        id: glyphGen

        readonly property var charToTrue: ({
            "0": 7,
            "1": 18,
            "2": 51,
            "3": 53,
            "4": 26,
            "5": 45,
            "6": 23,
            "7": 50,
            "8": 63,
            "9": 58,
            ":": 33
        })

        readonly property var elementMap: ({
            0: [0,1,5,4],
            1: [1,2,6,5],
            2: [2,3,7,6],
            3: [4,5,8,9],
            4: [6,7,10,8],
            5: [8,10,11,9],
            6: [9,11,13,12],
            7: [10,15,14,11],
            8: [12,13,17,16],
            9: [13,14,18,17],
            10:[14,15,19,18]
        })

        readonly property var elements4num: ({
            0:[0,1,2],
            1:[5,3,0],
            2:[2,4,5],
            3:[8,6,5],
            4:[5,7,10],
            5:[10,9,8]
        })

        readonly property real h:
            Math.max(1, pc.pixelSize)

        readonly property real referenceSize:
            Math.max(1, pc.actualReferencePixelSize)

        readonly property real thickness:
            Math.max(0.001, pc.line)

        readonly property real referenceAngle: {
            const ratio = thickness / (referenceSize * Math.sqrt(2))
            const clamped = Math.max(-1, Math.min(1, ratio))
            return Math.PI / 4 + Math.asin(clamped)
        }

        readonly property real sinA:
            Math.sin(referenceAngle)

        readonly property real cosA:
            Math.cos(referenceAngle)

        readonly property real tanA:
            Math.tan(referenceAngle)

        readonly property real cotA:
            1 / tanA

        readonly property real halfThickness:
            thickness / 2

        readonly property real leftInset:
            thickness / sinA

        readonly property real diagonalInset:
            thickness / tanA

        readonly property real width:
            Math.max(
                thickness * 2,
                (h + thickness / cosA) / tanA
            )

        readonly property real middleX:
            width / 2

        readonly property real middleY:
            h / 2

        readonly property real centerLeftPointX:
            diagonalInset
            + (middleY - thickness) / tanA

        readonly property real centerTopPointY:
            thickness
            + tanA * (middleX - (leftInset + diagonalInset))

        readonly property var polygons: (function () {
            const W = glyphGen.width
            const H = glyphGen.h
            const t = glyphGen.thickness
            const a = glyphGen.leftInset
            const b = glyphGen.diagonalInset
            const c = a + b
            const x9 = glyphGen.centerLeftPointX
            const y8 = glyphGen.centerTopPointY

            const p = new Array(20)

            p[0]  = [0, 0]
            p[3]  = [W, 0]
            p[16] = [0, H]
            p[19] = [W, H]

            p[1]  = [a, 0]
            p[2]  = [W - a, 0]
            p[17] = [a, H]
            p[18] = [W - a, H]

            p[4]  = [b, t]
            p[7]  = [W - b, t]
            p[12] = [b, H - t]
            p[15] = [W - b, H - t]

            p[5]  = [c, t]
            p[6]  = [W - c, t]
            p[13] = [c, H - t]
            p[14] = [W - c, H - t]

            p[9]  = [x9, H / 2]
            p[10] = [W - x9, H / 2]

            p[8]  = [W / 2, y8]
            p[11] = [W / 2, H - y8]

            return p
        })()

        property var _cache: ({})

        function clearCache() {
            _cache = {}
        }

        function _sameEdge(a, b) {
            return (a[0] === b[0] && a[1] === b[1])
                || (a[0] === b[1] && a[1] === b[0])
        }

        function _edgeExists(list, edge) {
            for (let i = 0; i < list.length; i++) {
                if (_sameEdge(list[i], edge))
                    return true
            }

            return false
        }

        function _isUniqueEdge(edge, maplines) {
            let seen = 0

            for (const key in maplines) {
                const edges = maplines[key]

                for (let i = 0; i < edges.length; i++) {
                    if (_sameEdge(edge, edges[i])) {
                        if (seen > 0)
                            return false

                        seen += 1
                    }
                }
            }

            return true
        }

        function _point_in_active(point, active_elements) {
            for (const idx in elementMap) {
                if (active_elements[idx]) {
                    const pts = elementMap[idx]

                    for (let i = 0; i < pts.length; i++) {
                        if (pts[i] === point)
                            return true
                    }
                }
            }

            return false
        }

        function _findidx(point, resultus) {
            for (let i = 0; i < resultus.length; i++) {
                if (resultus[i].length === 1
                        && resultus[i][0] === point) {
                    resultus.splice(i, 1)
                    break
                }
            }

            for (let num = 0; num < resultus.length; num++) {
                const arr = resultus[num]

                for (let j = 0; j < arr.length; j++) {
                    if (arr[j] === point)
                        return num
                }
            }

            return -1
        }

        function _paravozik(idx, start, resultus) {
            if (!resultus || resultus.length === 0)
                return []

            const edge = resultus[idx]
            const pos = edge.indexOf(start)

            if (pos !== -1)
                edge.splice(pos, 1)

            const remainder = edge[0]
            const finded_idx = _findidx(remainder, resultus)

            if (finded_idx === -1)
                return [start]

            return [start].concat(
                _paravozik(finded_idx, remainder, resultus)
            )
        }

        function pathForTrueNumber(truenumber) {
            const key = String(truenumber)

            // Во время создания компонента polygons может быть ещё
            // не вычислена — не ломаемся, путь пересчитается в refresh().
            if (!polygons || polygons.length < 20)
                return ""

            if (_cache[key] !== undefined)
                return _cache[key]

            let bits = truenumber.toString(2)

            while (bits.length < 6)
                bits = "0" + bits

            const numlist = bits
                .split("")
                .map(s => parseInt(s, 10))

            const maplines = {}

            for (const i in elementMap) {
                const k = elementMap[i]
                maplines[i] = []

                for (let linenum = 0; linenum < k.length; linenum++) {
                    maplines[i].push([
                        k[linenum],
                        k[(linenum + 1) % 4]
                    ])
                }
            }

            const maplinescategorized = {}

            for (const i in elementMap) {
                maplinescategorized[i] = {
                    u: [],
                    n: []
                }

                const edges = maplines[i]

                for (let linenum = 0; linenum < edges.length; linenum++) {
                    const e = edges[linenum]

                    maplinescategorized[i][
                        _isUniqueEdge(e, maplines) ? "u" : "n"
                    ].push(e)
                }
            }

            const active_elements = {}

            for (let i = 0; i <= 10; i++)
                active_elements[i] = false

            for (let idx = 0; idx < numlist.length; idx++) {
                if (numlist[idx]) {
                    const elements = elements4num[idx]

                    for (let j = 0; j < elements.length; j++) {
                        active_elements[elements[j]] = true
                    }
                }
            }

            const resultus = []

            for (const idx in elementMap) {
                if (active_elements[idx]) {
                    const uedges = maplinescategorized[idx].u

                    for (let i = 0; i < uedges.length; i++) {
                        resultus.push([
                            uedges[i][0],
                            uedges[i][1]
                        ])
                    }
                } else {
                    const nedges = maplinescategorized[idx].n

                    for (let i = 0; i < nedges.length; i++) {
                        const e = nedges[i]
                        const a = e[0]
                        const b = e[1]

                        if (_point_in_active(a, active_elements)
                                || _point_in_active(b, active_elements)) {
                            if (!_edgeExists(resultus, e))
                                resultus.push([a, b])
                        }
                    }
                }
            }

            const resulted_paravozik = []

            while (resultus.length > 0) {
                const sub = _paravozik(
                    0,
                    resultus[0][0],
                    resultus
                )

                if (sub.length >= 2
                        && polygons[sub[0]][0]
                        > polygons[sub[1]][0]) {
                    sub.reverse()
                }

                if (sub.length === 3)
                    sub.reverse()

                resulted_paravozik.push(sub)
            }

            let path = ""

            for (let i = 0; i < resulted_paravozik.length; i++) {
                const chain = resulted_paravozik[i]

                for (let n = 0; n < chain.length; n++) {
                    const pt = polygons[chain[n]]

                    path += (n === 0 ? "M " : "L ")
                    path += pt[0] + "," + pt[1] + " "
                }

                path += "Z "
            }

            _cache[key] = path
            return path
        }

        function pathForChar(ch) {
            const tn = charToTrue[ch]

            if (tn === undefined)
                return ""

            return pathForTrueNumber(tn)
        }
    }

    // Плавный морфинг между глифами: контуры старого и нового
    // символа нормализуются к общему числу точек и интерполируются.
    QtObject {
        id: morph

        property real progress: 1
        property var pairs: []
        property var fromContours: []
        property real fromW: 1
        property real fromH: 1
        property var toContours: []

        onProgressChanged: apply()

        function contoursForChar(c) {
            return parsePath(glyphGen.pathForChar(c))
        }

        function parsePath(str) {
            const contours = []

            if (!str || str.length === 0)
                return contours

            const subs = str.split("M")

            for (let s = 0; s < subs.length; s++) {
                const seg = subs[s].replace("Z", "").trim()

                if (seg.length === 0)
                    continue

                const chunks = seg.split("L")
                const pts = []

                for (let c = 0; c < chunks.length; c++) {
                    const xy = chunks[c].trim().split(/[\s,]+/)

                    if (xy.length < 2)
                        continue

                    const x = parseFloat(xy[0])
                    const y = parseFloat(xy[1])

                    if (!isNaN(x) && !isNaN(y))
                        pts.push([x, y])
                }

                if (pts.length >= 3)
                    contours.push(pts)
            }

            return contours
        }

        function centroid(c) {
            let x = 0
            let y = 0

            for (let i = 0; i < c.length; i++) {
                x += c[i][0]
                y += c[i][1]
            }

            return [x / c.length, y / c.length]
        }

        function signedArea(c) {
            let s = 0

            for (let i = 0; i < c.length; i++) {
                const a = c[i]
                const b = c[(i + 1) % c.length]
                s += a[0] * b[1] - b[0] * a[1]
            }

            return s
        }

        function areaSign(c) {
            return signedArea(c) >= 0 ? 1 : -1
        }

        // Нормированные позиции вершин контура по длине дуги, [0,1).
        // Периметр — замкнутый, включая ребро от последней вершины к первой.
        function normPositions(c) {
            const m = c.length
            const out = [0]
            let acc = 0

            for (let i = 0; i < m - 1; i++) {
                const a = c[i]
                const b = c[i + 1]
                acc += Math.sqrt(
                    (b[0] - a[0]) * (b[0] - a[0])
                    + (b[1] - a[1]) * (b[1] - a[1]))
                out.push(acc)
            }

            const last = c[m - 1]
            const first = c[0]
            const per = acc + Math.sqrt(
                (first[0] - last[0]) * (first[0] - last[0])
                + (first[1] - last[1]) * (first[1] - last[1]))

            if (per > 0) {
                for (let i = 1; i < out.length; i++)
                    out[i] = out[i] / per
            }

            return out
        }

        // Точки контура на заданных нормированных позициях [0,1).
        // Позиция вершины даёт точную вершину, прочие лежат на рёбрах,
        // поэтому форма контура сохраняется точно.
        function sampleAt(c, positions) {
            const m = c.length
            const lens = []
            let per = 0

            for (let i = 0; i < m; i++) {
                const a = c[i]
                const b = c[(i + 1) % m]
                const l = Math.sqrt(
                    (b[0] - a[0]) * (b[0] - a[0])
                    + (b[1] - a[1]) * (b[1] - a[1]))
                lens.push(l)
                per += l
            }

            const out = []
            let seg = 0
            let acc = 0

            for (let k = 0; k < positions.length; k++) {
                if (per <= 0) {
                    out.push([c[0][0], c[0][1]])
                    continue
                }

                const target = positions[k] * per

                while (seg < m - 1 && acc + lens[seg] <= target) {
                    acc += lens[seg]
                    seg++
                }

                const a = c[seg]
                const b = c[(seg + 1) % m]
                const t = lens[seg] > 0 ? (target - acc) / lens[seg] : 0

                out.push([
                    a[0] + (b[0] - a[0]) * t,
                    a[1] + (b[1] - a[1]) * t
                ])
            }

            return out
        }

        // Сдвиг начала обхода b так, чтобы точки b шли в фазе с a —
        // контуры не «закручиваются» при интерполяции.
        function bestRotation(a, b) {
            const n = a.length
            let bestK = 0
            let bestD = Infinity

            for (let k = 0; k < n; k++) {
                let d = 0

                for (let i = 0; i < n; i++) {
                    const p = a[i]
                    const q = b[(i + k) % n]
                    const dx = p[0] - q[0]
                    const dy = p[1] - q[1]
                    d += dx * dx + dy * dy

                    if (d >= bestD)
                        break
                }

                if (d < bestD) {
                    bestD = d
                    bestK = k
                }
            }

            if (bestK === 0)
                return b

            const out = new Array(n)

            for (let i = 0; i < n; i++)
                out[i] = b[(i + bestK) % n]

            return out
        }

        // Сшивает дырки с внешним контуром «замочной скважиной»:
        // глиф становится одним кольцом положительного обхода.
        // Совпадающие рёбра моста геометрически невидимы, а морф
        // одного кольца не порождает оторванных фрагментов при
        // любом правиле заливки.
        function bridgeHoles(cs) {
            const outers = []
            const holes = []

            for (let i = 0; i < cs.length; i++) {
                if (cs[i].length < 3)
                    continue

                if (areaSign(cs[i]) === 1)
                    outers.push(cs[i])
                else
                    holes.push(cs[i])
            }

            for (let h = 0; h < holes.length; h++) {
                const H = holes[h]
                let bo = -1
                let bv = -1
                let bh = 0
                let bd = Infinity

                for (let i = 0; i < outers.length; i++) {
                    for (let j = 0; j < outers[i].length; j++) {
                        for (let k = 0; k < H.length; k++) {
                            const dx = outers[i][j][0] - H[k][0]
                            const dy = outers[i][j][1] - H[k][1]
                            const d = dx * dx + dy * dy

                            if (d < bd) {
                                bd = d
                                bo = i
                                bv = j
                                bh = k
                            }
                        }
                    }
                }

                if (bo === -1)
                    continue

                const ring = []
                const O = outers[bo]

                for (let i = 0; i <= bv; i++)
                    ring.push(O[i])

                for (let i = 0; i < H.length; i++)
                    ring.push(H[(bh + i) % H.length])

                ring.push(H[bh])
                ring.push(O[bv])

                for (let i = bv + 1; i < O.length; i++)
                    ring.push(O[i])

                outers[bo] = ring
            }

            return outers
        }

        function buildPairs(fromCs, toCs) {
            const A = bridgeHoles(fromCs)
            const B = bridgeHoles(toCs)
            const matched = []

            // Жадное сопоставление по близости центроидов, отдельно для
            // каждого знака площади: внешний контур идёт во внешний,
            // дырка — в дырку. Иначе дырка может спариться с внешним
            // контуром и «взорваться» в него. Непарные растворяются.
            for (let s = 0; s < 2; s++) {
                const sign = s === 0 ? 1 : -1
                let again = true

                while (again && A.length > 0 && B.length > 0) {
                    again = false
                    let bi = -1
                    let bj = -1
                    let bd = Infinity

                    for (let i = 0; i < A.length; i++) {
                        if (areaSign(A[i]) !== sign)
                            continue

                        const ca = centroid(A[i])

                        for (let j = 0; j < B.length; j++) {
                            if (areaSign(B[j]) !== sign)
                                continue

                            const cb = centroid(B[j])
                            const dx = ca[0] - cb[0]
                            const dy = ca[1] - cb[1]
                            const d = dx * dx + dy * dy

                            if (d < bd) {
                                bd = d
                                bi = i
                                bj = j
                            }
                        }
                    }

                    if (bi >= 0) {
                        matched.push([A[bi], B[bj]])
                        A.splice(bi, 1)
                        B.splice(bj, 1)
                        again = true
                    }
                }
            }

            // Контур без пары растворяется на месте.
            for (let i = 0; i < A.length; i++)
                matched.push([A[i], null])

            for (let j = 0; j < B.length; j++)
                matched.push([null, B[j]])

            const pairs = []

            for (let k = 0; k < matched.length; k++) {
                let a = matched[k][0]
                let b = matched[k][1]

                // Контур без пары растворяется на месте.
                if (!a) {
                    const c = centroid(b)
                    a = []

                    for (let i = 0; i < 4; i++)
                        a.push([c[0], c[1]])
                } else if (!b) {
                    const c = centroid(a)
                    b = []

                    for (let i = 0; i < 4; i++)
                        b.push([c[0], c[1]])
                }

                // Общие позиции: вершины обоих контуров. Тогда на t=0
                // и t=1 форма воспроизводится точно, без срезанных углов.
                // Почти совпадающие позиции сливаем — меньше дрожания точек.
                const sorted = normPositions(a)
                    .concat(normPositions(b))
                    .sort((x, y) => x - y)

                const all = [sorted[0]]

                for (let i = 1; i < sorted.length; i++) {
                    if (sorted[i] - all[all.length - 1] > 0.001)
                        all.push(sorted[i])
                }

                let ra = sampleAt(a, all)
                let rb = sampleAt(b, all)

                rb = bestRotation(ra, rb)

                // При разном обходе переворачиваем более вырожденный
                // контур — иначе дырка потеряет роль дырки в заливке.
                if (areaSign(ra) !== areaSign(rb)) {
                    if (Math.abs(signedArea(ra))
                            < Math.abs(signedArea(rb)))
                        ra = ra.slice().reverse()
                    else
                        rb = rb.slice().reverse()
                }

                pairs.push([ra, rb])
            }

            return pairs
        }

        function pairT(pr, t) {
            if (pr[2])
                return t * t
            if (pr[3])
                return 1 - (1 - t) * (1 - t)
            return t
        }

        function interpContours(prs, t) {
            const out = []

            for (let k = 0; k < prs.length; k++) {
                const a = prs[k][0]
                const b = prs[k][1]
                const tt = pairT(prs[k], t)
                const c = []

                for (let i = 0; i < a.length; i++) {
                    c.push([
                        a[i][0] + (b[i][0] - a[i][0]) * tt,
                        a[i][1] + (b[i][1] - a[i][1]) * tt
                    ])
                }

                out.push(c)
            }

            return out
        }

        // Путь контура с углами, скруглёнными радиусом r. Дуга угла —
        // квадратичная кривая (a, p, b), разбитая на отрезки: путь
        // содержит только M/L/Z и не зависит от поддержки Q в PathSvg.
        function roundedPath(c, r) {
            const n = c.length
            let s = ""

            for (let i = 0; i < n; i++) {
                const p = c[i]
                const prev = c[(i + n - 1) % n]
                const next = c[(i + 1) % n]

                const d1 = Math.sqrt(
                    (p[0] - prev[0]) * (p[0] - prev[0])
                    + (p[1] - prev[1]) * (p[1] - prev[1]))
                const d2 = Math.sqrt(
                    (next[0] - p[0]) * (next[0] - p[0])
                    + (next[1] - p[1]) * (next[1] - p[1]))

                const t1 = d1 > 1e-9
                    ? Math.min(r, d1 * 0.45) / d1 : 0
                const t2 = d2 > 1e-9
                    ? Math.min(r, d2 * 0.45) / d2 : 0

                const ax = p[0] + (prev[0] - p[0]) * t1
                const ay = p[1] + (prev[1] - p[1]) * t1
                const bx = p[0] + (next[0] - p[0]) * t2
                const by = p[1] + (next[1] - p[1]) * t2

                s += (i === 0 ? "M " : "L ")
                    + ax.toFixed(2) + "," + ay.toFixed(2) + " "

                if (r > 0.05) {
                    for (let k = 1; k <= 3; k++) {
                        const u = k / 3
                        const v = 1 - u
                        const qx = v * v * ax
                            + 2 * v * u * p[0]
                            + u * u * bx
                        const qy = v * v * ay
                            + 2 * v * u * p[1]
                            + u * u * by

                        s += "L " + qx.toFixed(2) + "," + qy.toFixed(2) + " "
                    }
                } else {
                    s += "L " + bx.toFixed(2) + "," + by.toFixed(2) + " "
                }
            }

            return s + "Z "
        }

        function interpPairs(prs, t) {
            // Скругление живёт только в середине анимации:
            // у краёв (t=0, t=1) форма точно совпадает с глифами.
            const round = pc.morphRoundness
                * glyphGen.thickness
                * Math.sin(Math.PI * t)

            let s = ""

            for (let k = 0; k < prs.length; k++) {
                const a = prs[k][0]
                const b = prs[k][1]
                const tt = pairT(prs[k], t)
                const c = []

                for (let i = 0; i < a.length; i++) {
                    c.push([
                        a[i][0] + (b[i][0] - a[i][0]) * tt,
                        a[i][1] + (b[i][1] - a[i][1]) * tt
                    ])
                }

                s += roundedPath(c, round)
            }

            return s
        }

        function begin() {
            const prev = (pairs.length > 0 && progress < 1)
                ? interpContours(pairs, progress)
                : toContours

            toContours = contoursForChar(pc.ch)

            // Прежней формы нет (первое появление) — без морфа.
            if (prev.length === 0) {
                pairs = []
                progress = 1
                apply()
                return
            }

            fromContours = prev
            fromW = glyphGen.width
            fromH = glyphGen.h
            pairs = buildPairs(fromContours, toContours)

            morphAnim.stop()
            progress = 0
            apply()

            if (pairs.length > 0)
                morphAnim.restart()
        }

        function refresh() {
            glyphGen.clearCache()
            toContours = contoursForChar(pc.ch)

            if (pairs.length > 0 && progress < 1) {
                // Масштабируем замороженные контуры под новую геометрию.
                const sx = fromW > 0 ? glyphGen.width / fromW : 1
                const sy = fromH > 0 ? glyphGen.h / fromH : 1
                const scaled = []

                for (let i = 0; i < fromContours.length; i++) {
                    const c = fromContours[i]
                    const sc = []

                    for (let j = 0; j < c.length; j++)
                        sc.push([c[j][0] * sx, c[j][1] * sy])

                    scaled.push(sc)
                }

                fromContours = scaled
                fromW = glyphGen.width
                fromH = glyphGen.h
                pairs = buildPairs(fromContours, toContours)
            } else {
                progress = 1
            }

            apply()
        }

        function apply() {
            if (pairs.length > 0 && progress < 1)
                svgPath.path = interpPairs(pairs, progress)
            else
                svgPath.path = glyphGen.pathForChar(pc.ch)
        }
    }

    NumberAnimation {
        id: morphAnim
        target: morph
        property: "progress"
        from: 0
        to: 1
        duration: pc.morphDuration
        easing.type: Easing.InOutQuad
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        transform: [
            Scale {
                origin.x: 0
                origin.y: 0
                xScale: pc.mirrorX ? -1 : 1
                yScale: 1
            },
            Translate {
                x: pc.mirrorX ? pc.width : 0
                y: 0
            }
        ]

        ShapePath {
            fillColor: pc.color
            strokeColor: "transparent"
            // Ненулевое правило: самопересечения при морфинге
            // не превращаются в дырки, а дырки глифов сохраняются.
            fillRule: ShapePath.WindingFill

            PathSvg {
                id: svgPath
                path: glyphGen.pathForChar(pc.ch)
            }
        }
    }
    Timer {
        id: delayTimer
        interval: 1000
        running: true
        repeat: false

        onTriggered: morph.refresh()
    }
    Behavior on color {
        ColorAnimation {
            duration: 250
        }
    }
}
