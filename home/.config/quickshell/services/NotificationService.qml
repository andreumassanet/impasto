// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   S E R V I C E                                │
// │   the shell is the notification daemon                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Owns org.freedesktop.Notifications. If another daemon holds the name, the
// server stays unregistered and takes over by itself once it is released.
//
// Only capabilities the island actually renders are declared; claiming more
// makes applications send content that gets dropped.
Singleton {
    id: root

    signal arrived(var notification)

    // For notifications that do not set their own timeout.
    readonly property int defaultTimeout: SettingsService.notificationTimeout

    property var current: null
    property var history: []
    readonly property int historyLimit: 50

    readonly property bool active: root.current !== null
    readonly property bool critical: root.active
        && root.current.urgency === NotificationUrgency.Critical

    readonly property NotificationServer server: NotificationServer {
        id: server

        // Survives a config reload, so editing the shell does not drop a
        // notification that is on screen.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true

        // Not yet rendered anywhere, so not claimed. Declaring these would
        // make applications send buttons and a history the island discards.
        actionsSupported: false
        persistenceSupported: false

        onNotification: notification => {
            // Tracking keeps the object alive past this handler; without it
            // the notification is destroyed as soon as the signal returns.
            notification.tracked = true
            root.present(notification)
        }
    }

    // Each notification expires on its own clock from arrival, shown or not:
    // one nobody closes would otherwise stay alive for the whole session.
    // Expiring it closes it, so the island lets go through `closing` below.
    readonly property Component lifetime: Component {
        Timer {
            running: true
        }
    }

    function expireLater(notification: var): void {
        const timeout = root.timeoutFor(notification)
        if (timeout <= 0)
            return
        const timer = root.lifetime.createObject(root, { interval: timeout })
        const done = () => {
            if (timer)
                timer.destroy()
        }
        timer.triggered.connect(() => {
            if (notification)
                notification.expire()
            done()
        })
        notification.closed.connect(done)
        // An application that updates its notification in place (a progress
        // bar, a volume) starts its clock again.
        const again = () => {
            if (timer)
                timer.restart()
        }
        notification.summaryChanged.connect(again)
        notification.bodyChanged.connect(again)
    }

    // An application can close its own notification while the island is
    // showing it, and the object goes with it.
    readonly property Connections closing: Connections {
        target: root.current
        function onClosed(reason: int): void {
            root.dismiss()
        }
    }

    function timeoutFor(notification: var): int {
        // Critical urgency waits for the user. Anything else that asks to stay
        // forever is capped, or a misbehaving application owns the island.
        if (notification.urgency === NotificationUrgency.Critical)
            return 0
        if (notification.expireTimeout > 0)
            return Math.min(notification.expireTimeout, 15000)
        return root.defaultTimeout
    }

    // Closing a notification destroys the object, so the history keeps a copy
    // of what the list draws rather than the notification itself. Pixels sent
    // in a hint are served by that object, so an entry carrying them keeps it
    // alive with a lock until the entry leaves the history.
    function record(notification: var): var {
        const pixels = notification.image.startsWith("image://qsimage/")
        return {
            id: notification.id,
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            image: notification.image,
            urgency: notification.urgency,
            lock: pixels ? root.retainer.createObject(root, { object: notification }) : null
        }
    }

    readonly property Component retainer: Component {
        RetainableLock {
            locked: true
        }
    }

    // Every change to the history comes through here, so no entry leaves it
    // still holding its notification. One still open is closed with it:
    // dismissed when the user took it away, expired when the limit pushed it
    // out.
    function keep(next: var, dismissed: bool): void {
        for (const entry of root.history) {
            if (next.includes(entry))
                continue
            if (entry.lock)
                entry.lock.destroy()
            const open = root.server.trackedNotifications.values.find(n => n.id === entry.id)
            if (open) {
                if (dismissed)
                    open.dismiss()
                else
                    open.expire()
            }
        }
        root.history = next
    }

    function present(notification: var): void {
        root.keep([root.record(notification)]
            .concat(root.history)
            .slice(0, root.historyLimit), false)
        root.expireLater(notification)

        // Critical notifications ignore do-not-disturb.
        const isCritical = notification.urgency === NotificationUrgency.Critical
        if (root.doNotDisturb && !isCritical)
            return

        // Newest wins, except over a critical one. The newcomer is still
        // recorded.
        if (root.critical && !isCritical)
            return

        root.current = notification
        root.arrived(notification)
    }

    // Takes it off the island without telling the application it was acted on.
    function dismiss(): void {
        root.current = null
    }

    // The user closed it deliberately, so the application is told.
    function close(): void {
        if (root.current)
            root.current.dismiss()
        root.dismiss()
    }

    function clearHistory(): void {
        root.keep([], true)
    }

    function remove(entry: var): void {
        root.keep(root.history.filter(other => other !== entry), true)
        if (root.current && root.current.id === entry.id)
            root.dismiss()
    }

    // Kept in settings so it survives a restart. Notifications are still
    // recorded while it is on; they just do not take the island.
    readonly property bool doNotDisturb: SettingsService.doNotDisturb

    function toggleDoNotDisturb(): void {
        const silence = !root.doNotDisturb
        SettingsService.set("doNotDisturb", silence)
        if (silence)
            root.dismiss()
    }
}
