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

    readonly property real actualReferencePixelSize:
        referencePixelSize > 0 ? referencePixelSize : pixelSize

    readonly property real calculatedWidth:
        glyphGen.width

    implicitHeight: pixelSize
    implicitWidth: calculatedWidth

    onPixelSizeChanged: glyphGen.clearCache()
    onReferencePixelSizeChanged: glyphGen.clearCache()
    onLineChanged: glyphGen.clearCache()
    onChChanged: svgPath.path = glyphGen.pathForChar(pc.ch)

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
            svgPath.path = pathForChar(pc.ch)
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
            fillRule: ShapePath.OddEvenFill

            PathSvg {
                id: svgPath
                path: glyphGen.pathForChar(pc.ch)
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: 250
        }
    }
}