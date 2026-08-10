import QtQuick
import QtQuick.Shapes

Shape {
    anchors.fill: parent

    ShapePath {
        fillColor: Settings.barColor
        strokeColor: "transparent"

        startX: 0
        startY: 0

        PathLine {
            x: Settings.leftMargin
            y: Settings.barGap
        }

        PathLine {
            x: Settings.leftMargin + Settings.barHeight * (403.16/1000)
            y: Settings.barGap + Settings.barHeight / 2
        }

        PathLine {
            x: Settings.leftMargin
            y: Settings.barGap + Settings.barHeight
        }

        PathLine {
            x: width - Settings.rightMargin
            y: Settings.barGap + Settings.barHeight
        }

        PathLine {
            x: width - Settings.rightMargin - Settings.barHeight * (403.16/1000)
            y: Settings.barGap + Settings.barHeight / 2
        }

        PathLine {
            x: width - Settings.rightMargin
            y: Settings.barGap
        }

        PathLine {
            x: Settings.leftMargin
            y: Settings.barGap
        }
    }
}

//0.4228