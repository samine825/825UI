import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"
import "EmojiData.js" as EmojiData

// Пикер эмодзи без окна. Каркас — как в настройках: таб-бар
// категорий + контентная панель. Внутри — заголовочная строка
// (поиск + имя под курсором, как шапка уведомлений в панели
// управления) и грид эмодзи по образцу сетки обоев в настройках:
// явные координаты, отсечение невидимого, один общий индикатор
// ховера (заливка c1 переезжает между ячейками). Ячейки слушают
// пассивные HoverHandler/TapHandler — 3D-тилт не глохнет.
// Данные — локальный EmojiData.js, один раз спарсенный из
// unicode.org скриптом Tools/emoji_parse.py. Недавние — до 24
// символов, персист по stateFile (пусто — без сохранения, тесты).
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

    // === категории и фильтрация ===
    readonly property var cats: EmojiData.categories

    readonly property var shown: {
        const cat = cats[currentTab]

        if (query.trim() !== "")
            return EmojiData.search(query,
                cat && cat.id === "frequent" ? "" : cat.id)

        if (cat && cat.id === "frequent")
            return recentList
                .map(ch => EmojiData.infoOf(ch))
                .filter(e => e !== undefined)

        return cat ? EmojiData.search("", cat.id) : []
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
                root.query = ""
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
                        text: "Search " + root.cats[root.currentTab].label
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

            // --- грид эмодзи (паттерн сетки обоев) ---
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

                property real cell:
                    (width - margin * 2 - gap * (columns - 1))
                        / columns

                property real rows:
                    Math.ceil(root.shown.length / columns)

                contentWidth: width
                contentHeight: Math.max(height,
                    rows * (cell + gap) + margin * 2)

                // общий индикатор ховера: заливка c1 переезжает
                // между ячейками, как активный таб
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

                Repeater {
                    model: root.shown

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        // пикер скрытой ячейки экономит рендер
                        readonly property bool inViewport: {
                            const top = y - grid.contentY

                            return top < grid.height + 200
                                && top + height > -200
                        }

                        x: grid.margin
                            + (index % grid.columns)
                            * (grid.cell + grid.gap)
                        y: grid.margin
                            + Math.floor(index / grid.columns)
                            * (grid.cell + grid.gap)
                        width: grid.cell
                        height: grid.cell
                        // над общим индикатором ховера: эмодзи
                        // видны на его заливке
                        z: 2

                        SText {
                            anchors.centerIn: parent
                            visible: cell.inViewport
                            text: cell.modelData.ch
                            color: Settings.c1
                            font.pixelSize: grid.cell * 0.5
                        }

                        // пассивные хэндлеры: тилт контейнера
                        // продолжает следить за мышью
                        HoverHandler {
                            id: hover

                            onHoveredChanged: {
                                hoverInd.target = hovered ? cell : null

                                if (hovered)
                                    root.hoveredName =
                                        cell.modelData.name
                                else if (hoverInd.target === null)
                                    root.hoveredName = ""
                            }
                        }

                        TapHandler {
                            cursorShape: Qt.PointingHandCursor

                            onTapped: root.pick(cell.modelData.ch)
                        }
                    }
                }

                // пустая категория или пустой поиск
                SText {
                    anchors.centerIn: parent
                    visible: root.shown.length === 0
                    text: root.query.trim() === ""
                        ? "Nothing here yet"
                        : "Nothing found"
                    color: Settings.c1
                    font.pixelSize: Settings.textSm
                    font.bold: true
                }
            }
        }
    }
}
