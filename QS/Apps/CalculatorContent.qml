import QtQuick
import Quickshell
import "../Components"
import "../Fonts"
import "../"
import "Calc.js" as Calc

// Содержимое калькулятора без окна: логика + визуал в одном Item
// фиксированного размера. Обёртка-PanelWindow — Calculator.qml; в
// тестах содержимое инстанцируется прямо в видимом окне стенда.
Item {
    id: root

    implicitWidth: 440
    implicitHeight: 708

    signal closeRequested()

    // === состояние калькулятора ===
    property string expression: ""

    // после "=" первая цифра начинает заново, оператор продолжает
    property bool justEvaluated: false

    // живой предпросчёт: null, пока выражение не вычисляется целиком
    readonly property var previewValue:
        expression === "" || justEvaluated
            ? null : Calc.evaluateOrNull(expression)

    readonly property string previewText:
        previewValue === null
            ? "" : "= " + Calc.format(previewValue)

    function append(text) {
        // после "=" цифра и точка начинают новый ввод,
        // оператор продолжает от результата
        if (justEvaluated) {
            if (text >= "0" && text <= "9" || text === ".")
                expression = ""
            else
                justEvaluated = false

            // с пустым выражением двоичный оператор и процент
            // бессмысленны, минус — унарный
            if (expression === "" && (text === "×" || text === "÷"
                                      || text === "%" || text === "+"))
                return
        }

        // два оператора подряд: последний заменяет предыдущий
        // (минус после оператора не заменяет — это унарный "-5")
        if (text !== "−" && expression.length > 0) {
            const last = expression[expression.length - 1]

            if ((text === "+" || text === "×" || text === "÷"
                    || text === "%")
                    && (last === "+" || last === "−" || last === "×"
                        || last === "÷" || last === "%" || last === ".")) {
                expression = expression.slice(0, -1)
            }
        }

        // точка не может открывать число — подставляем "0."
        if (text === "." && !/[0-9.]$/.test(expression)) {
            expression += "0"
        }

        expression += text
    }

    function backspace() {
        justEvaluated = false

        if (expression.length > 0)
            expression = expression.slice(0, -1)
    }

    function clearAll() {
        expression = ""
        justEvaluated = false
    }

    // меняет знак последнего числа: оборачивает его в (−N)
    function negate() {
        justEvaluated = false

        const match = expression.match(/(\d+\.?\d*)$/)

        if (!match)
            return

        const start = expression.length - match[1].length

        expression = expression.slice(0, start) + "(−" + match[1] + ")"
    }

    function evaluate() {
        if (expression === "" || justEvaluated)
            return

        try {
            const value = Calc.evaluate(expression)

            expression = Calc.format(value)
            justEvaluated = true
        } catch (e) {
            shakeAnim.start()
        }
    }

    // === тряска контента при ошибке ===
    SequentialAnimation {
        id: shakeAnim

        PropertyAnimation {
            target: shakeWrap; property: "x"
            to: -Settings.line * 2; duration: 60
        }
        PropertyAnimation {
            target: shakeWrap; property: "x"
            to: Settings.line * 2; duration: 90
        }
        PropertyAnimation {
            target: shakeWrap; property: "x"
            to: 0; duration: 90
        }
    }

    // приёмник клавиатуры: цифры, операторы, Enter/Backspace/Esc
    Item {
        id: keysItem

        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                root.closeRequested()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Enter
                    || event.key === Qt.Key_Return) {
                root.evaluate()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Backspace) {
                root.backspace()
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Delete
                    || event.key === Qt.Key_C) {
                root.clearAll()
                event.accepted = true
                return
            }

            const t = event.text

            if ((t >= "0" && t <= "9") || t === "." || t === "%"
                    || t === "(" || t === ")") {
                root.append(t)
                event.accepted = true
            } else if (t === "+") {
                root.append("+")
                event.accepted = true
            } else if (t === "-") {
                root.append("−")
                event.accepted = true
            } else if (t === "*" || t === "x" || t === "X") {
                root.append("×")
                event.accepted = true
            } else if (t === "/") {
                root.append("÷")
                event.accepted = true
            }
        }

        // обёртка для тряски (x анимируется при ошибке)
        Item {
            id: shakeWrap

            anchors.fill: parent

            Column {
                anchors.fill: parent
                spacing: Settings.line * 4

                // --- хедер-бар ---
                Item {
                    id: headerBar

                    width: parent.width
                        - InfexGeometry.tipMult * Settings.line / 2
                    height: Settings.barHeight
                    anchors.horizontalCenter: parent.horizontalCenter

                    SFrame {
                        anchors.fill: parent
                    }

                    SText {
                        anchors.centerIn: parent
                        text: "Calculator"
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                    }
                }

                // --- контентная область ---
                SPanel {
                    id: contentArea

                    width: parent.width
                    height: parent.height - headerBar.height
                        - Settings.line * 4
                    cornerCut: Settings.line * 2
                    strokeColor: Settings.c1
                    fillColor: Settings.c2
                    shadow: "outside"
                    shadowColor: Settings.c2

                    // поля и зазор сетки
                    property real pad: Settings.line * 3
                    property real gridGap: Settings.line * 2

                    readonly property real btnSize:
                        (width - pad * 2 - gridGap * 3) / 4

                    Column {
                        id: contentCol

                        x: contentArea.pad
                        y: contentArea.pad
                        width: contentArea.width - contentArea.pad * 2
                        spacing: Settings.line * 3

                        // === дисплей ===
                        Item {
                            width: parent.width
                            height: Settings.line * 11

                            // выражение; выравнивание вправо, длинный
                            // ввод прокручивается к хвосту
                            TextInput {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: Settings.line
                                height: Settings.textLg * 1.4
                                readOnly: true
                                text: root.expression
                                color: Settings.c1
                                font.pixelSize: Settings.textLg
                                font.bold: true
                                horizontalAlignment: TextInput.AlignRight
                                verticalAlignment: TextInput.AlignVCenter
                                cursorVisible: false
                                cursorDelegate: Item {}
                                selectionColor: Settings.c1
                                selectedTextColor: Settings.c2
                                clip: true
                            }

                            SText {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: Settings.line
                                anchors.bottomMargin: Settings.line
                                text: root.previewText
                                color: Settings.c1
                                opacity: root.previewText === "" ? 0 : 0.55
                                font.pixelSize: Settings.textSm
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Settings.animFast
                                    }
                                }
                            }
                        }

                        // === кнопки 4x5 ===
                        Grid {
                            columns: 4
                            spacing: contentArea.gridGap

                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "C"
                                role: "clear"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                icon: Glyphs.iconBackspace
                                role: "backspace"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "%"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "÷"
                            }

                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "7"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "8"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "9"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "×"
                            }

                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "4"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "5"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "6"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "−"
                            }

                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "1"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "2"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "3"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "+"
                            }

                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "±"
                                role: "negate"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "0"
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "."
                            }
                            CalcButton {
                                width: contentArea.btnSize
                                height: contentArea.btnSize
                                label: "="
                                role: "equals"
                                accent: true
                            }
                        }
                    }
                }
            }
        }
    }

    // === кнопка: SPanel со вспышкой заливки при нажатии ===
    component CalcButton: SPanel {
        id: btn

        property string label: ""
        property string icon: ""
        // clear / backspace / negate / equals — иначе просто вставка
        property string role: "insert"
        property bool accent: false
        property bool flash: false

        signal activated()

        cornerCut: Settings.line * 2
        strokeColor: Settings.c1
        fillColor: flash || accent ? Settings.c1 : "transparent"

        VIcon {
            anchors.centerIn: parent
            visible: btn.icon !== ""
            width: parent.width * 0.5
            height: width
            strokePath: btn.icon
            lineColor: btn.flash || btn.accent
                ? Settings.c2 : Settings.c1
        }

        SText {
            anchors.centerIn: parent
            visible: btn.icon === ""
            text: btn.label
            color: btn.flash || btn.accent
                ? Settings.c2 : Settings.c1
            font.pixelSize: Settings.textMd
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            onPressed: btn.flash = true
            onReleased: btn.flash = false
            onCanceled: btn.flash = false
            onClicked: btn.activated()
        }

        onActivated: {
            if (role === "clear")
                root.clearAll()
            else if (role === "backspace")
                root.backspace()
            else if (role === "negate")
                root.negate()
            else if (role === "equals")
                root.evaluate()
            else
                root.append(label)
        }
    }
}
