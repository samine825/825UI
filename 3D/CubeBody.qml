import QtQuick
import QtQuick3D
import QtQuick3D.Physics

/*
 * Один физический куб.
 *
 * Вся логика перетаскивания и маятникового
 * раскачивания инкапсулирована здесь.
 */
DynamicRigidBody {
    id: cube

    /* ============================================
     * КОНФИГУРАЦИЯ
     * ============================================ */

    property real cubeSize: 84

    property url textureSource: "applecat.jpg"

    /*
     * Ссылка на View3D, в котором живёт куб.
     * Нужна для перевода координат мыши в мировые.
     */
    property Item view3d: null


    /* ============================================
     * СОСТОЯНИЕ ПЕРЕТАСКИВАНИЯ
     * ============================================ */

    property bool dragging: false

    property real pointerWorldX: 0
    property real pointerWorldY: 0

    property real previousPointerWorldX: 0
    property real previousPointerWorldY: 0

    property double previousPointerTime: 0

    property real throwVelocityX: 0
    property real throwVelocityY: 0

    /*
     * Реальная локальная 3D-точка внутри куба,
     * за которую пользователь схватил объект.
     */
    property vector3d grabLocalPoint:
        Qt.vector3d(0, 0, 0)

    /*
     * Полный исходный quaternion куба
     * в момент захвата.
     */
    property quaternion grabBaseRotation:
        Qt.quaternion(1, 0, 0, 0)

    /*
     * Дополнительный угол вокруг МИРОВОЙ оси Z.
     */
    property real swingAngle: 0
    property real swingAngularVelocity: 0

    /* Для стабильного расчёта ускорения маятника */
    property real timerLastWorldX: 0
    property real timerLastWorldY: 0
    property real timerLastVelX: 0
    property real timerLastVelY: 0
    property real smoothedPivotAccelX: 0
    property real smoothedPivotAccelY: 0


    /* ============================================
     * ФИЗИЧЕСКОЕ ТЕЛО
     * ============================================ */

    mass: 1.4

    collisionShapes: [
        BoxShape {
            extents:
                Qt.vector3d(
                    cube.cubeSize,
                    cube.cubeSize,
                    cube.cubeSize
                )
        }
    ]

    Model {
        source: "#Cube"

        scale:
            Qt.vector3d(
                cube.cubeSize / 100,
                cube.cubeSize / 100,
                cube.cubeSize / 100
            )

        materials: [
            PrincipledMaterial {
                baseColor: "#ffffff"

                baseColorMap:
                    Texture {
                        source: cube.textureSource
                    }
            }
        ]
    }


    /* ============================================
     * МАТЕМАТИКА
     * ============================================ */

    function clamp(value, minimum, maximum) {
        return Math.max(
            minimum,
            Math.min(maximum, value)
        )
    }

    function multiplyQuaternions(a, b) {
        return a.times(b)
    }

    function rotateVector(q, v) {
        return q.times(v)
    }

    /*
     * Перевод координат QML-мыши (относительно View3D)
     * в мировые координаты.
     *
     * Центр экрана = (0, 0, 0)
     * X вправо, Y вверх
     */
    function mouseToWorld(px, py) {
        return Qt.vector3d(
            px - cube.view3d.width / 2,
            cube.view3d.height / 2 - py,
            0
        )
    }

    /*
     * Текущая ориентация куба.
     *
     * swingRotation идёт СЛЕВА:
     * swing * original
     *
     * поэтому это вращение вокруг МИРОВОЙ оси Z.
     */
    function currentDragRotation() {

        var swingRotation =
            Quaternion.fromAxisAndAngle(
                Qt.vector3d(0, 0, 1),
                cube.swingAngle
            )

        return multiplyQuaternions(
            swingRotation,
            cube.grabBaseRotation
        ).normalized()
    }

    /*
     * Вычисляет положение центра куба так,
     * чтобы точка хвата всегда была под мышью.
     */
    function updateCubeFromPivot() {

        var rotation =
            currentDragRotation()

        var rotatedGrab =
            rotateVector(
                rotation,
                cube.grabLocalPoint
            )

        var center =
            Qt.vector3d(
                cube.pointerWorldX - rotatedGrab.x,
                cube.pointerWorldY - rotatedGrab.y,
                0
            )

        cube.kinematicPosition = center
        cube.kinematicRotation = rotation
    }


    /* ============================================
     * API ЗАХВАТА (вызывается из CubeGrabArea)
     * ============================================ */

    function startDrag(worldX, worldY) {

        /*
         * Полный текущий quaternion,
         * без перевода через Euler.
         */
        var currentRotation = cube.rotation

        cube.grabBaseRotation = currentRotation

        /*
         * Расстояние курсора от центра
         * в мировых экранных координатах.
         */
        var screenOffset =
            Qt.vector3d(
                worldX - cube.position.x,
                worldY - cube.position.y,
                0
            )

        /*
         * Переводим точку из world
         * в локальное пространство куба.
         */
        cube.grabLocalPoint =
            currentRotation
                .inverted()
                .times(screenOffset)

        cube.swingAngle = 0
        cube.swingAngularVelocity = 0

        cube.previousPointerWorldX = worldX
        cube.previousPointerWorldY = worldY

        cube.pointerWorldX = worldX
        cube.pointerWorldY = worldY

        cube.previousPointerTime = Date.now()

        cube.throwVelocityX = 0
        cube.throwVelocityY = 0

        cube.timerLastWorldX = worldX
        cube.timerLastWorldY = worldY
        cube.timerLastVelX = 0
        cube.timerLastVelY = 0
        cube.smoothedPivotAccelX = 0
        cube.smoothedPivotAccelY = 0

        cube.isKinematic = true

        updateCubeFromPivot()

        cube.dragging = true
    }


    function moveDrag(worldX, worldY) {

        if (!cube.dragging)
            return

        var now = Date.now()

        var dt =
            Math.max(
                0.001,
                (now - cube.previousPointerTime) / 1000.0
            )

        /*
         * Скорость точки подвеса.
         */
        var vx =
            (worldX - cube.previousPointerWorldX) / dt

        var vy =
            (worldY - cube.previousPointerWorldY) / dt

        cube.throwVelocityX =
            clamp(vx, -2500, 2500)

        cube.throwVelocityY =
            clamp(vy, -2500, 2500)

        cube.pointerWorldX = worldX
        cube.pointerWorldY = worldY

        cube.previousPointerWorldX = worldX
        cube.previousPointerWorldY = worldY

        cube.previousPointerTime = now

        /*
         * КРИТИЧНО: сразу двигаем kinematic body,
         * не ждём Timer.
         */
        updateCubeFromPivot()
    }


    function endDrag() {

        if (!cube.dragging && !cube.isKinematic)
            return

        cube.dragging = false

        cube.kinematicRotation =
            currentDragRotation()

        /*
         * Возвращаем физический solver.
         */
        cube.isKinematic = false

        /*
         * Передаём скорость мыши.
         */
        cube.setLinearVelocity(
            Qt.vector3d(
                cube.throwVelocityX,
                cube.throwVelocityY,
                0
            )
        )

        /*
         * Передаём накопленное вращение
         * вокруг мировой оси Z.
         */
        cube.setAngularVelocity(
            Qt.vector3d(
                0,
                0,
                cube.swingAngularVelocity
            )
        )
    }


    /* ============================================
     * ФИЗИКА РАСКАЧИВАНИЯ
     * ============================================ */
    Timer {
        id: swingTimer

        interval: 8
        repeat: true
        running: cube.dragging

        onTriggered: {
            if (!cube.dragging)
                return

            var dt = interval / 1000.0

            // Текущая ориентация и вектор подвеса
            var rotation = cube.currentDragRotation()
            var rotatedGrab = cube.rotateVector(rotation, cube.grabLocalPoint)
            var r = Qt.vector3d(-rotatedGrab.x, -rotatedGrab.y, -rotatedGrab.z)

            /*
             * 1. УСКОРЕНИЕ ТОЧКИ ПОДВЕСА (МЫШИ)
             */
            var currentX = cube.pointerWorldX
            var currentY = cube.pointerWorldY

            var velX = (currentX - cube.timerLastWorldX) / dt
            var velY = (currentY - cube.timerLastWorldY) / dt

            var rawAccelX = (velX - cube.timerLastVelX) / dt
            var rawAccelY = (velY - cube.timerLastVelY) / dt

            var maxAccel = 15000.0
            rawAccelX = cube.clamp(rawAccelX, -maxAccel, maxAccel)
            rawAccelY = cube.clamp(rawAccelY, -maxAccel, maxAccel)

            var smoothing = 0.12
            cube.smoothedPivotAccelX += (rawAccelX - cube.smoothedPivotAccelX) * smoothing
            cube.smoothedPivotAccelY += (rawAccelY - cube.smoothedPivotAccelY) * smoothing

            cube.timerLastWorldX = currentX
            cube.timerLastWorldY = currentY
            cube.timerLastVelX = velX
            cube.timerLastVelY = velY

            /*
             * 2. ГРАВИТАЦИЯ
             */
            var gravity = Qt.vector3d(0, -980, 0)
            var forceGravity = gravity.times(cube.mass)

            var gravityTorqueZ = (r.x * forceGravity.y) - (r.y * forceGravity.x)

            /*
             * 3. ИНЕРЦИЯ ОТ ДВИЖЕНИЯ РУКИ
             */
            var inertialForce = Qt.vector3d(
                -cube.mass * cube.smoothedPivotAccelX,
                -cube.mass * cube.smoothedPivotAccelY,
                0
            )

            var pivotTorqueZ = (r.x * inertialForce.y) - (r.y * inertialForce.x)

            /*
             * 4. ОБЩИЙ МОМЕНТ И ВРАЩЕНИЕ
             */
            var totalTorqueZ = gravityTorqueZ + pivotTorqueZ

            var size = cube.cubeSize
            var inertiaZ = cube.mass * size * size / 6.0

            var angularAcceleration = totalTorqueZ / Math.max(inertiaZ, 0.001)

            cube.swingAngularVelocity += angularAcceleration * dt

            // Воздушное затухание
            cube.swingAngularVelocity *= Math.pow(0.993, dt * 60)

            cube.swingAngularVelocity = cube.clamp(
                cube.swingAngularVelocity,
                -18,
                18
            )

            cube.swingAngle += cube.swingAngularVelocity * dt * 180.0 / Math.PI

            cube.updateCubeFromPivot()
        }
    }
}