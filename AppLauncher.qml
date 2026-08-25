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
        selectedIndex = 0
        filterText = ""
        if (searchInput) searchInput.text = ""
        updateFilter()
        root.visible = true
        
        searchInput.forceActiveFocus()
    }

    function hide() {
        root.visible = false
    }

    property var line: 5
    property var thickness: 90




    property string filterText: ""
    property int selectedIndex: 0
    property var filteredApps: []

    readonly property int panelW: 520
    readonly property int panelH: Math.min(520, Screen.height - 160)

    function updateFilter() {
        let appsSource = DesktopEntries.applications.values || DesktopEntries.applications
        let allApps = Array.from(appsSource)
        
        let q = filterText.trim().toLowerCase()
        if (q === "") {
            filteredApps = allApps
        } else {
            filteredApps = allApps.filter(app =>
                app.name && app.name.toLowerCase().indexOf(q) !== -1
            )
        }
        if (selectedIndex >= filteredApps.length)
            selectedIndex = 0
    }

    function launchApp(entry) {
        Quickshell.execDetached({ command: entry.command, workingDirectory: entry.workingDirectory })
        root.hide()
    }

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

    

    // круг
    Item {
        id: panel
        width: 900
        height: 900
        x: (Screen.width - width) / 2
//        y: -900/2

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: width / 2
            border.width: thickness
            
            border.color: "#000000"
            
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
            
            border.color: "#ffffff"
            
            layer.enabled: true
        }
        Rectangle {
            anchors.fill: parent

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.topMargin: root.line * 2
            anchors.bottomMargin: root.line * 2
            anchors.leftMargin: root.line * 2
            anchors.rightMargin: root.line * 2

            color: "transparent"
            radius: width / 2
            border.width: thickness - root.line*4
            
            border.color: "#000000"
            
            layer.enabled: true
        }

        // поиск
        Item {
            id: searchArea
            x: 20
            y: 16
            width: parent.width - 40
            height: 36

            Rectangle {
                anchors.fill: parent
                radius: 4
                color: "#252540"
                border.width: 1
                border.color: "#35355a"
            }

            Text {
                id: searchIcon
                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                text: "\u2315"
                font.family: "IosevkaTerm NF"
                font.pixelSize: 16
                color: "#6a6a8a"
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
                color: "#e0e0f0"
                font.family: "IosevkaTerm NF"
                font.pixelSize: 13
                clip: true
                selectByMouse: true

                onTextChanged: {
                    root.filterText = text
                    root.updateFilter()
                }

                Keys.onReturnPressed: {
                    if (root.selectedIndex < root.filteredApps.length)
                        root.launchApp(root.filteredApps[root.selectedIndex])
                }

                Keys.onUpPressed: {
                    if (root.selectedIndex > 0)
                        root.selectedIndex--
                    root.ensureVisible(root.selectedIndex)
                }
                Keys.onDownPressed: {
                    if (root.selectedIndex < root.filteredApps.length - 1)
                        root.selectedIndex++
                    root.ensureVisible(root.selectedIndex)
                }
                Keys.onEscapePressed: {
                    root.hide()
                }
            }
        }

        // список
        Flickable {
            id: listFlick
            x: 12
            y: searchArea.bottom + 8
            width: parent.width - 24
            height: parent.height - y - 12
            contentWidth: width
            contentHeight: listCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: listCol
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.filteredApps

                    delegate: Item {
                        id: row
                        width: listCol.width
                        height: 32

                        readonly property bool selected: index === root.selectedIndex

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            color: row.selected ? "#35355a" : "transparent"
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10

                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                height: 18
                                source: modelData.icon ? Quickshell.iconPath(modelData.icon, "application-x-executable") : ""
                                visible: status === Image.Ready
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.name
                                font.family: "IosevkaTerm NF"
                                font.pixelSize: 13
                                color: row.selected ? "#ffffff" : "#b0b0d0"
                                elide: Text.ElideRight
                                width: row.width - 40 
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.genericName || ""
                                font.family: "IosevkaTerm NF"
                                font.pixelSize: 11
                                color: "#555570"
                                elide: Text.ElideRight
                                width: Math.max(0, row.width - 160)
                                visible: text.length > 0
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: {
                                root.selectedIndex = index
                                root.launchApp(modelData)
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: root.filteredApps.length === 0
            text: "No apps found"
            font.family: "IosevkaTerm NF"
            font.pixelSize: 13
            color: "#555570"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: searchArea.bottom
            anchors.topMargin: 40
        }
    }
}