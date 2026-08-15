import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

PanelWindow {
    id: settingsRoot
    visible: false
    exclusiveZone: -1 // Поверх всех окон
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    property var tabNames: ["System", "Bar", "Wallpapers", "Monitor", "About"]
    property int currentTab: 0

    // Затемнение фона при вызове меню
    MouseArea {
        anchors.fill: parent
        onClicked: settingsRoot.visible = false
    }

    // Окно меню
    Rectangle {
            
        id: windowFrame
        width: 700
        height: 500
        anchors.centerIn: parent
        color: "transparent"
        
        Column {
            anchors.fill : parent
            // anchors.margins: ((313.856 / 403.16)*10)/2
            spacing: 7.5
            anchors.horizontalCenter: parent.horizontalCenter
            // --- Система табов ---
            Item {
                id: tabBar
                width: parent.width - ((403.16 / 313.856)*10)
                height: 50
                anchors.horizontalCenter: parent.horizontalCenter

                property real point: height * (403.16/1000)
                property real tabWidth: width / settingsRoot.tabNames.length

                // 1. Основной контур бара
                Shape {
                    id: tabShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap // Гарантирует, что концы линий не вылезут за рамки
                        strokeColor: Settings.barColor
                        strokeWidth: 5
                        fillColor: "#000000"
                        startX: 0; startY: 0
                        PathLine { x: tabShape.width; y: 0 }
                        PathLine { x: tabShape.width - tabBar.point; y: tabShape.height / 2 }
                        PathLine { x: tabShape.width; y: tabShape.height }
                        PathLine { x: 0; y: tabShape.height }
                        PathLine { x: tabBar.point; y: tabShape.height / 2 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                // 2. Активный индикатор (плавно ездит)
                Shape {

            
                    id: activeIndicator
                    preferredRendererType: Shape.CurveRenderer
                    
                    property real indH: tabBar.height - 5 * 3
                    property real indPoint: indH * (403.16/1000)
                    
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
                        startX: 0; startY: 0
                        PathLine { x: activeIndicator.width; y: 0 }
                        PathLine { x: activeIndicator.width - activeIndicator.indPoint; y: activeIndicator.height / 2 }
                        PathLine { x: activeIndicator.width; y: activeIndicator.height }
                        PathLine { x: 0; y: activeIndicator.height }
                        PathLine { x: activeIndicator.indPoint; y: activeIndicator.height / 2 }
                        PathLine { x: 0; y: 0 }
                    }
                }

                // 3. Плавно анимированные перегородки (отдельные Shape для каждой)
                Repeater {
                    model: settingsRoot.tabNames.length - 1
                    delegate: Shape {
                        id: dividerShape // Добавляем id
                        preferredRendererType: Shape.CurveRenderer
                        anchors.fill: parent
                        z: 2 // Поверх белого индикатора

                        // Выносим свойство на уровень делегата, чтобы оно было видно внутри PathLine
                        property real xPos: (index + 1) * tabBar.tabWidth

                        ShapePath {
                            joinStyle: ShapePath.MiterJoin
                            capStyle: ShapePath.FlatCap // Убирает вылезающие хвостики сверху и снизу
                            strokeColor: Settings.barColor
                            strokeWidth: 5
                            fillColor: "transparent"

                            startX: dividerShape.xPos; startY: 0
                            PathLine {
                                // Обращаемся к xPos через id делегата
                                x: settingsRoot.currentTab <= index ? dividerShape.xPos - tabBar.point : dividerShape.xPos + tabBar.point
                                y: tabBar.height / 2
                                Behavior on x {
                                    NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                                }
                            }
                            PathLine {
                                x: dividerShape.xPos; y: tabBar.height
                                
                            }
                        }
                    }
                }

                // Текст табов (оверлей)
                // Текст табов (оверлей)
Row {
    anchors.fill: parent
    z: 3
    Repeater {
        model: settingsRoot.tabNames
        delegate: Item {
            width: tabBar.tabWidth
            height: tabBar.height

            // Считаем, с какой стороны вставка «съедает» пространство
            property real textOffset: {
                var i = index;
                var last = settingsRoot.tabNames.length - 1;
                // Левая вставка: край бара (для табa 0) ИЛИ перегородка слева наклоняется вправо
                var leftNotch = (i === 0) || (settingsRoot.currentTab >= i);
                // Правая вставка: край бара (для последнего таба) ИЛИ перегородка справа наклоняется влево
                var rightNotch = (i === last) || (settingsRoot.currentTab <= i);

                if (leftNotch && !rightNotch)  return  tabBar.point / 2;  // сдвинуть вправо
                if (rightNotch && !leftNotch) return -tabBar.point / 2;  // сдвинуть влево
                return 0;  // симметрично или обе вставки — центр не смещается
            }

            Text {
                text: modelData
                color: settingsRoot.currentTab === index ? "#0a0a0a" : Settings.barColor
                anchors.verticalCenter: parent.verticalCenter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: textOffset
                font.bold: true
                Behavior on color { ColorAnimation { duration: 200 } }
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

            // --- Контент табов ---
            Item {
                id: contentArea
                width: parent.width 
                height: parent.height - tabBar.height

                Rectangle {
                    
                    id: contentBackground
                    anchors.fill: parent
                    color: "#000000"
                    border.color: Settings.barColor
                    border.width: 5
                    z: 0
                }

                // Таб 0: система
                Item {
                    visible: settingsRoot.currentTab === 1
                    anchors.fill: parent
                    Text {
                        text: "чето чето"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }

                // Таб 1: Бар
                Item {
                    visible: settingsRoot.currentTab === 1
                    anchors.fill: parent
                    Text {
                        text: "чето чето"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }
                // Таб 2: Обои
                Item {
                    visible: settingsRoot.currentTab === 0
                    anchors.fill: parent

                    Column {
                        anchors.centerIn: parent
                        spacing: 15

                        Text {
                            text: "awww"
                            color: Settings.barColor
                            font.pixelSize: 16
                        }

                        Process {
                            id: wallProcess
                            command: ["bash", "-c", "awww --random --transition-type random"] 
                        }

                        Rectangle {
                            width: 200
                            height: 40
                            radius: 8
                            color: Settings.barColor
                            border.color: Settings.barColor

                            Text {
                                text: "Сменить случайно"
                                color: "#000000"
                                anchors.centerIn: parent
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    wallProcess.running = false
                                    wallProcess.running = true
                                }
                            }
                        }
                    }
                }
                // Таб 3: О системе
                Item {
                    visible: settingsRoot.currentTab === 2
                    anchors.fill: parent
                    Text {
                        text: "чето"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }
                // Таб 4: О системе
                Item {
                    visible: settingsRoot.currentTab === 2
                    anchors.fill: parent
                    Text {
                        text: "чето"
                        color: Settings.barColor
                        anchors.centerIn: parent
                    }
                }
            }
        }
    }
}