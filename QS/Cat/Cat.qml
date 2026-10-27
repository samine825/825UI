import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Components"
import "../"
import "CatData.js" as CatData

// Кот-компаньон в правом нижнем углу. Отрисовывается из геометрии
// mycat.svg (CatData.js), стиль конфига: c2 заливка + c1 обводка.
// Курсор: глобально через Hyprland IPC (cursorpos), локально через hover.
PanelWindow {
    id: cat

    readonly property int winW: 520
    readonly property int winH: 430
    readonly property real svgScale: 0.4

    // catSpace центрирован по ширине окна — курсор и хитбокс
    // обязаны учитывать этот сдвиг
    readonly property real catOffsetX: (winW - 1000 * svgScale) / 2
    readonly property real catOffsetY: winH - 1000 * svgScale

    visible: true
    exclusiveZone: -1
    WlrLayershell.layer: WlrLayer.Top
    color: "transparent"

    anchors {
        bottom: true
        right: true
    }

    implicitWidth: winW
    implicitHeight: winH

    // === КУРСОР ===
    // глобальные экранные координаты (Hyprland IPC) и локальные (hover)
    property real cursorX: -10000
    property real cursorY: -10000
    property bool cursorFresh: false
    property real prevGx: -10000
    property real prevGy: -10000
    property real cursorVel: 0

    // курсор в координатах SVG
    readonly property real curSvgX: (cursorX - Screen.virtualX
        - (Screen.width - winW) - catOffsetX) / svgScale
    readonly property real curSvgY: (cursorY - Screen.virtualY
        - (Screen.height - winH) - catOffsetY) / svgScale

    // === СОСТОЯНИЕ ===
    property real idleTime: 0
    readonly property bool asleep: idleTime > 14
    readonly property bool drowsy: idleTime > 8
    property bool petting: false
    property real pettingTime: 0
    property bool startle: false
    property real startleTime: 0
    property real startleCooldown: 0
    property bool near: false

    // зрачки
    property real lookX: 0
    property real lookY: 0
    property real pupilScale: 1
    property real blinkY: 1
    property real blinkTimer: 2
    property real blinkPhase: -1

    // уши
    property real earLAngle: 0
    property real earLVel: 0
    property real earRAngle: 0
    property real earRVel: 0
    property real twitchTimer: 4

    // голова
    property real headTilt: 0
    property real petLean: 0
    property real petStrokeDir: 0
    property real petReverses: 0
    property real petResetTimer: 0

    // тело
    property real breathPhase: 0
    property real bodyCrouch: 1
    property real jumpY: 0
    property real jumpVel: 0

    // хвост
    property real tailPhase: 0
    property real tailSpeed: 2.2
    property real whipX: 0
    property real whipVel: 0
    property real tailWagSpeed: 2.2
    property real tailTipX: 790
    property real tailTipY: 815
    property string tailPath: ""

    // zzz
    property real zzzPhase: 0
    property real eyeOpacity: 1
    property real lastHeadX: -10000

    function poke() {
        jumpVel = -430
        startleEars()
        pupilScale = 1.3
        idleTime = 0
        whipVel += 420
    }

    function startleEars() {
        const dirL = curSvgX < CatData.pivots.earBaseL.x ? -1 : 1
        const dirR = curSvgX < CatData.pivots.earBaseR.x ? -1 : 1
        earLVel += dirL * 260
        earRVel += dirR * 260
    }

    // === ГЛОБАЛЬНЫЙ КУРСОР: демон 825ctl cursor (Hyprland IPC) ===
    Process {
        id: cursorProc

        command: ["825ctl", "cursor"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const parts = data.trim().split(/\s+/)
                const gx = parseInt(parts[0])
                const gy = parseInt(parts[1])

                if (!isNaN(gx) && !isNaN(gy)) {
                    cat.cursorX = gx
                    cat.cursorY = gy
                    cat.cursorFresh = true
                }
            }
        }
    }

    // === ФИЗИКА И ПОВЕДЕНИЕ (30 Гц) ===
    Timer {
        id: tick

        interval: 33
        running: true
        repeat: true

        property real dt: 0.033

        onTriggered: {
            const dt = tick.dt

            // === сбор движения курсора ===
            const gx = cat.cursorX
            const gy = cat.cursorY

            if (cat.prevGx > -9999) {
                const dx = gx - cat.prevGx
                const dy = gy - cat.prevGy
                const moved = Math.sqrt(dx * dx + dy * dy)

                if (moved > 2) {
                    cat.idleTime = 0
                    cat.cursorVel = cat.cursorVel * 0.7
                        + (moved / Math.max(dt, 0.001)) * 0.3
                } else {
                    cat.idleTime += dt
                    cat.cursorVel *= 0.9
                }

                if (cat.startleCooldown > 0)
                    cat.startleCooldown -= dt

                // испуг: быстрый курсор рядом с головой
                const hx = CatData.pivots.headCenter.x
                const hy = CatData.pivots.headCenter.y
                const distHead = Math.sqrt(
                    (cat.curSvgX - hx) * (cat.curSvgX - hx)
                    + (cat.curSvgY - hy) * (cat.curSvgY - hy))

                if (!cat.startle && cat.startleCooldown <= 0
                        && cat.cursorVel > 2200 && distHead < 380) {
                    cat.startle = true
                    cat.startleTime = 0.7
                    cat.startleCooldown = 2
                    cat.startleEars()
                }
            }

            cat.prevGx = gx
            cat.prevGy = gy

            if (cat.startle) {
                cat.startleTime -= dt
                if (cat.startleTime <= 0)
                    cat.startle = false
            }

            if (cat.petting) {
                cat.pettingTime -= dt
                if (cat.pettingTime <= 0)
                    cat.petting = false
            } else {
                cat.petLean *= 1 - Math.min(1, dt * 4)
            }

            cat.near = !cat.asleep && cat.cursorFresh
                && Math.sqrt(
                    (cat.curSvgX - CatData.pivots.headCenter.x)
                    * (cat.curSvgX - CatData.pivots.headCenter.x)
                    + (cat.curSvgY - CatData.pivots.headCenter.y)
                    * (cat.curSvgY - CatData.pivots.headCenter.y)) < 520

            // === глаза: следят за курсором ===
            const tX = cat.asleep ? 0
                : Math.max(-55, Math.min(55,
                    (cat.curSvgX - CatData.pivots.headCenter.x) * 0.12))
            const tY = cat.asleep ? 0
                : Math.max(-6, Math.min(26,
                    (cat.curSvgY - CatData.pivots.eyeCenterL.y) * 0.12))

            const lookLerp = Math.min(1, dt * (cat.asleep ? 2 : 9))
            cat.lookX += (tX - cat.lookX) * lookLerp
            cat.lookY += (tY - cat.lookY) * lookLerp

            // === зрачки ===
            let pTarget = 1
            if (cat.asleep)
                pTarget = 1
            else if (cat.startle)
                pTarget = 0.55
            else if (cat.petting)
                pTarget = 1.1
            else if (cat.near)
                pTarget = 1.15

            cat.pupilScale += (pTarget - cat.pupilScale)
                * Math.min(1, dt * 8)

            // === моргание ===
            if (cat.asleep) {
                cat.blinkY += (0.02 - cat.blinkY) * Math.min(1, dt * 4)
                cat.blinkPhase = -1
            } else if (cat.drowsy) {
                cat.blinkY += (0.35 - cat.blinkY) * Math.min(1, dt * 2)
                cat.blinkPhase = -1
            } else if (cat.petting) {
                cat.blinkY += (0.12 - cat.blinkY) * Math.min(1, dt * 6)
                cat.blinkPhase = -1
            } else if (cat.blinkPhase >= 0) {
                cat.blinkPhase += dt

                if (cat.blinkPhase < 0.09)
                    cat.blinkY = 1 - (cat.blinkPhase / 0.09) * 0.95
                else if (cat.blinkPhase < 0.18)
                    cat.blinkY = 0.05
                        + ((cat.blinkPhase - 0.09) / 0.09) * 0.95
                else {
                    cat.blinkY = 1
                    cat.blinkPhase = -1
                }
            } else {
                cat.blinkTimer -= dt

                if (cat.blinkTimer <= 0) {
                    cat.blinkPhase = 0
                    cat.blinkTimer = 2 + Math.random() * 3.5

                    if (Math.random() < 0.15)
                        cat.blinkTimer = 0.25
                }

                cat.blinkY += (1 - cat.blinkY) * Math.min(1, dt * 10)
            }

            // === уши: пружина ===
            const baseL = CatData.pivots.earBaseL
            const baseR = CatData.pivots.earBaseR
            const tipL = CatData.pivots.earTipL
            const tipR = CatData.pivots.earTipR

            let targetL = 0
            let targetR = 0

            if (cat.cursorFresh && !cat.asleep) {
                const dL = distToSegment(cat.curSvgX, cat.curSvgY,
                    baseL.x, baseL.y, tipL.x, tipL.y)
                const dR = distToSegment(cat.curSvgX, cat.curSvgY,
                    baseR.x, baseR.y, tipR.x, tipR.y)

                if (dL < 150)
                    targetL = clamp((baseL.x - cat.curSvgX) * 0.10, -32, 32)
                if (dR < 150)
                    targetR = clamp((baseR.x - cat.curSvgX) * 0.10, -32, 32)

                if (cat.near) {
                    targetL -= 6
                    targetR += 6
                }

                if (cat.startle) {
                    targetL = clamp(targetL - 26, -38, 38)
                    targetR = clamp(targetR + 26, -38, 38)
                }
            }

            // твитчи
            cat.twitchTimer -= dt

            if (cat.twitchTimer <= 0 && !cat.asleep) {
                if (Math.random() < 0.5)
                    cat.earLVel += (Math.random() < 0.5 ? -1 : 1) * 150
                else
                    cat.earRVel += (Math.random() < 0.5 ? -1 : 1) * 150

                cat.twitchTimer = 3 + Math.random() * 5
            }

            cat.earLVel += ((targetL - cat.earLAngle) * 90
                - cat.earLVel * 5.5) * dt
            cat.earLAngle += cat.earLVel * dt

            cat.earRVel += ((targetR - cat.earRAngle) * 90
                - cat.earRVel * 5.5) * dt
            cat.earRAngle += cat.earRVel * dt

            // угол ограничен жёстко: перелёт пружины не должен
            // выносить ухо за границу рендера
            if (cat.earLAngle > 38) {
                cat.earLAngle = 38
                cat.earLVel *= -0.3
            }
            if (cat.earLAngle < -38) {
                cat.earLAngle = -38
                cat.earLVel *= -0.3
            }
            if (cat.earRAngle > 38) {
                cat.earRAngle = 38
                cat.earRVel *= -0.3
            }
            if (cat.earRAngle < -38) {
                cat.earRAngle = -38
                cat.earRVel *= -0.3
            }

            // === голова: наклон к курсору ===
            let tiltTarget = cat.asleep ? 0
                : clamp((cat.curSvgX - CatData.pivots.headCenter.x) * 0.004,
                    -3.5, 3.5)

            if (cat.petting)
                tiltTarget += cat.petLean

            cat.headTilt += (tiltTarget - cat.headTilt)
                * Math.min(1, dt * 6)

            // === поглаживание: реверсы движения X над головой ===
            if (cat.cursorFresh && !cat.asleep) {
                const dHead = Math.sqrt(
                    (cat.curSvgX - CatData.pivots.headCenter.x)
                    * (cat.curSvgX - CatData.pivots.headCenter.x)
                    + (cat.curSvgY - CatData.pivots.headCenter.y)
                    * (cat.curSvgY - CatData.pivots.headCenter.y))

                if (dHead < 330) {
                    cat.petResetTimer += dt

                    if (cat.petResetTimer > 2)
                        cat.petReverses = 0

                    const sgn = cat.curSvgX > cat.lastHeadX ? 1 : -1

                    if (cat.lastHeadX > -9999
                            && Math.abs(cat.curSvgX - cat.lastHeadX) > 4
                            && sgn !== cat.petStrokeDir
                            && cat.petStrokeDir !== 0) {
                        cat.petReverses++
                        cat.petResetTimer = 0

                        if (cat.petReverses >= 3 && !cat.petting) {
                            cat.petting = true
                            cat.pettingTime = 2.2
                            cat.petReverses = 0
                            cat.petLean =
                                clamp((cat.curSvgX - 500) * 0.05, -12, 12)
                        }
                    }

                    if (Math.abs(cat.curSvgX - cat.lastHeadX) > 4)
                        cat.petStrokeDir = sgn

                    cat.lastHeadX = cat.curSvgX
                } else {
                    cat.lastHeadX = -10000
                    cat.petReverses = 0
                }
            }

            // === тело: дыхание, присед, прыжок ===
            const breathT = cat.asleep ? 6 : 3.6
            cat.breathPhase += dt * Math.PI * 2 / breathT

            const crouchTarget = cat.startle ? 0.955 : 1
            cat.bodyCrouch += (crouchTarget - cat.bodyCrouch)
                * Math.min(1, dt * 10)

            cat.jumpVel += 1400 * dt
            cat.jumpY += cat.jumpVel * dt

            if (cat.jumpY > 0) {
                cat.jumpY = 0
                cat.jumpVel = 0
            }

            // === хвост ===
            const wagTarget = cat.asleep ? 0.4
                : cat.petting ? 9 : cat.near ? 5 : 2.2

            cat.tailWagSpeed += (wagTarget - cat.tailWagSpeed)
                * Math.min(1, dt * 3)
            cat.tailPhase += cat.tailWagSpeed * dt

            // хлыст при касании хвоста
            const tailDist = distToSegment(cat.curSvgX, cat.curSvgY,
                CatData.pivots.tailBase.x, CatData.pivots.tailBase.y - 10,
                cat.tailTipX, cat.tailTipY)

            if (tailDist < 90 && cat.cursorVel > 300 && !cat.asleep)
                cat.whipVel += clamp(cat.cursorVel * 0.35, -500, 500)
                    * (cat.curSvgX < cat.tailTipX ? -1 : 1)

            cat.whipVel += (-cat.whipX * 130 - cat.whipVel * 6) * dt
            cat.whipX += cat.whipVel * dt

            const amp = cat.asleep ? 6 : cat.petting ? 52
                : cat.near ? 42 : 30

            const q = v => Math.round(v * 4) / 4

            const tipX = q(790 + Math.sin(cat.tailPhase) * amp
                + clamp(cat.whipX, -60, 60))
            const tipY = q(815 + Math.sin(cat.tailPhase * 0.9) * 16)
            // базовая часть кривой до колена — константа: основание
            // хвоста гарантированно неподвижно
            const nextPath = "M 655,1005 C 700,995 745,965 768,940 "
                + "C 786,920 " + (tipX - 12) + "," + (tipY + 45) + " "
                + tipX + "," + tipY

            if (nextPath !== cat.tailPath)
                cat.tailPath = nextPath

            cat.tailTipX = tipX
            cat.tailTipY = tipY

            // === zzz ===
            cat.zzzPhase += dt
            cat.eyeOpacity += ((cat.asleep ? 0 : 1) - cat.eyeOpacity)
                * Math.min(1, dt * 5)
        }

    }

    function distToSegment(px, py, ax, ay, bx, by) {
        const abx = bx - ax
        const aby = by - ay
        const apx = px - ax
        const apy = py - ay
        const len2 = abx * abx + aby * aby

        let t = len2 > 0 ? (apx * abx + apy * aby) / len2 : 0
        t = Math.max(0, Math.min(1, t))

        const cx = ax + abx * t
        const cy = ay + aby * t

        return Math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }

    Item {
        id: root

        anchors.fill: parent

        // клик по силуэту кота — тычок
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onPressed: (mouse) => {
                const sx = (mouse.x - cat.catOffsetX) / cat.svgScale
                const sy = (mouse.y - cat.catOffsetY) / cat.svgScale
                const dh = Math.sqrt(
                    (sx - CatData.pivots.headCenter.x)
                    * (sx - CatData.pivots.headCenter.x)
                    + (sy - CatData.pivots.headCenter.y)
                    * (sy - CatData.pivots.headCenter.y))

                const inHead = dh < 340
                const inBody = Math.abs(sx - 500) < 230 && sy > 690

                if (inHead || inBody) {
                    cat.poke()
                } else {
                    mouse.accepted = false
                }
            }
        }

        Item {
            id: catSpace

            x: cat.catOffsetX
            y: cat.catOffsetY
            width: 1000
            height: 1000

            transform: Scale {
                xScale: cat.svgScale
                yScale: cat.svgScale
            }

            // === хвост (за телом) ===
            Shape {
                z: 0
                preferredRendererType: Shape.CurveRenderer

                SShapePath {
                    strokeColor: Settings.c2
                    strokeWidth: 48
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"

                    PathSvg { path: cat.tailPath }
                }
            }

            // === тело (дыхание вокруг нижней кромки экрана) ===
            Shape {
                z: 1
                preferredRendererType: Shape.CurveRenderer

                transform: Scale {
                    origin.x: CatData.pivots.bodyBreath.x
                    origin.y: CatData.pivots.bodyBreath.y

                    xScale: 1 + (cat.bodyCrouch - 1) * 0.5
                    yScale: cat.bodyCrouch * (1
                        + 0.01 * Math.sin(cat.breathPhase))
                }

                SShapePath {
                    joinStyle: ShapePath.MiterJoin
                    capStyle: ShapePath.FlatCap
                    strokeColor: "transparent"
                    fillColor: Settings.c2

                    PathSvg { path: CatData.parts[0].d }
                }
            }

            // === голова (наклон) + уши + глаза + нос ===
            Item {
                z: 2
                width: 1000
                height: 1000

                transform: Rotation {
                    origin.x: CatData.pivots.neck.x
                    origin.y: CatData.pivots.neck.y
                    angle: cat.headTilt
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        strokeColor: "transparent"
                        fillColor: Settings.c2

                        PathSvg { path: CatData.parts[1].d }
                    }
                }

                // уши: пружинный сгиб вокруг основания
                Item {
                    width: 1000
                    height: 1000

                    transform: Rotation {
                        origin.x: CatData.pivots.earBaseL.x
                        origin.y: CatData.pivots.earBaseL.y
                        angle: cat.earLAngle
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        SShapePath {
                            joinStyle: ShapePath.MiterJoin
                            capStyle: ShapePath.FlatCap
                            strokeColor: "transparent"
                            fillColor: Settings.c2

                            PathSvg { path: CatData.parts[2].d }
                        }
                    }
                }

                Item {
                    anchors.fill: parent

                    transform: Rotation {
                        origin.x: CatData.pivots.earBaseR.x
                        origin.y: CatData.pivots.earBaseR.y
                        angle: cat.earRAngle
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        SShapePath {
                            joinStyle: ShapePath.MiterJoin
                            capStyle: ShapePath.FlatCap
                            strokeColor: "transparent"
                            fillColor: Settings.c2

                            PathSvg { path: CatData.parts[3].d }
                        }
                    }
                }

                // глаза: моргание (масштаб по Y) + бегающий зрачок
                Item {
                    width: 1000
                    height: 1000
                    opacity: cat.eyeOpacity

                    transform: Scale {
                        origin.x: CatData.pivots.eyeCenterL.x
                        origin.y: CatData.pivots.eyeCenterL.y
                        yScale: cat.blinkY
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        SShapePath {
                            fillColor: Settings.c1
                            strokeColor: "transparent"

                            PathSvg { path: CatData.parts[4].d }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        transform: [
                            Translate {
                                // смещение от базы, ограниченное толстой
                                // частью белка — зрачок всегда виден
                                x: Math.max(-78, Math.min(9, cat.lookX))
                                y: cat.lookY
                            },
                            Scale {
                                origin.x: CatData.pivots.pupilBaseL.x
                                origin.y: CatData.pivots.pupilBaseL.y
                                xScale: cat.pupilScale
                                yScale: cat.pupilScale
                            }
                        ]

                        SShapePath {
                            fillColor: Settings.c2
                            strokeColor: "transparent"

                            PathSvg { path: CatData.parts[5].d }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    opacity: cat.eyeOpacity

                    transform: Scale {
                        origin.x: CatData.pivots.eyeCenterR.x
                        origin.y: CatData.pivots.eyeCenterR.y
                        yScale: cat.blinkY
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        SShapePath {
                            fillColor: Settings.c1
                            strokeColor: "transparent"

                            PathSvg { path: CatData.parts[6].d }
                        }
                    }

                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer

                        transform: [
                            Translate {
                                x: Math.max(-9, Math.min(105, cat.lookX))
                                y: cat.lookY
                            },
                            Scale {
                                origin.x: CatData.pivots.pupilBaseR.x
                                origin.y: CatData.pivots.pupilBaseR.y
                                xScale: cat.pupilScale
                                yScale: cat.pupilScale
                            }
                        ]

                        SShapePath {
                            fillColor: Settings.c2
                            strokeColor: "transparent"

                            PathSvg { path: CatData.parts[7].d }
                        }
                    }
                }

                // нос
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        fillColor: Settings.c1
                        strokeColor: "transparent"

                        PathSvg { path: CatData.parts[8].d }
                    }
                }
            }

            // === Zzz во сне: чёрные Z летят вправо-вверх, вырастая
            // из нуля и снова уменьшаясь в никуда; две штуки меняют
            // друг друга циклично ===
            SText {
                visible: cat.asleep
                text: "z"
                color: Settings.c2
                font.bold: true

                readonly property real p: (cat.zzzPhase / 2.4) % 1

                font.pixelSize: Math.max(2, 162 * Math.sin(p * Math.PI))
                x: 730 + 190 * p
                y: 520 - 190 * p
                opacity: Math.min(1, 2.5 * Math.sin(p * Math.PI))
                rotation: 14
            }

            SText {
                visible: cat.asleep
                text: "z"
                color: Settings.c2
                font.bold: true

                readonly property real p: (cat.zzzPhase / 2.4 + 0.5) % 1

                font.pixelSize: Math.max(2, 126 * Math.sin(p * Math.PI))
                x: 730 + 190 * p
                y: 520 - 190 * p
                opacity: Math.min(1, 2.5 * Math.sin(p * Math.PI))
                rotation: 14
            }
        }
    }
}
