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

    readonly property Timer expiry: Timer {
        onTriggered: root.dismiss()
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

    function present(notification: var): void {
        root.history = [notification].concat(root.history).slice(0, root.historyLimit)

        // Critical notifications ignore do-not-disturb.
        const isCritical = notification.urgency === NotificationUrgency.Critical
        if (root.doNotDisturb && !isCritical)
            return

        // Newest wins, except over a critical one. The newcomer is still
        // recorded.
        if (root.critical && !isCritical)
            return

        root.current = notification

        const timeout = root.timeoutFor(notification)
        root.expiry.stop()
        if (timeout > 0) {
            root.expiry.interval = timeout
            root.expiry.start()
        }

        root.arrived(notification)
    }

    // Takes it off the island without telling the application it was acted on.
    function dismiss(): void {
        root.expiry.stop()
        root.current = null
    }

    // The user closed it deliberately, so the application is told.
    function close(): void {
        if (root.current)
            root.current.dismiss()
        root.dismiss()
    }

    function clearHistory(): void {
        root.history = []
    }

    function remove(notification: var): void {
        root.history = root.history.filter(entry => entry !== notification)
        if (root.current === notification)
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
