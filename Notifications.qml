pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root
    
    property list<var> notifications: []
    property int unread: 0
    
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
}
