import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"
import "../"
PanelWindow {
    id: root
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    focusable: true
    exclusiveZone: -1
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"
    MouseArea {
        anchors.fill: parent
        onClicked: root.hide()
    }
    function show() {
        root.visible = true
    }

    function hide() {
        root.visible = false
    }

    property var tabNames: ["System", "Bar", "Wallpapers", "Monitor", "About"]
    property int currentTab: 0

    property var wallpaperModel: []
    property var wallpaperBuffer: []
    property bool wallpapersLoaded: false

    // управление стрелками зацикленно
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 100

        Keys.onLeftPressed: {
            root.currentTab = (root.currentTab - 1 + root.tabNames.length) % root.tabNames.length
        }

        Keys.onRightPressed: {
            root.currentTab = (root.currentTab + 1) % root.tabNames.length
        }
    }

    Process {
        id: wallpaperScanner
        command: [
            "sh", "-c",
            "find $HOME/Pictures/Wallpapers -maxdepth 1 -type f 2>/dev/null | grep -Ei '\\.(jpg|jpeg|png|webp|bmp|gif|svg)$' | sort"
        ]
        running: false

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                var line = String(data).trim()
                if (line !== "") {
                    root.wallpaperBuffer.push(line)
                }
            }
        }

        onRunningChanged: {
            if (!wallpaperScanner.running) {
                root.wallpaperModel = root.wallpaperBuffer.slice().sort()
            }
        }
    }

    Process {
        id: wallpaperApplyProcess
        running: false
    }
    Process {
        id: matugenProcess

        running: false

        property string output: ""
        property string errorOutput: ""

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                matugenProcess.output += String(data) + "\n"
            }
        }

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: function(data) {
                matugenProcess.errorOutput += String(data) + "\n"
            }
        }

        onRunningChanged: {
            if (matugenProcess.running)
                return

            var stdoutText = matugenProcess.output.trim()
            var stderrText = matugenProcess.errorOutput.trim()

            if (stderrText !== "")
                console.log("Matugen stderr:", stderrText)

            if (stdoutText === "") {
                console.log("Matugen: empty stdout")
                matugenProcess.output = ""
                matugenProcess.errorOutput = ""
                return
            }

            try {
                var result = JSON.parse(stdoutText)
//primary
                var primary = result.base16.base00.light.color
                var secondary = result.base16.base00.dark.color

                console.log("Matugen primary:", primary)
                console.log("Matugen secondary:", secondary)

                if (primary && secondary)
                    Settings.setColors(primary, secondary)
            } catch (e) {
                console.log("Matugen JSON parse error:", e)
                console.log("Raw Matugen output:", stdoutText)
            }

            matugenProcess.output = ""
            matugenProcess.errorOutput = ""
        }
    }

    function ensureWallpapersLoaded() {
        if (!root.wallpapersLoaded) {
            root.wallpapersLoaded = true
            root.rescanWallpapers()
        }
    }

    function rescanWallpapers() {
        root.wallpaperBuffer = []
        root.wallpaperModel = []

        wallpaperScanner.running = false
        wallpaperScanner.running = true
    }

    function applyWallpaper(path) {
        if (!path)
            return

        wallpaperApplyProcess.running = false
        const transitions = ["simple", "fade", "wipe", "any", "wave"]
        const randomTransition = transitions[Math.floor(Math.random() * transitions.length)];
        wallpaperApplyProcess.command = [
            "sh", "-c",
            `awww img "${path}"
                --transition-fps 144
                --transition-type ${randomTransition}
                --transition-pos ${Math.random()},${Math.random()}
                --transition-duration 1.5
                --transition-angle ${Math.random() * 360}
                --transition-wave ${Math.random()*100},${Math.random()*100}
                `.replace(/\n/g, ' '),
            "sh"
        ]
//--transition-bezier ${Math.random()},${Math.random()},${Math.random()},${Math.random()}
        wallpaperApplyProcess.running = true

        matugenProcess.running = false
        matugenProcess.output = ""
        console.log(path)
        matugenProcess.command = [
            "sh",
            "-c",
            `matugen image "${path}" -m dark --json hex --prefer=saturation`,
            "sh"
        ]

        matugenProcess.running = true
    }

    onVisibleChanged: {
        if (root.visible) {

            if (root.currentTab === 2) {
                root.ensureWallpapersLoaded()
            }
        }
    }

    onCurrentTabChanged: {
        if (root.visible && root.currentTab === 2) {
            root.ensureWallpapersLoaded()
        }
    }
    MouseFollow {
        id: tiltContainer
        anchors.centerIn: parent

        width: 700
        height: 500

        x: (Screen.width - width) / 2
        y: Settings.line

        Item {
            id: windowFrame
            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: Settings.line * 4

                // --- Таб-бар: паровозик из InfexBox, как SystemStats.
                // Стыки статичны (Tab/Notch-пары, совпадают поточечно),
                // активный таб выделяется горизонтальной заливкой c1:
                // переход заливки между соседними боксами вместо
                // отдельной формы-индикатора, текст инвертируется
                // полосой заливки
                Item {
                    id: tabBar
                    anchors.horizontalCenter: parent.horizontalCenter

                    height: Settings.barHeight - Settings.line

                    // шаг стыков и торцов — чистая функция высоты
                    property real point: height * InfexGeometry.notchFrac

                    // количество табов: чтение под защитой — при разборке
                    // шелла корень уже null, а cellW/width пересчитываются
                    // из-за умирающих зависимостей (availW, maxTextW)
                    readonly property int tabCount:
                        root ? root.tabNames.length : 0

                    // доступная ширина: панель минус пояс-запас кончика
                    // фрейма (как у старого таб-бара)
                    readonly property real availW:
                        parent.width - InfexGeometry.tipMult
                            * Settings.line / 2

                    // эталонные тексты: точная ширина рендера
                    readonly property real maxTextW: {
                        var m = 0
                        if (tabMetrics.count === tabBar.tabCount) {
                            for (var i = 0; i < root.tabNames.length; i++) {
                                var it = tabMetrics.itemAt(i)
                                if (it)
                                    m = Math.max(m, it.implicitWidth)
                            }
                        }
                        return m
                    }

                    // клетка: равные доли ширины минус стыковые зоны,
                    // но не уже самого широкого текста со стандартным
                    // полем по 3 линии с каждой стороны
                    readonly property real cellW: Math.max(
                        maxTextW + Settings.line * 6,
                        (availW - (tabBar.tabCount + 1) * point
                            - Settings.line) / tabBar.tabCount)

                    // полная ширина поезда: клетки + стыковые зоны
                    width: tabBar.tabCount * cellW
                        + (tabBar.tabCount + 1) * point
                        + Settings.line

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => {
                            if (event.angleDelta.y > 0) {
                                root.currentTab = (root.currentTab - 1 + root.tabNames.length) % root.tabNames.length
                            } else if (event.angleDelta.y < 0) {
                                root.currentTab = (root.currentTab + 1) % root.tabNames.length
                            }
                        }
                    }

                    // скрытые эталонные тексты — точный источник ширины
                    Repeater {
                        id: tabMetrics
                        model: root.tabNames

                        SText {
                            visible: false
                            text: modelData
                            font.bold: true
                        }
                    }

                    Repeater {
                        model: root.tabNames

                        delegate: InfexBox {
                            id: car

                            y: -Settings.line / 2
                            height: Settings.barHeight

                            // рамка до края бокса (sideInset: 0): стыки
                            // совпадают поточечно; торцевой вагон шире
                            // на стыковую зону фреймовой выемки
                            x: index === 0
                                ? 0
                                : index * tabBar.cellW
                                    + (index + 1) * tabBar.point
                            width: tabBar.cellW + tabBar.point
                                + Settings.line
                                + (index === 0 ? tabBar.point : 0)

                            sideInset: 0

                            // стенки: фреймовые выемки на торцах; стык
                            // указывает выемкой на активный таб (логика
                            // разделителей старого таб-бара) и при
                            // переезде активного проезжает плоское
                            // положение
                            wallLeft: index === 0
                                ? 1
                                : (root.currentTab >= index ? 1 : -1)
                            wallRight: index === root.tabNames.length - 1
                                ? 1
                                : (root.currentTab <= index ? 1 : -1)

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

                            // нарост внешней тени — только по силуэту
                            // поезда: на стыках пояса нет
                            shadowOuterLeft: index === 0
                            shadowOuterRight:
                                index === root.tabNames.length - 1

                            fillAxis: "horizontal"

                            // сторона заливки — по текущему ходу
                            // стенок: заливка тяготеет к стенке,
                            // которая сейчас глубже в Tab. При
                            // переезде активного это даёт волну:
                            // старый вагон опустошается в сторону
                            // нового (его стенка к новому уходит в
                            // Tab, заливка дренирует в растущую
                            // выпуклость), новый заполняется со
                            // стороны старого (его стенка к старому
                            // возвращается из Tab). В покое стенки
                            // равны — сторона не важна: заливка
                            // пуста или полна
                            fillFrom: wallLeft < wallRight
                                ? "left"
                                : wallLeft > wallRight
                                    ? "right" : "left"

                            // активный таб — полная заливка; переход
                            // заливки едет по вагонам
                            fillFraction: root.currentTab === index ? 1 : 0

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

                                    // контент на всю рамку вагона:
                                    // вершины рёбер на верхнем/нижнем
                                    // крае стоят на месте при любой
                                    // глубине стенок — текст центруется
                                    // по клетке верхнего края
                                    width: car.width - Settings.line
                                    height: tabBar.height

                                    // компенсация слайда контента:
                                    // Loader начинается правее выемки
                                    readonly property real wallShift:
                                        -Math.max(0,
                                            car.wallLeft * car.notch)

                                    // сдвиг текста из старого таб-бара:
                                    // от вогнутой стенки на полшага
                                    // выемки — центровка по клетке
                                    // середины высоты
                                    readonly property real leftCut:
                                        index === 0
                                        || root.currentTab >= index
                                            ? 1 : 0
                                    readonly property real rightCut:
                                        index === root.tabNames.length - 1
                                        || root.currentTab <= index
                                            ? 1 : 0

                                    property real textShift:
                                        (leftCut - rightCut)
                                            * tabBar.point / 2

                                    Behavior on textShift {
                                        NumberAnimation {
                                            duration: Settings.animBase
                                            easing.type: Easing.InOutQuad
                                        }
                                    }

                                    SText {
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset:
                                            tabContent.textShift
                                                + tabContent.wallShift
                                        text: modelData
                                        color: tabContent.inverted
                                            ? Settings.c2 : Settings.c1
                                        font.bold: true
                                    }
                                }
                            }

                            // клики мимо contentHolder: невизуальный
                            // элемент не включает маску силуэта
                            MouseArea {
                                parent: car
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentTab = index
                            }
                        }
                    }
                }

                // контент
                Item {
                    id: contentArea
                    width: parent.width
                    height: parent.height - tabBar.height - Settings.line*1.5

                    // Панель контента: InfexBox-контейнер — октагон
                    // (плоские рёбра, срезы углов), тень-нарост снаружи;
                    // дети-страницы маскируются силуэтом бокса
                    InfexBox {
                        id: contentPanel

                        x: -Settings.line / 2
                        y: -Settings.line / 2
                        width: parent.width + Settings.line
                        height: parent.height + Settings.line

                        edgeLeft: "Flat"
                        edgeRight: "Flat"
                        cornerCut: Settings.line * 2
                        sideInset: 0

                        // system
                        Item {
                            visible: root.currentTab === 0
                            anchors.fill: parent
                            anchors.margins: Settings.line

                            SText {
                                text: "System"
                                color: Settings.c1
                                anchors.centerIn: parent
                            }
                        }

                        // bar
                        Item {
                            visible: root.currentTab === 1
                            anchors.fill: parent
                            anchors.margins: Settings.line

                            SText {
                                text: "Bar"
                                color: Settings.c1
                                anchors.centerIn: parent
                            }
                        }

                        // wallpapers
                        Item {
                            id: wallpapersTab
                            visible: root.currentTab === 2
                            anchors.fill: parent
                            anchors.margins: Settings.line
                            clip: true

                            Flickable {
                                id: wallpaperFlick
                                anchors.fill: parent
                                clip: true
                                interactive: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickDeceleration: 1000

                                property real margin: Settings.line*1.5
                                property real gap: Settings.line*2
                                property real columns: 4

                                property real itemSize: Math.max(
                                    80,
                                    Math.floor((width - margin * 2 - gap * (columns - 1)) / columns)
                                )

                                property real rows: Math.ceil(root.wallpaperModel.length / columns)

                                contentWidth: width
                                contentHeight: Math.max(
                                    height,
                                    rows * (itemSize + gap) + margin * 2
                                )

                                Repeater {
                                    model: root.wallpaperModel

                                    delegate: Item {
                                        id: wallpaperDelegate

                                        property string path: modelData
                                        property real col: index % wallpaperFlick.columns
                                        property real row: Math.floor(index / wallpaperFlick.columns)

                                        property bool inViewport: {
                                            var top = y - wallpaperFlick.contentY
                                            var bottom = top + height
                                            return top < wallpaperFlick.height + 300 && bottom > -300
                                        }

                                        width: wallpaperFlick.itemSize
                                        height: wallpaperFlick.itemSize

                                        x: wallpaperFlick.margin + col * (wallpaperFlick.itemSize + wallpaperFlick.gap)
                                        y: wallpaperFlick.margin + row * (wallpaperFlick.itemSize + wallpaperFlick.gap)

                                        // Плитка: InfexBox-октагон. Бокс раздат на
                                        // пол-линии с каждой стороны — рамка (штрих
                                        // идёт на пол-линии внутрь бокса) ложится
                                        // на старые видимые границы; картинка и
                                        // подпись — контейнер, режутся силуэтом
                                        // (срезы углов вместо треугольников-заглушек)
                                        InfexBox {
                                            x: -Settings.line / 2
                                            y: -Settings.line / 2
                                            width: parent.width + Settings.line
                                            height: parent.height + Settings.line

                                            edgeLeft: "Flat"
                                            edgeRight: "Flat"
                                            cornerCut: Settings.line * 2
                                            sideInset: 0

                                            Loader {
                                                anchors.fill: parent
                                                active: wallpaperDelegate.inViewport

                                                sourceComponent: Component {
                                                    Image {
                                                        anchors.fill: parent
                                                        asynchronous: true
                                                        cache: false
                                                        smooth: true
                                                        sourceSize: Qt.size(320, 320)
                                                        source: "file://" + wallpaperDelegate.path.replace(/ /g, "%20")
                                                        fillMode: Image.PreserveAspectCrop
                                                    }
                                                }
                                            }

                                            // подпись
                                            SRectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: Settings.line
                                                height: 20
                                                color: '#77' + Settings.c2.slice(1);

                                                SText {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 20
                                                    anchors.leftMargin: 20
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: wallpaperDelegate.path.split("/").pop()
                                                    color: "white"
                                                    elide: Text.ElideMiddle
                                                    font.pixelSize: 10
                                                    horizontalAlignment: Text.AlignHCenter
                                                }
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            z: 4
                                            onClicked: root.applyWallpaper(wallpaperDelegate.path)
                                        }
                                    }
                                }

                                SText {
                                    anchors.centerIn: parent
                                    visible: root.wallpaperModel.length === 0
                                    text: "~/Pictures/Wallpapers"
                                    color: Settings.c1
                                }
                            }

                            // скролл
                            SRectangle {
                                id: wallpaperScrollTrack
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Settings.line
                                radius: 0
                                color: Settings.c2
                                visible: wallpaperFlick.contentHeight > wallpaperFlick.height + 2

                                SRectangle {
                                    id: wallpaperScrollHandle
                                    width: parent.width
                                    radius: parent.radius
                                    color: Settings.c1

                                    height: Math.max(
                                        20,
                                        Math.floor(parent.height * (parent.height / Math.max(1, wallpaperFlick.contentHeight)))
                                    )

                                    y: {
                                        var maxContent = Math.max(1, wallpaperFlick.contentHeight - wallpaperFlick.height)
                                        var ratio = wallpaperFlick.contentY / maxContent
                                        return Math.round((wallpaperScrollTrack.height - height) * ratio)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -Settings.line
                                    z: 2
                                    cursorShape: Qt.SizeVerCursor

                                    property bool dragging: false
                                    property real grabOffset: 0

                                    function contentYFromHandleY(handleY) {
                                        var maxContent = Math.max(1, wallpaperFlick.contentHeight - wallpaperFlick.height)
                                        var maxHandle = Math.max(1, wallpaperScrollTrack.height - wallpaperScrollHandle.height)
                                        var ratio = Math.max(0, Math.min(1, handleY / maxHandle))
                                        return ratio * maxContent
                                    }

                                    onPressed: {
                                        var handleTop = wallpaperScrollHandle.y
                                        var handleBottom = handleTop + wallpaperScrollHandle.height

                                        if (mouseY >= handleTop && mouseY <= handleBottom) {
                                            dragging = true
                                            grabOffset = mouseY - handleTop
                                        } else {
                                            var desiredY = mouseY - wallpaperScrollHandle.height / 2
                                            var maxY = wallpaperScrollTrack.height - wallpaperScrollHandle.height
                                            desiredY = Math.max(0, Math.min(maxY, desiredY))
                                            wallpaperFlick.contentY = contentYFromHandleY(desiredY)
                                            dragging = true
                                            grabOffset = wallpaperScrollHandle.height / 2
                                        }
                                    }

                                    onPositionChanged: {
                                        if (!pressed || !dragging)
                                            return

                                        var desiredY = mouseY - grabOffset
                                        var maxY = wallpaperScrollTrack.height - wallpaperScrollHandle.height
                                        desiredY = Math.max(0, Math.min(maxY, desiredY))

                                        wallpaperFlick.contentY = contentYFromHandleY(desiredY)
                                    }

                                    onReleased: {
                                        dragging = false
                                    }
                                }
                            }
                        }

                        // monitor
                        Item {
                            visible: root.currentTab === 3
                            anchors.fill: parent
                            anchors.margins: Settings.line

                            SText {
                                text: "Monitor"
                                color: Settings.c1
                                anchors.centerIn: parent
                            }
                        }

                        // about
                        Item {
                            visible: root.currentTab === 4
                            anchors.fill: parent
                            anchors.margins: Settings.line

                            SText {
                                text: "About"
                                color: Settings.c1
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
            }
        }
    }
}