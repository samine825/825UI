import QtQuick

/*
 * 2D-зона захвата, которая следует
 * за визуальным центром куба.
 */
Item {
    id: grabArea

    /*
     * Ссылка на PhysicsCube.
     */
    property var cube: null

    /*
     * Ссылка на View3D сцены.
     */
    property Item view3d: null

    z: 1000

    width:
        cube
            ? cube.cubeSize * 2.0
            : 0

    height: width

    x:
        (view3d && cube)
            ? view3d.width / 2
              + cube.position.x
              - width / 2
            : 0

    y:
        (view3d && cube)
            ? view3d.height / 2
              - cube.position.y
              - height / 2
            : 0


    MouseArea {
        id: cubeMouse

        anchors.fill: parent

        hoverEnabled: true

        cursorShape: Qt.OpenHandCursor


        onPressed: function(mouse) {

            if (!grabArea.cube || !grabArea.view3d)
                return

            var p =
                grabArea.mapToItem(
                    grabArea.view3d,
                    mouse.x,
                    mouse.y
                )

            var world =
                grabArea.cube.mouseToWorld(p.x, p.y)

            grabArea.cube.startDrag(world.x, world.y)

            cursorShape = Qt.ClosedHandCursor
        }


        onPositionChanged: function(mouse) {

            if (!cubeMouse.pressed)
                return

            if (!grabArea.cube || !grabArea.view3d)
                return

            var p =
                grabArea.mapToItem(
                    grabArea.view3d,
                    mouse.x,
                    mouse.y
                )

            var world =
                grabArea.cube.mouseToWorld(p.x, p.y)

            grabArea.cube.moveDrag(world.x, world.y)
        }


        onReleased: {

            if (grabArea.cube)
                grabArea.cube.endDrag()

            cursorShape = Qt.OpenHandCursor
        }


        onCanceled: {

            if (grabArea.cube)
                grabArea.cube.endDrag()

            cursorShape = Qt.OpenHandCursor
        }
    }
}