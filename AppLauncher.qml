import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

PanelWindow {
    FontLoader {
        id: clockFont
        source: "fonts/infex-main-150.ttf"
    }
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
        selectedIndex = 0
        filterText = ""

        updateFilter()
        root.visible = true

        circle.rotation = 0
        root.filterText = ""
        searchInput.text = ""
        searchInput.forceActiveFocus()
    }

    function hide() {
        root.visible = false
    }




    property var line: 5
    property var thickness: 90





//    property string filterText: ""
//    property int selectedIndex: 0
//    property var filteredApps: []

    readonly property int panelW: 520
    readonly property int panelH: Math.min(520, Screen.height - 160)

//    function updateFilter() {
//        let appsSource = DesktopEntries.applications.values || DesktopEntries.applications
//        let allApps = Array.from(appsSource)
//
//        let q = filterText.trim().toLowerCase()
//        if (q === "") {
//            filteredApps = allApps
//        } else {
//            filteredApps = allApps.filter(app =>
//                app.name && app.name.toLowerCase().indexOf(q) !== -1
//            )
//        }
//        if (selectedIndex >= filteredApps.length)
//            selectedIndex = 0
//    }
//
//    function launchApp(entry) {
//        Quickshell.execDetached({ command: entry.command, workingDirectory: entry.workingDirectory })
//        root.hide()
//    }

    property string filterText: ""
    property int selectedIndex: 0
    property var allApps: []
    property var filteredApps: []





	// ---
	// ВРЕМЕННЫЙ МОДУЛЬ
	Process {
	    id: appListLoader
	    command: [
	        "sh", "-c",
	        //"cd /data/data/com.termux/files/usr/share/applications && grep -E '^[[:space:]]*(Name|Exec|Icon)=' *.desktop 2>/dev/null"
	        "cd /usr/share/applications && grep -E '^(Name|Exec|Icon)=' *.desktop 2>/dev/null"
	    ]
	    running: true
	    property var tempApps: ({})

	    stdout: SplitParser {
	        onRead: (line) => {
	            line = line.trim();
	            if (!line) return;

	            let separator = line.indexOf(":");
	            if (separator < 1) return;

	            let fileName = line.substring(0, separator);
	            let kv = line.substring(separator + 1);
	            let eq = kv.indexOf("=");
	            if (eq < 1) return;

	            let key = kv.substring(0, eq);
	            let value = kv.substring(eq + 1).trim();

	            let app = appListLoader.tempApps[fileName];
	            if (!app)
	                app = {};

	            if (key === "Name")
	                app.name = value;
	            else if (key === "Exec")
	                app.command = value.replace(/%[fFuUidDkK]/g, "").trim();
	            else if (key === "Icon")
	                app.icon = value;

	            appListLoader.tempApps[fileName] = app;

	            let apps = [];
	            let files = Object.keys(appListLoader.tempApps);
	            for (let i = 0; i < files.length; ++i) {
	                let item = appListLoader.tempApps[files[i]];
	                if (item.name && item.command)
	                    apps.push(item);
	            }

	            apps.sort((a, b) => a.name.localeCompare(b.name));
	            root.allApps = apps;
	            root.updateFilter();
	        }
	    }
	}

	// Функция фильтрации (остается прежней) ---
	function updateFilter() {
	    let q = filterText.trim().toLowerCase();
	    if (q === "") {
	        filteredApps = root.allApps;
	    } else {
	        filteredApps = root.allApps.filter(app =>
	            app.name && app.name.toLowerCase().indexOf(q) !== -1
	        );
	    }
	    if (filteredApps.length === 0) {
	        selectedIndex = 0;
	        circle.rotation = 0;
	    } else if (selectedIndex >= filteredApps.length) {
	        selectedIndex = filteredApps.length - 1;
	        circle.rotation = selectedIndex * angle;
	    }
	}

	// Функция запуска (использует родную команду из .desktop) ---
	function launchApp(entry) {
	    if (!entry) return;
	    // Запускает бинарник или скрипт, прописанный в Exec=
	    Quickshell.execDetached({ command: entry.command });
	    root.hide();
	}

	// ---

	property var elementsCount: 11
	property var angle: 360.0 / elementsCount
    // круг
    Item {


        //transform: Rotation {id: abcd; origin.x: 500; origin.y: 500; axis { x: 0; y: 1; z: 0 } angle: 54 }
        id: circle
        width: 900
        height: 900
        x: (Screen.width - width) / 2
        y: -width/2
		rotation: 0
        Behavior on rotation {
            NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
        }
        Rectangle {
            x: -root.line
            y: -root.line
            width: circle.width + root.line*2
            height: circle.height + root.line*2

            color: "transparent"
            radius: width / 2
            border.width: root.thickness + root.line*2

            border.color: "#000000"

            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: width / 2
            border.width: root.thickness

            border.color: "#ffffff"

            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.topMargin: root.line
            anchors.bottomMargin: root.line
            anchors.leftMargin: root.line
            anchors.rightMargin: root.line

            color: "transparent"
            radius: width / 2
            border.width: root.thickness - root.line*2

            border.color: "#000000"

            layer.enabled: true
        }


        Repeater {
            model: elementsCount

            delegate: Shape {
                id: dividerShape
                preferredRendererType: Shape.CurveRenderer
                anchors.fill: parent
                z: 1

                property real pointCoef: (403.16 / 1000)

                rotation: index * angle

                ShapePath {
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap
                    strokeColor: Settings.barColor
                    strokeWidth: root.line
                    fillColor: "transparent"

                    startX: dividerShape.width / 2
                    startY: root.line * 0.5

                    PathLine {
                        x: 180 <= ((index + root.selectedIndex) % root.elementsCount) * root.angle
                            ? dividerShape.width / 2 - dividerShape.pointCoef * (root.thickness - root.line * 0.5)
                            : dividerShape.width / 2 + dividerShape.pointCoef * (root.thickness - root.line * 0.5)
                        y: root.thickness / 2

                        Behavior on x {
                            NumberAnimation { duration: 500; easing.type: Easing.InOutQuad }
                        }
                    }

                    PathLine {
                        x: dividerShape.width / 2
                        y: root.thickness - root.line * 0.5
                    }
                }
            }
        }

        Item {
		    id: active
		    width: circle.width
		    height: circle.height

		    z: 2
		    rotation: -circle.rotation
		    Shape {

		        id: activeShape
		        anchors.fill: parent
		        preferredRendererType: Shape.CurveRenderer

		        ShapePath {
		            id: sh
		            fillColor: "#ffffff"
		            strokeColor: "transparent"
		            strokeWidth: 0

		            // дуги
		            readonly property real rr: circle.width / 2 - root.line * 2
		            readonly property real r: circle.width / 2 - (root.thickness - root.line * 2)

		            // углы дуг
		            readonly property real angle1: (90-root.angle/2) * Math.PI / 180
		            readonly property real angle2: (90+root.angle/2) * Math.PI / 180

		            function offX(theta, radius, sign) {
		                var t = Math.sqrt(Math.max(0, radius*radius - root.line*root.line*9))
		                return circle.width/2 + t * Math.cos(theta) - sign * 3*root.line * Math.sin(theta)
		            }
		            function offY(theta, radius, sign) {
		                var t = Math.sqrt(Math.max(0, radius*radius - root.line*root.line*9))
		                return circle.height/2 + t * Math.sin(theta) + sign * 3*root.line * Math.cos(theta)
		            }

		            readonly property real rMid: (rr + r) / 2
		            readonly property real pointCoef: 403.16 / 1000
		            readonly property real notchDepth: pointCoef * (root.thickness - root.line * 3)

		            startX: sh.offX(sh.angle1, sh.rr, 1)
		            startY: sh.offY(sh.angle1, sh.rr, 1)

		            // внешняя дуга
		            PathArc {
		                x: sh.offX(sh.angle2, sh.rr, -1)
		                y: sh.offY(sh.angle2, sh.rr, -1)
		                radiusX: sh.rr
		                radiusY: sh.rr
		                useLargeArc: false
		                direction: PathArc.Clockwise
		            }
		            // право верх
		            PathLine {
		                x: sh.offX(sh.angle2, sh.rMid, -1) + sh.notchDepth * Math.sin(sh.angle2)
		                y: sh.offY(sh.angle2, sh.rMid, -1) - sh.notchDepth * Math.cos(sh.angle2)
		            }
		            // право низ
		            PathLine {
		                x: sh.offX(sh.angle2, sh.r, -1)
		                y: sh.offY(sh.angle2, sh.r, -1)
		            }
		            // внутренняя дуга
		            PathArc {
		                x: sh.offX(sh.angle1, sh.r, 1)
		                y: sh.offY(sh.angle1, sh.r, 1)
		                radiusX: sh.r
		                radiusY: sh.r
		                useLargeArc: false
		                direction: PathArc.Counterclockwise
		            }
		            // лево низ
		            PathLine {
		                x: sh.offX(sh.angle1, sh.rMid, 1) - sh.notchDepth * Math.sin(sh.angle1)
		                y: sh.offY(sh.angle1, sh.rMid, 1) + sh.notchDepth * Math.cos(sh.angle1)
		            }
		            // лево верх
		            PathLine {
		                x: sh.startX
		                y: sh.startY
		            }
		        }
		    }
		}
        Repeater {
		    model: root.filteredApps

		    delegate: Item {
		        z: 3
		        property real pointCoef: (403.16 / 1000)
		        id: appCell
		        anchors.fill: parent
		        visible: Math.abs(index - root.selectedIndex) <= Math.floor(root.elementsCount / 2)
		        rotation: -index * root.angle

		        Item {
		            y: appCell.height - root.thickness + root.line
		            property var dlinna: (Math.sin((angle/2)*(Math.PI / 180))*(circle.height/2))*2

		            property bool idx0: 0 <= -((-index+1 + selectedIndex) % elementsCount) * angle
		            property bool idx1: 0 <= -((-index + selectedIndex) % elementsCount) * angle
		            property var gR: idx0
		                        ? ((circle.width-dlinna) / 2) - (pointCoef * (thickness - (line * 0.5))*0.5)
		                        : ((circle.width-dlinna) / 2) + (pointCoef * (thickness - (line * 0.5))*0.5)
		            property var gL: idx0 === idx1
		                        ? dlinna
		                        : idx1
		                        ? dlinna - (pointCoef * (thickness - (line * 0.5)))
		                        : dlinna + (pointCoef * (thickness - (line * 0.5)))
		            x: gR
		            width: gL
		            height: root.thickness - root.line*2
		            Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }
		            Behavior on x { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

		            Column {
		            	anchors.centerIn: parent
			            Image {
			                id: appIcon
			                width: 40
			                height: 40
			                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
			                fillMode: Image.PreserveAspectFit
			                smooth: true
			                visible: source !== "" && status === Image.Ready
			                anchors.horizontalCenter: parent.horizontalCenter
			            }
			            Text {
			                id: appText
			                color: index === root.selectedIndex ? "#000000" : "#ffffff"
			                Behavior on color { ColorAnimation { duration: 300 } }

			                text: modelData.name || ""
			                font.family: Settings.infex ? clockFont.name : ""
			                font.pixelSize: 15
			                horizontalAlignment: Text.AlignHCenter
			                verticalAlignment: Text.AlignVCenter
			                anchors.horizontalCenter: parent.horizontalCenter
			                elide: Text.ElideRight
			            }
	            	}
		        }
		    }
		}
    }

    Item {
        id: searchArea
        width: circle.width - root.thickness*2 - root.line*6 - inputHeight
        height: circle.height - root.thickness*2 - root.line*6  - inputHeight
        x: circle.x + circle.width/2
        y: circle.y + circle.width/2

        property real arcRadius: searchArea.width/2
        property real arcCenterX: circle.width / 2
        property real arcCenterY: circle.height / 2
        property real charAngle: 3

        property real firstAngle: curvedText.firstAngle + 90
        property real secondAngle: -curvedText.firstAngle - 90

        property real inputHeight: 50

        readonly property real angleDiff: {
            let diff = (searchArea.secondAngle - searchArea.firstAngle) % 360;
            if (diff < 0) diff += 360;
            return diff;
        }
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "#000000"
                strokeWidth: searchArea.inputHeight + root.line*2
                fillColor: "transparent"

                startX: searchArea.width/2 * Math.sin(searchArea.firstAngle * Math.PI / 180)
                startY: searchArea.width/2 * Math.cos(searchArea.firstAngle * Math.PI / 180)

                PathArc {
                    x: searchArea.width/2 * Math.sin(searchArea.secondAngle * Math.PI / 180)
                    y: searchArea.width/2 * Math.cos(searchArea.secondAngle * Math.PI / 180)
                    radiusX: searchArea.width / 2
                    radiusY: searchArea.height / 2
                    direction: PathArc.Counterclockwise
                    useLargeArc: searchArea.angleDiff > 180
                    Behavior on x {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                }
                Behavior on startX {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on startY {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
            }

            ShapePath {
                strokeColor: "#ffffff"
                strokeWidth: searchArea.inputHeight
                fillColor: "transparent"

                startX: searchArea.width/2 * Math.sin(searchArea.firstAngle * Math.PI / 180)
                startY: searchArea.width/2 * Math.cos(searchArea.firstAngle * Math.PI / 180)

                PathArc {
                    x: searchArea.width/2 * Math.sin(searchArea.secondAngle * Math.PI / 180)
                    y: searchArea.width/2 * Math.cos(searchArea.secondAngle * Math.PI / 180)
                    radiusX: searchArea.width / 2
                    radiusY: searchArea.height / 2
                    direction: PathArc.Counterclockwise
                    useLargeArc: searchArea.angleDiff > 180
                    Behavior on x {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                }
                Behavior on startX {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on startY {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
            }

            ShapePath {
                strokeColor: "#000000"
                strokeWidth: searchArea.inputHeight - root.line*2
                fillColor: "transparent"

                startX: searchArea.width/2 * Math.sin(searchArea.firstAngle * Math.PI / 180)
                startY: searchArea.width/2 * Math.cos(searchArea.firstAngle * Math.PI / 180)

                PathArc {
                    x: searchArea.width/2 * Math.sin(searchArea.secondAngle * Math.PI / 180)
                    y: searchArea.width/2 * Math.cos(searchArea.secondAngle * Math.PI / 180)
                    radiusX: searchArea.width / 2
                    radiusY: searchArea.height / 2
                    direction: PathArc.Counterclockwise
                    useLargeArc: searchArea.angleDiff > 180
                    Behavior on x {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 100
                            easing.type: Easing.OutQuad
                        }
                    }
                }
                Behavior on startX {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on startY {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }

        TextInput {
            id: searchInput
            x: 0
            y: 0
            width: 1
            height: 1
            color: "transparent"
            font.pixelSize: 1
            opacity: 0.01
            clip: false
            cursorVisible: false
            selectByMouse: false
            focus: true

            onTextChanged: {
                root.filterText = text
                root.updateFilter()
            }

            Keys.onReturnPressed: {
                if (root.selectedIndex < root.filteredApps.length)
                    root.launchApp(root.filteredApps[root.selectedIndex])
            }

            Keys.onLeftPressed: {
                if (root.selectedIndex > 0) {
                    root.selectedIndex -= 1
                    circle.rotation = root.selectedIndex * root.angle
                }
            }

            Keys.onRightPressed: {
                if (root.selectedIndex < root.filteredApps.length - 1) {
                    root.selectedIndex += 1
                    circle.rotation = root.selectedIndex * root.angle
                }
            }

            Keys.onEscapePressed: {
                root.hide()
            }
        }

        Item {
            id: curvedText
            anchors.fill: parent

            readonly property real r: searchArea.arcRadius

            property var anglesArray: []
            property real totalTextAngle: 0
            Behavior on totalTextAngle {NumberAnimation { duration: 1}}

            function recalculateAngles() {
                let count = textRepeater.count;
                let widths = [];
                let totalW = 0;

                for (let i = 0; i < count; ++i) {
                    let item = textRepeater.itemAt(i);
                    let w = item ? item.contentWidth : 12;
                    widths.push(w);
                    totalW += w;
                }

                totalTextAngle = (totalW / (2 * Math.PI * r)) * 360;

                let currentAngleOffset = 0;
                let tempAngles = [];

                for (let i = 0; i < count; ++i) {
                    let charAngleWidth = (widths[i] / (2 * Math.PI * r)) * 360;
                    tempAngles.push(currentAngleOffset + charAngleWidth / 2);
                    currentAngleOffset += charAngleWidth;
                }

                anglesArray = tempAngles;
            }

            property real firstAngle: 270 - totalTextAngle / 2

            Repeater {
                id: textRepeater
                model: searchInput.text.length

                delegate: Text {
                    font.family: Settings.infex ? clockFont.name : ""
                    id: charText
                    required property int index
                    property string character: searchInput.text.charAt(index)

                    color: "#ffffff"
                    font.pixelSize: 20
                    text: character
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter

                    onContentWidthChanged: curvedText.recalculateAngles()

                    property real myAngleOffset: (curvedText.anglesArray && curvedText.anglesArray.length > index) 
                        ? curvedText.anglesArray[index] 
                        : 0

                    property real theta: (curvedText.firstAngle + (curvedText.totalTextAngle - myAngleOffset)) * Math.PI / 180

                    x: -searchArea.arcRadius * Math.cos(theta) - width / 2
                    y: -searchArea.arcRadius * Math.sin(theta) - height / 2
                    rotation: theta * 180 / Math.PI + 90

                    Behavior on x { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                    Behavior on y { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                    Behavior on rotation { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                }
            }

            Connections {
                target: searchInput
                function onTextChanged() {
                    Qt.callLater(curvedText.recalculateAngles);
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onClicked: {
                searchInput.forceActiveFocus()
            }
        }
    }
}