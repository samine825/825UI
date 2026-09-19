import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick3D
import QtQuick3D.Physics

/*
 * Отдельное overlay-окно с 3D физической сценой.
 *
 * Кубы добавляются через addCube():
 *
 *     physicsScene.addCube({
 *         x: 0,
 *         y: 160,
 *         size: 84,
 *         texture: "applecat.jpg"
 *     })
 */
PanelWindow {
    id: physicsScene

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


    property real wallThickness: 42
    property real worldDepth: 99999


    /* ============================================
     * ПУБЛИЧНЫЙ API
     * ============================================ */

    function addCube(options) {

        options = options || {}

        cubesModel.append({
            size:
                options.size !== undefined
                    ? options.size
                    : 84,

            texture:
                options.texture !== undefined
                    ? "" + options.texture
                    : "applecat.jpg",

            startX:
                options.x !== undefined
                    ? options.x
                    : 0,

            startY:
                options.y !== undefined
                    ? options.y
                    : 160
        })
    }


    function removeCube(index) {

        if (index < 0 || index >= cubesModel.count)
            return

        cubesModel.remove(index)
    }


    function clearCubes() {
        cubesModel.clear()
    }


    property int cubeCount: cubesModel.count


    /* ============================================
     * МОДЕЛЬ КУБОВ
     * ============================================ */

    ListModel {
        id: cubesModel
    }


    /* ============================================
     * МАСКА ВВОДА
     *
     * Кликабельны только зоны захвата кубов,
     * остальной экран прозрачен для мыши.
     * ============================================ */

    property var grabRegions: []

    mask: Region {
        regions: physicsScene.grabRegions
    }

    Component {
        id: regionComponent

        Region {}
    }

    function registerGrabArea(item) {

        var region =
            regionComponent.createObject(
                physicsScene,
                { item: item }
            )

        physicsScene.grabRegions =
            physicsScene.grabRegions.concat([region])

        return region
    }

    function unregisterGrabArea(region) {

        if (!region)
            return

        var list =
            physicsScene.grabRegions.slice()

        var idx =
            list.indexOf(region)

        if (idx !== -1) {
            list.splice(idx, 1)
            physicsScene.grabRegions = list
        }

        region.destroy()
    }


    /* ============================================
     * 3D СЦЕНА
     * ============================================ */

    View3D {
        id: view

        anchors.fill: parent

        camera: orthoCamera

        environment: SceneEnvironment {

            backgroundMode:
                SceneEnvironment.Transparent

            clearColor:
                "transparent"
        }


        OrthographicCamera {
            id: orthoCamera

            position:
                Qt.vector3d(0, 0, 99999)

            horizontalMagnification: 1.0
            verticalMagnification: 1.0

            clipNear: 1.0
            clipFar: 999999.0
        }


        DirectionalLight {
            eulerRotation:
                Qt.vector3d(-35, -25, 0)

            brightness: 1.4
        }


        DirectionalLight {
            eulerRotation:
                Qt.vector3d(45, 130, 0)

            brightness: 0.45
        }


        PhysicsWorld {
            id: physicsWorld

            scene: view.scene

            running: true

            gravity:
                Qt.vector3d(0, -980, 0)
        }


        PhysicsMaterial {
            id: cubeMaterial

            staticFriction: 0.70
            dynamicFriction: 0.52
            restitution: 0.32
        }


        PhysicsMaterial {
            id: wallMaterial

            staticFriction: 0.84
            dynamicFriction: 0.72
            restitution: 0.20
        }


        /*
         * КУБЫ
         */
        Repeater3D {
            id: cubeRepeater

            model: cubesModel

            delegate: CubeBody {

                cubeSize:
                    model.size

                textureSource:
                    model.texture

                position:
                    Qt.vector3d(
                        model.startX,
                        model.startY,
                        0
                    )

                view3d: view

                physicsMaterial: cubeMaterial
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
                    - physicsScene.wallThickness / 2,

                    0
                )

            physicsMaterial: wallMaterial

            collisionShapes: [
                BoxShape {
                    extents:
                        Qt.vector3d(

                            view.width
                            + physicsScene.wallThickness * 2,

                            physicsScene.wallThickness,

                            physicsScene.worldDepth
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
                    + physicsScene.wallThickness / 2,

                    0
                )

            physicsMaterial: wallMaterial

            collisionShapes: [
                BoxShape {
                    extents:
                        Qt.vector3d(

                            view.width
                            + physicsScene.wallThickness * 2,

                            physicsScene.wallThickness,

                            physicsScene.worldDepth
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
                    - physicsScene.wallThickness / 2,

                    0,
                    0
                )

            physicsMaterial: wallMaterial

            collisionShapes: [
                BoxShape {
                    extents:
                        Qt.vector3d(

                            physicsScene.wallThickness,

                            view.height
                            + physicsScene.wallThickness * 2,

                            physicsScene.worldDepth
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
                    + physicsScene.wallThickness / 2,

                    0,
                    0
                )

            physicsMaterial: wallMaterial

            collisionShapes: [
                BoxShape {
                    extents:
                        Qt.vector3d(

                            physicsScene.wallThickness,

                            view.height
                            + physicsScene.wallThickness * 2,

                            physicsScene.worldDepth
                        )
                }
            ]
        }
    }


    /* ============================================
     * ЗОНЫ ЗАХВАТА (по одной на каждый куб)
     * ============================================ */

    Repeater {
        model: cubesModel

        delegate: CubeGrabArea {

            property var region: null

            /*
             * Привязка через count заставляет binding
             * пересчитаться, когда Repeater3D
             * создаст соответствующий куб.
             */
            cube:
                cubeRepeater.count > index
                    ? cubeRepeater.objectAt(index)
                    : null

            view3d: view

            Component.onCompleted: {
                region =
                    physicsScene.registerGrabArea(this)
            }

            Component.onDestruction: {
                physicsScene.unregisterGrabArea(region)
            }
        }
    }
}