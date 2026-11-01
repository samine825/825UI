import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Fonts"
import "../Components"
import "../"

Item {
    id: r

    // Полная динамическая ширина всей панели: строка элементов + скосы по краям
    width: statsRow.implicitWidth + root.point * 2
    height: Settings.barHeight

    Item {
        id: root
        x: Settings.barGap + Settings.line * InfexGeometry.edgeMult * 1.5
        width: parent.width
        height: Settings.barHeight
        anchors.verticalCenter: parent.verticalCenter

        property string cpuText: "CPU --%"
        property string tempText: "TEMP --°C"
        property string ramText: "RAM --.-/--.- GB"

        // доли заполнения секций снизу вверх: cpu и ram — сами проценты,
        // температура — от 0 до 100°C
        property real cpuFraction: 0
        property real tempFraction: 0
        property real ramFraction: 0

        property double previousTotal: 0
        property double previousIdle: 0

        readonly property real point: height * InfexGeometry.notchFrac

        // горизонтальный отступ кромки заливки от оси перегородки:
        // полторы линии по перпендикуляру диагонали — обводка (линия)
        // плюс зазор-тень (линия), как у внутренней тени фрейма
        readonly property real gapDx: 1.5 * Settings.line
            * Math.sqrt(1 + Math.pow(2 * point / height, 2))

        // x на диагонали перегородки (dvx — её левый край в координатах
        // фрейма) на высоте y. Диагональ идёт от (dvx + point, line/2)
        // через вершину (dvx, H/2) к (dvx + point, H − line/2)
        function diagX(dvx, y) {
            const H = statsFrame.height
            const mid = H / 2
            const top = Settings.line / 2
            const bot = H - Settings.line / 2

            if (y <= mid)
                return dvx + root.point * (mid - y) / (mid - top)

            return dvx + root.point * (y - mid) / (bot - mid)
        }

        // x левой грани силуэта на высоте y: выемка контура — вершина
        // на mid, сдвинутая внутрь на point. Формулы те же, что у
        // HexContour силуэта (inset = line/2, shift = 0), поэтому
        // кромка заливки прячется точно под обводку — маска не нужна
        // (Shape внутри layer у части драйверов не рендерится)
        function leftEdgeX(y) {
            const H = statsFrame.height
            const t = Settings.line / 2
            const b = H - t
            const mid = H / 2

            if (y <= mid)
                return t + root.point * (y - t) / (mid - t)

            return t + root.point * (b - y) / (b - mid)
        }

        // x правой грани силуэта — зеркально
        function rightEdgeX(y) {
            const H = statsFrame.height
            const W = statsFrame.width
            const t = Settings.line / 2
            const b = H - t
            const mid = H / 2

            if (y <= mid)
                return W - t - root.point * (y - t) / (mid - t)

            return W - t - root.point * (b - y) / (b - mid)
        }

        // контур заливки секции ниже уровня level, обрезанный точно
        // по силуэту фрейма: верхняя кромка — уровень, бока —
        // диагонали перегородок с отступом под тень (null — грань
        // силуэта), низ и края — по контуру HexContour
        function sectionPath(leftDv, rightDv, level) {
            const H = statsFrame.height
            const mid = H / 2
            const t = Settings.line / 2
            const b = H - t
            const f = function (v) { return v.toFixed(2) }

            // уровень не выше верхней грани силуэта; выше внутренней
            // грани нижней обводки заливки нет
            const lv = Math.max(level, t)
            if (lv >= H - Settings.line)
                return "M 0,0"

            const xl = leftDv === null ? leftEdgeX(lv) : diagX(leftDv, lv)
            const xr = rightDv === null ? rightEdgeX(lv) : diagX(rightDv, lv)

            let s = "M " + f(xl) + "," + f(lv)
                + " L " + f(xr) + "," + f(lv)

            // правая кромка вниз до дна силуэта
            if (rightDv === null) {
                if (lv < mid)
                    s += " L " + f(rightEdgeX(mid)) + "," + f(mid)

                s += " L " + f(rightEdgeX(b)) + "," + f(b)
            } else {
                if (lv < mid)
                    s += " L " + f(diagX(rightDv, mid)) + "," + f(mid)

                s += " L " + f(diagX(rightDv, b)) + "," + f(b)
            }

            // низ и левая кромка вверх до уровня
            if (leftDv === null) {
                s += " L " + f(leftEdgeX(b)) + "," + f(b)

                if (lv < mid)
                    s += " L " + f(leftEdgeX(mid)) + "," + f(mid)
            } else {
                s += " L " + f(diagX(leftDv, b)) + "," + f(b)

                if (lv < mid)
                    s += " L " + f(diagX(leftDv, mid)) + "," + f(mid)
            }

            return s + " Z"
        }

        // границы фрейма = видимому внешнему краю обводки
        // (старая обводка выпирала на пол-линию — компенсируем ростом).
        // Весь контент — дети фрейма: строка (текст c1 и перегородки)
        // под заливками, над ними копии текста c2 в полосе заливки;
        // обводка и внутренняя тень (z:1) поверх всего. Маска не нужна
        // — контуры заливок обрезаны аналитически по силуэту
        SFrame {
            id: statsFrame

            x: -Settings.line / 2
            y: -Settings.line / 2
            width: parent.width + Settings.line
            height: parent.height + Settings.line
            shadowOverContent: true
            contentMasked: false

            // === строка контента: адаптивные ячейки и перегородки ===
            // базовый текст c1 — под заливками: там, где проходит
            // заливка, его показывают инвертированные копии ниже
            Row {
                id: statsRow
                anchors.centerIn: parent
                spacing: 0

                // --- [ЯЧЕЙКА 1: CPU] ---
                Item {
                    id: cpuCell

                    width: cpuItem.implicitWidth + Settings.line * 6
                    height: root.height

                    SText {
                        id: cpuItem

                        anchors.centerIn: parent
                        text: root.cpuText
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // --- [ПЕРЕГОРОДКА 1: разметка раскладки] ---
                // сама перегородка рисуется над фреймом (div1Shape):
                // её c1 проходит поверх внутренней тени основы
                Item {
                    id: div1

                    width: root.point // Ширина равна шагу наклона, чтобы не было наложений
                    height: root.height
                }

                // --- [ЯЧЕЙКА 2: TEMP] ---
                Item {
                    id: tempCell

                    width: tempItem.implicitWidth + Settings.line * 6
                    height: root.height

                    SText {
                        id: tempItem

                        anchors.centerIn: parent
                        text: root.tempText
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // --- [ПЕРЕГОРОДКА 2: разметка раскладки] ---
                Item {
                    id: div2

                    width: root.point
                    height: root.height
                }

                // --- [ЯЧЕЙКА 3: RAM] ---
                Item {
                    id: ramCell

                    width: ramItem.implicitWidth + Settings.line * 6
                    height: root.height

                    SText {
                        id: ramItem

                        anchors.centerIn: parent
                        text: root.ramText
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // === заливка CPU ===
            // id обязателен: биндинг PathSvg живёт внутри SShapePath —
            // чужого компонента, — через границу видны только id
            Item {
                id: cpuFill

                anchors.fill: parent

                // y верхней кромки заливки в координатах фрейма: ход от
                // внутренней грани нижней обводки (0%) до внутренней
                // грани верхней (100%) — видимое заполнение равно точной
                // доле метрики от внутренней высоты; анимируется
                property real level:
                    parent.height - Settings.line
                    - root.cpuFraction
                        * (parent.height - 2 * Settings.line)

                Behavior on level {
                    NumberAnimation {
                        duration: Settings.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        fillColor: Settings.c1
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: root.sectionPath(null,
                                statsRow.x + div1.x - root.gapDx,
                                cpuFill.level)
                        }
                    }
                }
            }

            // === заливка TEMP ===
            Item {
                id: tempFill

                anchors.fill: parent

                property real level:
                    parent.height - Settings.line
                    - root.tempFraction
                        * (parent.height - 2 * Settings.line)

                Behavior on level {
                    NumberAnimation {
                        duration: Settings.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        fillColor: Settings.c1
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: root.sectionPath(
                                statsRow.x + div1.x + root.gapDx,
                                statsRow.x + div2.x - root.gapDx,
                                tempFill.level)
                        }
                    }
                }
            }

            // === заливка RAM ===
            Item {
                id: ramFill

                anchors.fill: parent

                property real level:
                    parent.height - Settings.line
                    - root.ramFraction
                        * (parent.height - 2 * Settings.line)

                Behavior on level {
                    NumberAnimation {
                        duration: Settings.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        fillColor: Settings.c1
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: root.sectionPath(
                                statsRow.x + div2.x + root.gapDx,
                                null,
                                ramFill.level)
                        }
                    }
                }
            }

            // === инвертированный контент (паттерн слайдеров панели
            // управления): полоса-клип от уровня заливки до дна, внутри
            // — полноразмерный слепок зоны с текстом c2. Виден только
            // там, где под ним заливка; базовый текст c1 прикрыт ею

            // --- [CPU] ---
            Item {
                id: cpuCopy

                x: statsRow.x + cpuCell.x
                y: cpuFill.level
                width: cpuCell.width
                height: statsFrame.height - cpuFill.level
                clip: true

                Item {
                    width: parent.width
                    height: statsFrame.height
                    y: -cpuFill.level

                    SText {
                        anchors.centerIn: parent
                        text: root.cpuText
                        color: Settings.c2
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // --- [TEMP] ---
            Item {
                id: tempCopy

                x: statsRow.x + tempCell.x
                y: tempFill.level
                width: tempCell.width
                height: statsFrame.height - tempFill.level
                clip: true

                Item {
                    width: parent.width
                    height: statsFrame.height
                    y: -tempFill.level

                    SText {
                        anchors.centerIn: parent
                        text: root.tempText
                        color: Settings.c2
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // --- [RAM] ---
            Item {
                id: ramCopy

                x: statsRow.x + ramCell.x
                y: ramFill.level
                width: ramCell.width
                height: statsFrame.height - ramFill.level
                clip: true

                Item {
                    width: parent.width
                    height: statsFrame.height
                    y: -ramFill.level

                    SText {
                        anchors.centerIn: parent
                        text: root.ramText
                        color: Settings.c2
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // перегородки c1 — НАД фреймом: их обводка рендерится поверх
        // внутренней тени основы (c2) и не режется ею у краёв; зазоры-
        // тени вокруг перегородок (отступ заливок) остаются под ней.
        // Позиции берутся из раскладки строки; координаты корня —
        // строка живёт во фрейме, тот сдвинут на пол-линии
        Shape {
            id: div1Shape

            x: statsRow.x + div1.x - Settings.line / 2
            y: statsRow.y - Settings.line / 2
            width: root.point
            height: root.height
            preferredRendererType: Shape.CurveRenderer

            SShapePath {
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap
                strokeColor: Settings.c1
                strokeWidth: Settings.line
                fillColor: "transparent"

                startX: root.point
                startY: 0
                PathLine { x: 0; y: root.height / 2 }
                PathLine { x: root.point; y: root.height }
            }
        }

        Shape {
            id: div2Shape

            x: statsRow.x + div2.x - Settings.line / 2
            y: statsRow.y - Settings.line / 2
            width: root.point
            height: root.height
            preferredRendererType: Shape.CurveRenderer

            SShapePath {
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap
                strokeColor: Settings.c1
                strokeWidth: Settings.line
                fillColor: "transparent"

                startX: root.point
                startY: 0
                PathLine { x: 0; y: root.height / 2 }
                PathLine { x: root.point; y: root.height }
            }
        }

        // Логика сбора метрик (Bash скрипт)
        Process {
            id: statsProcess
            command: [
                "bash", "-c",
                "cpu=$(awk '/^cpu / { idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; printf \"%d %d\", total, idle }' /proc/stat); " +
                "mem=$(awk '/MemTotal:/ {total=$2} /MemAvailable:/ {available=$2} END {printf \"%d %d\", total-available, total}' /proc/meminfo); " +
                "temp=; " +
                "for hw in /sys/class/hwmon/hwmon*; do " +
                    "[ -r \"$hw/name\" ] || continue; name=$(cat \"$hw/name\" 2>/dev/null); " +
                    "case \"$name\" in coretemp|k10temp|zenpower|fam15h_power) " +
                        "for input in \"$hw\"/temp*_input; do " +
                            "[ -r \"$input\" ] || continue; num=${input##*temp}; num=${num%_input}; " +
                            "label=; [ -r \"$hw/temp${num}_label\" ] && label=$(cat \"$hw/temp${num}_label\" 2>/dev/null); " +
                            "case \"$label\" in Package*|Tctl*|Tdie*|CPU*|Core*|\"\") temp=$(cat \"$input\" 2>/dev/null); [ -n \"$temp\" ] && break 2; ;; esac; " +
                        "done; ;; esac; " +
                "done; " +
                "if [ -z \"$temp\" ]; then " +
                    "for z in /sys/class/thermal/thermal_zone*; do " +
                        "[ -r \"$z/type\" ] || continue; [ -r \"$z/temp\" ] || continue; type=$(cat \"$z/type\" 2>/dev/null); " +
                        "case \"$type\" in *cpu*|*CPU*|*Core*|*core*|x86_pkg_temp*|k10temp*|coretemp*) temp=$(cat \"$z/temp\" 2>/dev/null); [ -n \"$temp\" ] && break; ;; esac; " +
                    "done; " +
                "fi; " +
                "printf \"CPU %s %s\\nRAM %s %s\\nTEMP %s\\n\" $cpu $mem ${temp:--1}"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    var text = this.text.trim()
                    if (!text) return
                    var cpuMatch = text.match(/CPU\s+(\d+)\s+(\d+)/)
                    var ramMatch = text.match(/RAM\s+(\d+)\s+(\d+)/)
                    var tempMatch = text.match(/TEMP\s+(-?\d+)/)

                    if (cpuMatch) {
                        var cpuTotal = Number(cpuMatch[1])
                        var cpuIdle = Number(cpuMatch[2])
                        if (root.previousTotal > 0) {
                            var deltaTotal = cpuTotal - root.previousTotal
                            var deltaIdle = cpuIdle - root.previousIdle
                            if (deltaTotal > 0) {
                                var usage = (1 - deltaIdle / deltaTotal) * 100
                                var cpuPct = Math.round(Math.max(0, Math.min(100, usage)))
                                root.cpuText = "CPU " + cpuPct + "%"
                                root.cpuFraction = cpuPct / 100
                            }
                        }
                        root.previousTotal = cpuTotal; root.previousIdle = cpuIdle
                    }
                    if (ramMatch) {
                        var usedKiB = Number(ramMatch[1])
                        var totalKiB = Number(ramMatch[2])
                        if (totalKiB > 0) {
                            var usedGiB = usedKiB / 1024 / 1024
                            var totalGiB = totalKiB / 1024 / 1024
                            root.ramText = "RAM " + usedGiB.toFixed(1) + "/" + totalGiB.toFixed(1) + " GB"
                            root.ramFraction = Math.max(0, Math.min(1, usedKiB / totalKiB))
                        }
                    }
                    if (tempMatch) {
                        var rawTemp = Number(tempMatch[1])
                        if (rawTemp >= 0) {
                            var deg = rawTemp >= 1000 ? rawTemp / 1000 : rawTemp
                            root.tempText = "TEMP " + Math.round(deg) + "°C"
                            root.tempFraction = Math.max(0, Math.min(1, deg / 100))
                        } else {
                            root.tempText = "TEMP --°C"
                            root.tempFraction = 0
                        }
                    }
                }
            }
        }

        Timer {
            interval: 1000; repeat: true; running: true; triggeredOnStart: true
            onTriggered: if (!statsProcess.running) statsProcess.running = true
        }
    }
}
