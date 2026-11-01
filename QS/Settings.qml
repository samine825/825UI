pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
        }

        onAdapterUpdated: writeAdapter()
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