import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import ".."

// Радиальное колесо выбора — общий класс для лаунчера приложений,
// Wi-Fi и Bluetooth. Элементы модели: { label, icon }. Листается
// колесом мыши и стрелками, выбор — Enter или клик по сектору,
// Esc закрывает. searchEnabled включает арку поиска с изогнутым
// текстом ввода (клик по центру передаёт ей фокус).
PanelWindow {
    id: wheel

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    visible: false
    focusable: true
    exclusiveZone: -1
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    color: "transparent"

    property var model: []
    property bool searchEnabled: false

    signal activated(var item, int index)
    signal searchChanged(string text)
    signal opened()

    function show() {
        selectedIndex = 0
        searchInput.text = ""
        circle.rotation = 0
        visible = true
        searchInput.forceActiveFocus()
        opened()
    }

    function hide() {
        visible = false
    }

    property var line: Settings.line
    property var thickness: Settings.barHeight

    property int selectedIndex: 0
    readonly property int elementsCount: 13
    readonly property real angle: 360.0 / elementsCount

    // окно видимости: показываются клетки в ±half от выбранной
    readonly property int half: Math.floor(elementsCount / 2)

    readonly property int itemCount: model ? model.length : 0

    onItemCountChanged: {
        if (selectedIndex >= itemCount) {
            selectedIndex = Math.max(0, itemCount - 1)
            circle.rotation = selectedIndex * angle
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: wheel.hide()
    }

    MouseFollow {
        id: tiltContainer

        width: 900
        height: 900

        x: (Screen.width - width) / 2
        y: -width / 2

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (event.angleDelta.y > 0) {
                    if (wheel.selectedIndex > 0) {
                        wheel.selectedIndex -= 1
                        circle.rotation = wheel.selectedIndex * wheel.angle
                    }
                } else if (event.angleDelta.y < 0) {
                    if (wheel.selectedIndex < wheel.itemCount - 1) {
                        wheel.selectedIndex += 1
                        circle.rotation = wheel.selectedIndex * wheel.angle
                    }
                }
            }
        }

        Item {
            id: circle

            anchors.fill: parent

            rotation: 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Settings.animSlow
                    easing.type: Easing.OutQuad
                }
            }

            SRectangle {
                x: -wheel.line
                y: -wheel.line
                width: circle.width + wheel.line*2
                height: circle.height + wheel.line*2

                color: "transparent"
                radius: width / 2
                border.width: wheel.thickness + wheel.line*2

                border.color: Settings.c2

            }
            SRectangle {
                anchors.fill: parent
                color: "transparent"
                radius: width / 2
                border.width: wheel.thickness

                border.color: Settings.c1

            }
            SRectangle {
                anchors.fill: parent

                anchors.topMargin: wheel.line
                anchors.bottomMargin: wheel.line
                anchors.leftMargin: wheel.line
                anchors.rightMargin: wheel.line

                color: "transparent"
                radius: width / 2
                border.width: wheel.thickness - wheel.line*2

                border.color: Settings.c2

            }


            Repeater {
                model: wheel.elementsCount

                delegate: Shape {
                    id: dividerShape
                    preferredRendererType: Shape.CurveRenderer
                    anchors.fill: parent
                    z: 1

                    property real pointCoef: InfexGeometry.notchFrac

                    // Перегородка j лежит между секторами d = (half - j) mod N
                    // и d + 1. В секторе r показывается клетка
                    // rep(r) — единственный индекс с таким остатком в окне
                    // видимости |i - selectedIndex| <= half. Перегородка
                    // видима, когда обе клетки по бокам реальны, плюс
                    // по одной на границах списка (перед первым и после
                    // последнего элемента), если граница в окне.
                    readonly property int pairIndex:
                        ((wheel.half - index) % wheel.elementsCount
                        + wheel.elementsCount) % wheel.elementsCount

                    function sectorApp(r) {
                        return r + wheel.elementsCount * Math.floor(
                            (wheel.selectedIndex + wheel.half - r)
                            / wheel.elementsCount)
                    }

                    visible: {
                        const n = wheel.itemCount

                        if (n === 0)
                            return false

                        const a = sectorApp(pairIndex)
                        const b = sectorApp(
                            (pairIndex + 1) % wheel.elementsCount)

                        const aReal = a >= 0 && a <= n - 1
                        const bReal = b >= 0 && b <= n - 1

                        // между двумя заполненными секторами
                        if (aReal && bReal)
                            return true

                        // ровно по одной перегородке на границах списка:
                        // пустой сосед у первого элемента (b === 0)
                        // или у последнего (a === n - 1)
                        if (b === 0 && !aReal)
                            return true

                        if (a === n - 1 && !bReal)
                            return true

                        return false
                    }

                    rotation: index * wheel.angle

                    SShapePath {
                        joinStyle: ShapePath.MiterJoin
                        capStyle: ShapePath.FlatCap
                        strokeColor: Settings.c1
                        strokeWidth: wheel.line
                        fillColor: "transparent"

                        startX: dividerShape.width / 2
                        startY: wheel.line * 0.5

                        PathLine {
                            x: 180 <= ((index + wheel.selectedIndex)
                                    % wheel.elementsCount) * wheel.angle
                                ? dividerShape.width / 2
                                    - dividerShape.pointCoef
                                    * (wheel.thickness - wheel.line * 0.5)
                                : dividerShape.width / 2
                                    + dividerShape.pointCoef
                                    * (wheel.thickness - wheel.line * 0.5)
                            y: wheel.thickness / 2

                            Behavior on x {
                                NumberAnimation {
                                    duration: Settings.animSlow
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        PathLine {
                            x: dividerShape.width / 2
                            y: wheel.thickness - wheel.line * 0.5
                        }
                    }
                }
            }

            Item {
                id: active
                width: circle.width
                height: circle.height

                z: 2
                rotation: -circle.rotation
                Shape {

                    id: activeShape
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    SShapePath {
                        id: sh
                        fillColor: Settings.c1
                        strokeColor: "transparent"
                        strokeWidth: 0

                        // дуги
                        readonly property real rr: circle.width / 2
                            - wheel.line * 2
                        readonly property real r: circle.width / 2
                            - (wheel.thickness - wheel.line * 2)

                        // углы дуг
                        readonly property real angle1:
                            (90 - wheel.angle / 2) * Math.PI / 180
                        readonly property real angle2:
                            (90 + wheel.angle / 2) * Math.PI / 180

                        function offX(theta, radius, sign) {
                            var t = Math.sqrt(Math.max(0,
                                radius * radius - wheel.line * wheel.line * 9))
                            return circle.width / 2
                                + t * Math.cos(theta)
                                - sign * 3 * wheel.line * Math.sin(theta)
                        }
                        function offY(theta, radius, sign) {
                            var t = Math.sqrt(Math.max(0,
                                radius * radius - wheel.line * wheel.line * 9))
                            return circle.height / 2
                                + t * Math.sin(theta)
                                + sign * 3 * wheel.line * Math.cos(theta)
                        }

                        readonly property real rMid: (rr + r) / 2
                        readonly property real pointCoef: InfexGeometry.notchFrac
                        readonly property real notchDepth: pointCoef
                            * (wheel.thickness - wheel.line * 3)

                        startX: sh.offX(sh.angle1, sh.rr, 1)
                        startY: sh.offY(sh.angle1, sh.rr, 1)

                        // внешняя дуга
                        PathArc {
                            x: sh.offX(sh.angle2, sh.rr, -1)
                            y: sh.offY(sh.angle2, sh.rr, -1)
                            radiusX: sh.rr
                            radiusY: sh.rr
                            useLargeArc: false
                            direction: PathArc.Clockwise
                        }
                        // право верх
                        PathLine {
                            x: sh.offX(sh.angle2, sh.rMid, -1)
                                + sh.notchDepth * Math.sin(sh.angle2)
                            y: sh.offY(sh.angle2, sh.rMid, -1)
                                - sh.notchDepth * Math.cos(sh.angle2)
                        }
                        // право низ
                        PathLine {
                            x: sh.offX(sh.angle2, sh.r, -1)
                            y: sh.offY(sh.angle2, sh.r, -1)
                        }
                        // внутренняя дуга
                        PathArc {
                            x: sh.offX(sh.angle1, sh.r, 1)
                            y: sh.offY(sh.angle1, sh.r, 1)
                            radiusX: sh.r
                            radiusY: sh.r
                            useLargeArc: false
                            direction: PathArc.Counterclockwise
                        }
                        // лево низ
                        PathLine {
                            x: sh.offX(sh.angle1, sh.rMid, 1)
                                - sh.notchDepth * Math.sin(sh.angle1)
                            y: sh.offY(sh.angle1, sh.rMid, 1)
                                + sh.notchDepth * Math.cos(sh.angle1)
                        }
                        // лево верх
                        PathLine {
                            x: sh.startX
                            y: sh.startY
                        }
                    }
                }
            }

            Repeater {
                model: wheel.model

                delegate: Item {
                    id: appCell

                    required property int index
                    required property var modelData

                    anchors.fill: parent
                    z: 3

                    visible: Math.abs(appCell.index - wheel.selectedIndex)
                            <= wheel.half

                    rotation: -appCell.index * wheel.angle

                    readonly property real cx: width / 2
                    readonly property real cy: height / 2

                    // Радиус, на котором расположены центры букв.
                    // Увеличение последнего числа сдвигает текст внутрь кольца.
                    readonly property real labelRadius:
                        height / 2 - wheel.line - 17

                    // Радиус, на котором расположен центр иконки.
                    readonly property real iconRadius:
                        height / 2 - wheel.thickness + wheel.line + 22

                    property color labelColor:
                        appCell.index === wheel.selectedIndex
                            ? Settings.c2
                            : Settings.c1

                    // у элементов с полем status место иконки показывает
                    // статус подключения (wifi/bt/аудио), а не иконку
                    readonly property bool hasStatus:
                        appCell.modelData.status !== undefined
                            && appCell.modelData.status !== null

                    Image {
                        id: cellIcon

                        width: 30
                        height: 30

                        x: appCell.cx - width / 2
                        y: appCell.cy + appCell.iconRadius + height - 10

                        source: appCell.modelData.icon
                            ? appCell.modelData.icon : ""

                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        visible: status === Image.Ready
                            && !appCell.hasStatus
                    }

                    // глиф или индикатор статуса (wifi/bt/аудио) вместо
                    // иконки темы, если та не загрузилась
                    SIcon {
                        width: 30
                        height: 30

                        x: appCell.cx - width / 2
                        y: appCell.cy + appCell.iconRadius + height - 10

                        fillPath: appCell.modelData.glyphFill
                            ? appCell.modelData.glyphFill : ""
                        strokePath: appCell.modelData.glyphStroke
                            ? appCell.modelData.glyphStroke : ""
                        status: appCell.hasStatus
                            ? appCell.modelData.status : ""

                        visible: appCell.hasStatus
                            || cellIcon.status !== Image.Ready
                    }

                    FontMetrics {
                        id: labelFont
                    }

                    TextMetrics {
                        id: labelMetrics

                        text: appCell.modelData.label
                            ? appCell.modelData.label : ""

                        elide: Qt.ElideRight

                        // Оставляем отступы от краёв сектора.
                        elideWidth: Math.max(
                            1,
                            appCell.labelRadius
                                * Math.max(1, wheel.angle - 10)
                                * Math.PI / 180
                        )
                    }

                    readonly property var letters: {
                        // Обновлять расчёт также при изменении шрифта.
                        const currentFont = labelFont.font
                        const chars = Array.from(labelMetrics.elidedText)
                        const widths = []

                        let totalWidth = 0

                        for (let i = 0; i < chars.length; ++i) {
                            const w = labelFont.advanceWidth(chars[i])
                            widths.push(w)
                            totalWidth += w
                        }

                        let offset = -totalWidth / 2
                        const result = []

                        for (let i = 0; i < chars.length; ++i) {
                            result.push({
                                character: chars[i],
                                radians: (offset + widths[i] / 2)
                                        / appCell.labelRadius
                            })

                            offset += widths[i]
                        }

                        return result
                    }

                    Repeater {
                        model: appCell.letters

                        delegate: SText {
                            id: letter
                            font.bold: true
                            required property var modelData

                            readonly property real theta: modelData.radians

                            text: modelData.character
                            color: appCell.labelColor

                            width: implicitWidth
                            height: implicitHeight


                            x: appCell.cx
                            + appCell.labelRadius * Math.sin(theta)
                            - width / 2

                            y: appCell.cy
                            + appCell.labelRadius * Math.cos(theta)
                            - height / 2

                            rotation: -theta * 180 / Math.PI
                            transformOrigin: Item.Center
                        }
                    }
                }
            }
        }

        // Клик по кольцу секторов — выбор элемента. Позиция переводится
        // в полярные координаты: угол отсчитывается по часовой от
        // направления вниз (выбранный сектор смотрит вниз), радиус
        // должен попадать в полосу кольца. Клик мимо кольца передаётся
        // элементам ниже (поиск, закрытие).
        MouseArea {
            id: ringMouse

            anchors.fill: parent

            property int pressIndex: -1

            function hitIndex(mouse) {
                const cx = width / 2
                const dx = mouse.x - cx
                const dy = mouse.y - height / 2
                const r = Math.sqrt(dx * dx + dy * dy)

                if (r < cx - wheel.thickness + wheel.line * 2 || r > cx)
                    return -1

                const a = Math.atan2(-dx, dy) * 180 / Math.PI

                // ячейка i указывает в (selectedIndex - i) * angle от низа
                const j = ((wheel.selectedIndex
                            - Math.round(a / wheel.angle))
                           % wheel.elementsCount + wheel.elementsCount)
                          % wheel.elementsCount
                const i = j + wheel.elementsCount
                    * Math.round((wheel.selectedIndex - j)
                        / wheel.elementsCount)

                if (i < 0 || i >= wheel.itemCount)
                    return -1

                if (Math.abs(i - wheel.selectedIndex) > wheel.half)
                    return -1

                return i
            }

            onPressed: (mouse) => {
                pressIndex = hitIndex(mouse)

                if (pressIndex === -1)
                    mouse.accepted = false
            }

            onClicked: {
                if (pressIndex >= 0)
                    wheel.activated(wheel.model[pressIndex], pressIndex)

                pressIndex = -1
            }
        }

        Item {
            id: searchArea
            visible: wheel.searchEnabled
            width: circle.width - wheel.thickness*2 - wheel.line*6 - inputHeight
            height: circle.height - wheel.thickness*2 - wheel.line*6  - inputHeight
            x: circle.x + circle.width/2
            y: circle.y + circle.width/2

            property real arcRadius: searchArea.width/2
            property real arcCenterX: circle.width / 2
            property real arcCenterY: circle.height / 2
            property real charAngle: 3

            property real firstAngle: curvedText.firstAngle + 90
            property real secondAngle: -curvedText.firstAngle - 90

            property real inputHeight: 50

            readonly property real angleDiff: {
                let diff = (searchArea.secondAngle - searchArea.firstAngle) % 360;
                if (diff < 0) diff += 360;
                return diff;
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                SShapePath {
                    strokeColor: Settings.c2
                    strokeWidth: searchArea.inputHeight + wheel.line*2
                    fillColor: "transparent"

                    startX: searchArea.width/2 * Math.sin(searchArea.firstAngle * Math.PI / 180)
                    startY: searchArea.width/2 * Math.cos(searchArea.firstAngle * Math.PI / 180)

                    PathArc {
                        x: searchArea.width/2 * Math.sin(searchArea.secondAngle * Math.PI / 180)
                        y: searchArea.width/2 * Math.cos(searchArea.secondAngle * Math.PI / 180)
                        radiusX: searchArea.width / 2
                        radiusY: searchArea.height / 2
                        direction: PathArc.Counterclockwise
                        useLargeArc: searchArea.angleDiff > 180
                        Behavior on x {
                            NumberAnimation {
                                duration: Settings.animInstant
                                easing.type: Easing.OutQuad
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Settings.animInstant
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Behavior on startX {
                        NumberAnimation {
                            duration: Settings.animInstant
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on startY {
                        NumberAnimation {
                            duration: Settings.animInstant
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                SShapePath {
                    strokeColor: Settings.c1
                    strokeWidth: searchArea.inputHeight
                    fillColor: "transparent"

                    startX: searchArea.width/2 * Math.sin(searchArea.firstAngle * Math.PI / 180)
                    startY: searchArea.width/2 * Math.cos(searchArea.firstAngle * Math.PI / 180)

                    PathArc {
                        x: searchArea.width/2 * Math.sin(searchArea.secondAngle * Math.PI / 180)
                        y: searchArea.width/2 * Math.cos(searchArea.secondAngle * Math.PI / 180)
                        radiusX: searchArea.width / 2
                        radiusY: searchArea.height / 2
                        direction: PathArc.Counterclockwise
                        useLargeArc: searchArea.angleDiff > 180
                        Behavior on x {
                            NumberAnimation {
                                duration: Settings.animInstant
                                easing.type: Easing.OutQuad
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Settings.animInstant
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Behavior on startX {
                        NumberAnimation {
                            duration: Settings.animInstant
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on startY {
                        NumberAnimation {
                            duration: Settings.animInstant
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                SShapePath {
                    strokeColor: Settings.c2
                    strokeWidth: searchArea.inputHeight - wheel.line*2
                    fillColor: "transparent"

                    startX: searchArea.width/2 * Math.sin(searchArea.firstAngle * Math.PI / 180)
                    startY: searchArea.width/2 * Math.cos(searchArea.firstAngle * Math.PI / 180)

                    PathArc {
                        x: searchArea.width/2 * Math.sin(searchArea.secondAngle * Math.PI / 180)
                        y: searchArea.width/2 * Math.cos(searchArea.secondAngle * Math.PI / 180)
                        radiusX: searchArea.width / 2
                        radiusY: searchArea.height / 2
                        direction: PathArc.Counterclockwise
                        useLargeArc: searchArea.angleDiff > 180
                        Behavior on x {
                            NumberAnimation {
                                duration: Settings.animInstant
                                easing.type: Easing.OutQuad
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Settings.animInstant
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Behavior on startX {
                        NumberAnimation {
                            duration: Settings.animInstant
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on startY {
                        NumberAnimation {
                            duration: Settings.animInstant
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }

            Item {
                id: curvedText
                anchors.fill: parent

                readonly property real r: searchArea.arcRadius

                property var anglesArray: []
                property real totalTextAngle: 0
                Behavior on totalTextAngle {NumberAnimation { duration: 1}}

                function recalculateAngles() {
                    let count = textRepeater.count;
                    let widths = [];
                    let totalW = 0;

                    for (let i = 0; i < count; ++i) {
                        let item = textRepeater.itemAt(i);
                        let w = item ? item.contentWidth : 12;
                        widths.push(w);
                        totalW += w;
                    }

                    totalTextAngle = (totalW / (2 * Math.PI * r)) * 360;

                    let currentAngleOffset = 0;
                    let tempAngles = [];

                    for (let i = 0; i < count; ++i) {
                        let charAngleWidth = (widths[i] / (2 * Math.PI * r)) * 360;
                        tempAngles.push(currentAngleOffset + charAngleWidth / 2);
                        currentAngleOffset += charAngleWidth;
                    }

                    anglesArray = tempAngles;
                }

                property real firstAngle: 270 - totalTextAngle / 2

                Repeater {
                    id: textRepeater
                    model: searchInput.text.length

                    delegate: SText {
                        id: charText
                        font.bold: true
                        required property int index
                        property string character: searchInput.text.charAt(index)

                        color: Settings.c1
                        font.pixelSize: Settings.textMd
                        text: character
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        onContentWidthChanged: curvedText.recalculateAngles()

                        property real myAngleOffset: (curvedText.anglesArray && curvedText.anglesArray.length > index)
                            ? curvedText.anglesArray[index]
                            : 0

                        property real theta: (curvedText.firstAngle + (curvedText.totalTextAngle - myAngleOffset)) * Math.PI / 180

                        x: -searchArea.arcRadius * Math.cos(theta) - width / 2
                        y: -searchArea.arcRadius * Math.sin(theta) - height / 2
                        rotation: theta * 180 / Math.PI + 90

                        Behavior on x { NumberAnimation { duration: Settings.animInstant; easing.type: Easing.OutQuad } }
                        Behavior on y { NumberAnimation { duration: Settings.animInstant; easing.type: Easing.OutQuad } }
                        Behavior on rotation { NumberAnimation { duration: Settings.animInstant; easing.type: Easing.OutQuad } }
                    }
                }

                Connections {
                    target: searchInput
                    function onTextChanged() {
                        Qt.callLater(curvedText.recalculateAngles);
                    }
                }
            }

            // searchArea позиционируется своим левым верхним углом в
            // центре круга (так рисуется арка), поэтому хитбокс
            // центрируется явно и проверяет попадание в круг.
            MouseArea {
                x: -width / 2
                y: -height / 2
                width: searchArea.width + searchArea.inputHeight
                    + wheel.line * 2
                height: searchArea.height + searchArea.inputHeight
                    + wheel.line * 2
                acceptedButtons: Qt.LeftButton

                onClicked: (mouse) => {
                    const dx = mouse.x - width / 2
                    const dy = mouse.y - height / 2
                    const r = width / 2

                    if (dx * dx + dy * dy <= r * r) {
                        searchInput.forceActiveFocus()
                    } else {
                        mouse.accepted = false
                    }
                }
            }
        }
    }

    // Скрытый приёмник клавиатуры: стрелки — листание, Enter — выбор,
    // Esc — закрытие. При searchEnabled текст сюда же попадает
    // в арку поиска.
    TextInput {
        id: searchInput
        x: 0
        y: 0
        width: 1
        height: 1
        color: "transparent"
        font.pixelSize: 1
        opacity: 0.01
        clip: false
        cursorVisible: false
        selectByMouse: false
        focus: true

        onTextChanged: {
            wheel.selectedIndex = 0
            circle.rotation = 0
            wheel.searchChanged(text)
        }

        Keys.onReturnPressed: {
            if (wheel.selectedIndex < wheel.itemCount)
                wheel.activated(wheel.model[wheel.selectedIndex],
                    wheel.selectedIndex)
        }

        Keys.onLeftPressed: {
            if (wheel.selectedIndex > 0) {
                wheel.selectedIndex -= 1
                circle.rotation = wheel.selectedIndex * wheel.angle
            }
        }

        Keys.onRightPressed: {
            if (wheel.selectedIndex < wheel.itemCount - 1) {
                wheel.selectedIndex += 1
                circle.rotation = wheel.selectedIndex * wheel.angle
            }
        }

        Keys.onEscapePressed: {
            wheel.hide()
        }
    }
}
