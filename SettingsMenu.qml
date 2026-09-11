import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

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

        wallpaperApplyProcess.command = [
            "sh", "-c",
            "awww img --transition-fps 144 --transition-type random \"$1\" --transition-duration 1.5",
            "sh",
            path
        ]

        wallpaperApplyProcess.running = true
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
                height: Settings.barHeight - Settings.line
                anchors.horizontalCenter: parent.horizontalCenter

                property real point: height * (403.16 / 1000)
                property real tabBorderWidth: Settings.line
                property real blackOutlineWidth: Settings.line

                // Активная вкладка "съедается" стрелками разделителей на point слева и справа.
                // Компенсируем это, делая её номинально шире на 2 * point.
                property real activeExtra: root.currentTab >= 0 ? 2 * point : 0

                // Базовая ширина обычной (неактивной) вкладки
                property real baseTabWidth: (width - activeExtra) / root.tabNames.length

                // Левая граница вкладки i
                function tabX(i) {
                    return i * baseTabWidth
                        + (i > root.currentTab ? activeExtra : 0)
                }

                // Ширина вкладки i
                function tabW(i) {
                    return tabX(i + 1) - tabX(i)
                }

                // Плавная анимация при смене вкладки (предотвращает скачок при инициализации)
                property bool animationsEnabled: false
                Component.onCompleted: animationsEnabled = true

                // черная обводка
                Shape {
                    id: tabOuterOutline

                    anchors.fill: parent
                    z: -1
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap

                        strokeColor: Settings.c2

                        strokeWidth: tabBar.tabBorderWidth
                                    + tabBar.blackOutlineWidth * 2

                        fillColor: "transparent"

                        startX: 0
                        startY: 0

                        PathLine { x: tabShape.width;                y: 0 }
                        PathLine { x: tabShape.width - tabBar.point; y: tabShape.height / 2 }
                        PathLine { x: tabShape.width;                y: tabShape.height }
                        PathLine { x: 0;                             y: tabShape.height }
                        PathLine { x: tabBar.point;                  y: tabShape.height / 2 }
                        PathLine { x: 0;                             y: 0 }
                    }
                }

                Shape {
                    id: tabShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        strokeColor: Settings.c1
                        strokeWidth: Settings.line
                        fillColor: Settings.c2

                        startX: 0
                        startY: 0

                        PathLine { x: tabShape.width;                y: 0 }
                        PathLine { x: tabShape.width - tabBar.point; y: tabShape.height / 2 }
                        PathLine { x: tabShape.width;                y: tabShape.height }
                        PathLine { x: 0;                             y: tabShape.height }
                        PathLine { x: tabBar.point;                  y: tabShape.height / 2 }
                        PathLine { x: 0;                             y: 0 }
                    }
                }

                Shape {
                    id: activeIndicator
                    preferredRendererType: Shape.CurveRenderer

                    property real indH: tabBar.height - Settings.line * 3
                    property real indPoint: indH * (403.16 / 1000)
                    property real inset: Settings.line * 3

                    width: tabW(root.currentTab) - inset * 2
                    height: indH
                    y: (tabBar.height - indH) / 2
                    x: tabX(root.currentTab) + inset

                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        fillColor: Settings.c1
                        strokeColor: "transparent"

                        startX: 0
                        startY: 0

                        PathLine { x: activeIndicator.width;                            y: 0 }
                        PathLine { x: activeIndicator.width - activeIndicator.indPoint; y: activeIndicator.height / 2 }
                        PathLine { x: activeIndicator.width;                            y: activeIndicator.height }
                        PathLine { x: 0;                                                y: activeIndicator.height }
                        PathLine { x: activeIndicator.indPoint;                         y: activeIndicator.height / 2 }
                        PathLine { x: 0;                                                y: 0 }
                    }
                }

                Repeater {
                    model: root.tabNames.length - 1

                    delegate: Shape {
                        id: dividerShape
                        preferredRendererType: Shape.CurveRenderer
                        anchors.fill: parent
                        z: 2

                        property real xPos: tabX(index + 1)


                        ShapePath {
                            joinStyle: ShapePath.MiterJoin
                            capStyle: ShapePath.FlatCap
                            strokeColor: Settings.c1
                            strokeWidth: Settings.line
                            fillColor: "transparent"

                            startX: dividerShape.xPos
                            startY: 0

                            PathLine {
                                x: root.currentTab <= index
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
                        model: root.tabNames

                        delegate: Item {
                            x: tabX(index)
                            width: tabW(index)
                            height: tabBar.height

                            property real textOffset: {
                                var i = index
                                var last = root.tabNames.length - 1

                                var leftNotch = (i === 0) || (root.currentTab >= i)
                                var rightNotch = (i === last) || (root.currentTab <= i)

                                if (leftNotch && !rightNotch)
                                    return tabBar.point / 2

                                if (rightNotch && !leftNotch)
                                    return -tabBar.point / 2

                                return 0
                            }

                            Text {
                                text: modelData
                                color: root.currentTab === index ? Settings.c2 : Settings.c1
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
                                onClicked: root.currentTab = index
                            }
                        }
                    }
                }
            }

            // контент
            Item {
                id: contentArea
                width: parent.width
                height: parent.height - tabBar.height - Settings.line*1.5

                Rectangle {
                    x: -Settings.line
                    y: -Settings.line
                    width: parent.width + Settings.line * 2
                    height: parent.height + Settings.line * 2
                    color: Settings.c2
                    border.color: Settings.c2
                    border.width: Settings.line * 2
                }

                Rectangle {
                    anchors.fill: parent
                    color: Settings.c2
                    border.color: Settings.c1
                    border.width: Settings.line
                }

                // system
                Item {
                    visible: root.currentTab === 0
                    anchors.fill: parent
                    anchors.margins: Settings.line

                    Text {
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

                    Text {
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

                                // уголки
                                Shape {
                                    anchors.fill: parent
                                    z: 2

                                    // ВЛ
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: Settings.c2
                                        startX: 0
                                        startY: 0
                                        PathLine { x: wallpaperDelegate.cornerCut; y: 0 }
                                        PathLine { x: 0; y: wallpaperDelegate.cornerCut }
                                        PathLine { x: 0; y: 0 }
                                    }

                                    // ВП
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: Settings.c2
                                        startX: wallpaperDelegate.width - wallpaperDelegate.cornerCut
                                        startY: 0
                                        PathLine { x: wallpaperDelegate.width; y: 0 }
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.width - wallpaperDelegate.cornerCut; y: 0 }
                                    }

                                    // НП
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: Settings.c2
                                        startX: wallpaperDelegate.width
                                        startY: wallpaperDelegate.height - wallpaperDelegate.cornerCut
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.height }
                                        PathLine { x: wallpaperDelegate.width - wallpaperDelegate.cornerCut; y: wallpaperDelegate.height }
                                        PathLine { x: wallpaperDelegate.width; y: wallpaperDelegate.height - wallpaperDelegate.cornerCut }
                                    }

                                    // НЛ
                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: "transparent"
                                        fillColor: Settings.c2
                                        startX: wallpaperDelegate.cornerCut
                                        startY: wallpaperDelegate.height
                                        PathLine { x: 0; y: wallpaperDelegate.height }
                                        PathLine { x: 0; y: wallpaperDelegate.height - wallpaperDelegate.cornerCut }
                                        PathLine { x: wallpaperDelegate.cornerCut; y: wallpaperDelegate.height }
                                    }
                                }

                                // белая рамка
                                Shape {
                                    anchors.fill: parent
                                    z: 3

                                    ShapePath {
                                        joinStyle: ShapePath.MiterJoin
                                        capStyle: ShapePath.FlatCap
                                        strokeColor: Settings.c1
                                        strokeWidth: Settings.line 
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

                                // подпись
                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Settings.line/2
                                    height: 20
                                    color: '#77' + Settings.c2.slice(1);
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
                                    onClicked: root.applyWallpaper(wallpaperDelegate.path)
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: root.wallpaperModel.length === 0
                            text: "~/Pictures/Wallpapers"
                            color: Settings.c1
                        }
                    }

                    // скролл
                    Rectangle {
                        id: wallpaperScrollTrack
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Settings.line
                        radius: 0
                        color: Settings.c2
                        visible: wallpaperFlick.contentHeight > wallpaperFlick.height + 2

                        Rectangle {
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

                    // кнопка обновления
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: Settings.line
                        width: 100
                        height: 24
                        radius: 12
                        color: "transparent"
                        border.color: Settings.c1
                        z: 3

                        Text {
                            anchors.centerIn: parent
                            text: wallpaperScanner.running ? "Скан…" : "Обновить"
                            color: Settings.c1
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.rescanWallpapers()
                        }
                    }
                }

                // monitor
                Item {
                    visible: root.currentTab === 3
                    anchors.fill: parent
                    anchors.margins: Settings.line

                    Text {
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

                    Text {
                        text: "About"
                        color: Settings.c1
                        anchors.centerIn: parent
                    }
                }
            }
        }

        // чорн обводка окна контента
        Rectangle {
            id: contentBlackOutline
            anchors.fill: contentArea
            anchors.margins: -Settings.line
            z: -1
            color: Settings.c2
        }

    }
}