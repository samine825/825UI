import QtQuick
import QtQuick.Shapes

Item {
    id: clockRoot

    property bool isHovered: false
    property bool showSeconds: Settings.secondsMode === 2 || (Settings.secondsMode === 1 && isHovered)

    property date currentTime: new Date()

    property real fontsize: Settings.barHeight / (2*(150/1000)+1)
    property real hvost: (313.856/1000) * fontsize

    width: textContainer.width + (hvost * 2)
    height: Settings.barHeight + Settings.barGap * 2

    // --- ПРОЦЕДУРНЫЙ ГЕНЕРАТОР ГЛИФОВ (порт твоего python) ---
    QtObject {
        id: glyphGen

        readonly property int l: 1000
        readonly property int d: 150

        // truenumber из твоего перебора + ":" = 33 (как ты попросил)
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

        readonly property var polygons: (function () {
            const L = glyphGen.l
            const d = glyphGen.d
            const p = new Array(20)
            for (let i = 0; i < 20; i++) p[i] = [0, 0]

            // 1
            p[0]  = [0, 0]
            p[3]  = [L, 0]
            p[16] = [0, L]
            p[19] = [L, L]

            // 2
            const hyp = (L/2) * Math.sqrt(2)
            const katet = d/2
            const angle = Math.PI/2 - Math.acos(katet/hyp) + Math.PI/4
            const iskomoe = L - (L/Math.tan(angle))

            p[1]  = [iskomoe, 0]
            p[2]  = [L - iskomoe, 0]
            p[17] = [iskomoe, L]
            p[18] = [L - iskomoe, L]

            // 3
            const hzk = d/Math.tan(angle)
            p[4]  = [hzk, d]
            p[7]  = [L - hzk, d]
            p[12] = [hzk, L - d]
            p[15] = [L - hzk, L - d]

            // 4
            p[5]  = [hzk + iskomoe, d]
            p[6]  = [L - hzk - iskomoe, d]
            p[13] = [hzk + iskomoe, L - d]
            p[14] = [L - hzk - iskomoe, L - d]

            // 5
            const tri2 = (L/2)/Math.tan(angle)
            p[9]  = [tri2, L/2]
            p[10] = [L - tri2, L/2]

            // 6
            const tri3 = (L/2)/Math.tan(Math.PI/2 - angle)
            p[8]  = [L/2, L - tri3]
            p[11] = [L/2, tri3]

            return p
        })()

        property var _cache: ({})

        function _sameEdge(a, b) {
            return (a[0] === b[0] && a[1] === b[1]) || (a[0] === b[1] && a[1] === b[0])
        }

        function _edgeExists(list, edge) {
            for (let i = 0; i < list.length; i++)
                if (_sameEdge(list[i], edge)) return true
            return false
        }

        function _isUniqueEdge(edge, maplines) {
            let seen = 0
            for (const key in maplines) {
                const edges = maplines[key]
                for (let i = 0; i < edges.length; i++) {
                    if (_sameEdge(edge, edges[i])) {
                        if (seen > 0) return false
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
                    for (let i = 0; i < pts.length; i++)
                        if (pts[i] === point) return true
                }
            }
            return false
        }

        // findidx (порт python, включая удаление singleton [point])
        function _findidx(point, resultus) {
            for (let i = 0; i < resultus.length; i++) {
                if (resultus[i].length === 1 && resultus[i][0] === point) {
                    resultus.splice(i, 1)
                    break
                }
            }
            for (let num = 0; num < resultus.length; num++) {
                const arr = resultus[num]
                for (let j = 0; j < arr.length; j++)
                    if (arr[j] === point) return num
            }
            return -1
        }

        function _paravozik(idx, start, resultus) {
            if (!resultus || resultus.length === 0) return []
            const edge = resultus[idx]
            const pos = edge.indexOf(start)
            if (pos !== -1) edge.splice(pos, 1)

            const remainder = edge[0]
            const finded_idx = _findidx(remainder, resultus)
            if (finded_idx === -1) return [start]
            return [start].concat(_paravozik(finded_idx, remainder, resultus))
        }

        function pathForTrueNumber(truenumber) {
            const key = String(truenumber)
            if (_cache[key] !== undefined) return _cache[key]

            let bits = truenumber.toString(2)
            while (bits.length < 6) bits = "0" + bits
            const numlist = bits.split("").map(s => parseInt(s, 10))

            // maplines
            const maplines = {}
            for (const i in elementMap) {
                const k = elementMap[i]
                maplines[i] = []
                for (let linenum = 0; linenum < k.length; linenum++)
                    maplines[i].push([k[linenum], k[(linenum + 1) % 4]])
            }

            // categorize edges unique/non-unique
            const maplinescategorized = {}
            for (const i in elementMap) {
                maplinescategorized[i] = { u: [], n: [] }
                const edges = maplines[i]
                for (let linenum = 0; linenum < edges.length; linenum++) {
                    const e = edges[linenum]
                    maplinescategorized[i][_isUniqueEdge(e, maplines) ? "u" : "n"].push(e)
                }
            }

            const active_elements = {}
            for (let i = 0; i <= 10; i++) active_elements[i] = false

            // активируем элементы (6 -> 11)
            for (let idx = 0; idx < numlist.length; idx++) {
                if (numlist[idx]) {
                    const elements = elements4num[idx]
                    for (let j = 0; j < elements.length; j++)
                        active_elements[elements[j]] = true
                }
            }

            // resultus
            const resultus = []
            for (const idx in elementMap) {
                if (active_elements[idx]) {
                    const uedges = maplinescategorized[idx].u
                    for (let i = 0; i < uedges.length; i++)
                        resultus.push([uedges[i][0], uedges[i][1]])
                } else {
                    const nedges = maplinescategorized[idx].n
                    for (let i = 0; i < nedges.length; i++) {
                        const e = nedges[i]
                        const a = e[0], b = e[1]
                        if (_point_in_active(a, active_elements) || _point_in_active(b, active_elements)) {
                            if (!_edgeExists(resultus, e))
                                resultus.push([a, b])
                        }
                    }
                }
            }

            // paravozik
            const resulted_paravozik = []
            while (resultus.length > 0) {
                const sub = _paravozik(0, resultus[0][0], resultus)

                if (sub.length >= 2 && polygons[sub[0]][0] > polygons[sub[1]][0])
                    sub.reverse()
                if (sub.length === 3)
                    sub.reverse()

                resulted_paravozik.push(sub)
            }

            // svg-path
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
            if (tn === undefined) return ""
            return pathForTrueNumber(tn)
        }
    }

    // --- символ ---
    component ProcChar: Item {
        id: pc
        property string ch: "0"
        property real pixelSize: 10
        property color color: "white"

        // отражение по X (нужно тебе)
        property bool mirrorX: true


        implicitHeight: pixelSize
        implicitWidth: pixelSize

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // ВАЖНО: правильное зеркало для координат 0..1000 без клипа
            transform: [
                Scale {
                    origin.x: 0
                    origin.y: 0
                    xScale: (pc.mirrorX ? -1 : 1) * (pc.width / 1000)
                    yScale: (pc.height / 1000)
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
                PathSvg { path: glyphGen.pathForChar(pc.ch) }
            }
        }
    }

    Item {
        id: textContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        property string mainStr: Qt.formatTime(clockRoot.currentTime, "HH:mm")
        property string secStr: Qt.formatTime(clockRoot.currentTime, ":ss")

        width: mainRow.implicitWidth + secWrapper.width
        height: parent.height

        Row {
            id: mainRow
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: textContainer.mainStr.split("")
                delegate: ProcChar {
                    ch: modelData
                    pixelSize: clockRoot.fontsize
                    color: Settings.c1
                    mirrorX: true
                }
            }
        }

        Item {
            id: secWrapper
            anchors.left: mainRow.right
            anchors.verticalCenter: parent.verticalCenter

            height: secRow.implicitHeight
            width: clockRoot.showSeconds ? secRow.implicitWidth : 0
            clip: true

            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            Row {
                id: secRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: textContainer.secStr.split("")
                    delegate: ProcChar {
                        ch: modelData
                        pixelSize: clockRoot.fontsize
                        color: Settings.c1
                        mirrorX: true
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: clockRoot.isHovered = true
        onExited: clockRoot.isHovered = false
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockRoot.currentTime = new Date()
    }
}