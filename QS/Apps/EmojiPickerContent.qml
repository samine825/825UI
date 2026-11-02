import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"
import "EmojiData.js" as EmojiData

// Пикер эмодзи без окна: поиск + категории (канонический таб-бар)
// + сетка с ховером. Клик — выбор: копирование в буфер делает
// обёртка или потребитель сигналом emojiPicked. Недавние — до 24
// символов; персист по stateFile (пусто — без сохранения, тесты).
// Ячейка слушает HoverHandler/TapHandler, а не MouseArea: пассивные
// хэндлеры не перехватывают ховер у MouseFollow — 3D-тилт живёт.
Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    signal closeRequested()
    signal emojiPicked(string ch)

    // путь к файлу недавних; пусто — состояние только на сессию
    property string stateFile: ""

    property var recentList: []
    property string query: ""
    property int currentTab: 0
    property string hoveredName: ""

    // === поиск и фильтрация ===
    readonly property var cats: EmojiData.categories
    readonly property string activeCat:
        cats[currentTab] ? cats[currentTab].id : ""

    readonly property var filtered: {
        const q = query.trim().toLowerCase()

        if (activeCat === "frequent") {
            if (q === "")
                return recentList

            return recentList.filter(ch => {
                const info = EmojiData.infoOf(ch)

                return info
                    && (info.name.toLowerCase().indexOf(q) !== -1
                        || info.kw.toLowerCase().indexOf(q) !== -1)
            })
        }

        return EmojiData.search(query, activeCat)
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
        spacing: Settings.line * 2

        // --- строка поиска ---
        SPanel {
            id: searchPanel

            width: parent.width
            height: Settings.line * 7
            cornerCut: Settings.line * 2
            strokeColor: Settings.c1
            fillColor: Settings.c2

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: Settings.line * 3
                anchors.rightMargin: Settings.line * 3
                verticalAlignment: TextInput.AlignVCenter
                text: root.query
                onTextChanged: root.query = text
                color: Settings.c1
                font.pixelSize: Settings.textSm
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
                }
            }
        }

        // --- категории ---
        TabBar {
            id: tabBar

            width: parent.width
            names: root.cats.map(c => c.label)
            current: root.currentTab
            onActivated: (index) => root.currentTab = index
        }

        // --- зона сетки эмодзи ---
        Item {
            width: parent.width
            height: parent.height
                - searchPanel.height - tabBar.height - nameLabel.height
                - Settings.line * 2 * 3

            Flickable {
                id: gridFlick

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: flow.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: gridFlick.contentHeight > gridFlick.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                Flow {
                    id: flow

                    width: gridFlick.width
                    spacing: Settings.line

                    Repeater {
                        model: root.filtered

                        delegate: Item {
                            id: cell

                            width: (gridFlick.width
                                    - Settings.line * 9) / 10
                            height: width

                            readonly property string ch:
                                typeof modelData === "string"
                                    ? modelData : modelData.ch
                            readonly property string ename:
                                typeof modelData === "string"
                                    ? EmojiData.nameOf(modelData)
                                    : modelData.name

                            SRectangle {
                                anchors.fill: parent
                                color: hover.hovered
                                    ? Settings.c1 : "transparent"
                            }

                            SText {
                                anchors.centerIn: parent
                                text: cell.ch
                                color: Settings.c1
                                font.pixelSize: Settings.textLg
                            }

                            // пассивные хэндлеры: тилт контейнера
                            // продолжает следить за мышью
                            HoverHandler {
                                id: hover

                                onHoveredChanged:
                                    root.hoveredName = hovered
                                        ? cell.ename : ""
                            }

                            TapHandler {
                                cursorShape: Qt.PointingHandCursor

                                onTapped: root.pick(cell.ch)
                            }
                        }
                    }
                }
            }

            // пустая категория или пустой поиск
            SText {
                anchors.centerIn: parent
                visible: root.filtered.length === 0
                text: root.query.trim() === ""
                    ? "Nothing here yet"
                    : "Nothing found"
                color: Settings.c1
                font.pixelSize: Settings.textSm
            }
        }

        // --- имя под курсором ---
        SText {
            id: nameLabel

            width: parent.width
            height: Settings.line * 4
            text: root.hoveredName
            color: Settings.c1
            font.pixelSize: Settings.textXs
            verticalAlignment: Text.AlignVCenter
        }
    }
}
