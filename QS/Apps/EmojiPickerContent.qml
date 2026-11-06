import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"
import "EmojiData.js" as EmojiData

// Пикер эмодзи без окна. Каркас — как в настройках: таб-бар
// категорий + контентная панель. Все эмодзи лежат одним списком
// (как сетка обоев: явные координаты, отсечение невидимого),
// секции разделены заголовками групп; табы не фильтруют, а
// прокручивают список к своей секции, и наоборот — прокручивание
// двигает активный таб. Поиск оставляет совпадения всех групп
// (с их заголовками). Общий индикатор ховера — заливка c1,
// переезжает между ячейками. Ячейки слушают пассивные
// HoverHandler/TapHandler. Данные — локальный EmojiData.js,
// один раз спарсенный из unicode.org скриптом Tools/emoji_parse.py.
// Недавние — первой секцией, до 24 символов, персист по stateFile.
Item {
    id: root

    implicitWidth: 760
    implicitHeight: 640

    signal closeRequested()
    signal emojiPicked(string ch)

    // путь к файлу недавних; пусто — состояние только на сессию
    property string stateFile: ""

    property var recentList: []
    property string query: ""
    property int currentTab: 0
    property string hoveredName: ""

    // === построение единого списка ===
    // элементы: { header: true, name, x, y, tabIndex }
    //           { header: false, entry, x, y }
    // tops — y-якоря секций по индексу таба
    readonly property var layout: buildLayout()

    function labelOf(group) {
        const cat = cats.find(c => c.id === group)

        return cat ? cat.label : group
    }

    function buildLayout() {
        const q = query.trim().toLowerCase()
        const all = EmojiData.entries

        const filtered = q === "" ? all : all.filter(e =>
            e.name.toLowerCase().indexOf(q) !== -1
            || e.kw.toLowerCase().indexOf(q) !== -1)

        const items = []
        const tops = []
        const margin = grid.margin
        const cellStep = grid.cell + grid.gap
        const headerStep = grid.headerH + grid.gap
        const recent = recentList
            .map(ch => EmojiData.infoOf(ch))
            .filter(e => e !== undefined)

        let y = margin
        let col = 0

        function placeHeader(name, tabIndex) {
            if (col !== 0) {
                col = 0
                y += cellStep
            }

            items.push({ header: true, name: name,
                x: margin, y: y, tabIndex: tabIndex })
            tops.push({ tabIndex: tabIndex, y: y })
            y += headerStep
        }

        function placeEntry(e) {
            items.push({ header: false, entry: e,
                x: margin + col * cellStep, y: y })

            col++

            if (col === grid.columns) {
                col = 0
                y += cellStep
            }
        }

        if (filtered !== all) {
            // поиск: совпадения всех групп, с их заголовками
            let lastGroup = ""

            for (let i = 0; i < filtered.length; i++) {
                const e = filtered[i]

                if (e.group !== lastGroup) {
                    lastGroup = e.group
                    placeHeader(labelOf(e.group),
                        catIndex(e.group))
                }

                placeEntry(e)
            }
        } else {
            // полный список: недавние первой секцией
            if (recent.length > 0) {
                placeHeader(labelOf("frequent"), 0)

                for (let r = 0; r < recent.length; r++)
                    placeEntry(recent[r])
            }

            let lastGroup = ""

            for (let i = 0; i < all.length; i++) {
                const e = all[i]

                if (e.group !== lastGroup) {
                    lastGroup = e.group
                    placeHeader(labelOf(e.group),
                        catIndex(e.group))
                }

                placeEntry(e)
            }
        }

        return {
            items: items,
            tops: tops,
            // нижнее поле + незавершённый ряд
            height: y + (col !== 0 ? cellStep : 0) + margin
        }
    }

    function catIndex(group) {
        if (group === "frequent")
            return 0

        for (let i = 1; i < cats.length; i++) {
            if (cats[i].id === group)
                return i
        }

        return 0
    }

    function pick(ch) {
        // наверх и без дублей, максимум 24; копирование в буфер —
        // забота обёртки (сигнал emojiPicked)
        recentList = [ch].concat(
            recentList.filter(c => c !== ch)).slice(0, 24)
        saveRecent()

        emojiPicked(ch)
    }

    function loadRecent(text) {
        if (text === "")
            return

        try {
            const data = JSON.parse(text)

            if (data && data.recent instanceof Array)
                recentList = data.recent
        } catch (e) {
            // битый файл — начинаем с пустых недавних
        }
    }

    function saveRecent() {
        if (stateFile === "")
            return

        store.setText(JSON.stringify({ recent: recentList }))
    }

    readonly property var cats: EmojiData.categories

    FileView {
        id: store

        path: root.stateFile
        printErrors: false

        onLoaded: root.loadRecent(this.text())
        onLoadFailed: (error) => {
            // первого запуска файл ещё нет — это норма
        }
    }

    Column {
        anchors.fill: parent
        spacing: Settings.line * 4

        // --- табы категорий (как в настройках) ---
        TabBar {
            id: tabBar

            width: parent.width
                - InfexGeometry.tipMult * Settings.line / 2
            anchors.horizontalCenter: parent.horizontalCenter
            names: root.cats.map(c => c.label)
            current: root.currentTab

            onActivated: (index) => {
                root.currentTab = index
                root.scrollToSection(index)
            }
        }

        // --- контентная панель ---
        SPanel {
            id: contentArea

            width: parent.width
            height: parent.height - tabBar.height
                - Settings.line * 4
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: Settings.c2
            shadow: "outside"
            shadowColor: Settings.c2

            // --- заголовочная строка: поиск + имя под курсором ---
            Item {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Settings.line * 2
                height: Settings.textLg

                TextInput {
                    id: searchInput

                    anchors.left: parent.left
                    anchors.right: hoveredLabel.visible
                        ? hoveredLabel.left : parent.right
                    anchors.rightMargin: hoveredLabel.visible
                        ? Settings.line * 3 : 0
                    anchors.verticalCenter: parent.verticalCenter
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.query
                    onTextChanged: root.query = text
                    color: Settings.c1
                    font.pixelSize: Settings.textSm
                    font.bold: true
                    cursorVisible: false
                    cursorDelegate: Item {}
                    selectionColor: Settings.c1
                    selectedTextColor: Settings.c2
                    clip: true

                    Keys.onEscapePressed: (event) => {
                        if (text !== "")
                            text = ""
                        else
                            root.closeRequested()

                        event.accepted = true
                    }

                    SText {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text === ""
                        text: "Search"
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                        font.bold: true
                    }
                }

                // имя эмодзи под курсором — справа, как кнопки в шапке
                SText {
                    id: hoveredLabel

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width * 0.5)
                    visible: root.hoveredName !== ""
                    text: root.hoveredName
                    color: Settings.c1
                    elide: Text.ElideRight
                    font.pixelSize: Settings.textXs
                    horizontalAlignment: Text.AlignRight
                }
            }

            // --- единый список эмодзи (паттерн сетки обоев) ---
            Flickable {
                id: grid

                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Settings.line
                anchors.bottomMargin: Settings.line * 2
                anchors.leftMargin: Settings.line * 2
                anchors.rightMargin: Settings.line * 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 1000

                ScrollBar.vertical: ScrollBar {
                    policy: grid.contentHeight > grid.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                property real margin: Settings.line * 1.5
                property real gap: Settings.line * 1.5
                property int columns: 10
                property real headerH: Settings.textLg

                property real cell:
                    (width - margin * 2 - gap * (columns - 1))
                        / columns

                contentWidth: width
                contentHeight: Math.max(height,
                    root.layout.height)

                // прокрутка синхронизирует активный таб: секция под
                // верхней кромкой становится активной
                onContentYChanged: root.syncTab()

                // плавный доскролл при клике по табу
                NumberAnimation {
                    id: scrollAnim

                    target: grid
                    property: "contentY"
                    duration: Settings.animSlow
                    easing.type: Easing.OutCubic
                }

                Repeater {
                    model: root.layout.items

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        // скрытые ячейки не рендерятся
                        readonly property bool inViewport: {
                            const top = y - grid.contentY

                            return top < grid.height + 200
                                && top + height > -200
                        }

                        x: modelData.x
                        y: modelData.y
                        width: grid.cell
                        height: modelData.header
                            ? grid.headerH : grid.cell
                        // над общим индикатором ховера
                        z: modelData.header ? 3 : 2

                        // заголовок секции
                        SText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: cell.modelData.header
                            text: cell.modelData.header
                                ? cell.modelData.name : ""
                            color: Settings.c1
                            font.pixelSize: Settings.textSm
                            font.bold: true
                        }

                        // эмодзи
                        SText {
                            anchors.centerIn: parent
                            visible: !cell.modelData.header
                                && cell.inViewport
                            text: cell.modelData.header
                                ? "" : cell.modelData.entry.ch
                            color: Settings.c1
                            font.pixelSize: grid.cell * 0.5
                        }

                        // пассивные хэндлеры: тилт контейнера
                        // продолжает следить за мышью
                        HoverHandler {
                            id: hover

                            enabled: !cell.modelData.header

                            onHoveredChanged: {
                                hoverInd.target = hovered ? cell : null

                                if (hovered)
                                    root.hoveredName =
                                        cell.modelData.entry.name
                                else if (hoverInd.target === null)
                                    root.hoveredName = ""
                            }
                        }

                        TapHandler {
                            enabled: !cell.modelData.header
                            cursorShape: Qt.PointingHandCursor

                            onTapped: root.pick(
                                cell.modelData.entry.ch)
                        }
                    }
                }

                // общий индикатор ховера: заливка c1 переезжает
                // между ячейками
                SPanel {
                    id: hoverInd

                    property Item target: null

                    visible: target !== null
                    width: grid.cell
                    height: grid.cell
                    x: target ? target.x : 0
                    y: target ? target.y : 0
                    cornerCut: Settings.line
                    fillColor: Settings.c1
                    z: 1

                    Behavior on x {
                        NumberAnimation {
                            duration: Settings.animInstant
                        }
                    }

                    Behavior on y {
                        NumberAnimation {
                            duration: Settings.animInstant
                        }
                    }
                }

                // пустой поиск
                SText {
                    anchors.centerIn: parent
                    visible: root.layout.items.length === 0
                    text: "Nothing found"
                    color: Settings.c1
                    font.pixelSize: Settings.textSm
                    font.bold: true
                }
            }
        }
    }

    // таб → прокрутка к секции
    function scrollToSection(tabIndex) {
        const tops = layout.tops
        let target = null

        for (let i = 0; i < tops.length; i++) {
            if (tops[i].tabIndex === tabIndex) {
                target = tops[i]
                break
            }
        }

        // секции нет (пустые недавние, пустая группа) — к ближайшей
        if (!target)
            target = tops.length > 0 ? tops[0] : null

        if (!target)
            return

        scrollAnim.to = Math.min(target.y - grid.margin,
            Math.max(0, grid.contentHeight - grid.height))
        scrollAnim.restart()
    }

    // прокрутка → таб (секция под верхней кромкой)
    function syncTab() {
        if (scrollAnim.running || layout.tops.length === 0)
            return

        const edge = grid.contentY + grid.margin + 1
        let active = layout.tops[0].tabIndex

        for (let i = 0; i < layout.tops.length; i++) {
            if (layout.tops[i].y <= edge)
                active = layout.tops[i].tabIndex
            else
                break
        }

        if (currentTab !== active)
            currentTab = active
    }
}
