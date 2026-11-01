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

        // границы фрейма = видимому внешнему краю обводки
        // (старая обводка выпирала на пол-линии — компенсируем ростом).
        // Заливки секций — дети фрейма: маска силуэта режет их по
        // контуру, внутренняя тень и обводка лежат поверх (как
        // обложка в плеере панели управления)
        SFrame {
            x: -Settings.line / 2
            y: -Settings.line / 2
            width: parent.width + Settings.line
            height: parent.height + Settings.line
            shadowOverContent: true

            // заливка секции: снизу вверх на долю метрики, между
            // итерациями — плавно; внутри полноразмерный слепок зоны
            // (фон c1 + текст c2), совпадающий с базовым текстом
            Item {
                id: cpuFill

                x: statsRow.x + cpuCell.x + Settings.line / 2
                width: cpuCell.width
                anchors.bottom: parent.bottom
                height: root.cpuFraction * parent.height
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Settings.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }

                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        color: Settings.c1
                    }

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

            Item {
                id: tempFill

                x: statsRow.x + tempCell.x + Settings.line / 2
                width: tempCell.width
                anchors.bottom: parent.bottom
                height: root.tempFraction * parent.height
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Settings.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }

                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        color: Settings.c1
                    }

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

            Item {
                id: ramFill

                x: statsRow.x + ramCell.x + Settings.line / 2
                width: ramCell.width
                anchors.bottom: parent.bottom
                height: root.ramFraction * parent.height
                clip: true

                Behavior on height {
                    NumberAnimation {
                        duration: Settings.animSlow
                        easing.type: Easing.InOutQuad
                    }
                }

                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        color: Settings.c1
                    }

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

        // 3. Строка контента: адаптивные ячейки и встроенные перегородки
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

            // --- [ПЕРЕГОРОДКА 1] ---
            Shape {
                width: root.point // Ширина равна шагу наклона, чтобы не было наложений
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

            // --- [ПЕРЕГОРОДКА 2] ---
            Shape {
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

        // 4. Логика сбора метрик (Bash скрипт)
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
