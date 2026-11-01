import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../Components"
import "../Fonts"
import ".."

// Экран блокировки. Окно живёт всегда (прозрачный оверлей, как у
// уведомлений) — геометрия известна с старта, анимациям не с чем
// гоняться. Пока не заблокировано: маска ввода пуста (клики проходят
// насквозь), клавиатура не наша, всё прозрачно. По блокировке:
// чёрный фон и контент проявляются, а форма пароля повторяет жизнь
// уведомления, только доком не в угол, а в центр экрана: приезд
// (OutCubic 600 + полуоборот OutSine), док (InOutCubic 1200 + догон
// до полного оборота InOutBack), раскрытие — по символу OutBack 700.
// Закрытая форма = startSize уведомления, контент растянут на весь
// контейнер с зазором от кончиков выемок, без курсора. На время
// PAM-проверки ввод замораживается и стирается только по результату.
// Проверка пароля — PAM (дефолтный конфиг login), ошибка PAM
// отпирает, чтобы не запереть пользователя навсегда.
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
    // кончики выемок рамки infex (глубина от кромки на середине высоты)
    readonly property real tipX: 2 * InfexGeometry.notchFrac
        * (formH / 2 - line / 2)
    // закрытая форма = startSize уведомления: квадрат formH × formH
    readonly property real formClosedW: formH
    readonly property real formCharW: line * 4
    readonly property int formMaxLen: 32
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

        exitAnim.stop()
        dockYAnim.stop()
        dockRotAnim.stop()

        locked = true
        checking = false
        responded = false
        clockNow = new Date()
        passInput.text = ""

        // фон и контент проявляются (Behavior на opacity)
        blackBg.opacity = 1
        content.opacity = 1
        form.opacity = 1

        // форма прилетает как уведомление: из-за верхней кромки,
        // потом доком к центру экрана
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
        dockYAnim.stop()
        dockRotAnim.stop()

        // ввод и клавиатура отпускаются сразу, картинка гаснет плавно
        locked = false
        checking = false
        responded = false
        passInput.text = ""
        passInput.focus = false

        blackBg.opacity = 0
        content.opacity = 0
        exitAnim.from = form.y
        exitAnim.restart()
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
        color: "black"
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

    // форма ввода пароля: фрейм инфекса — та же форма, что у
    // уведомления; при пустом пароле — её состояние до раскрытия
    // (квадрат startSize), с символами раскрывается в стороны
    SFrame {
        id: form

        x: Math.round((lockScreen.width - width) / 2)
        y: -(lockScreen.formH)
        width: lockScreen.formClosedW
            + Math.min(passInput.text.length, lockScreen.formMaxLen)
                * lockScreen.formCharW
        height: lockScreen.formH
        fillColor: Settings.c2
        shadow: "both"
        opacity: 0

        // раскрытие — как расширение уведомления (OutBack, 700)
        Behavior on width {
            NumberAnimation {
                duration: 700
                easing.type: Easing.OutBack
            }
        }

        // проявление — как цветовое проявление уведомления (1500, InCubic)
        Behavior on opacity {
            NumberAnimation {
                duration: 1500
                easing.type: Easing.InCubic
            }
        }

        transform: Translate {
            id: formShake
        }

        // контент просто растягивается на весь контейнер; зазор от
        // кончиков выемок, иначе точки на середине высоты срежет
        // маской силуэта; без курсора-разделителя
        TextInput {
            id: passInput

            anchors.fill: parent
            leftPadding: lockScreen.tipX + Settings.line / 2
            rightPadding: lockScreen.tipX + Settings.line / 2
            verticalAlignment: TextInput.AlignVCenter
            horizontalAlignment: TextInput.AlignLeft
            readOnly: lockScreen.checking
            echoMode: TextInput.Password
            font.pixelSize: Settings.textLg
            color: Settings.c1
            selectionColor: Settings.c1
            selectedTextColor: Settings.c2
            cursorVisible: false
            opacity: lockScreen.checking ? 0.45 : 1

            Behavior on opacity {
                NumberAnimation { duration: Settings.animBase }
            }

            onAccepted: lockScreen.submit()
        }
    }

    // приезд: дуга прихода уведомления — OutCubic вниз до промежуточной
    // точки + полуоборот OutSine (600 мс), затем док к центру экрана:
    // InOutCubic 1200 мс и догон до полного оборота InOutBack
    PropertyAnimation {
        id: arriveYAnim

        target: form
        property: "y"
        from: -(lockScreen.formH)
        duration: 600
        easing.type: Easing.OutCubic
        to: lockScreen.formH * 2 + 20

        onFinished: {
            if (!lockScreen.locked)
                return

            dockYAnim.restart()
            dockRotAnim.restart()
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

    PropertyAnimation {
        id: dockYAnim

        target: form
        property: "y"
        duration: 1200
        easing.type: Easing.InOutCubic
        to: lockScreen.formFinalY
    }

    PropertyAnimation {
        id: dockRotAnim

        target: form
        property: "rotation"
        from: 180
        to: 360
        duration: 1200
        easing.type: Easing.InOutBack
    }

    // уход разблокированной формы вверх, как уход уведомления
    PropertyAnimation {
        id: exitAnim

        target: form
        property: "y"
        duration: 1000
        easing.type: Easing.InQuad
        to: -(lockScreen.formH)

        onFinished: {
            // сброс на следующий показ, экран к этому моменту прозрачен
            form.opacity = 0
        }
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
