#!/usr/bin/env bash
# Визуальный стенд приложений: контент-компонент QS/Apps/<Имя>
# (Item без окна — CalculatorContent, ClockContent, ...) в видимом
# простом окне, снимок через grabToImage. HOME подменён песочницей,
# X825_NOMASK=1 отключает маски (софтверный рендер их не рисует).
#
# Использование: paneltest.sh <ИмяКонтента> [секунд] [props-qml]
set -u
cd "$(dirname "$0")"

comp=${1:-CalculatorContent}
wait_s=${2:-5}
props=${3:-}

probe=shell.qml
if [ -e "$probe" ]; then
    echo "=== $probe уже существует — не трогаю ===" >&2
    exit 1
fi

cat > "$probe" <<EOF
import QtQuick
import Quickshell
import "QS/Apps"

ShellRoot {
    PanelWindow {
        visible: true
        color: "#402040"
        anchors { top: true; left: true }
        implicitWidth: 1250
        implicitHeight: 900

        Item {
            id: holder
            anchors.fill: parent

            ${comp} {
                id: app
                x: 60
                y: 40
                ${props}
            }
        }

        Timer {
            interval: ${wait_s}000; running: true; repeat: false
            onTriggered: holder.grabToImage(function (res) {
                res.saveToFile("/tmp/825grab.png")
                console.log("GRAB_SAVED")
                Qt.quit()
            })
        }
    }
}
EOF
trap 'rm -f "$probe"' EXIT

rm -f /tmp/825grab.png
mkdir -p /tmp/825testhome/.825UI
env -i HOME=/tmp/825testhome PATH=/usr/bin:/bin \
    QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    LIBGL_ALWAYS_SOFTWARE=1 X825_NOMASK=1 \
    xvfb-run -a -s "-screen 0 1280x960x24" \
    timeout $((wait_s + 12)) /usr/bin/qs -p "$(pwd)" 2>&1 \
    | grep -aE "ERROR|FATAL|WARN|GRAB" | grep -v "encoding" | head -15

if [ -f /tmp/825grab.png ]; then
    echo "=== снимок: /tmp/825grab.png ==="
else
    echo "=== снимок не сделан ==="
    exit 1
fi
