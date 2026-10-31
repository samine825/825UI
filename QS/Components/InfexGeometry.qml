pragma Singleton

import QtQuick
import Quickshell
import ".."

// Каноническая геометрия инфекса. Квадрат инфекса = высота бара
// минус 4 линии (обводка фрейма + зазор-тень сверху и снизу),
// отношение линии к стороне задаёт все точки контура. Единственный
// источник инфекс-коэффициентов: запечённые числа вида 403.16/1000
// в интерфейсе не используются. При смене barHeight/line всё
// пересчитывается на лету.
Singleton {
    id: geo

    readonly property real line: Settings.line

    readonly property real side:
        Math.max(1, Settings.barHeight - Settings.line * 4)

    // отношение линии к стороне в тысячных (в генераторе шрифта — d)
    readonly property real d: line / side * 1000

    // угол диагонали сетки — та же формула, что в Fonts/Infex.qml
    readonly property real refAngle: {
        const r = Math.max(-1, Math.min(1,
            line / (side * Math.sqrt(2))))

        return Math.PI / 4 + Math.asin(r)
    }

    readonly property real sinA: Math.sin(refAngle)
    readonly property real cosA: Math.cos(refAngle)
    readonly property real tanA: Math.tan(refAngle)

    // точки поля 1000 при текущем d (имена из генератора)
    readonly property real iskomoe: 1000 - 1000 / tanA // насечка кромки
    readonly property real innerX: d / tanA            // внутренняя точка
    readonly property real notchX: 500 / tanA          // глубина выемки
    readonly property real tip: iskomoe + innerX       // кончик рамки

    // выемка — доля высоты контура
    readonly property real notchFrac: notchX / 1000

    // насечка и кончик — множители к линии
    readonly property real edgeMult: iskomoe / d
    readonly property real tipMult: tip / d
    readonly property real tipFrac: tip / 1000
}
