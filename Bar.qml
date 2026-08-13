import QtQuick
import QtQuick.Shapes
Item {
    property real fontLineWidth: 0
    id: barRoot

    // Внешняя черная обводка
    Shape {
        anchors.fill: parent
        layer.enabled: false 
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "black"
            strokeWidth: fontLineWidth*2 // Толщина обводки
            joinStyle: ShapePath.MiterJoin // Острые углы
            capStyle: ShapePath.FlatCap
            fillColor: Settings.barColor

            startX: Settings.leftMargin
            startY: Settings.barGap

            PathLine { x: Settings.leftMargin; y: Settings.barGap }
            PathLine { x: Settings.leftMargin + Settings.barHeight * (403.16/1000); y: Settings.barGap + Settings.barHeight / 2 }
            PathLine { x: Settings.leftMargin; y: Settings.barGap + Settings.barHeight }
            PathLine { x: width - Settings.rightMargin; y: Settings.barGap + Settings.barHeight }
            PathLine { x: width - Settings.rightMargin - Settings.barHeight * (403.16/1000); y: Settings.barGap + Settings.barHeight / 2 }
            PathLine { x: width - Settings.rightMargin; y: Settings.barGap }
            PathLine { x: Settings.leftMargin; y: Settings.barGap }
        }
    }
    // Средняя белая обводка
    Shape {
        anchors.fill: parent
        layer.enabled: false 
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Settings.barColor
            strokeWidth: fontLineWidth // Толщина обводки
            joinStyle: ShapePath.MiterJoin // Острые углы
            capStyle: ShapePath.FlatCap
            fillColor: Settings.barColor

            startX: Settings.leftMargin
            startY: Settings.barGap

            PathLine { x: Settings.leftMargin; y: Settings.barGap }
            PathLine { x: Settings.leftMargin + Settings.barHeight * (403.16/1000); y: Settings.barGap + Settings.barHeight / 2 }
            PathLine { x: Settings.leftMargin; y: Settings.barGap + Settings.barHeight }
            PathLine { x: width - Settings.rightMargin; y: Settings.barGap + Settings.barHeight }
            PathLine { x: width - Settings.rightMargin - Settings.barHeight * (403.16/1000); y: Settings.barGap + Settings.barHeight / 2 }
            PathLine { x: width - Settings.rightMargin; y: Settings.barGap }
            PathLine { x: Settings.leftMargin; y: Settings.barGap }
        }
    }

    // Черный бар
    Shape {
        preferredRendererType: Shape.CurveRenderer
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 8
        
        ShapePath {
            fillColor: "black"
            strokeColor: "transparent"

            startX: 0
            startY: 0

            PathLine { x: Settings.leftMargin; y: Settings.barGap }
            PathLine { x: Settings.leftMargin + Settings.barHeight * (403.16/1000); y: Settings.barGap + Settings.barHeight / 2 }
            PathLine { x: Settings.leftMargin; y: Settings.barGap + Settings.barHeight }
            PathLine { x: width - Settings.rightMargin; y: Settings.barGap + Settings.barHeight }
            PathLine { x: width - Settings.rightMargin - Settings.barHeight * (403.16/1000); y: Settings.barGap + Settings.barHeight / 2 }
            PathLine { x: width - Settings.rightMargin; y: Settings.barGap }
            PathLine { x: Settings.leftMargin; y: Settings.barGap }
        }
    }
}