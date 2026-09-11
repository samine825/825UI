import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string cpuText: "CPU --%"
    property string tempText: "TEMP --°C"
    property string ramText: "RAM --.-/--.- GB"

    property double previousTotal: 0
    property double previousIdle: 0

    readonly property int horizontalPadding: 12
    readonly property int sectionGap: 10

    width: statsRow.implicitWidth + horizontalPadding * 2
    height: Settings.barHeight

    Rectangle {
        anchors.fill: parent
        color: "black"
        border.width: 1
        border.color: "#3a3a3a"
    }

    Row {
        id: statsRow
        anchors.centerIn: parent
        spacing: root.sectionGap

        Text {
            text: root.cpuText
            color: "white"
            font.pixelSize: Math.max(11, Settings.barHeight * 0.28)
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: "•"
            color: "#666666"
            font.pixelSize: Math.max(10, Settings.barHeight * 0.23)
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: root.tempText
            color: "white"
            font.pixelSize: Math.max(11, Settings.barHeight * 0.28)
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: "•"
            color: "#666666"
            font.pixelSize: Math.max(10, Settings.barHeight * 0.23)
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: root.ramText
            color: "white"
            font.pixelSize: Math.max(11, Settings.barHeight * 0.28)
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }
    }

    Process {
        id: statsProcess

        command: [
            "bash",
            "-c",
            "cpu=$(awk '/^cpu / { idle=$5+$6; total=0; for(i=2;i<=NF;i++) total+=$i; printf \"%d %d\", total, idle }' /proc/stat); " +
            "mem=$(awk '/MemTotal:/ {total=$2} /MemAvailable:/ {available=$2} END {printf \"%d %d\", total-available, total}' /proc/meminfo); " +
            "temp=; " +
            "for hw in /sys/class/hwmon/hwmon*; do " +
                "[ -r \"$hw/name\" ] || continue; " +
                "name=$(cat \"$hw/name\" 2>/dev/null); " +
                "case \"$name\" in coretemp|k10temp|zenpower|fam15h_power) " +
                    "for input in \"$hw\"/temp*_input; do " +
                        "[ -r \"$input\" ] || continue; " +
                        "num=${input##*temp}; num=${num%_input}; " +
                        "label=; [ -r \"$hw/temp${num}_label\" ] && label=$(cat \"$hw/temp${num}_label\" 2>/dev/null); " +
                        "case \"$label\" in Package*|Tctl*|Tdie*|CPU*|Core*|\"\") temp=$(cat \"$input\" 2>/dev/null); [ -n \"$temp\" ] && break 2; ;; esac; " +
                    "done; " +
                    ";; esac; " +
            "done; " +
            "if [ -z \"$temp\" ]; then " +
                "for z in /sys/class/thermal/thermal_zone*; do " +
                    "[ -r \"$z/type\" ] || continue; [ -r \"$z/temp\" ] || continue; " +
                    "type=$(cat \"$z/type\" 2>/dev/null); " +
                    "case \"$type\" in *cpu*|*CPU*|*Core*|*core*|x86_pkg_temp*|k10temp*|coretemp*) temp=$(cat \"$z/temp\" 2>/dev/null); [ -n \"$temp\" ] && break; ;; esac; " +
                "done; " +
            "fi; " +
            "printf \"CPU %s %s\\nRAM %s %s\\nTEMP %s\\n\" $cpu $mem ${temp:--1}"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                var text = this.text.trim()
                if (!text)
                    return

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
                            usage = Math.max(0, Math.min(100, usage))
                            root.cpuText = "CPU " + Math.round(usage) + "%"
                        }
                    }

                    root.previousTotal = cpuTotal
                    root.previousIdle = cpuIdle
                }

                if (ramMatch) {
                    var usedKiB = Number(ramMatch[1])
                    var totalKiB = Number(ramMatch[2])

                    if (totalKiB > 0) {
                        var usedGiB = usedKiB / 1024 / 1024
                        var totalGiB = totalKiB / 1024 / 1024
                        root.ramText = "RAM " + usedGiB.toFixed(1) + "/" + totalGiB.toFixed(1) + " GB"
                    }
                }

                if (tempMatch) {
                    var rawTemp = Number(tempMatch[1])

                    if (rawTemp >= 0) {
                        var tempC = rawTemp >= 1000 ? rawTemp / 1000 : rawTemp
                        root.tempText = "TEMP " + Math.round(tempC) + "°C"
                    } else {
                        root.tempText = "TEMP --°C"
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true

        onTriggered: {
            if (!statsProcess.running)
                statsProcess.running = true
        }
    }
}
