#!/usr/bin/env bash
# Визуальный стенд: рендерит бар SystemStats в Xvfb и сохраняет снимок
# через grabToImage (окна в Xvfb не мапятся, поэтому снимаем сам Item,
# а не экран). Пути: /tmp/825grab.png.
#
# Использование: visualtest.sh [секунд до снимка]
set -u
cd "$(dirname "$0")"

wait_s=${1:-8}

# граб-тест живёт временным shell.qml в корне репо: конфиг-корень qs
# обязан содержать импортируемые каталоги (QS/Bar)
probe=shell.qml
if [ -e "$probe" ]; then
    echo "=== $probe уже существует — не трогаю ===" >&2
    exit 1
fi

cat > "$probe" <<'EOF'
import QtQuick
import Quickshell
import "QS/Bar"

ShellRoot {
    PanelWindow {
        visible: true
        color: "#402040"
        anchors { top: true; left: true }
        implicitWidth: 1200
        implicitHeight: 80

        Item {
            id: holder
            anchors.fill: parent

            SystemStats {
                id: bar
                x: 50
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Timer {
            interval: 8000; running: true; repeat: false
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
env -i HOME="$HOME" PATH=/usr/bin:/bin \
    QT_QPA_PLATFORM=xcb QT_QUICK_BACKEND=software \
    LIBGL_ALWAYS_SOFTWARE=1 \
    xvfb-run -a -s "-screen 0 1920x1080x24" \
    timeout $((wait_s + 12)) /usr/bin/qs -p "$(pwd)" 2>&1 \
    | grep -aE "ERROR|FATAL|WARN|GRAB" | head -20

if [ -f /tmp/825grab.png ]; then
    echo "=== снимок: /tmp/825grab.png ==="
else
    echo "=== снимок не сделан ==="
    exit 1
fi
