import QtQuick
import ".."

// Канонический таб-бар: паровозик InfexBox (как таб-бар настроек).
// Стыки-замки указывают выемкой на активный таб и при переезде
// проезжают плоское положение; активный таб выделяется горизонтальной
// заливкой c1 с волной по направлению переезда, текст инвертируется
// полосой заливки. Владеет только визуалом и сигналами: состояние
// хранит потребитель через current + onActivated.
Item {
    id: tabBar

    property var names: []
    property int current: 0

    signal activated(int index)

    implicitWidth: 300
    implicitHeight: Settings.barHeight - Settings.line

    // шаг стыков и торцов — чистая функция высоты
    readonly property real point: height * InfexGeometry.notchFrac

    // эталонные тексты: точная ширина рендера
    readonly property real maxTextW: {
        var m = 0
        if (tabMetrics.count === names.length) {
            for (var i = 0; i < names.length; i++) {
                var it = tabMetrics.itemAt(i)
                if (it)
                    m = Math.max(m, it.implicitWidth)
            }
        }
        return m
    }

    // клетка: равные доли ширины минус стыковые зоны, но не уже
    // самого широкого текста со стандартным полем
    readonly property real cellW: Math.max(
        maxTextW + Settings.line * 6,
        (width - (names.length + 1) * point - Settings.line)
            / Math.max(1, names.length))

    function cycle(delta) {
        const n = Math.max(1, names.length)

        activated((current + delta % n + n) % n)
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: (event) => {
            if (event.angleDelta.y > 0)
                tabBar.cycle(-1)
            else if (event.angleDelta.y < 0)
                tabBar.cycle(1)
        }
    }

    // скрытые эталонные тексты — точный источник ширины
    Repeater {
        id: tabMetrics
        model: tabBar.names

        SText {
            visible: false
            text: modelData
            font.pixelSize: Settings.textXs
            font.bold: true
        }
    }

    Repeater {
        model: tabBar.names

        delegate: InfexBox {
            id: car

            y: -Settings.line / 2
            height: tabBar.height + Settings.line

            // рамка до края бокса (sideInset: 0): стыки совпадают
            // поточечно; торцевой вагон шире на стыковую зону
            // фреймовой выемки
            x: index === 0
                ? 0
                : index * tabBar.cellW + (index + 1) * tabBar.point
            width: tabBar.cellW + tabBar.point + Settings.line
                + (index === 0 ? tabBar.point : 0)

            sideInset: 0

            // стенки: фреймовые выемки на торцах; стык указывает
            // выемкой на активный таб и при переезде проезжает
            // плоское положение
            wallLeft: index === 0
                ? 1
                : (tabBar.current >= index ? 1 : -1)
            wallRight: index === tabBar.names.length - 1
                ? 1
                : (tabBar.current <= index ? 1 : -1)

            Behavior on wallLeft {
                NumberAnimation {
                    duration: Settings.animBase
                    easing.type: Easing.InOutQuad
                }
            }

            Behavior on wallRight {
                NumberAnimation {
                    duration: Settings.animBase
                    easing.type: Easing.InOutQuad
                }
            }

            // нарост внешней тени — только по силуэту поезда
            shadowOuterLeft: index === 0
            shadowOuterRight: index === tabBar.names.length - 1

            fillAxis: "horizontal"

            // сторона заливки — по текущему ходу стенок (заливка
            // тяготеет к стенке, которая глубже в Tab): старый таб
            // опустошается в сторону нового, новый заполняется со
            // стороны старого
            fillFrom: wallLeft < wallRight
                ? "left"
                : wallLeft > wallRight ? "right" : "left"

            // активный таб — полная заливка
            fillFraction: tabBar.current === index ? 1 : 0

            Behavior on fillFraction {
                NumberAnimation {
                    duration: Settings.animBase
                    easing.type: Easing.OutQuad
                }
            }

            content: Component {
                Item {
                    id: tabContent

                    property bool inverted: false

                    // контент на всю рамку вагона: вершины рёбер на
                    // верхнем/нижнем крае стоят на месте при любой
                    // глубине стенок
                    width: car.width - Settings.line
                    height: tabBar.height

                    // компенсация слайда контента: Loader начинается
                    // правее выемки
                    readonly property real wallShift:
                        -Math.max(0, car.wallLeft * car.notch)

                    // сдвиг текста: от вогнутой стенки на полшага
                    // выемки — центровка по клетке середины высоты
                    readonly property real leftCut:
                        index === 0 || tabBar.current >= index ? 1 : 0
                    readonly property real rightCut:
                        index === tabBar.names.length - 1
                        || tabBar.current <= index ? 1 : 0

                    property real textShift:
                        (leftCut - rightCut) * tabBar.point / 2

                    Behavior on textShift {
                        NumberAnimation {
                            duration: Settings.animBase
                            easing.type: Easing.InOutQuad
                        }
                    }

                    SText {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset:
                            tabContent.textShift + tabContent.wallShift
                        text: modelData
                        color: tabContent.inverted
                            ? Settings.c2 : Settings.c1
                        font.pixelSize: Settings.textXs
                        font.bold: true
                    }
                }
            }

            // клики мимо contentHolder: невизуальный элемент не
            // включает маску силуэта
            MouseArea {
                parent: car
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: tabBar.activated(index)
            }
        }
    }
}
