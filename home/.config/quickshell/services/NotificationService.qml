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
import Quickshell.Io
import Quickshell.Services.Notifications

import "../theme"

// Owns org.freedesktop.Notifications. If another daemon holds the name, the
// server stays unregistered and takes over by itself once it is released.
//
// Only capabilities the island actually renders are declared; claiming more
// makes applications send content that gets dropped.
Singleton {
    id: root

    signal arrived(var notification)

    // Every notification that comes in, shown or not, by the program's name.
    signal received(string appName)

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

        // Buttons on the island, and a history kept on disk.
        actionsSupported: true
        persistenceSupported: true

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
    //
    // `live` is false for an entry read back from disk: notification ids start
    // again at every login, so only a live entry may be matched to an open
    // notification by its id.
    function record(notification: var): var {
        const pixels = notification.image.startsWith("image://qsimage/")
        return {
            id: notification.id,
            live: true,
            time: Date.now(),
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            icon: notification.appIcon || notification.desktopEntry || "",
            image: notification.image,
            urgency: notification.urgency,
            lock: pixels ? root.retainer.createObject(root, { object: notification }) : null
        }
    }

    // A sender's icon: the icon set's picture for it first, by the name it
    // gives, its desktop entry or its own name, so a sender handing in its
    // logo by path, or nothing, still looks like the rest; then that path.
    // "" when there is none.
    function iconOf(named: string, appName: string): string {
        const entry = appName ? DesktopEntries.heuristicLookup(appName) : null
        for (const name of [named, entry?.icon ?? "", appName.toLowerCase()]) {
            if (name === "" || name.includes("/"))
                continue
            const themed = Theme.appIcon(name)
            if (themed !== "")
                return themed
        }
        if (named.startsWith("/"))
            return `file://${named}`
        if (named.includes("://"))
            return named
        return ""
    }

    // For a sender with no icon of its own: the icon set's notifications
    // icon, or its alert for a critical one.
    function standIn(critical: bool): string {
        return Theme.appIcon(critical ? "com.github.timecraft.notifier" : "cs-notifications")
    }

    // The open notification behind a history entry, while it is still open.
    function openOf(entry: var): var {
        if (!entry || !entry.live)
            return null
        return root.server.trackedNotifications.values.find(n => n.id === entry.id) ?? null
    }

    // ── ACTIONS ─────────────────────────────────────────────────────────────
    //
    // `default` is what clicking the notification does; the rest are its
    // buttons. Invoking one closes the notification unless it is resident.
    function defaultAction(notification: var): var {
        if (!notification)
            return null
        return Array.from(notification.actions)
            .find(action => action.identifier === "default") ?? null
    }

    function buttonsOf(notification: var): var {
        if (!notification)
            return []
        return Array.from(notification.actions)
            .filter(action => action.identifier !== "default" && action.text !== "")
    }

    function invoke(action: var): void {
        if (action)
            action.invoke()
        root.dismiss()
    }

    // An entry in the history, clicked: its notification's default action,
    // while the notification is still open.
    function open(entry: var): bool {
        const action = root.defaultAction(root.openOf(entry))
        if (!action)
            return false
        action.invoke()
        return true
    }

    // ── ON THE ISLAND ───────────────────────────────────────────────────────
    //
    // One row, as an incoming call is on a phone's island: the picture, the
    // text, and up to two short buttons at the end. More buttons, or longer
    // ones, would crowd the text out, so they go under it as a row that
    // shares the width. Sizes are declared, since the island takes its shape
    // before the layer exists.
    readonly property int toastPadding: 12
    // The row: a picture of `toastPicture`, beside a title and up to two
    // lines of body, which is what sets its height.
    readonly property int toastRow: 54
    readonly property int toastPicture: 48
    readonly property int stackedRow: 40

    // One width whatever it says, as a phone's island keeps one expanded
    // shape: the row is laid out inside it, with the app and the time at the
    // far end of the title so a short alert is not text and then nothing.
    readonly property int toastWidth: 400

    readonly property int textGap: 12
    readonly property int buttonGap: 8
    readonly property int buttonPad: 26
    readonly property int buttonHeight: 42

    // Labels short enough, together, to sit beside the text.
    readonly property int inlineLetters: 20

    function inlineButtons(notification: var): bool {
        const buttons = root.buttonsOf(notification)
        return buttons.length <= 2
            && buttons.reduce((sum, action) => sum + action.text.length, 0) <= root.inlineLetters
    }

    readonly property int toastHeight: 2 * root.toastPadding + root.toastRow
        + (root.inlineButtons(root.current) ? 0 : root.stackedRow)

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
            const open = root.openOf(entry)
            if (open) {
                if (dismissed)
                    open.dismiss()
                else
                    open.expire()
            }
        }
        root.history = next
        root.save()
    }

    // The rule for an application (`SettingsService.notificationRules`):
    // "mute" closes it unseen, "silent" keeps it without showing it, "popup"
    // shows it without keeping it; "" is the default.
    function ruleFor(app: string): string {
        const rules = SettingsService.notificationRules ?? ({})
        return rules[app] ?? ""
    }

    function present(notification: var): void {
        const rule = root.ruleFor(notification.appName ?? "")
        if (rule === "mute") {
            notification.dismiss()
            return
        }
        root.received(notification.appName ?? "")

        // A transient notification asks not to be kept.
        if (!notification.transient && rule !== "popup") {
            root.keep([root.record(notification)]
                .concat(root.history)
                .slice(0, root.historyLimit), false)
        }
        root.expireLater(notification)

        // Critical notifications ignore do-not-disturb.
        const isCritical = notification.urgency === NotificationUrgency.Critical
        if (rule === "silent" || (root.doNotDisturb && !isCritical))
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

    // ── ON DISK ─────────────────────────────────────────────────────────────
    //
    // The history outlives the shell, in the state directory and shared by
    // every profile. Pixels sent in a hint live in the notification, so an
    // entry that had them comes back with its app's mark instead.
    readonly property FileView store: FileView {
        path: `${SettingsService.stateDirectory}/notifications.json`
        watchChanges: false

        onLoaded: {
            try {
                const kept = JSON.parse(text()).history ?? []
                // Anything already recorded this session goes first.
                root.history = root.history.concat(kept.map(entry => Object.assign({}, entry, {
                    live: false, lock: null
                }))).slice(0, root.historyLimit)
            } catch (error) {
                console.warn("Cannot read the notification history:", error)
            }
            root.restored = true
        }
        onLoadFailed: root.restored = true
    }

    // Nothing is written until the file has been read, or the first
    // notification of a session would replace the history on disk.
    property bool restored: false

    function save(): void {
        if (!root.restored)
            return
        const plain = root.history.map(entry => ({
            id: entry.id,
            time: entry.time ?? 0,
            summary: entry.summary,
            body: entry.body,
            appName: entry.appName,
            icon: entry.icon ?? "",
            image: entry.image.startsWith("image://qsimage/") ? "" : entry.image,
            urgency: entry.urgency
        }))
        root.store.setText(JSON.stringify({ history: plain }))
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
