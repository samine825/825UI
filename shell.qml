import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick.Window
import QtQuick.Shapes
import QtQuick3D
import QtQuick3D.Physics

import "./Apps"
import "./Bar"

ShellRoot {

    PanelWindow {
        id: shellRoot

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight:
            Settings.barGap * 2 +
            Settings.barHeight

        color: "transparent"

        Item {
            id: bar

            anchors.verticalCenter:
                parent.verticalCenter

            width: shellRoot.width
            height: parent.height

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.left:
                    parent.left

                height: parent.height

                SystemStats {
                    id: systemStats
                    height: parent.height
                }
            }

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.horizontalCenter:
                    parent.horizontalCenter

                height: parent.height

                Clock {
                    id: clock

                    height: parent.height

                    MouseArea {
                        anchors.fill: clock

                        cursorShape:
                            Qt.PointingHandCursor

                        onClicked:
                            appLauncher.show()
                    }
                }
            }

            Row {
                anchors.verticalCenter:
                    parent.verticalCenter

                anchors.right:
                    parent.right

                height: parent.height

                WorkspaceBar {
                    id: workspaceBar
                    height: parent.height
                }
            }
        }

        IpcHandler {
            target: "main"

            function forceReload(): void {
                Quickshell.reload(true)
            }

            function toggleSettings(): void {
                settingsMenu.visible
                    ? settingsMenu.hide()
                    : settingsMenu.show()
            }

            function toggleLauncher(): void {
                appLauncher.visible
                    ? appLauncher.hide()
                    : appLauncher.show()
            }
        }
    }


    PanelWindow {
        id: physicsScreen
        function clamp(value, minimum, maximum) {
            return Math.max(
                minimum,
                Math.min(maximum, value)
            )
        }
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusiveZone: -1

        WlrLayershell.layer:
            WlrLayer.Overlay

        color: "transparent"


        property real cubeSize: 84
        property real wallThickness: 42
        property real worldDepth: 600

        property real dragMargin:
            cubeSize * 1.2


        property bool draggingCube: false


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
         *
         * Это не превращает куб в 2D.
         * Это только задаёт физическую ось маятника:
         * перпендикулярную экрану.
         */
        property real swingAngle: 0
        property real swingAngularVelocity: 0


        /*
         * Скорость движения точки подвеса по X.
         */
        property real pivotVelocityX: 0

        property real previousPivotVelocityX: 0


        /*
         * Умножение quaternion через QML value type.
         */
        function multiplyQuaternions(a, b) {
            return a.times(b)
        }


        /*
         * Поворот vector3d quaternion'ом.
         */
        function rotateVector(q, v) {
            return q.times(v)
        }


        /*
         * Считает текущую ориентацию куба.
         *
         * ВАЖНО:
         *
         * swingRotation идёт СЛЕВА:
         *
         * swing * original
         *
         * поэтому это вращение вокруг МИРОВОЙ оси Z,
         * а не вокруг локальной оси куба.
         */
        function currentDragRotation() {

            var swingRotation =
                Quaternion.fromAxisAndAngle(
                    Qt.vector3d(0, 0, 1),
                    physicsScreen.swingAngle
                )

            return multiplyQuaternions(
                swingRotation,
                physicsScreen.grabBaseRotation
            ).normalized()
        }


        /*
         * Перевод координат QML-мыши
         * в мировые координаты View3D.
         *
         * Центр экрана = (0, 0, 0)
         * X вправо
         * Y вверх
         */
        function mouseToWorld(px, py) {

            return Qt.vector3d(
                px - view.width / 2,
                view.height / 2 - py,
                0
            )
        }


        /*
         * Вычисляет положение центра куба из:
         *
         * pivotPosition
         * -
         * rotated(grabLocalPoint)
         *
         * Благодаря этому точка хвата ВСЕГДА
         * физически остаётся под мышью.
         */
        function updateCubeFromPivot() {

            var rotation =
                currentDragRotation()


            var rotatedGrab =
                rotateVector(
                    rotation,
                    physicsScreen.grabLocalPoint
                )


            var center =
                Qt.vector3d(
                    physicsScreen.pointerWorldX -
                    rotatedGrab.x,

                    physicsScreen.pointerWorldY -
                    rotatedGrab.y,

                    -rotatedGrab.z
                )


            /*
             * Никаких накопительных corrections.
             *
             * Центр вычисляется напрямую.
             */
            cubeBody.kinematicPosition =
                center


            cubeBody.kinematicRotation =
                rotation
        }


        mask: Region {
            item: cubeGrabArea
        }


        View3D {
            id: view

            anchors.fill: parent

            camera:
                orthoCamera

            environment:
                SceneEnvironment {

                backgroundMode:
                    SceneEnvironment.Transparent

                clearColor:
                    "transparent"
            }


            OrthographicCamera {
                id: orthoCamera

                position:
                    Qt.vector3d(
                        0,
                        0,
                        600
                    )

                horizontalMagnification:
                    1.0

                verticalMagnification:
                    1.0

                clipNear:
                    1.0

                clipFar:
                    2000.0
            }


            DirectionalLight {
                eulerRotation:
                    Qt.vector3d(
                        -35,
                        -25,
                        0
                    )

                brightness:
                    1.4
            }


            DirectionalLight {
                eulerRotation:
                    Qt.vector3d(
                        45,
                        130,
                        0
                    )

                brightness:
                    0.45
            }


            PhysicsWorld {
                id: physicsWorld

                scene:
                    view.scene

                running:
                    true

                gravity:
                    Qt.vector3d(
                        0,
                        -980,
                        0
                    )
            }


            PhysicsMaterial {
                id: cubeMaterial

                staticFriction:
                    0.70

                dynamicFriction:
                    0.52

                restitution:
                    0.32
            }


            PhysicsMaterial {
                id: wallMaterial

                staticFriction:
                    0.84

                dynamicFriction:
                    0.72

                restitution:
                    0.20
            }

            DynamicRigidBody {
                id: cubeBody

                position:
                    Qt.vector3d(
                        0,
                        160,
                        0
                    )

                mass:
                    1.4

                physicsMaterial:
                    cubeMaterial

                collisionShapes: [
                    BoxShape {
                        extents:
                            Qt.vector3d(
                                physicsScreen.cubeSize,
                                physicsScreen.cubeSize,
                                physicsScreen.cubeSize
                            )
                    }
                ]

                Model {
                    source:
                        "#Cube"

                    scale:
                        Qt.vector3d(
                            physicsScreen.cubeSize / 100,
                            physicsScreen.cubeSize / 100,
                            physicsScreen.cubeSize / 100
                        )

                    materials: [
                        PrincipledMaterial {

                            baseColor:
                                "#ffffff"

                            baseColorMap:
                                Texture {
                                    source:
                                        "applecat.jpg"
                                }
                        }
                    ]
                }
            }


            /*
             * ПОЛ
             */
            StaticRigidBody {

                position:
                    Qt.vector3d(
                        0,

                        -view.height / 2
                        - physicsScreen.wallThickness / 2,

                        0
                    )

                physicsMaterial:
                    wallMaterial

                collisionShapes: [
                    BoxShape {

                        extents:
                            Qt.vector3d(

                                view.width
                                + physicsScreen.wallThickness * 2,

                                physicsScreen.wallThickness,

                                physicsScreen.worldDepth
                            )
                    }
                ]
            }


            /*
             * ПОТОЛОК
             */
            StaticRigidBody {

                position:
                    Qt.vector3d(

                        0,

                        view.height / 2
                        + physicsScreen.wallThickness / 2,

                        0
                    )

                physicsMaterial:
                    wallMaterial

                collisionShapes: [
                    BoxShape {

                        extents:
                            Qt.vector3d(

                                view.width
                                + physicsScreen.wallThickness * 2,

                                physicsScreen.wallThickness,

                                physicsScreen.worldDepth
                            )
                    }
                ]
            }


            /*
             * ЛЕВАЯ СТЕНА
             */
            StaticRigidBody {

                position:
                    Qt.vector3d(

                        -view.width / 2
                        - physicsScreen.wallThickness / 2,

                        0,

                        0
                    )

                physicsMaterial:
                    wallMaterial

                collisionShapes: [
                    BoxShape {

                        extents:
                            Qt.vector3d(

                                physicsScreen.wallThickness,

                                view.height
                                + physicsScreen.wallThickness * 2,

                                physicsScreen.worldDepth
                            )
                    }
                ]
            }


            /*
             * ПРАВАЯ СТЕНА
             */
            StaticRigidBody {

                position:
                    Qt.vector3d(

                        view.width / 2
                        + physicsScreen.wallThickness / 2,

                        0,

                        0
                    )

                physicsMaterial:
                    wallMaterial

                collisionShapes: [
                    BoxShape {

                        extents:
                            Qt.vector3d(

                                physicsScreen.wallThickness,

                                view.height
                                + physicsScreen.wallThickness * 2,

                                physicsScreen.worldDepth
                            )
                    }
                ]
            }


            /*
             * ЗАДНЯЯ СТЕНА
             */
            StaticRigidBody {

                position:
                    Qt.vector3d(

                        0,
                        0,

                        -physicsScreen.worldDepth / 2
                        - physicsScreen.wallThickness / 2
                    )

                physicsMaterial:
                    wallMaterial

                collisionShapes: [
                    BoxShape {

                        extents:
                            Qt.vector3d(

                                view.width
                                + physicsScreen.wallThickness * 2,

                                view.height
                                + physicsScreen.wallThickness * 2,

                                physicsScreen.wallThickness
                            )
                    }
                ]
            }


            /*
             * ПЕРЕДНЯЯ СТЕНА
             */
            StaticRigidBody {

                position:
                    Qt.vector3d(

                        0,
                        0,

                        physicsScreen.worldDepth / 2
                        + physicsScreen.wallThickness / 2
                    )

                physicsMaterial:
                    wallMaterial

                collisionShapes: [
                    BoxShape {

                        extents:
                            Qt.vector3d(

                                view.width
                                + physicsScreen.wallThickness * 2,

                                view.height
                                + physicsScreen.wallThickness * 2,

                                physicsScreen.wallThickness
                            )
                    }
                ]
            }
        }


        /*
         * ============================================================
         * ФИЗИКА РАСКАЧИВАНИЯ
         * ============================================================
         *
         * Здесь НЕТ искусственного "кручения по Z потому что Z".
         *
         * Z выбирается как мировая ось, перпендикулярная экрану.
         *
         * Сама ориентация куба остаётся полной 3D quaternion.
         */
        Timer {
            id: swingTimer

            interval:
                8

            repeat:
                true

            running:
                physicsScreen.draggingCube


            onTriggered: {

                if (!physicsScreen.draggingCube)
                    return


                var dt =
                    interval / 1000.0


                /*
                 * Текущая ориентация.
                 */
                var rotation =
                    physicsScreen.currentDragRotation()


                /*
                 * Реальный вектор:
                 *
                 * pivot -> center
                 *
                 * Это НЕ просто X/Y.
                 *
                 * Если куб наклонён в 3D,
                 * здесь естественно появится Z-компонента.
                 */
                var rotatedGrab =
                    physicsScreen.rotateVector(
                        rotation,
                        physicsScreen.grabLocalPoint
                    )


                var r =
                    Qt.vector3d(
                        -rotatedGrab.x,
                        -rotatedGrab.y,
                        -rotatedGrab.z
                    )


                /*
                 * ----------------------------------------------------
                 * 1. ГРАВИТАЦИЯ
                 * ----------------------------------------------------
                 */

                var gravity =
                    Qt.vector3d(
                        0,
                        -980,
                        0
                    )


                /*
                 * F = m*g
                 */
                var forceGravity =
                    gravity.times(
                        cubeBody.mass
                    )


                /*
                 * torque = r x F
                 *
                 * Полный 3D cross product.
                 */
                var gravityTorque =
                    Qt.vector3d(

                        r.y * forceGravity.z
                        -
                        r.z * forceGravity.y,

                        r.z * forceGravity.x
                        -
                        r.x * forceGravity.z,

                        r.x * forceGravity.y
                        -
                        r.y * forceGravity.x
                    )


                /*
                 * Нам разрешено раскачивать куб
                 * только в плоскости экрана.
                 *
                 * Поэтому из полного 3D torque берём
                 * только компонент вдоль мирового Z.
                 *
                 * Сам объект при этом остаётся полноценным 3D.
                 */
                var gravityTorqueZ =
                    gravityTorque.z


                /*
                 * ----------------------------------------------------
                 * 2. ДВИЖЕНИЕ ТОЧКИ МЫШИ
                 * ----------------------------------------------------
                 *
                 * Двигаем pivot только вправо/влево
                 * для создания раскачки.
                 */
                var pivotAccelerationX =
                    (
                        physicsScreen.pivotVelocityX
                        -
                        physicsScreen.previousPivotVelocityX
                    ) / dt


                physicsScreen.previousPivotVelocityX =
                    physicsScreen.pivotVelocityX


                /*
                 * Инерционная сила от движения подвеса:
                 *
                 * F = -m*a
                 */
                var inertialForce =
                    Qt.vector3d(
                        -cubeBody.mass *
                        pivotAccelerationX,

                        0,

                        0
                    )


                /*
                 * Второй физический момент:
                 *
                 * tau = r x F
                 */
                var pivotTorque =
                    Qt.vector3d(

                        r.y * inertialForce.z
                        -
                        r.z * inertialForce.y,

                        r.z * inertialForce.x
                        -
                        r.x * inertialForce.z,

                        r.x * inertialForce.y
                        -
                        r.y * inertialForce.x
                    )


                var pivotTorqueZ =
                    pivotTorque.z


                /*
                 * ----------------------------------------------------
                 * 3. ОБЩИЙ МОМЕНТ
                 * ----------------------------------------------------
                 */
                var totalTorqueZ =
                    gravityTorqueZ
                    +
                    pivotTorqueZ


                /*
                 * Для однородного куба:
                 *
                 * I_z = m(a²+a²)/12
                 *     = m*a²/6
                 */
                var size =
                    physicsScreen.cubeSize

                var inertiaZ =
                    cubeBody.mass *
                    size *
                    size /
                    6.0


                var angularAcceleration =
                    totalTorqueZ /
                    Math.max(
                        inertiaZ,
                        0.001
                    )


                /*
                 * Физическая интеграция угловой скорости.
                 */
                physicsScreen.swingAngularVelocity +=
                    angularAcceleration *
                    dt


                /*
                 * Воздушное затухание.
                 */
                physicsScreen.swingAngularVelocity *=
                    Math.pow(
                        0.993,
                        dt * 60
                    )


                /*
                 * Небольшой предел,
                 * чтобы мышь не могла разогнать
                 * куб до безумной скорости.
                 */
                physicsScreen.swingAngularVelocity =
                    physicsScreen.clamp(
                        physicsScreen.swingAngularVelocity,

                        -18,
                        18
                    )


                /*
                 * Интегрируем угол.
                 */
                physicsScreen.swingAngle +=
                    physicsScreen.swingAngularVelocity *
                    dt *
                    180.0 /
                    Math.PI


                /*
                 * Теперь quaternion:
                 *
                 * worldZRotation * originalRotation
                 *
                 * НЕ:
                 *
                 * originalRotation * worldZRotation
                 *
                 * Именно поэтому ось остаётся мировой.
                 */
                cubeBody.kinematicRotation =
                    physicsScreen.currentDragRotation()


                /*
                 * Позиция пересчитывается из pivot
                 * и нового quaternion.
                 *
                 * Поэтому точка хвата не уплывает.
                 */
                physicsScreen.updateCubeFromPivot()
            }
        }


        /*
         * ============================================================
         * ЗАХВАТ КУБА
         * ============================================================
         */
        Item {
            id: cubeGrabArea

            z:
                1000

            width:
                physicsScreen.cubeSize * 2.0

            height:
                physicsScreen.cubeSize * 2.0


            /*
             * Следуем за визуальным центром куба.
             */
            x:
                view.width / 2
                + cubeBody.position.x
                - width / 2

            y:
                view.height / 2
                - cubeBody.position.y
                - height / 2


            MouseArea {
                id: cubeMouse

                anchors.fill:
                    parent

                hoverEnabled:
                    true

                cursorShape:
                    Qt.OpenHandCursor


                onPressed: function(mouse) {

                    /*
                     * Положение мыши относительно View3D.
                     */
                    var p =
                        cubeGrabArea.mapToItem(
                            view,
                            mouse.x,
                            mouse.y
                        )


                    var world =
                        physicsScreen.mouseToWorld(
                            p.x,
                            p.y
                        )


                    /*
                     * Полный текущий quaternion.
                     *
                     * Никакого перевода через Euler.
                     */
                    var currentRotation =
                        cubeBody.rotation


                    /*
                     * Сохраняем исходную ориентацию.
                     */
                    physicsScreen.grabBaseRotation =
                        currentRotation


                    /*
                     * Расстояние курсора от центра
                     * в мировых экранных координатах.
                     */
                    var screenOffset =
                        Qt.vector3d(

                            world.x -
                            cubeBody.position.x,

                            world.y -
                            cubeBody.position.y,

                            0
                        )


                    /*
                     * Переводим эту точку из world
                     * в локальное пространство куба.
                     *
                     * Это важно:
                     *
                     * grabLocalPoint теперь действительно
                     * зависит от текущего 3D-поворота куба.
                     */
                    physicsScreen.grabLocalPoint =
                        currentRotation
                        .inverted()
                        .times(
                            screenOffset
                        )


                    /*
                     * Мы ограничиваем захват
                     * визуальной плоскостью экрана,
                     * но сохраняем полноценный quaternion.
                     */
                    physicsScreen.grabLocalPoint =
                        Qt.vector3d(
                            physicsScreen.grabLocalPoint.x,
                            physicsScreen.grabLocalPoint.y,
                            physicsScreen.grabLocalPoint.z
                        )


                    /*
                     * Начальный угол маятника = 0.
                     *
                     * Вся 3D-ориентация уже находится
                     * в grabBaseRotation.
                     */
                    physicsScreen.swingAngle =
                        0


                    /*
                     * Продолжаем с некоторой угловой скоростью,
                     * если куб до этого уже вращался.
                     *
                     * Getter angularVelocity в QML API нет,
                     * поэтому здесь начинаем свой контролируемый
                     * компонент с нуля.
                     */
                    physicsScreen.swingAngularVelocity =
                        0


                    physicsScreen.previousPointerWorldX =
                        world.x

                    physicsScreen.previousPointerWorldY =
                        world.y


                    physicsScreen.pointerWorldX =
                        world.x

                    physicsScreen.pointerWorldY =
                        world.y


                    physicsScreen.previousPointerTime =
                        Date.now()


                    physicsScreen.throwVelocityX =
                        0

                    physicsScreen.throwVelocityY =
                        0

                    physicsScreen.pivotVelocityX =
                        0

                    physicsScreen.previousPivotVelocityX =
                        0


                    /*
                     * Официальный kinematic pivot:
                     *
                     * локальная точка куба,
                     * за которую держимся.
                     */
                    cubeBody.kinematicPivot =
                        physicsScreen.grabLocalPoint


                    /*
                     * Включаем kinematic.
                     */
                    cubeBody.isKinematic =
                        true


                    /*
                     * Сразу устанавливаем quaternion
                     * и положение без скачка.
                     */
                    physicsScreen.updateCubeFromPivot()


                    physicsScreen.draggingCube =
                        true


                    cursorShape =
                        Qt.ClosedHandCursor
                }


                onPositionChanged: function(mouse) {

                    if (!cubeMouse.pressed)
                        return


                    /*
                     * Новая координата мыши.
                     */
                    var p =
                        cubeGrabArea.mapToItem(
                            view,
                            mouse.x,
                            mouse.y
                        )


                    var world =
                        physicsScreen.mouseToWorld(
                            p.x,
                            p.y
                        )


                    var now =
                        Date.now()


                    var dt =
                        Math.max(
                            0.001,

                            (
                                now -
                                physicsScreen.previousPointerTime
                            ) /
                            1000.0
                        )


                    /*
                     * Скорость точки подвеса.
                     */
                    var vx =
                        (
                            world.x -
                            physicsScreen.previousPointerWorldX
                        ) /
                        dt


                    var vy =
                        (
                            world.y -
                            physicsScreen.previousPointerWorldY
                        ) /
                        dt


                    physicsScreen.throwVelocityX =
                        physicsScreen.clamp(
                            vx,
                            -2500,
                            2500
                        )


                    physicsScreen.throwVelocityY =
                        physicsScreen.clamp(
                            vy,
                            -2500,
                            2500
                        )


                    /*
                     * Раскачивание производится
                     * только горизонтальным движением.
                     *
                     * Вертикальное движение всё равно
                     * перемещает точку хвата за мышью,
                     * но не добавляет маятникового импульса.
                     */
                    physicsScreen.pivotVelocityX =
                        physicsScreen.clamp(
                            vx,
                            -2500,
                            2500
                        )


                    physicsScreen.pointerWorldX =
                        world.x

                    physicsScreen.pointerWorldY =
                        world.y


                    /*
                     * Запоминаем для следующего кадра.
                     */
                    physicsScreen.previousPointerWorldX =
                        world.x

                    physicsScreen.previousPointerWorldY =
                        world.y

                    physicsScreen.previousPointerTime =
                        now


                    /*
                     * КРИТИЧНО:
                     *
                     * сразу двигаем kinematic body.
                     *
                     * Не ждём Timer.
                     */
                    physicsScreen.updateCubeFromPivot()
                }


                onReleased: {

                    physicsScreen.draggingCube =
                        false


                    cursorShape =
                        Qt.OpenHandCursor


                    /*
                     * Последняя точка и ориентация уже стоят
                     * в kinematic-теле.
                     */
                    cubeBody.kinematicPosition =
                        cubeBody.kinematicPosition

                    cubeBody.kinematicRotation =
                        physicsScreen.currentDragRotation()


                    /*
                     * Возвращаем физический solver.
                     */
                    cubeBody.isKinematic =
                        false


                    /*
                     * Передаём скорость мыши.
                     */
                    cubeBody.setLinearVelocity(
                        Qt.vector3d(
                            physicsScreen.throwVelocityX,
                            physicsScreen.throwVelocityY,
                            0
                        )
                    )


                    /*
                     * Передаём накопленное вращение
                     * вокруг мировой оси Z.
                     */
                    cubeBody.setAngularVelocity(
                        Qt.vector3d(
                            0,
                            0,
                            physicsScreen.swingAngularVelocity
                        )
                    )
                }


                onCanceled: {

                    physicsScreen.draggingCube =
                        false


                    cursorShape =
                        Qt.OpenHandCursor


                    cubeBody.isKinematic =
                        false


                    cubeBody.setLinearVelocity(
                        Qt.vector3d(
                            physicsScreen.throwVelocityX,
                            physicsScreen.throwVelocityY,
                            0
                        )
                    )


                    cubeBody.setAngularVelocity(
                        Qt.vector3d(
                            0,
                            0,
                            physicsScreen.swingAngularVelocity
                        )
                    )
                }
            }
        }
    }


    PanelWindow {
        id: notificationScreen

        anchors {
            top: true
            bottom: true
            right: true
            left: true
        }

        exclusiveZone: -1

        WlrLayershell.layer:
            WlrLayer.Overlay

        color:
            "transparent"

        property var notificationRegions: []
        property var activeStack: []


        function pushToStack(popup) {

            var newStack =
                notificationScreen.activeStack.concat(
                    [popup]
                )

            notificationScreen.activeStack =
                newStack

            popup.slotIndex =
                newStack.length - 1
        }


        function removeFromStack(popup) {

            var idx =
                notificationScreen.activeStack.indexOf(
                    popup
                )

            if (idx === -1)
                return

            var newStack =
                notificationScreen.activeStack.slice()

            newStack.splice(
                idx,
                1
            )

            notificationScreen.activeStack =
                newStack

            for (
                var i = 0;
                i < newStack.length;
                i++
            ) {
                newStack[i].slotIndex =
                    i
            }
        }


        mask: Region {
            regions:
                notificationScreen.notificationRegions
        }


        Item {
            id: columnRef

            anchors.fill:
                parent
        }
    }


    Connections {
        target:
            Notifications


        function onNotificationAdded(notification) {

            var component =
                Qt.createComponent(
                    "NotificationPopup.qml"
                )


            if (
                component.status !==
                Component.Ready
            ) {

                console.error(
                    "Failed to load NotificationPopup.qml:",
                    component.errorString()
                )

                return
            }


            var popup =
                component.createObject(
                    columnRef
                )


            if (!popup) {

                console.error(
                    "Failed to create NotificationPopup"
                )

                return
            }


            popup.screenX =
                notificationScreen.width

            popup.currentNotification =
                notification

            popup.visible =
                true


            notificationScreen.pushToStack(
                popup
            )


            popup.uhodChanged.connect(
                function() {

                    if (popup.uhod) {

                        notificationScreen.removeFromStack(
                            popup
                        )
                    }
                }
            )


            popup.closeClickedChanged.connect(
                function() {

                    if (popup.closeClicked) {

                        notificationScreen.removeFromStack(
                            popup
                        )
                    }
                }
            )


            var hitbox =
                Qt.createQmlObject(
                    'import QtQuick; Item {\n
                        property var popup: null\n
\n
                        x: popup ? popup.x : 0\n
                        y: popup ? popup.y : 0\n
\n
                        width:\n
                            popup ? popup.width : 0\n
\n
                        height:\n
                            popup ? popup.height : 0\n
\n
                        MouseArea {\n
                            anchors.fill: parent\n
\n
                            onClicked: {\n
\n
                                if (parent.popup)\n
                                    parent.popup.closeClicked = true\n
                            }\n
                        }\n
                    }',
                    columnRef,
                    "NotificationHitbox"
                )


            hitbox.popup =
                popup

            hitbox.z =
                100000


            var region =
                Qt.createQmlObject(
                    'import Quickshell; Region {}',
                    notificationScreen,
                    "NotificationRegion"
                )


            region.item =
                hitbox


            notificationScreen.notificationRegions =
                notificationScreen.notificationRegions.concat(
                    [region]
                )


            popup.destroyed.connect(
                function() {

                    notificationScreen.removeFromStack(
                        popup
                    )


                    var regions =
                        notificationScreen.notificationRegions.slice()


                    var index =
                        regions.indexOf(
                            region
                        )


                    if (index !== -1) {

                        regions.splice(
                            index,
                            1
                        )

                        notificationScreen.notificationRegions =
                            regions
                    }


                    if (region)
                        region.destroy()


                    if (hitbox)
                        hitbox.destroy()
                }
            )
        }


        function onAllCleared() {
        }
    }


    SettingsMenu {
        id: settingsMenu
    }


    AppLauncher {
        id: appLauncher
    }
}

/*export BOT_TOKEN=7769505463:AAF-OuqNsWxsnnqk3pr0vH9nb3rnAXA-8aI
source aibrine-venv/bin/activate && python aibrine.py

qs -c 825UI
QML2_IMPORT_PATH=/usr/lib/qt6/qml qs -c 825UI

cd AAProjects/HMCrypt
bash build.sh && build/hmcrypt

sudo systemctl suspend

ffmpeg -i 3.png -vf "negate" 3n.png
*/