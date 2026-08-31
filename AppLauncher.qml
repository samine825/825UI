import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt5Compat.GraphicalEffects

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
            "cd /data/data/com.termux/files/usr/share/applications && grep -E '^(Name|Exec|Icon)=' *.desktop 2>/dev/null"
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




    function ensureVisible(index) {
        if (filteredApps.length === 0) return
        let rowHeight = 32 + 2
        let itemY = index * rowHeight
        
        if (itemY < listFlick.contentY) {
            listFlick.contentY = itemY
        } else if (itemY + rowHeight > listFlick.contentY + listFlick.height) {
            listFlick.contentY = itemY + rowHeight - listFlick.height
        }
    }

    
	property var elementsCount: 11
	property var angle: 360.0 / elementsCount
    // круг
    Item {
        id: circle
        width: 900
        height: 900
        x: (Screen.width - width) / 2
        y: -900/2
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
            border.width: thickness + root.line*2
            
            border.color: "#000000"
            
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: width / 2
            border.width: thickness
            
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
            border.width: thickness - root.line*2
            
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
		        //preferredRendererType: Shape.CurveRenderer
		
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
			                font.family: "IosevkaTerm NF"
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
    // поиск
    Item {
    
        id: searchArea
        x: (Screen.width - width) / 2
        y: circle.height/4
        width: circle.height/4
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#000000"
            border.width: 5
            border.color: "#ffffff"
        }

        Text {
            id: searchIcon
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
            text: "\u2315"
            font.family: "IosevkaTerm NF"
            font.pixelSize: 16
            color: "#ffffff"
        }
        
        TextInput {
            id: searchInput
            anchors {
                left: searchIcon.right
                right: parent.right
                leftMargin: 10
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            color: "#ffffff"
            font.family: "IosevkaTerm NF"
            font.pixelSize: 13
            clip: true
            selectByMouse: true
            
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
    }
}