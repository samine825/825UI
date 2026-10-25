import QtQuick

Item {
    id: root
    
    property int cellSize: 20
    property int interval: 100
    property bool running: true
    property color color: "#ffffff"

    property real animationSpeed: 0.10
    
    property int cols: Math.floor(width / cellSize)
    property int rows: Math.floor(height / cellSize)
    
    property var grid: []

    onColsChanged: resetGrid()
    onRowsChanged: resetGrid()

    function resetGrid() {
        if (cols <= 0 || rows <= 0) return;
        var newGrid = [];
        for (var i = 0; i < cols; i++) {
            newGrid[i] = [];
            for (var j = 0; j < rows; j++) {
                newGrid[i][j] = { target: 0, progress: 0.0 };
            }
        }
        grid = newGrid;
        canvas.requestPaint();
    }

    function clearGrid() {
        resetGrid();
    }

    function updateLife() {
        if (!running || cols <= 0 || rows <= 0) return;

        var nextGrid = [];
        for (var i = 0; i < cols; i++) {
            nextGrid[i] = [];
            for (var j = 0; j < rows; j++) {
                var neighbors = countNeighbors(i, j);
                var currentCell = grid[i][j];
                var nextTarget = currentCell.target;

                if (currentCell.target === 1) {
                    nextTarget = (neighbors === 2 || neighbors === 3) ? 1 : 0;
                } else {
                    nextTarget = (neighbors === 3) ? 1 : 0;
                }
                
                nextGrid[i][j] = { target: nextTarget, progress: currentCell.progress };
            }
        }
        grid = nextGrid;
    }

    function countNeighbors(x, y) {
        var count = 0;
        for (var i = -1; i <= 1; i++) {
            for (var j = -1; j <= 1; j++) {
                if (i === 0 && j === 0) continue;
                var col = (x + i + cols) % cols;
                var row = (y + j + rows) % rows;
                count += grid[col][row].target;
            }
        }
        return count;
    }

    Timer {
        interval: root.interval
        running: root.running
        repeat: true
        onTriggered: root.updateLife()
    }

    Timer {
        id: animationTimer
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            if (root.cols <= 0 || root.rows <= 0) return;
            
            var needsPaint = false;
            for (var i = 0; i < root.cols; i++) {
                for (var j = 0; j < root.rows; j++) {
                    var cell = root.grid[i][j];
                    if (cell.progress !== cell.target) {
                        if (cell.target === 1) {
                            cell.progress = Math.min(1.0, cell.progress + root.animationSpeed);
                        } else {
                            cell.progress = Math.max(0.0, cell.progress - root.animationSpeed);
                        }
                        needsPaint = true;
                    }
                }
            }
            if (needsPaint) {
                canvas.requestPaint();
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            if (!root.grid.length) return;

            ctx.fillStyle = root.color;
            ctx.strokeStyle = root.color;

            for (var i = 0; i < root.cols; i++) {
                for (var j = 0; j < root.rows; j++) {
                    var cell = root.grid[i][j];
                    
                    if (cell.progress > 0) {
                        var cellX = i * root.cellSize;
                        var cellY = j * root.cellSize;

                        if (cell.target === 1) {
                            var currentSize = root.cellSize * cell.progress;
                            var offset = (root.cellSize - currentSize) / 2;
                            ctx.fillRect(cellX + offset, cellY + offset, currentSize, currentSize);
                        } else {
                            var strokeWidth = (root.cellSize / 2) * cell.progress;
                            
                            if (strokeWidth > 0.5) {
                                ctx.lineWidth = strokeWidth;
                                var strokeOffset = strokeWidth / 2;
                                ctx.strokeRect(
                                    cellX + strokeOffset, 
                                    cellY + strokeOffset, 
                                    root.cellSize - strokeWidth, 
                                    root.cellSize - strokeWidth
                                );
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        function handleMouseAction(mouse) {
            if (root.cols <= 0 || root.rows <= 0) return;
            var cellX = Math.floor(mouse.x / root.cellSize);
            var cellY = Math.floor(mouse.y / root.cellSize);

            if (cellX >= 0 && cellX < root.cols && cellY >= 0 && cellY < root.rows) {
                if (mouse.buttons & Qt.LeftButton) {
                    if (!running) {
                        root.grid[cellX][cellY].target = 1;
                    }
                } else if (mouse.buttons & Qt.RightButton) {
                    if (!running) {
                        root.grid[cellX][cellY].target = 0;
                    }
                }
                canvas.requestPaint();
            }
        }

        onPressed: (mouse) => handleMouseAction(mouse)
        onPositionChanged: (mouse) => handleMouseAction(mouse)
    }
}
