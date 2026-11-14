// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   T R A Y   I C O N                                                      │
// │   a tray item's icon · in grey, drawn for a dark bar                     │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Effects

// An item names its icon, and the shell's icon theme draws named panel icons
// dark, for a light bar. Papirus-Dark carries tray icons of its own, light
// ones, so a named icon is looked up there first and the item's own is the
// fallback. Either way it is drawn in grey: the drawing inside an icon
// survives, which a flat silhouette of a round icon would not.
Item {
    id: root

    // `SystemTrayItem.icon`: `image://icon/<name>` or a picture the item sent.
    property string icon: ""

    readonly property string named: {
        const found = /^image:\/\/icon\/([^?]+)/.exec(root.icon)
        return found ? found[1] : ""
    }

    readonly property string panelIcon: root.named !== ""
        ? `file:///usr/share/icons/Papirus-Dark/22x22/panel/${root.named}.svg` : ""

    // Two pictures rather than one that switches its own source on an error,
    // which loops when an item such as nm-applet changes its icon every few
    // seconds. The item's own icon shows while the themed one is missing or
    // still loading.
    Image {
        id: themed

        anchors.fill: parent
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
        source: root.panelIcon
        visible: false
    }

    Image {
        id: own

        anchors.fill: parent
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
        source: themed.status === Image.Ready ? "" : root.icon
        visible: false
    }

    readonly property Item picture: themed.status === Image.Ready ? themed : own

    MultiEffect {
        anchors.fill: parent
        source: root.picture
        saturation: -1
        brightness: 0.1
    }
}
