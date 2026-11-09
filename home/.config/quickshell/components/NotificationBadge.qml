// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   N O T I F I C A T I O N   B A D G E                                    │
// │   the mark of the app that sent a notification                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// A small tile for the corner of the sender's picture, so the sender can be
// told from the app that carried it (a person on a web page in a browser):
// the icon set's picture of the site a browser notification speaks for, else
// the sender's own icon when it gave one as a file, else the icon set's
// picture of the app. Place it with `x` and `y`; it hides itself when there
// is nothing to show.
Rectangle {
    id: root

    // What the notification names as its icon: a name, a path or a URL.
    property string icon: ""
    property string appName: ""

    // The notification's body, whose first line names the site of a browser's.
    property string body: ""
    property int size: 18

    // Off while the corner has no sender's picture to sit on.
    property bool shown: true

    // A file that is gone, as a browser's temporary one is once it has been
    // read, falls back to the icon set's picture.
    property bool ownGone: false

    readonly property string own: NotificationService.ownPicture(root.icon)
    readonly property string site: NotificationService.siteIcon(root.body)

    visible: root.shown && mark.status === Image.Ready
    width: root.size
    height: root.size
    radius: root.size * 0.28
    color: Theme.island

    Image {
        id: mark

        anchors.centerIn: parent
        width: parent.width * 0.78
        height: width
        source: root.site !== "" ? root.site
            : root.own !== "" && !root.ownGone ? root.own
            : NotificationService.iconOf(root.icon, root.appName)
        asynchronous: true
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2

        onStatusChanged: {
            if (status === Image.Error && root.own !== "")
                root.ownGone = true
        }
    }
}
