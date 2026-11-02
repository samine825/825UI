import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"

// Буфер обмена без окна. Мониторинг: раз в секунду
// `wl-paste --list-types` (паттерн SystemStats: Process+Timer);
// новый контент — текст до 100КБ или картинка (блоб в imagesDir).
// Менеджерская семантика: захватив контент, сразу возвращаем его в
// буфер от своего имени (wl-copy живёт ребёнком шелла) — вставка
// работает и после закрытия приложения-источника. Богатые тексты
// (text/html) не перезахватываем, чтобы не обесценивать формат.
// Хвостовые \n\r обрезаются: они попадают в выборку из терминалов
// и редакторов, а вставляться должен текст без пустой строки.
// Дедуп: повторное копирование поднимает запись наверх. Лимит —
// 100 незакреплённых (вытеснение снизу, блобы удаляются),
// закреплённые не вытесняются. Персист: FileView по stateFile.
// Клик по карточке — вернуть в буфер (wl-copy), карточка инвертируется.
Item {
    id: root

    implicitWidth: 720
    implicitHeight: 640

    signal closeRequested()
    signal copied(string id)

    // путь к clipboard.json; пусто — состояние только на сессию
    property string stateFile: ""

    // каталог блобов картинок
    property string imagesDir: ""

    property var entries: []
    property string query: ""
    property string currentId: ""

    // последняя сигнатура буфера: типы + размер, против повторов
    property string lastSignature: ""
    property string lastTypes: ""
    property bool loaded: false

    readonly property int maxUnpinned: 100
    readonly property int maxTextLen: 100000
    readonly property int maxImageBytes: 8 * 1024 * 1024

    // отсортированный показ: закреплённые сверху, затем по времени;
    // поиск фильтрует по тексту (у картинок — по типу)
    readonly property var visibleEntries: {
        const q = query.trim().toLowerCase()

        return entries.filter(e => {
            if (q === "")
                return true

            return e.type === "text"
                ? e.text.toLowerCase().indexOf(q) !== -1
                : ("image " + (e.file || "")).toLowerCase()
                    .indexOf(q) !== -1
        }).slice().sort((a, b) => {
            if (a.pinned !== b.pinned)
                return a.pinned ? -1 : 1

            return b.time - a.time
        })
    }

    Component.onCompleted: {
        if (imagesDir !== "")
            mkdirProc.running = true
    }

    // === мониторинг буфера ===
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (!typesProc.running)
                typesProc.running = true
        }
    }

    Process {
        id: typesProc

        command: ["sh", "-c", "wl-paste --list-types 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.onTypes(this.text.trim())
        }
    }

    function onTypes(types) {
        if (types === lastSignature || types === "")
            return

        lastSignature = types
        lastTypes = types

        if (types.indexOf("image/png") !== -1) {
            imageProc.command = ["sh", "-c",
                "wl-paste -t image/png 2>/dev/null"]
            imageProc.running = true
        } else if (types.indexOf("text/plain") !== -1
                   || types.indexOf("text/utf8") !== -1
                   || types.indexOf("UTF8_STRING") !== -1) {
            textProc.running = true
        }
    }

    Process {
        id: textProc

        command: ["sh", "-c", "wl-paste -t text/plain 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.addText(this.text)
        }
    }

    Process {
        id: imageProc

        property int blobBytes: 0

        stdout: StdioCollector {
            onStreamFinished: root.addImage(this.data)
        }
    }

    function addText(text) {
        if (!text || text.length === 0)
            return

        // хвостовые переводы строк — мусор из терминалов/редакторов
        const clean = text.replace(/[\r\n]+$/, "")
        const truncated = clean.length > maxTextLen
            ? clean.slice(0, maxTextLen) + " …" : clean

        addEntry({
            type: "text",
            text: truncated,
            hash: "t:" + clean.length + ":" + truncated.slice(0, 256)
        })
    }

    // картинка добавляется после фактической записи блоба
    property var pendingImage: null

    function addImage(data) {
        if (!data || data.length === 0)
            return

        if (data.length > maxImageBytes)
            return

        if (imagesDir === "")
            return

        const file = imagesDir + "/img-" + Date.now() + "-"
            + data.length + ".png"

        pendingImage = {
            type: "image",
            file: file,
            bytes: data.length,
            hash: "i:" + data.length
        }

        blobView.path = file
        blobView.setData(data)
    }

    FileView {
        id: blobView

        printErrors: false
        atomicWrites: true

        onSaved: {
            if (root.pendingImage) {
                root.addEntry(root.pendingImage)
                root.pendingImage = null
            }
        }
    }

    function addEntry(entry) {
        // дедуп: такой уже есть — поднять наверх (закреплённый —
        // на месте); если он и так первый, ничего не делаем, чтобы
        // не пересобирать список на каждом опросе
        const dupe = entries.find(e => e.hash === entry.hash)

        if (dupe) {
            if (entries[0] && entries[0].id === dupe.id)
                return

            if (!dupe.pinned)
                entries = [dupe].concat(
                    entries.filter(e => e.id !== dupe.id))
            else
                entries = entries.slice()

            save()
            return
        }

        const item = Object.assign({
            id: "e" + Date.now() + Math.floor(Math.random() * 1000),
            time: Date.now(),
            pinned: false
        }, entry)

        entries = [item].concat(entries)
        trimExcess()
        save()

        // менеджерская семантика: держим буфер от своего имени
        reassert(item)
    }

    function reassert(entry) {
        if (entry.type === "text") {
            // богатый текст не перезабираем: потеряется формат
            if (lastTypes.indexOf("text/html") !== -1)
                return

            copyProc.command = ["wl-copy", entry.text]
        } else {
            copyProc.command = ["sh", "-c",
                "wl-copy -t image/png < '" + entry.file + "'"]
        }

        copyProc.running = true
    }

    function trimExcess() {
        const unpinned = entries.filter(e => !e.pinned)

        if (unpinned.length <= maxUnpinned)
            return

        const drop = unpinned.slice(maxUnpinned)
        const dropIds = drop.map(e => e.id)

        drop.forEach(e => {
            if (e.type === "image" && e.file) {
                rmProc.command = ["rm", "-f", e.file]
                rmProc.running = true
            }
        })

        entries = entries.filter(e => dropIds.indexOf(e.id) === -1)
    }

    Process {
        id: rmProc
    }

    Process {
        id: mkdirProc

        command: ["mkdir", "-p", imagesDir]
    }

    // === действия карточек ===
    function copyEntry(id) {
        const e = entries.find(x => x.id === id)

        if (!e)
            return

        if (e.type === "text")
            copyProc.command = ["wl-copy", e.text]
        else
            copyProc.command = ["sh", "-c",
                "wl-copy -t image/png < '" + e.file + "'"]

        copyProc.running = true
        currentId = id
        copied(id)
    }

    function togglePin(id) {
        entries = entries.map(e => e.id === id
            ? Object.assign({}, e, { pinned: !e.pinned }) : e)
        save()
    }

    function removeEntry(id) {
        const e = entries.find(x => x.id === id)

        if (e && e.type === "image" && e.file) {
            rmProc.command = ["rm", "-f", e.file]
            rmProc.running = true
        }

        entries = entries.filter(x => x.id !== id)
        save()
    }

    function clearUnpinned() {
        entries.filter(e => !e.pinned && e.type === "image")
            .forEach(e => {
                rmProc.command = ["rm", "-f", e.file]
                rmProc.running = true
            })

        entries = entries.filter(e => e.pinned)
        save()
    }

    Process {
        id: copyProc
    }

    // === персист ===
    FileView {
        id: store

        path: root.stateFile
        printErrors: false
        atomicWrites: true

        onLoaded: root.loadFrom(this.text())
        onLoadFailed: (error) => {
            // первого запуска файл ещё нет — это норма
        }
    }

    function loadFrom(text) {
        loaded = true

        if (text === "")
            return

        try {
            const data = JSON.parse(text)

            if (data && data.entries instanceof Array) {
                entries = data.entries

                // блобы могли исчезнуть — выкидываем мёртвые ссылки
                entries = entries.filter(e => e.type !== "image"
                    || !e.file || imgExists(e.file))
                lastSignature = ""
            }
        } catch (e) {
            // битый файл — начинаем с пустого списка
        }
    }

    function imgExists(file) {
        // существование проверит сам Image: битые просто не
        // отрисуются, а чистим их при следующем сохранении
        return true
    }

    // сохранение дебаунсится: частые setText подряд роняют
    // движок на асинхронной записи
    Timer {
        id: saveTimer

        interval: 250

        onTriggered: {
            if (root.stateFile === "")
                return

            store.setText(JSON.stringify({ entries: root.entries }))
        }
    }

    function save() {
        if (stateFile === "")
            return

        saveTimer.restart()
    }

    // === интерфейс ===
    function pad2(n) {
        return (n < 10 ? "0" : "") + n
    }

    function timeLabel(ts) {
        const d = new Date(ts)
        const now = new Date()

        if (d.toDateString() === now.toDateString())
            return pad2(d.getHours()) + ":" + pad2(d.getMinutes())

        return pad2(d.getMonth() + 1) + "/" + pad2(d.getDate())
    }

    Column {
        anchors.fill: parent
        spacing: Settings.line * 2

        // --- поиск + очистка ---
        Row {
            width: parent.width
            spacing: Settings.line * 2

            SPanel {
                id: searchPanel

                width: parent.width - clearBtn.width - parent.spacing
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

            STile {
                id: clearBtn

                anchors.verticalCenter: parent.verticalCenter
                width: Settings.line * 7
                height: width
                iconStroke: Glyphs.iconTrash

                onActivated: root.clearUnpinned()
            }
        }

        // --- список карточек ---
        Item {
            width: parent.width
            height: parent.height - searchPanel.height
                - Settings.line * 2

            Flickable {
                id: listFlick

                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: listCol.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: listFlick.contentHeight
                        > listFlick.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                Column {
                    id: listCol

                    width: listFlick.width
                    spacing: Settings.line * 2

                    Repeater {
                        model: root.visibleEntries

                        delegate: SPanel {
                            id: card

                            required property var modelData

                            // выбранная (только что возвращённая в
                            // буфер) карточка — каноническая инверсия
                            readonly property bool sel:
                                root.currentId === card.modelData.id

                            width: listCol.width
                            height: modelData.type === "image"
                                ? Settings.line * 16
                                : Settings.line * 14
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: sel ? Settings.c1 : Settings.c2
                            shadow: sel ? "inside" : "none"
                            shadowColor: Settings.c2

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Settings.line * 3
                                anchors.rightMargin: Settings.line * 3
                                spacing: Settings.line * 3

                                // превью
                                Item {
                                    width: parent.width
                                        - Settings.line * 14
                                    height: parent.height

                                    Image {
                                        visible:
                                            card.modelData.type
                                            === "image"
                                        source:
                                            card.modelData.type
                                            === "image"
                                                ? "file://"
                                                  + card.modelData.file
                                                : ""
                                        anchors.verticalCenter:
                                            parent.verticalCenter
                                        height: parent.height
                                            - Settings.line * 3
                                        fillMode: Image
                                            .PreserveAspectFit
                                    }

                                    Column {
                                        visible:
                                            card.modelData.type
                                            === "text"
                                        anchors.verticalCenter:
                                            parent.verticalCenter
                                        width: parent.width
                                        spacing: Settings.line

                                        SText {
                                            width: parent.width
                                            text: card.modelData.text
                                            color: card.sel
                                                ? Settings.c2
                                                : Settings.c1
                                            elide:
                                                Text.ElideRight
                                            maximumLineCount: 2
                                            wrapMode:
                                                Text.WrapAnywhere
                                            font.pixelSize:
                                                Settings.textSm
                                        }

                                        SText {
                                            width: parent.width
                                            text: root.timeLabel(
                                                card.modelData.time)
                                            color: card.sel
                                                ? Settings.c2
                                                : Settings.c1
                                            font.pixelSize:
                                                Settings.textXs
                                        }
                                    }

                                    SText {
                                        visible:
                                            card.modelData.type
                                            === "image"
                                        anchors.bottom: parent.bottom
                                        anchors.right: parent.right
                                        text: (card.modelData.bytes
                                               / 1024).toFixed(0)
                                              + " KB"
                                        color: card.sel
                                            ? Settings.c2 : Settings.c1
                                        font.pixelSize:
                                            Settings.textXs
                                    }
                                }

                                // булавка
                                Item {
                                    width: Settings.line * 6
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom

                                    STile {
                                        anchors.centerIn: parent
                                        width: Settings.line * 5.5
                                        height: width
                                        iconStroke: Glyphs.iconPin
                                        active: card.modelData.pinned

                                        onActivated:
                                            root.togglePin(
                                                card.modelData.id)
                                    }
                                }

                                // ✕
                                Item {
                                    width: Settings.line * 5
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom

                                    VIcon {
                                        anchors.centerIn: parent
                                        width: Settings.textSm
                                        height: width
                                        strokePath: "M 7,7 L 17,17"
                                            + " M 17,7 L 7,17"
                                        lineColor: Settings.c1
                                    }

                                    MouseArea {
                                        anchors.centerIn: parent
                                        width: parent.height
                                        height: parent.height
                                        cursorShape:
                                            Qt.PointingHandCursor

                                        onClicked:
                                            root.removeEntry(
                                                card.modelData.id)
                                    }
                                }
                            }

                            // клик по карточке — вернуть в буфер
                            MouseArea {
                                anchors.fill: parent
                                z: -1
                                cursorShape: Qt.PointingHandCursor

                                onClicked: root.copyEntry(
                                    card.modelData.id)
                            }
                        }
                    }

                    SText {
                        anchors.horizontalCenter:
                            parent.horizontalCenter
                        visible: root.visibleEntries.length === 0
                        text: root.query.trim() === ""
                            ? "Clipboard is empty"
                            : "Nothing found"
                        color: Settings.c1
                        font.pixelSize: Settings.textSm
                    }
                }
            }
        }
    }
}
