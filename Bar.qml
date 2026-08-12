import QtQuick
import QtQuick.Shapes

Shape {
    //anchors.fill: parent
    
        layer.enabled: true // 2. Enables high-quality anti-aliasing
        layer.samples: 8
        
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


    ShapePath {
        fillColor: Settings.barColor
        strokeColor: "transparent"

        startX: 0
        startY: 0

        
        PathLine {
            x: Settings.leftMargin - 50
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