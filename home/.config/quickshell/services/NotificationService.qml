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
        const time = Date.now()
        return {
            id: notification.id,
            live: true,
            time: time,
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            icon: root.keepPicture(notification.appIcon || notification.desktopEntry || "", `${time}-icon`),
            image: root.keepPicture(notification.image, `${time}-image`),
            urgency: notification.urgency,
            lock: pixels ? root.retainer.createObject(root, { object: notification }) : null
        }
    }

    // ── PICTURES ────────────────────────────────────────────────────────────
    //
    // A sender may hand in its picture as a file it deletes soon after (a
    // browser writes one into a temporary directory for each notification).
    // The island draws it at once, but the history draws it again later, so
    // the history keeps its own copy, made while the file is still there.
    readonly property string pictureDirectory: `${SettingsService.stateDirectory}/notification-pictures`

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.pictureDirectory])

    // The file behind a picture source, "" when it is not a file (an icon
    // name, pixels in a hint).
    function pictureFile(source: string): string {
        for (const prefix of ["image://icon/", "file://", ""]) {
            if (!source.startsWith(prefix))
                continue
            const rest = source.slice(prefix.length)
            return rest.startsWith("/") ? rest : ""
        }
        return ""
    }

    readonly property Component pictureReader: Component {
        FileView {
            blockLoading: true
            printErrors: false
        }
    }

    readonly property Component pictureWriter: Component {
        FileView {
            blockWrites: true
            preload: false
            printErrors: false
        }
    }

    // `source` with its file replaced by a copy in the state directory, named
    // `stem`; `source` itself when there is no file or it cannot be read. The
    // copy is read and written in place, not by a command, which would race
    // the sender deleting the file.
    function keepPicture(source: string, stem: string): string {
        const file = root.pictureFile(source)
        if (file === "" || file.startsWith(`${root.pictureDirectory}/`))
            return source

        const reader = root.pictureReader.createObject(root, { path: file })
        const bytes = reader.data()
        reader.destroy()
        if (!bytes || bytes.byteLength === 0)
            return source

        const extension = /\.[A-Za-z0-9]+$/.test(file) ? file.slice(file.lastIndexOf(".")) : ""
        const copy = `${root.pictureDirectory}/${stem}${extension}`
        const writer = root.pictureWriter.createObject(root, { path: copy })
        writer.setData(bytes)
        writer.destroy()
        return source.replace(file, copy)
    }

    // Removes the copies an entry owns once it leaves the history.
    function forgetPictures(entry: var): void {
        const copies = [entry.icon ?? "", entry.image ?? ""]
            .map(source => root.pictureFile(source))
            .filter(file => file.startsWith(`${root.pictureDirectory}/`))
        if (copies.length > 0)
            Quickshell.execDetached(["rm", "-f", ...copies])
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
        return root.ownPicture(named)
    }

    // A browser's notification gives its own logo, and the site it speaks for
    // only as the first line of the body (`web.whatsapp.com`). The icon set's
    // picture of that site, by its host, then by the host without its leading
    // labels (`whatsapp.com`), then by its name alone (`whatsapp`); "" when the
    // first line is not a host or the set has none.
    function siteIcon(body: string): string {
        const host = (body ?? "").split("\n")[0].trim().toLowerCase()
        if (!/^([a-z0-9-]+\.)+[a-z]{2,}$/.test(host))
            return ""
        const labels = host.split(".")
        const names = labels.slice(0, -1).map((label, first) => labels.slice(first).join("."))
        names.push(labels[labels.length - 2])
        for (const name of names) {
            const themed = Theme.appIcon(name)
            if (themed !== "")
                return themed
        }
        return ""
    }

    // What a sender gave as a file or a URL, as a source; "" for a name.
    function ownPicture(named: string): string {
        if (named.startsWith("/"))
            return `file://${named}`
        return named.includes("://") ? named : ""
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
            root.forgetPictures(entry)
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

    function present(notification: var): void {
        root.received(notification.appName ?? "")

        // A transient notification asks not to be kept.
        if (!notification.transient) {
            root.keep([root.record(notification)]
                .concat(root.history)
                .slice(0, root.historyLimit), false)
        }
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
