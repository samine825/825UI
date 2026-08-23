import QtQuick
import Quickshell
import QtQuick.Window
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

Rectangle {
    id: popupWindow

    property var maxWidth: 400
    property var startSize: 80
    property var line: 5

    y: -startSize
    x: !maxY ? ((screenX - width) / 2) : undefined
    width: startSize
    height: startSize
    color: 'transparent'

    FontLoader { 
        id: notifFont 
        source: "fonts/infex-main-150.ttf" 
    }
    
    property var currentNotification: null
    property var screenX: 0
    property real progress: 1.0

    Component {
        id: contentLayout
        
        Item {
            id: contentRoot
            anchors.fill: parent

            // парент ссылается на лоадер
            property color currentTextColor: parent.textColor
            property color currentBgColor: parent.backgroundColor

            // 1. маск
            Shape {
                id: maskShape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                visible: false

                property real point: parent.height * 0.5
                property real pad: parent.height * (313.857/2000)

                ShapePath {
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap
                    fillColor: "#ffffff"

                    startX: gs.padX
                    startY: gs.padY
                    
                    PathLine { x: gs.width - gs.padX; y: gs.padY }
                    PathLine { x: gs.width - gs.center; y: gs.center }
                    PathLine { x: gs.width - gs.padX; y: gs.height - gs.padY }
                    PathLine { x: gs.padX; y: gs.height - gs.padY }
                    PathLine { x: gs.center; y: gs.height - gs.center }
                    PathLine { x: gs.padX; y: gs.padY }
                }
            }

            // 2. контент
            Item {
                id: actualContent
                anchors.fill: parent
                visible: false 
                
                // задний фон 
                Rectangle {
                    anchors.fill: parent
                    color: contentRoot.currentBgColor
                }

                Row {
                    spacing: 12
                    width: parent.width
                    height: parent.height
                    
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right

                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    anchors.leftMargin: startSize - ((width - startSize)/16)
                    anchors.rightMargin: startSize - ((width - startSize)/16)

                    Image {
                        id: notifImage
                        width: startSize - 10*2
                        height: startSize - 10*2
                        fillMode: Image.PreserveAspectCrop
                        source: popupWindow.currentNotification ? popupWindow.currentNotification.image : ""
                        visible: popupWindow.currentNotification && popupWindow.currentNotification.image !== ""
                    }

                    Column {
                        id: contentColumn
                        width: parent.width - (notifImage.visible ? (notifImage.width + parent.spacing) : 0) - 40 
                        spacing: 5
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: popupWindow.currentNotification ? popupWindow.currentNotification.appName : ""
                            font.pixelSize: 10
                            color: contentRoot.currentTextColor
                            width: parent.width
                        }
                        Text {
                            text: popupWindow.currentNotification ? popupWindow.currentNotification.summary : ""
                            font.pixelSize: 15
                            font.bold: true
                            color: contentRoot.currentTextColor
                            wrapMode: Text.Wrap
                            width: parent.width
                        }
                        Text {
                            text: popupWindow.currentNotification ? popupWindow.currentNotification.body : ""
                            font.pixelSize: 10
                            color: contentRoot.currentTextColor
                            wrapMode: Text.Wrap
                            width: parent.width
                            visible: text.length > 0
                        }
                    }
                }
            }

            // 3. применение маски
            OpacityMask {
                anchors.fill: parent
                source: actualContent
                maskSource: maskShape
            }
        }
    }

    // 1. нижний слой
    Loader {
        id: runeDownLayer
        anchors.fill: parent
        sourceComponent: contentLayout
        property color textColor: '#000000'
        property color backgroundColor: '#ffffff'
    }

    // 2. верхний слой
    Item {
        id: progressBarContainer
        height: parent.height
        width: popupWindow.width * popupWindow.progress
        clip: true

        Loader {
            id: runeUpLayer
            width: popupWindow.width 
            height: popupWindow.height
            sourceComponent: contentLayout
            property color textColor: '#ffffff'
            property color backgroundColor: '#000000'
        }
    }


    // АНИМАЦИЯ
    
    // вылет по центру

    PropertyAnimation {
        id: progressAnimationColor
        target: runeUpLayer
        property: "backgroundColor"
        from: '#00000000'
        to: '#ff000000'
        duration: 1500
        running: popupWindow.currentNotification !== null && popupWindow.screenX !== null
        easing.type: Easing.InCubic
    }
    PropertyAnimation {
        id: progressAnimationColor2
        target: runeDownLayer
        property: "backgroundColor"
        from: '#00000000'
        to: '#ffffffff'
        duration: 1500
        running: popupWindow.currentNotification !== null && popupWindow.screenX !== null
        easing.type: Easing.InCubic
    }
    PropertyAnimation {
        id: progressAnimationY
        target: popupWindow
        property: "y"
        from: -startSize
        to: 300
        duration: 600
        running: popupWindow.currentNotification !== null && popupWindow.screenX !== null
        easing.type: Easing.OutCubic
        onFinished: {
            maxY = true
        }
    }
    PropertyAnimation {
        id: progressAnimationRotation
        target: popupWindow
        property: "rotation"
        from: 0
        to: 180
        duration: 600
        running: popupWindow.currentNotification !== null && popupWindow.screenX !== null
        easing.type: Easing.OutSine
    }
    property var maxY: false

    // уход в угол

    PropertyAnimation {
        id: progressAnimationX
        target: popupWindow
        property: "x"
        from: popupWindow.x
        to: popupWindow.screenX - (maxWidth+startSize+popupWindow.line)/2
        duration: 1200
        running: maxY !== false && closeClicked !== true
        easing.type: Easing.InOutCubic
    }
    PropertyAnimation {
        id: progressAnimationY2
        target: popupWindow
        property: "y"
        from: popupWindow.y
        to: popupWindow.line
        duration: 1200
        running: maxY !== false && closeClicked !== true
        easing.type: Easing.InCubic
    }
    PropertyAnimation {
        id: progressAnimationRotation2
        target: popupWindow
        property: "rotation"
        from: popupWindow.rotation
        to: 360
        duration: 1200
        running: maxY !== false
        easing.type: Easing.InOutBack
        onFinished: {
            ugolFinished = true && closeClicked !== true
        }
    }
    property var ugolFinished: false

    // раскрытие

    PropertyAnimation {
        id: progressAnimationWidth
        target: popupWindow
        property: "width"
        from: popupWindow.width
        to: maxWidth
        duration: 700
        running: ugolFinished !== false && closeClicked !== true
        easing.type: Easing.OutBack
    }
    PropertyAnimation {
        id: progressAnimationX2
        target: popupWindow
        property: "x"
        from: popupWindow.x
        to: popupWindow.screenX - maxWidth - ((20*(313.857/2000) * popupWindow.line) / 1.5)
        duration: 700
        running: ugolFinished !== false && closeClicked !== true
        easing.type: Easing.OutBack
        onFinished: {
            main = true
        }
    }
    property var main: false

    // время нахождения на экране после раскрытия
    PropertyAnimation {
        id: progressAnimationnn
        target: popupWindow
        property: "progress"
        from: 1.0
        to: 0.0
        duration: (popupWindow.currentNotification && popupWindow.currentNotification.expireTimeout > 0)
                  ? popupWindow.currentNotification.expireTimeout / 2
                  : 5000
        running: main !== false && !closeClicked
        easing.type: Easing.Linear
        onFinished: {
            uhod = true
        }
    }
    property var uhod: false

    // после времени нахождения на экране
    PropertyAnimation {
        id: progressAnimationWidth2
        target: popupWindow
        property: "width"
        from: popupWindow.width
        to: startSize
        duration: 1000
        running: uhod !== false || closeClicked !== false
        easing.type: Easing.InBack
    }
    PropertyAnimation {
        id: progressAnimationX3
        target: popupWindow
        property: "x"
        from: popupWindow.x
        to: popupWindow.screenX - (maxWidth+startSize+((20*(313.857/2000) * popupWindow.line) / 1.5))/2
        duration: 1000
        running: uhod !== false || closeClicked !== false
        easing.type: Easing.InBack
    }
    PropertyAnimation {
        id: progressAnimationY3
        target: popupWindow
        property: "y"
        from: popupWindow.y
        to: -startSize
        duration: 1000
        running: uhod !== false || closeClicked !== false
        easing.type: Easing.InQuad
        onFinished: {
            if (popupWindow.currentNotification) {
                Notifications.dismissNotification(popupWindow.currentNotification.notificationId)
                popupWindow.destroy()
            }
        }
    }

    // черная большая обводка (line x3)
    Shape {
        id: gsD
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        enabled: false

        property real center: parent.height * 0.5
        property real padX: (20*(313.857/2000) * popupWindow.line) / 3
        property real padY: popupWindow.line/2

        ShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            
            strokeColor: '#000000'
            strokeWidth: 15
            fillColor: "transparent"

            startX: gs.padX
            startY: gs.padY
            
            PathLine { x: gs.width - gs.padX; y: gs.padY }
            PathLine { x: gs.width - gs.center; y: gs.center }
            PathLine { x: gs.width - gs.padX; y: gs.height - gs.padY }
            PathLine { x: gs.padX; y: gs.height - gs.padY }
            PathLine { x: gs.center; y: gs.height - gs.center }
            PathLine { x: gs.padX; y: gs.padY }
        }
    }
    // белая большая обводка (line x1)
    Shape {
        id: gs
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        enabled: false
        

        property real center: parent.height * 0.5
        property real padX: (20*(313.857/2000) * popupWindow.line) / 3
        property real padY: popupWindow.line/2
        
        ShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap
            
            strokeColor: "#ffffff"
            strokeWidth: 5
            fillColor: "transparent"

            startX: gs.padX
            startY: gs.padY
            
            PathLine { x: gs.width - gs.padX; y: gs.padY }
            PathLine { x: gs.width - gs.center; y: gs.center }
            PathLine { x: gs.width - gs.padX; y: gs.height - gs.padY }
            PathLine { x: gs.padX; y: gs.height - gs.padY }
            PathLine { x: gs.center; y: gs.height - gs.center }
            PathLine { x: gs.padX; y: gs.padY }
        }
    }


    // клик закрытия
    MouseArea {
        anchors.fill: parent
        onClicked: {
            closeClicked = true
        }
    }
    property var closeClicked: false
}
