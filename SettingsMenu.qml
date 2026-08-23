import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: settingsRoot
    visible: false
    focusable: true

    // Окно должно реально получать клавиатуру от композитора
    // (иначе focus/Keys внутри не работают — клавиши не доходят до Qt)
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    exclusiveZone: -1
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    property var tabNames: ["System", "Bar", "Wallpapers", "Monitor", "About"]
    property int currentTab: 0

    property var wallpaperModel: []
    property var wallpaperBuffer: []
    property bool wallpapersLoaded: false

    // Управление активным табом стрелками вправо/влево (зацикленно).
    // PanelWindow — не Item, поэтому Keys висит на Item-обёртке с фокусом.
    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        z: 100

        Keys.onLeftPressed: {
            settingsRoot.currentTab = (settingsRoot.currentTab - 1 + settingsRoot.tabNames.length) % settingsRoot.tabNames.length
        }

        Keys.onRightPressed: {
            settingsRoot.currentTab = (settingsRoot.currentTab + 1) % settingsRoot.tabNames.length
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
                    settingsRoot.wallpaperBuffer.push(line)
                }
            }
        }

        onRunningChanged: {
            if (!wallpaperScanner.running) {
                settingsRoot.wallpaperModel = settingsRoot.wallpaperBuffer.slice().sort()
            }
        }
    }

    Process {
        id: wallpaperApplyProcess
        running: false
    }

    function ensureWallpapersLoaded() {
        if (!settingsRoot.wallpapersLoaded) {
            settingsRoot.wallpapersLoaded = true
            settingsRoot.rescanWallpapers()
        }
    }

    function rescanWallpapers() {
        settingsRoot.wallpaperBuffer = []
        settingsRoot.wallpaperModel = []

        wallpaperScanner.running = false
        wallpaperScanner.running = true
    }

    function applyWallpaper(path) {
        if (!path)
            return

        wallpaperApplyProcess.running = false

        wallpaperApplyProcess.command = [
            "sh", "-c",
            "awww img --transition-fps 144 --transition-type random \"$1\" --transition-duration 1.5",
            "sh",
            path
        ]

        wallpaperApplyProcess.running = true
    }

    onVisibleChanged: {
        if (settingsRoot.visible) {
            // Фокус на окно, чтобы стрелки гарантированно ловились
            settingsRoot.forceActiveFocus()

            if (settingsRoot.currentTab === 2) {
                settingsRoot.ensureWallpapersLoaded()
            }
        }
    }

    onCurrentTabChanged: {
        if (settingsRoot.visible && settingsRoot.currentTab === 2) {
            settingsRoot.ensureWallpapersLoaded()
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: settingsRoot.visible = false
    }

    Rectangle {
        id: windowFrame
        width: 700
        height: 500
        anchors.centerIn: parent
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 17.5

            // --- Tabs ---
            Item {
                id: tabBar
                width: parent.width - ((403.16 / 313.856) * 10)
                height: 50
                anchors.horizontalCenter: parent.horizontalCenter

                property real point: height * (403.16 / 1000)
                property real tabWidth: width / settingsRoot.tabNames.length

                property real tabBorderWidth: 5
                property real blackOutlineWidth: 5

                // Внешняя черная обводка.
                // Размеры и координаты tabBar не меняются.
                Shape {
                    id: tabOuterOutline

                    anchors.fill: parent
                    z: -1
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap

                        strokeColor: "black"

                        // Существующая цветная линия имеет ширину 5px.
                        // Благодаря этой формуле черная часть снаружи будет 5px.
                        strokeWidth: tabBar.tabBorderWidth
                                    + tabBar.blackOutlineWidth * 2

                        fillColor: "transparent"

                        startX: 0
                        startY: 0

                        PathLine {
                            x: tabShape.width
                            y: 0
                        }

                        PathLine {
                            x: tabShape.width - tabBar.point
                            y: tabShape.height / 2
                        }

                        PathLine {
                            x: tabShape.width
                            y: tabShape.height
                        }

                        PathLine {
                            x: 0
                            y: tabShape.height
                        }

                        PathLine {
                            x: tabBar.point
                            y: tabShape.height / 2
                        }

                        PathLine {
                            x: 0
                            y: 0
                        }
                    }
                }

                Shape {
                    id: tabShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        strokeColor: Settings.barColor
                        strokeWidth: 5
                        fillColor: "#000000"

                        startX: 0
                        startY: 0

                        PathLine { x: tabShape.width; y: 0 }
                        PathLine { x: tabShape.width - tabBar.point; y: tabShape.height / 2 }
                        PathLine { x: tabShape.width; y: tabShape.height }
                        PathLine { x: 0; y: tabShape.height }
                        PathLine { x: tabBar.point; y: tabShape.height / 2 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Shape {
                    id: activeIndicator
                    preferredRendererType: Shape.CurveRenderer

                    property real indH: tabBar.height - 5 * 3
                    property real indPoint: indH * (403.16 / 1000)

                    width: tabBar.tabWidth - 5 * 6
                    height: indH
                    y: (tabBar.height - indH) / 2
                    x: settingsRoot.currentTab * tabBar.tabWidth + 5 * 3

                    Behavior on x {
                        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                    }

                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        fillColor: Settings.barColor
                        strokeColor: "transparent"

                        startX: 0
                        startY: 0

                        PathLine { x: activeIndicator.width; y: 0 }
                        PathLine { x: activeIndicator.width - activeIndicator.indPoint; y: activeIndicator.height / 2 }
                        PathLine { x: activeIndicator.width; y: activeIndicator.height }
                        PathLine { x: 0; y: activeIndicator.height }
                        PathLine { x: activeIndicator.indPoint; y: activeIndicator.height / 2 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                Repeater {
                    model: settingsRoot.tabNames.length - 1

                    delegate: Shape {
                        id: dividerShape
                        preferredRendererType: Shape.CurveRenderer
                        anchors.fill: parent
                        z: 2

                        property real xPos: (index + 1) * tabBar.tabWidth

                        ShapePath {
                            joinStyle: ShapePath.MiterJoin
                            capStyle: ShapePath.FlatCap
                            strokeColor: Settings.barColor
                            strokeWidth: 5
                            fillColor: "transparent"

                            startX: dividerShape.xPos
                            startY: 0

                            PathLine {
                                x: settingsRoot.currentTab <= index
                                    ? dividerShape.xPos - tabBar.point
                                    : dividerShape.xPos + tabBar.point
                                y: tabBar.height / 2

                                Behavior on x {
                                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                                }
                            }

                            PathLine {
                                x: dividerShape.xPos
                                y: tabBar.height
                            }
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    z: 3

                    Repeater {
                        model: settingsRoot.tabNames

                        delegate: Item {
                            width: tabBar.tabWidth
                            height: tabBar.height

                            property real textOffset: {
                                var i = index
                                var last = settingsRoot.tabNames.length - 1

                                var leftNotch = (i === 0) || (settingsRoot.currentTab >= i)
                                var rightNotch = (i === last) || (settingsRoot.currentTab <= i)

                                if (leftNotch && !rightNotch)
                                    return tabBar.point / 2

                                if (rightNotch && !leftNotch)
                                    return -tabBar.point / 2

                                return 0
                            }

                            Text {
                                text: modelData
                                color: settingsRoot.currentTab === index ? "#0a0a0a" : Settings.barColor
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.horizontalCenterOffset: textOffset
                                font.bold: true

                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }

                                Behavior on anchors.horizontalCenterOffset {
                                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsRoot.currentTab = index
                            }
                        }
                    }
                }
            }

            // --- Content ---
            Item {
                id: contentArea
                width: parent.width
                height: parent.height - tabBar.height - 7.5

                Rectangle {
                    x: -5
                    y: -5
                    width: parent.width + 10
                    height: parent.height + 10
                    color: "#000000"
                    border.color: "#000000"
                    border.width: 10
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    border.color: Settings.barColor
                    border.width: 5
                }

                // System
                Item {
                    visible: settingsRoot.currentTab === 0
                    anchors.fill: parent
                    anchors.margins: 5

                    Text {
                        text: "System"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }

                // Bar
                Item {
                    visible: settingsRoot.currentTab === 1
                    anchors.fill: parent
                    anchors.margins: 5

                    Text {
                        text: "Bar"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }

                // Wallpapers
                Item {
                    id: wallpapersTab
                    visible: settingsRoot.currentTab === 2
                    anchors.fill: parent
                    anchors.margins: 5
                    clip: true

                    Flickable {
                        id: wallpaperFlick
                        anchors.fill: parent
                        clip: true
                        interactive: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 1000

                        property real margin: 7.5
                        property real gap: 10
                        property real columns: 4

                        property real itemSize: Math.max(
                            80,
                            Math.floor((width - margin * 2 - gap * (columns - 1)) / columns)
                        )

                        property real rows: Math.ceil(settingsRoot.wallpaperModel.length / columns)

                        contentWidth: width
                        contentHeight: Math.max(
                            height,
                            rows * (itemSize + gap) + margin * 2
                        )

                        Repeater {
                            model: settingsRoot.wallpaperModel

                            delegate: Item {
                                id: wallpaperDelegate

                                property string path: modelData
                                property real col: index % wallpaperFlick.columns
                                property real row: Math.floor(index / wallpaperFlick.columns)

                                property real cornerCut: 10

                                property bool inViewport: {
                                    var top = y - wallpaperFlick.contentY
                                    var bottom = top + height
                                    return top < wallpaperFlick.height + 300 && bottom > -300
                                }

                                width: wallpaperFlick.itemSize
                                height: wallpaperFlick.itemSize

                                x: wallpaperFlick.margin + col * (wallpaperFlick.itemSize + wallpaperFlick.gap)
                                y: wallpaperFlick.margin + row * (wallpaperFlick.itemSize + wallpaperFlick.gap)

                                // Изображение (lazy load — только в вьюпорте)
                                Loader {
                                    id: imgLoader
                                    anchors.fill: parent
                                    active: wallpaperDelegate.inViewport
                                    z: 0

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

                                // Треугольники в углах (закрывают углы изображения)
                                Shape {
                                    anchors.fill: parent
                                    z: 2

                                    // Верхний-левый
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: "#0a0a0a"
                                        startX: 0
                                        startY: 0
                                        PathLine { x: wallpaperDelegate.cornerCut; y: 0 }
                                        PathLine { x: 0; y: wallpaperDelegate.cornerCut }
                                        PathLine { x: 0; y: 0 }
                                    }

                                    // Верхний-правый
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: "#000000"
                                        startX: wallpaperDelegate.width - wallpaperDelegate.cornerCut
                                        startY: 0
                                        PathLine { x: wallpaperDelegate.width; y: 0 }
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.width - wallpaperDelegate.cornerCut; y: 0 }
                                    }

                                    // Нижний-правый
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: "#0a0a0a"
                                        startX: wallpaperDelegate.width
                                        startY: wallpaperDelegate.height - wallpaperDelegate.cornerCut
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.height }
                                        PathLine { x: wallpaperDelegate.width - wallpaperDelegate.cornerCut; y: wallpaperDelegate.height }
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.height - wallpaperDelegate.cornerCut }
                                    }

                                    // Нижний-левый
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: "#000000"
                                        startX: wallpaperDelegate.cornerCut
                                        startY: wallpaperDelegate.height
                                        PathLine { x: 0; y: wallpaperDelegate.height }
                                        PathLine { x: 0; y: wallpaperDelegate.height - wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.cornerCut; y: wallpaperDelegate.height }
                                    }
                                }

                                // Белая восьмиугольная рамка (5px)
                                Shape {
                                    anchors.fill: parent
                                    z: 3

                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "white"
                                        strokeWidth: 5
                                        fillColor: "transparent"

                                        startX: wallpaperDelegate.cornerCut
                                        startY: 0
                                        PathLine { x: wallpaperDelegate.width - wallpaperDelegate.cornerCut; y: 0 }
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.height - wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.width - wallpaperDelegate.cornerCut; y: wallpaperDelegate.height }
                                        PathLine { x: wallpaperDelegate.cornerCut; y: wallpaperDelegate.height }
                                        PathLine { x: 0; y: wallpaperDelegate.height - wallpaperDelegate.cornerCut }
                                        PathLine { x: 0; y: wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.cornerCut; y: 0 }
                                    }
                                }

                                // Подпись файла
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 2.5
                                    height: 20
                                    color: Qt.rgba(0, 0, 0, 0.5)
                                    z: 1

                                    Text {
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

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    z: 4
                                    onClicked: settingsRoot.applyWallpaper(wallpaperDelegate.path)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: settingsRoot.wallpaperModel.length === 0
                            text: "~/Pictures/Wallpapers"
                            color: Settings.barColor
                        }
                    }

                    // ===== Скроллбар =====
                    Rectangle {
                        id: wallpaperScrollTrack
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 5
                        radius: 0
                        color: Qt.rgba(0,0,0,0)
                        visible: wallpaperFlick.contentHeight > wallpaperFlick.height + 2

                        Rectangle {
                            id: wallpaperScrollHandle
                            width: parent.width
                            radius: parent.radius
                            color: Settings.barColor

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
                            anchors.margins: -5
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

                    // Кнопка обновления
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 5
                        width: 100
                        height: 24
                        radius: 12
                        color: "transparent"
                        border.color: Settings.barColor
                        z: 3

                        Text {
                            anchors.centerIn: parent
                            text: wallpaperScanner.running ? "Скан…" : "Обновить"
                            color: Settings.barColor
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsRoot.rescanWallpapers()
                        }
                    }
                }

                // Monitor
                Item {
                    visible: settingsRoot.currentTab === 3
                    anchors.fill: parent
                    anchors.margins: 5

                    Text {
                        text: "Monitor"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }

                // About
                Item {
                    visible: settingsRoot.currentTab === 4
                    anchors.fill: parent
                    anchors.margins: 5

                    Text {
                        text: "About"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }
            }
        }

        // Чёрная обводка окна контента (5px снару...[truncated]
        // Зависит от contentArea (id), поэтому не участвует в layout Column.
        Rectangle {
            id: contentBlackOutline
            anchors.fill: contentArea
            anchors.margins: -5
            z: -1
            color: "#000000"
        }

    }
}