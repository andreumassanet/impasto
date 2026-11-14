// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   V   O   L   U   M   E       F   A   C   E                              │
// │   the volume as a knob · turned to the level, barred when muted          │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import Quickshell

import "../../../theme"
import "../../../services"
import "../../../components"

Instrument {
    id: face

    line: AudioService.muted ? Tr.t("Muted") : `${AudioService.volume}%`
    reading: AudioService.muted ? Tr.t("Muted") : `${AudioService.volume}%`
    note: AudioService.muted ? `${AudioService.volume}% · ${Tr.t("muted")}` : Tr.t("output")
    tint: AudioService.muted ? face.ink.muted : face.ink.text
    filled: true

    Knob {
        anchors.centerIn: parent
        ink: face.ink
        size: Math.min(parent.width, parent.height)
        fraction: AudioService.volume / 100
        muted: AudioService.muted
    }

    extra: [
        UsageBar {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            progress: AudioService.muted ? 0 : AudioService.volume / 100
            fillColor: face.ink.accent
            trackColor: face.ink.raised
        }
    ]
}
