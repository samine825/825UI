pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    property alias barGap: settings.barGap
    property alias barHeight: settings.barHeight
    property alias line: settings.line
    property alias leftMargin: settings.leftMargin
    property alias rightMargin: settings.rightMargin
    property alias edgeSize: settings.edgeSize
    property alias c1: settings.c1
    property alias c2: settings.c2
    property alias barType: settings.barType
    property alias secondsMode: settings.secondsMode
    property alias infex: settings.infex

    // режим без уведомлений: попапы не показываются, всё падает
    // только в архив панели управления
    property alias dnd: settings.dnd

    // === ТОКЕНЫ АНИМАЦИЙ ===
    // instant — слежение за курсором в слайдерах, fast — мелкие
    // реакции, base — стандартная длительность цветов и геометрии,
    // slow — крупные перемещения (колесо), morph — морфинг цифр
    readonly property int animInstant: 60
    readonly property int animFast: 200
    readonly property int animBase: 250
    readonly property int animSlow: 500
    readonly property int animMorph: 400

    // === ШКАЛА ТЕКСТА (от линии, без clamp) ===
    readonly property int textXs: line * 3
    readonly property int textSm: line * 4
    readonly property int textMd: line * 5
    readonly property int textLg: line * 6

    // тестовый хук: X825_NOMASK=1 отключает маски контента в
    // SPanel/SFrame — в софтверном рендере Xvfb шейдер OpacityMask
    // не исполняется и замаскированный контент невидим; на реальной
    // системе переменной нет, маскирование работает как всегда
    readonly property bool unmaskedTest:
        Quickshell.env("X825_NOMASK") === "1"

    // === ОБВОДКИ ОКОН HYPRLAND ===
    // палитра шелла ведёт и обводками окон: активная — c1, неактивная
    // — c2, через hyprctl keyword на лету. Применяется при смене
    // c1/c2, при загрузке конфига шелла и при reload конфига Hyprland
    // (keyword'ы сбрасываются к значениям из его конфига)
    function toHyprRgba(colorStr) {
        // "#rrggbb" / "#aarrggbb" → "rgba(rrggbbaa)"
        let hex = colorStr.replace("#", "")
        if (hex.length === 8)
            hex = hex.slice(2) + hex.slice(0, 2)
        else
            hex += "ff"
        return "rgba(" + hex + ")"
    }

    function applyWindowBorders() {
        // значения в кавычках: скобки rgba() без кавычек — синтаксическая
        // ошибка bash. Сигнатура инстанса: из окружения шелла, иначе —
        // единственный инстанс в $XDG_RUNTIME_DIR/hypr
        hyprBorderProcess.command = ["bash", "-c",
            'sig="${HYPRLAND_INSTANCE_SIGNATURE:'
            + '-$(ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)}"\n'
            + 'export HYPRLAND_INSTANCE_SIGNATURE="$sig"\n'
            + "hyprctl keyword general:col.active_border '"
                + toHyprRgba(settings.c1) + "'\n"
            + "hyprctl keyword general:col.inactive_border '"
                + toHyprRgba(settings.c2) + "'\n"
            + "hyprctl keyword general:border_size " + settings.line]
        hyprBorderProcess.running = true
    }

    onC1Changed: hyprBorderDebounce.restart()
    onC2Changed: hyprBorderDebounce.restart()

    Timer {
        // двойной сигнал при setColors (c1 и c2 вместе) — один прогон
        id: hyprBorderDebounce

        interval: animFast
        onTriggered: applyWindowBorders()
    }

    Process {
        id: hyprBorderProcess

        // ответ hyprctl в qslog: «ok» или причина отказа
        stdout: StdioCollector {
            onStreamFinished: console.warn("[hyprctl]", this.text.trim())
        }
    }

    Component.onCompleted: applyWindowBorders()

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded")
                hyprBorderDebounce.restart()
        }
    }

    FileView {
        id: configFile

        path: Qt.resolvedUrl("./settings.json")
        watchChanges: true

        adapter: JsonAdapter {
            id: settings

            property int barGap: 20
            property int barHeight: 70
            property int line: 5
            property int leftMargin: 100
            property int rightMargin: 100
            property int edgeSize: 20
            property string c1: "#ffffff"
            property string c2: "#000000"
            property int barType: 0
            property int secondsMode: 0
            property bool infex: true
            property bool dnd: false
        }

        onAdapterUpdated: {
            writeAdapter()

            // конфиг шелла загружен/обновлён — обводки окон следуют
            hyprBorderDebounce.restart()
        }
        onFileChanged: reload()
    }

    function setColors(primary, secondary) {
        if (!primary || !secondary)
            return

        settings.c1 = primary
        settings.c2 = secondary

        configFile.writeAdapter()
    }
}