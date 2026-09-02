import QtQuick

Item {
    id: clockRoot
    
    FontLoader {
        id: clockFont
        source: "fonts/infex-main-150.ttf"
    }

    property bool isHovered: false
    property bool showSeconds: Settings.secondsMode === 2 || (Settings.secondsMode === 1 && isHovered)
    
    property date currentTime: new Date()

    property real fontsize: Settings.barHeight / (2*(150/1000)+1)
    property real hvost: (((313.856) / 1000)) * fontsize
    
    width: textContainer.width + (hvost * 2) + (Settings.infex ? 0 : Settings.barHeight)
    height: Settings.barHeight + Settings.barGap * 2

    // контейнер, который держит оба текста и центрируется
    Item {
        id: textContainer
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        
        width: mainTime.implicitWidth + secWrapper.width
        height: parent.height

        Text {
            id: mainTime
            text: Qt.formatTime(clockRoot.currentTime, "HH:mm")
            
            font.family: Settings.infex ? clockFont.name : ""
            font.pixelSize: clockRoot.fontsize
            color: Settings.barColor

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }

        // контейнер для секунд
        Item {
            id: secWrapper
            anchors.left: mainTime.right // после основных часов
            anchors.verticalCenter: parent.verticalCenter
            
            height: secText.implicitHeight 

            // от 0 до реальной ширины текста
            width: clockRoot.showSeconds ? secText.implicitWidth : 0
            clip: true 

            Behavior on width {
                NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
            }

            Text {
                id: secText
                text: Qt.formatTime(clockRoot.currentTime, ":ss")
                
                font.family: Settings.infex ? clockFont.name : ""
                font.pixelSize: clockRoot.fontsize
                color: Settings.barColor

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: clockRoot.isHovered = true
        onExited: clockRoot.isHovered = false
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockRoot.currentTime = new Date()
    }
}