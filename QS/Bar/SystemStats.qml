import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Fonts"
import "../Components"
import "../"

// Статистика бара — паровозик из трёх InfexBox: CPU, TEMP, RAM.
// Каждый вагон — самостоятельный элемент со своей заливкой снизу
// и инверсией контента; стыки — пары рёбер Tab/Notch, совпадающие
// поточечно, потому что глубина выемки — чистая функция высоты.
// Разделители и аналитика силуэта всего блока больше не нужны:
// обводка стыка — это обводки рёбер двух соседей на одной линии,
// заливка каждого вагона клипается собственным контуром.
//
// Геометрия совместима со старым блоком 1:1: логические границы —
// ячейка + зона стыка (point), внешние рёбра крайних вагонов —
// выемки фрейма; боксы расширены на line и сдвинуты на пол-линии,
// так что видимый внешний край и диагонали стыков лежат там же,
// где были; зазоры заливок от стыков (gapDx — полторы линии по
// перпендикуляру диагонали) сохранены.
Item {
    id: r

    // тестовый хук: статические фракции для пиксельного сравнения
    // (отрицательные — жить на реальных метриках)
    property real debugCpu: -1
    property real debugTemp: -1
    property real debugRam: -1

    width: cpuCar.width + tempCar.width + ramCar.width
        - 2 * Settings.line
    height: Settings.barHeight

    Item {
        id: root
        x: Settings.barGap + Settings.line * InfexGeometry.edgeMult * 1.5
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Settings.barHeight

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

        // шаг выемки стыков и торцов (как у SFrame)
        readonly property real point:
            Settings.barHeight * InfexGeometry.notchFrac

        // ширина ячеек: реальная ширина текста + по 3 линии с каждой
        // стороны (скрытые SText — точный источник, TextMetrics занижал)
        readonly property real cpuW: cpuItem.implicitWidth
            + Settings.line * 6
        readonly property real tempW: tempItem.implicitWidth
            + Settings.line * 6
        readonly property real ramW: ramItem.implicitWidth
            + Settings.line * 6

        // логическая ширина паровозика: ячейки + зоны стыков
        readonly property real logicalWidth:
            cpuW + point + tempW + point + ramW


        // горизонтальный отступ кромки заливки от стыка:
        // полторы линии по перпендикуляру диагонали — обводка
        // плюс зазор-тень, как у внутренней тени фрейма
        readonly property real gapDx: 1.5 * Settings.line
            * Math.sqrt(1 + Math.pow(2 * point / height, 2))

        // эталонные тексты: дают точный implicitWidth рендера
        SText {
            id: cpuItem

            visible: false
            text: root.cpuText
            font.pixelSize: Settings.textSm
            font.bold: true
        }

        SText {
            id: tempItem

            visible: false
            text: root.tempText
            font.pixelSize: Settings.textSm
            font.bold: true
        }

        SText {
            id: ramItem

            visible: false
            text: root.ramText
            font.pixelSize: Settings.textSm
            font.bold: true
        }

        // === вагон 1: CPU. Левая выемка фрейма врезается на point,
        // стык справа — Notch: диагональ уходит влево к середине,
        // как у старого разделителя ===
        InfexBox {
            id: cpuCar

            // рамка до края бокса: стыки совпадают поточечно
            // только при нулевой узкости
            sideInset: 0

            shadowOuterRight: false

            x: 0
            y: -Settings.line / 2
            width: root.cpuW + 2 * root.point + Settings.line
            height: Settings.barHeight + Settings.line

            edgeLeft: "Notch"
            edgeRight: "Notch"
            fillGapLeft: 0
            fillGapRight: Settings.line

            fillFraction: r.debugCpu >= 0
                ? r.debugCpu : root.cpuFraction

            Behavior on fillFraction {
                NumberAnimation {
                    duration: Settings.animSlow
                    easing.type: Easing.InOutQuad
                }
            }

            content: Component {
                Item {
                    id: cpuContent

                    property bool inverted: false

                    width: root.cpuW
                    height: Settings.barHeight

                    SText {
                        anchors.centerIn: parent
                        text: root.cpuText
                        color: cpuContent.inverted
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // === вагон 2: TEMP. Стыки: слева Tab (заполняет выемку
        // CPU), справа Notch ===
        InfexBox {
            id: tempCar

            // рамка до края бокса: стыки совпадают поточечно
            // только при нулевой узкости
            sideInset: 0

            shadowOuterLeft: false
            shadowOuterRight: false

            x: cpuCar.width - Settings.line
            y: -Settings.line / 2
            width: root.tempW + root.point + Settings.line
            height: Settings.barHeight + Settings.line

            edgeLeft: "Tab"
            edgeRight: "Notch"
            fillGapLeft: Settings.line
            fillGapRight: Settings.line

            fillFraction: r.debugTemp >= 0
                ? r.debugTemp : root.tempFraction

            Behavior on fillFraction {
                NumberAnimation {
                    duration: Settings.animSlow
                    easing.type: Easing.InOutQuad
                }
            }

            content: Component {
                Item {
                    id: tempContent

                    property bool inverted: false

                    width: root.tempW
                    height: Settings.barHeight

                    SText {
                        anchors.centerIn: parent
                        text: root.tempText
                        color: tempContent.inverted
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // === вагон 3: RAM. Стык слева — Tab, правый торец —
        // выемка фрейма ===
        InfexBox {
            id: ramCar

            // рамка до края бокса: стыки совпадают поточечно
            // только при нулевой узкости
            sideInset: 0

            shadowOuterLeft: false

            x: cpuCar.width + tempCar.width - 2 * Settings.line
            y: -Settings.line / 2
            width: root.ramW + root.point + Settings.line
            height: Settings.barHeight + Settings.line

            edgeLeft: "Tab"
            edgeRight: "Notch"
            fillGapLeft: Settings.line
            fillGapRight: 0

            fillFraction: r.debugRam >= 0
                ? r.debugRam : root.ramFraction

            Behavior on fillFraction {
                NumberAnimation {
                    duration: Settings.animSlow
                    easing.type: Easing.InOutQuad
                }
            }

            content: Component {
                Item {
                    id: ramContent

                    property bool inverted: false

                    width: root.ramW
                    height: Settings.barHeight

                    SText {
                        anchors.centerIn: parent
                        text: root.ramText
                        color: ramContent.inverted
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                        verticalAlignment: Text.AlignVCenter
                    }
                }
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
