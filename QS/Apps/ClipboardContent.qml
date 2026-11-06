import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Components"
import "../Fonts"
import "../"

// Буфер обмена без окна. Каркас — как в панели управления: шапка-
// бар с поиском (TextInput в SFrame, как дата) + контентная панель
// со строкой «N entries» и Clear all, список карточек в стиле
// истории уведомлений (карточка на две строки, время, пин и крестик
// тайлами, выбранная инвертируется).
//
// Мониторинг: раз в секунду `wl-paste --list-types`; текст читается
// ВСЕГДА, когда типы текстовые — дедуп по содержимому. Сигнатура
// типов используется только для картинок: блобы тяжёлые, а тексты
// подряд из одного приложения дают одинаковый список типов, и
// фильтр по сигнатуре терял каждую вторую копию. Захваченный
// контент сразу перезабирается от своего имени (wl-copy живёт
// ребёнком шелла) — вставка работает после закрытия источника;
// богатые тексты (text/html) не перезабираются. Хвостовые \n\r
// срезаются: из терминалов и редакторов приходит лишняя пустая
// строка. Лимит — 100 незакреплённых (вытеснение снизу), пины
// не вытесняются. Персист: FileView по stateFile.
Item {
    id: root

    implicitWidth: 760
    implicitHeight: 620

    signal closeRequested()
    signal copied(string id)

    // путь к clipboard.json; пусто — состояние только на сессию
    property string stateFile: ""

    // каталог блобов картинок
    property string imagesDir: ""

    property var entries: []
    property string query: ""
    property string currentId: ""

    // сигнатура типов картинок: блобы читаем только при её смене
    property string lastImageSig: ""

    // последний набор типов: богатый текст не перезабираем
    property string lastTypes: ""

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
        if (types === "")
            return

        lastTypes = types

        const hasText = types.indexOf("text/plain") !== -1
            || types.indexOf("text/utf8") !== -1
            || types.indexOf("UTF8_STRING") !== -1

        // текст читаем всегда: дедуп по содержимому ниже
        if (hasText && !textProc.running)
            textProc.running = true

        // картинки — только при смене набора типов
        if (types.indexOf("image/png") !== -1
                && types !== lastImageSig && !imageProc.running) {
            lastImageSig = types
            imageProc.running = true
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
        // на месте); если он и так первый, ничего не делаем
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
        if (text === "")
            return

        try {
            const data = JSON.parse(text)

            if (data && data.entries instanceof Array) {
                entries = data.entries

                // блобы могли исчезнуть — выкидываем мёртвые ссылки
                entries = entries.filter(e => e.type !== "image"
                    || !e.file || imgExists(e.file))
                lastImageSig = ""
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
        spacing: Settings.line * 4

        // --- шапка-бар с поиском (как бар с датой) ---
        Item {
            id: headerBar

            width: parent.width
                - InfexGeometry.tipMult * Settings.line / 2
            height: Settings.barHeight
            anchors.horizontalCenter: parent.horizontalCenter

            SFrame {
                anchors.fill: parent
            }

            TextInput {
                id: searchInput

                anchors.fill: parent
                anchors.leftMargin: Settings.line * 6
                anchors.rightMargin: Settings.line * 6
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
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
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // --- контентная панель ---
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

            // --- строка заголовка: счётчик и очистка ---
            Item {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Settings.line * 2
                height: Settings.textLg

                SText {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.entries.length
                        + (root.entries.length === 1
                            ? " entry" : " entries")
                    color: Settings.c1
                    font.pixelSize: Settings.textMd
                    font.bold: true
                }

                STile {
                    id: clearBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Settings.textLg
                    height: width
                    iconStroke: Glyphs.iconTrash

                    onActivated: root.clearUnpinned()
                }
            }

            // --- список карточек (паттерн истории уведомлений) ---
            Flickable {
                id: listFlick

                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: Settings.line
                anchors.bottomMargin: Settings.line * 2
                anchors.leftMargin: Settings.line * 2
                anchors.rightMargin: Settings.line * 2
                clip: true
                contentWidth: width
                contentHeight: listCol.height
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: listFlick.contentHeight > listFlick.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                Column {
                    id: listCol

                    width: listFlick.width
                    spacing: Settings.line

                    Repeater {
                        model: root.visibleEntries

                        delegate: SPanel {
                            id: card

                            required property var modelData

                            // выбранная (только что возвращённая в
                            // буфер) карточка — каноническая инверсия
                            readonly property bool sel:
                                root.currentId === card.modelData.id

                            readonly property bool isImage:
                                card.modelData.type === "image"

                            width: listCol.width
                            height: Settings.barHeight + Settings.line * 2
                            cornerCut: Settings.line * 2
                            strokeColor: Settings.c1
                            fillColor: sel ? Settings.c1 : Settings.c2
                            shadow: sel ? "inside" : "none"
                            shadowColor: Settings.c2

                            Item {
                                anchors.fill: parent
                                anchors.margins: Settings.line * 2

                                // булавка
                                STile {
                                    id: pinTile

                                    anchors.left: parent.left
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    width: Settings.line * 5.5
                                    height: width
                                    iconStroke: Glyphs.iconPin
                                    active: card.modelData.pinned

                                    onActivated: root.togglePin(
                                        card.modelData.id)
                                }

                                // миниатюра картинки
                                Image {
                                    id: thumb

                                    anchors.left: pinTile.right
                                    anchors.leftMargin:
                                        Settings.line * 2
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    width: height
                                    height: parent.height
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    visible: card.isImage
                                    source: card.isImage
                                        ? "file://"
                                          + card.modelData.file : ""
                                }

                                Column {
                                    anchors.left: card.isImage
                                        ? thumb.right : pinTile.right
                                    anchors.leftMargin:
                                        Settings.line * 2
                                    anchors.right: timeLabel.left
                                    anchors.rightMargin:
                                        Settings.line * 2
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    spacing: Settings.line / 2

                                    SText {
                                        width: parent.width
                                        text: card.isImage
                                            ? (card.modelData.bytes
                                               / 1024).toFixed(0)
                                              + " KB image"
                                            : card.modelData.text
                                        color: card.sel
                                            ? Settings.c2 : Settings.c1
                                        elide: Text.ElideRight
                                        font.pixelSize:
                                            Settings.textSm
                                        font.bold: true
                                    }

                                    SText {
                                        width: parent.width
                                        visible: !card.isImage
                                        text: root.timeLabel(
                                            card.modelData.time)
                                        color: card.sel
                                            ? Settings.c2 : Settings.c1
                                        elide: Text.ElideRight
                                        font.pixelSize:
                                            Settings.textXs
                                    }
                                }

                                SText {
                                    id: timeLabel

                                    anchors.right: delTile.left
                                    anchors.rightMargin:
                                        Settings.line * 2
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    visible: card.isImage
                                    text: root.timeLabel(
                                        card.modelData.time)
                                    color: card.sel
                                        ? Settings.c2 : Settings.c1
                                    font.pixelSize: Settings.textXs
                                }

                                // ✕
                                STile {
                                    id: delTile

                                    anchors.right: parent.right
                                    anchors.verticalCenter:
                                        parent.verticalCenter
                                    width: Settings.line * 5.5
                                    height: width
                                    iconStroke: "M 7,7 L 17,17"
                                        + " M 17,7 L 7,17"

                                    onActivated: root.removeEntry(
                                        card.modelData.id)
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
                        font.bold: true
                    }
                }
            }
        }
    }
}
