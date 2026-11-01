import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Components"
import "../Fonts"
import ".."

// Экран блокировки. Окно живёт всегда (прозрачный оверлей, как у
// уведомлений) — геометрия известна с старта, анимациям не с чем
// гоняться. Пока не заблокировано: маска ввода пуста (клики проходят
// насквозь), клавиатура не наша, всё прозрачно. По блокировке форма
// пароля начинается как анимация уведомления: приезд OutCubic 600 +
// полуоборот OutSine, обводка видна сразу, тело проявляется 1500
// InCubic; когда форма дошла до нижней точки Y по середине X —
// начинается затемнение (чёрный фон и контент). Раскрытие — по
// фактической ширине текста (OutBack, animFast): точки всегда
// помещаются в талию. Закрытая форма = startSize уведомления с той
// же геометрией контура (кончики сходятся в центре), пароль по
// центру, курсор убит пустым delegate. Уход — реверс приезда: гаснет
// затемнение, затем форма улетает вверх с обратным вращением
// (InCubic 600 + OutSine 600). На время PAM-проверки ввод
// замораживается и стирается только по результату. Проверка пароля —
// PAM (дефолтный конфиг login), ошибка PAM отпирает, чтобы не
// запереть пользователя навсегда.
PanelWindow {
    id: lockScreen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusiveZone: -1
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    // клавиатура целиком у блокировки, пока она открыта
    WlrLayershell.keyboardFocus: locked
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // маска = область принятия ввода: пустая — весь ввод насквозь
    mask: Region {
        item: lockScreen.locked ? inputBlocker : null
    }

    // === состояние ===
    property bool locked: false
    property bool checking: false
    property bool responded: false

    // === раскладка центрального блока ===
    readonly property real line: Settings.line
    readonly property real bigSize: Math.round(height / 5)
    readonly property real avatarSize: Math.round(height / 5.4)
    readonly property real formH: Settings.barHeight * 2
    readonly property real nameH: Settings.textLg

    readonly property real gap1: line * 6              // время → аватар
    readonly property real gap2: line * 4              // аватар → имя
    readonly property real gap3: Settings.barGap * 2   // имя → форма

    readonly property real blockH: bigSize + gap1 + avatarSize
        + gap2 + nameH + gap3 + formH
    readonly property real blockTop: Math.round((height - blockH) / 2)

    // === форма пароля ===
    // закрытая форма = startSize уведомления; контур формы — контур
    // уведомления 1:1 (см. NotificationPopup): кончики выемок на
    // height/2, при ширине height они сходятся в центре
    readonly property real formClosedW: formH
    readonly property real formFinalY: blockTop + bigSize + gap1
        + avatarSize + gap2 + nameH + gap3

    // === аватар: ~/.face, если нет — дефолтное фото ===
    readonly property url faceUrl:
        "file://" + Quickshell.env("HOME") + "/.face"
    readonly property url defaultFace:
        Qt.resolvedUrl("../Textures/4.jpg")
    property bool faceOk: true
    readonly property url avatarSource: faceOk ? faceUrl : defaultFace

    // === время ===
    property date clockNow: new Date()
    readonly property string timeStr: Qt.formatTime(clockNow, "HH:mm")

    function lock() {
        if (locked)
            return

        exitDelay.stop()
        exitYAnim.stop()
        exitRotAnim.stop()

        locked = true
        checking = false
        responded = false
        clockNow = new Date()
        passInput.text = ""

        // экран прозрачен: затемнение начнётся, когда форма долетит
        blackBg.opacity = 0
        content.opacity = 0

        // форма прилетает как уведомление: обводка видна сразу,
        // тело проявляется, полёт из-за верхней кромки в центр экрана
        form.opacity = 1
        formBody.opacity = 1
        form.y = -formH
        form.rotation = 0
        arriveYAnim.restart()
        arriveRotAnim.restart()

        passInput.forceActiveFocus()
    }

    function unlock() {
        if (!locked)
            return

        arriveYAnim.stop()
        arriveRotAnim.stop()

        // ввод и клавиатура отпускаются сразу, картинка гаснет плавно
        locked = false
        checking = false
        responded = false
        passInput.text = ""
        passInput.focus = false

        blackBg.opacity = 0
        content.opacity = 0

        // реверс приезда: сначала гаснет затемнение, затем форма
        // улетает вверх с обратным вращением
        exitDelay.restart()
    }

    function submit() {
        if (!locked || checking)
            return

        if (passInput.text.length === 0)
            return

        if (!pam.active) {
            checking = true

            if (!pam.start()) {
                // PAM не поднялся: отпираем, не запираем навсегда
                checking = false
                console.error("825 lockscreen: не удалось запустить PAM")
                unlock()
            }
        } else if (pam.responseRequired && !responded) {
            responded = true
            pam.respond(passInput.text)
        }
        // PAM ещё не спрашивает — текст остаётся, ответит onPamMessage
    }

    function failShake() {
        passInput.text = ""
        shakeAnim.restart()
    }

    Item {
        id: inputBlocker
        anchors.fill: parent
    }

    Rectangle {
        id: blackBg

        anchors.fill: parent
        color: Settings.c2
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.animSlow
                easing.type: Easing.InOutQuad
            }
        }
    }

    // клик мимо контента возвращает фокус в поле пароля
    MouseArea {
        anchors.fill: parent
        onClicked: passInput.forceActiveFocus()
    }

    Item {
        id: content

        anchors.fill: parent
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: Settings.animSlow
                easing.type: Easing.InOutQuad
            }
        }

        // время большим инфексом
        Row {
            id: timeRow

            x: Math.round((lockScreen.width - width) / 2)
            y: lockScreen.blockTop

            Repeater {
                model: 5

                delegate: Infex {
                    ch: lockScreen.timeStr.length > index
                        ? lockScreen.timeStr[index] : "0"
                    pixelSize: lockScreen.bigSize
                    referencePixelSize: lockScreen.bigSize
                    line: Settings.line
                    color: Settings.c1
                    mirrorX: true
                }
            }
        }

        // аватар: квадратная панель со скосами, фото под обводкой
        SPanel {
            id: avatar

            x: Math.round((lockScreen.width - width) / 2)
            y: lockScreen.blockTop + lockScreen.bigSize
                + lockScreen.gap1
            width: lockScreen.avatarSize
            height: lockScreen.avatarSize
            cornerCut: lockScreen.line * 2
            innerStroke: true
            fillColor: Settings.c2
            shadow: "none"

            Image {
                anchors.fill: parent
                source: lockScreen.avatarSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                onStatusChanged: {
                    if (status === Image.Error)
                        lockScreen.faceOk = false
                }
            }
        }

        // имя пользователя
        SText {
            x: Math.round((lockScreen.width - width) / 2)
            y: avatar.y + avatar.height + lockScreen.gap2
            text: Quickshell.env("USER") || "user"
            color: Settings.c1
            font.pixelSize: Settings.textLg
        }
    }

    // форма ввода пароля: контур уведомления 1:1 — padX =
    // 0.5·tipMult·line, padY = line/2, кончики выемок на height/2
    // (при ширине height сходятся в центре, как у уведомления до
    // раскрытия). Обводки (тёмный нарост + c1) видны сразу, тело
    // с точками проявляется, как цвет уведомления
    Item {
        id: form

        x: Math.round((lockScreen.width - width) / 2)
        y: -(lockScreen.formH)
        // ширина по факту текста: точки всегда помещаются в талию
        // (запас line с каждой стороны), потолок — край экрана
        width: passInput.text.length === 0
            ? lockScreen.formClosedW
            : Math.max(
                lockScreen.formClosedW,
                Math.min(
                    passInput.contentWidth + lockScreen.formH
                        + lockScreen.line * 2,
                    lockScreen.width - lockScreen.line * 8))
        height: lockScreen.formH
        opacity: 0

        readonly property real padX:
            0.5 * InfexGeometry.tipMult * lockScreen.line
        readonly property real padY: lockScreen.line / 2

        // раскрытие — как расширение уведомления (OutBack), но быстро
        Behavior on width {
            NumberAnimation {
                duration: Settings.animFast
                easing.type: Easing.OutBack
            }
        }

        transform: Translate {
            id: formShake
        }

        component NotifContour: SShapePath {
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            startX: form.padX
            startY: form.padY

            PathLine { x: form.width - form.padX; y: form.padY }
            // правый кончик зажат к центру: OutBack при схлопывании
            // промахивается ниже закрытой ширины — без клампа контур
            // пересекается сам на себе
            PathLine {
                x: Math.max(form.height / 2,
                    form.width - form.height / 2)
                y: form.height / 2
            }
            PathLine { x: form.width - form.padX; y: form.height - form.padY }
            PathLine { x: form.padX; y: form.height - form.padY }
            PathLine { x: form.height / 2; y: form.height / 2 }
            PathLine { x: form.padX; y: form.padY }
        }

        // тело: заливка + точки, проявляется как цвет уведомления
        Item {
            id: formBody

            anchors.fill: parent
            opacity: 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 1500
                    easing.type: Easing.InCubic
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                NotifContour {
                    fillColor: Settings.c2
                    strokeColor: "transparent"
                    strokeWidth: 0
                }
            }

            // пароль по центру талии контура; курсор убит пустым
            // delegate — TextInput сам возвращает cursorVisible при
            // фокусе, поэтому одного флага мало
            TextInput {
                id: passInput

                anchors.fill: parent
                leftPadding: form.height / 2
                rightPadding: form.height / 2
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                readOnly: lockScreen.checking
                echoMode: TextInput.Password
                font.pixelSize: Settings.textLg
                color: Settings.c1
                selectionColor: Settings.c1
                selectedTextColor: Settings.c2
                cursorVisible: false
                cursorDelegate: Item {}
                clip: true
                opacity: lockScreen.checking ? 0.45 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Settings.animBase }
                }

                onAccepted: lockScreen.submit()
            }
        }

        // тёмная обводка-нарост снаружи, как у уведомления
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            NotifContour {
                fillColor: "transparent"
                strokeColor: Settings.c2
                strokeWidth: lockScreen.line * 3
            }
        }

        // основная обводка c1 — поверх всего
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            NotifContour {
                fillColor: "transparent"
                strokeColor: Settings.c1
                strokeWidth: lockScreen.line
            }
        }
    }

    // приезд: дуга прихода уведомления — OutCubic вниз + полуоборот
    // OutSine (600 мс), полёт из-за верхней кромки сразу в центр
    // экрана (нижняя точка Y, середина X)
    PropertyAnimation {
        id: arriveYAnim

        target: form
        property: "y"
        from: -(lockScreen.formH)
        duration: 600
        easing.type: Easing.OutCubic
        to: lockScreen.formFinalY

        onFinished: {
            if (!lockScreen.locked)
                return

            // форма долетела до нижней точки по центру X —
            // начинается затемнение
            blackBg.opacity = 1
            content.opacity = 1
        }
    }

    PropertyAnimation {
        id: arriveRotAnim

        target: form
        property: "rotation"
        from: 0
        to: 180
        duration: 600
        easing.type: Easing.OutSine
    }

    // уход — реверс приезда: затемнение уходит (animSlow), после чего
    // форма улетает вверх — InCubic 600 + обратный полуоборот OutSine
    Timer {
        id: exitDelay

        interval: Settings.animSlow

        onTriggered: {
            formBody.opacity = 0
            exitYAnim.restart()
            exitRotAnim.restart()
        }
    }

    PropertyAnimation {
        id: exitYAnim

        target: form
        property: "y"
        duration: 600
        easing.type: Easing.InCubic
        to: -(lockScreen.formH)

        onFinished: {
            // сброс на следующий показ, форма к этому моменту за экраном
            form.opacity = 0
        }
    }

    PropertyAnimation {
        id: exitRotAnim

        target: form
        property: "rotation"
        duration: 600
        easing.type: Easing.OutSine
        to: 0
    }

    // неверный пароль: форма трясётся
    SequentialAnimation {
        id: shakeAnim

        alwaysRunToEnd: true

        NumberAnimation {
            target: formShake
            property: "x"
            to: -Settings.line * 2
            duration: 60
        }
        NumberAnimation {
            target: formShake
            property: "x"
            to: Settings.line * 2
            duration: 90
        }
        NumberAnimation {
            target: formShake
            property: "x"
            to: 0
            duration: 90
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: lockScreen.locked
        onTriggered: lockScreen.clockNow = new Date()
    }

    PamContext {
        id: pam

        // первый промпт — ответ тем, что в поле; текст не стирается
        // до завершения проверки. Повторные промпты (стек с ретраями
        // после неверного пароля) сжигаются пустым ответом, чтобы
        // один Enter не превратился в самоповтор
        onPamMessage: {
            if (!pam.responseRequired)
                return

            if (!lockScreen.responded && passInput.text.length > 0) {
                lockScreen.responded = true
                pam.respond(passInput.text)
            } else if (lockScreen.responded) {
                pam.respond("")
            }
        }

        onCompleted: (result) => {
            lockScreen.checking = false
            lockScreen.responded = false

            if (result === PamResult.Success) {
                lockScreen.unlock()
            } else {
                // Failed / MaxTries / Error — трясём, ждём новую попытку
                lockScreen.failShake()
            }
        }

        onError: (error) => {
            lockScreen.checking = false
            lockScreen.responded = false
            console.error("825 lockscreen: ошибка PAM:",
                PamError.toString(error))
            // не запираем пользователя навсегда
            lockScreen.unlock()
        }
    }
}
