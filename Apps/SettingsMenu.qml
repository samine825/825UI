import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../SmoothColorElements"
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

    Item {
        id: windowFrame
        width: 700
        height: 500
        anchors.centerIn: parent

        Column {
            anchors.fill: parent
            spacing: Settings.line * 3.5

            // --- Tabs ---
            Item {
                id: tabBar
                width: parent.width - ((403.16 / 313.856) * 10)
                height: Settings.barHeight - Settings.line
                anchors.horizontalCenter: parent.horizontalCenter

                property real point: height * (403.16 / 1000)
                property real tabWidth: width / root.tabNames.length

                property real tabBorderWidth: Settings.line
                property real blackOutlineWidth: Settings.line

                // черная обводка
                Shape {
                    id: tabOuterOutline

                    anchors.fill: parent
                    z: -1
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
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

                    SShapePath {
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

                    width: tabBar.tabWidth - Settings.line * 6
                    height: indH
                    y: (tabBar.height - indH) / 2
                    x: root.currentTab * tabBar.tabWidth + Settings.line * 3

                    Behavior on x {
                        NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                    }

                    SShapePath {
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

                        property real xPos: (index + 1) * tabBar.tabWidth

                        SShapePath {
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
                            width: tabBar.tabWidth
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

                            SText {
                                text: modelData
                                color: root.currentTab === index ? Settings.c2 : Settings.c1
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.horizontalCenterOffset: textOffset
                                font.bold: true

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

                SRectangle {
                    x: -Settings.line
                    y: -Settings.line
                    width: parent.width + Settings.line * 2
                    height: parent.height + Settings.line * 2
                    color: Settings.c2
                    border.color: Settings.c2
                    border.width: Settings.line * 2
                }

                SRectangle {
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
                                    SShapePath {
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
                                    SShapePath {
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
                                    SShapePath {
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
                                    SShapePath {
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

                                    SShapePath {
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
                                SRectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: Settings.line/2
                                    height: 20
                                    color: '#77' + Settings.c2.slice(1);
                                    z: 1

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

                    // кнопка обновления
                    SRectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: Settings.line
                        width: 100
                        height: 24
                        radius: 12
                        color: "transparent"
                        border.color: Settings.c1
                        z: 3

                        SText {
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

        // чорн обводка окна контента
        SRectangle {
            id: contentBlackOutline
            anchors.fill: contentArea
            anchors.margins: -Settings.line
            z: -1
            color: Settings.c2
        }

    }
}