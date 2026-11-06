pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Bluetooth

Singleton {
    id: root

    property list<var> notifications: []
    property int unread: 0

    // архив для панели управления: всё, что приходило, новое сверху.
    // signal historyChanged генерируется автоматически из свойства
    property list<var> history: []
    readonly property int historyMax: 50

    signal notificationAdded(notification: var)
    signal notificationRemoved(notificationId: int)
    signal allCleared

    NotificationServer {
        id: notifServer
        actionsSupported: true
        bodySupported: true
        imageSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        persistenceSupported: true
        
        onNotification: (notification) => {
            // диагностика: кто шлёт уведомления (видно в логах qs)
            console.warn("825 notification from '"
                + notification.appName + "': "
                + notification.summary + " — " + notification.body)

            var entry = {
                notificationId: notification.id,
                summary: notification.summary,
                body: notification.body,
                appName: notification.appName,
                appIcon: notification.appIcon,
                image: notification.image,
                urgency: notification.urgency,
                expireTimeout: notification.expireTimeout,
                time: Date.now(),
                popup: true
            }
            
            
            root.notifications = [...root.notifications, entry]
            root.unread++
            root.notificationAdded(entry)
            root.pushHistory(entry)
            
            let timeout = notification.expireTimeout > 0 ? notification.expireTimeout : 5000
            if (notification.urgency === NotificationUrgency.Critical) timeout = 0
            
            if (timeout > 0) {
                let timer = Qt.createQmlObject('import QtQuick 2.0; Timer {}', root, "notifTimer_" + notification.id)
                timer.interval = timeout
                timer.triggered.connect(() => {
                    root.dismissNotification(notification.id)
                    timer.destroy()
                })
                timer.start()
            }
        }
    }
    
    function dismissNotification(id) {
        let idx = root.notifications.findIndex(n => n.notificationId === id)
        if (idx !== -1) {
            root.notifications.splice(idx, 1)
            root.notificationRemoved(id)
        }
        let values = notifServer.trackedNotifications.values
        let serverIdx = values.findIndex(n => n.id === id)
        if (serverIdx !== -1) {
            values[serverIdx].dismiss()
        }
    }
    
    function dismissAll() {
        let values = notifServer.trackedNotifications.values
        for (let i = 0; i < values.length; i++) {
            values[i].dismiss()
        }
        root.notifications = []
        root.unread = 0
        root.allCleared()
    }

    // === архив ===

    function pushHistory(entry) {
        const copy = Object.assign({}, entry)
        root.history = [copy].concat(root.history)
            .slice(0, root.historyMax)
    }

    function removeHistory(id) {
        root.history = root.history.filter(
            h => h.notificationId !== id)
    }

    function clearHistory() {
        if (root.history.length === 0)
            return

        root.history = []
    }

    // === внутренние уведомления (bluetooth и т.п.) ===
    // иконки нет, текст приходит целиком от вызывающего; попап
    // показывается только вне режима без уведомлений, архив
    // пополняется всегда. id отрицательные — не пересекаются
    // с uint-идентификаторами DBus-сервера
    property int localId: -1

    function notify(appName, summary, body) {
        const entry = {
            notificationId: root.localId--,
            summary: summary,
            body: body,
            appName: appName,
            appIcon: "",
            image: "",
            urgency: NotificationUrgency.Normal,
            expireTimeout: 5000,
            time: Date.now(),
            popup: !Settings.dnd
        }

        root.unread++
        root.pushHistory(entry)

        if (Settings.dnd)
            return

        root.notifications = [...root.notifications, entry]
        root.notificationAdded(entry)

        let timer = Qt.createQmlObject('import QtQuick 2.0; Timer {}',
            root, "localNotifTimer_" + entry.notificationId)
        timer.interval = 5000
        timer.triggered.connect(() => {
            root.dismissNotification(entry.notificationId)
            timer.destroy()
        })
        timer.start()
    }

    // === bluetooth: уведомления о подключении/отключении ===
    // устройства опрашиваются раз в полторы секунды; состояния
    // запоминаются, чтобы не шуметь при старте и не повторяться
    property var btStates: ({})

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: root.syncBt()
    }

    function syncBt() {
        const adapter = Bluetooth.defaultAdapter

        if (!adapter || !adapter.devices) {
            if (Object.keys(root.btStates).length > 0)
                root.btStates = {}
            return
        }

        const devs = adapter.devices.values || []
        const cur = {}

        for (let i = 0; i < devs.length; i++) {
            const d = devs[i]

            if (!d)
                continue

            const connected = d.connected
                || d.state === BluetoothDeviceState.Connected
            cur[d.address] = connected

            // впервые видим — без уведомления (шум при старте)
            if (root.btStates[d.address] === undefined)
                continue

            if (connected !== root.btStates[d.address])
                root.notify("Bluetooth",
                    d.name !== "" ? d.name : d.address,
                    connected ? "Connected" : "Disconnected")
        }

        root.btStates = cur
    }
}
