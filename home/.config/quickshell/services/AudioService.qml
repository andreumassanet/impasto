// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A U D I O   S E R V I C E                                              │
// │   default sink volume and mute · reactive, via pipewire                  │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

import "../theme"

// Volume state for the default output.
//
// Pipewire pushes changes, so nothing here polls and the OSD reacts on the
// same frame the key is pressed. A sink has to be bound through a tracker
// before its audio properties are readable.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool ready: root.sink !== null && root.sink.ready

    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool sourceReady: root.source !== null && root.source.ready
    readonly property bool sourceMuted: root.sourceReady ? root.source.audio.muted : false
    readonly property string sourceIcon: root.sourceMuted ? "󰍭" : "󰍬"

    // Pipewire reports a 0–1 factor; everything above the service speaks
    // percent.
    readonly property int volume: root.ready ? Math.round(root.sink.audio.volume * 100) : 0
    readonly property bool muted: root.ready ? root.sink.audio.muted : false

    readonly property string icon: {
        if (!root.ready || root.muted)
            return "󰝟"
        if (root.volume === 0)
            return "󰕿"
        return root.volume < 50 ? "󰖀" : "󰕾"
    }

    readonly property int sourceVolume: root.sourceReady
        ? Math.round(root.source.audio.volume * 100) : 0

    // ── OUTPUTS AND APPLICATIONS ────────────────────────────────────────────
    //
    // For the sound panel: every output that can be chosen, and every
    // application playing, each with its own level. Tracked so their
    // properties and levels are bound.
    // The machine's own outputs first, then the digital ones by number.
    readonly property var outputs: Pipewire.nodes.values
        .filter(node => node.isSink && !node.isStream && node.audio)
        .sort((a, b) => {
            const digital = node => /HDMI|DisplayPort/.test(node.description || node.name) ? 1 : 0
            return digital(a) - digital(b)
                || (a.description || a.name).localeCompare(b.description || b.name, undefined,
                                                          { numeric: true })
        })

    readonly property var streams: Pipewire.nodes.values
        .filter(node => node.type === PwNodeType.AudioOutStream && node.audio)

    // Microphones to choose from: sources that are not a sink's monitor.
    readonly property var inputs: Pipewire.nodes.values
        .filter(node => !node.isSink && !node.isStream && node.audio
                && (node.properties?.["media.class"] ?? "") === "Audio/Source")

    // Every capture stream, tracked so its properties arrive.
    readonly property var inStreams: Pipewire.nodes.values.filter(node =>
        node.type === PwNodeType.AudioInStream)

    // Applications recording: capture streams that are not a capture of what
    // plays — the spectrum's cava, a recorder's system sound, a level meter.
    // Only once bound: a stream that has just appeared has no properties
    // yet, and would pass for a microphone until they come.
    readonly property var captures: root.inStreams.filter(node => {
        if (!node.ready)
            return false
        const props = node.properties ?? {}
        return props["stream.capture.sink"] !== "true" && props["stream.monitor"] !== "true"
            && props["application.name"] !== "cava"
    })

    PwObjectTracker {
        objects: [root.sink, root.source].concat(root.outputs).concat(root.streams)
            .concat(root.inputs).concat(root.inStreams)
    }

    // What every output's description starts with, word by word — on most
    // machines the sound card's name, repeated before each of its outputs.
    readonly property string outputPrefix: {
        const names = root.outputs.map(node => (node.description || node.name).split(" "))
        if (names.length < 2)
            return ""
        let shared = 0
        while (names.every(words => shared < words.length - 1 && words[shared] === names[0][shared]))
            shared++
        return names[0].slice(0, shared).join(" ")
    }

    // An output as a person would call it: without the card's name, and a
    // numbered digital output as the port it is.
    function outputName(node: var): string {
        const full = node.description || node.nickname || node.name
        const short = root.outputPrefix !== "" && full.startsWith(root.outputPrefix)
            ? full.slice(root.outputPrefix.length).trim() : full
        return short.replace(/^HDMI \/ DisplayPort (\d+) Output$/, "HDMI $1")
    }

    function choose(node: var): void {
        Pipewire.preferredDefaultAudioSink = node
    }

    function chooseInput(node: var): void {
        Pipewire.preferredDefaultAudioSource = node
    }

    function streamName(node: var): string {
        const props = node.properties ?? {}
        const raw = props["application.name"] || props["application.process.binary"] || node.name
        return raw.charAt(0).toUpperCase() + raw.slice(1)
    }

    // The application's own icon, named by the stream or by its binary.
    function streamIcon(node: var): string {
        const props = node.properties ?? {}
        const named = props["application.icon-name"] || props["application.process.binary"] || ""
        return named !== "" ? Quickshell.iconPath(named.toLowerCase(), true) : ""
    }

    function setStreamVolume(node: var, percent: int): void {
        if (node && node.audio)
            node.audio.volume = Math.max(0, Math.min(100, percent)) / 100
    }

    function toggleStreamMute(node: var): void {
        if (node && node.audio)
            node.audio.muted = !node.audio.muted
    }

    function setSourceVolume(percent: int): void {
        if (root.sourceReady)
            root.source.audio.volume = Math.max(0, Math.min(100, percent)) / 100
    }

    // The rows of the bar's sound card (`VolumeModule`): the two levels, the
    // applications under a heading, and the outputs under one when there is
    // more than one to choose.
    readonly property int cardRows: 2
        + (root.streams.length > 0 ? 1 + root.streams.length : 0)
        + (root.outputs.length > 1 ? 1 + root.outputs.length : 0)

    // ── THE SOUND PANEL'S SIZE ──────────────────────────────────────────────
    //
    // Declared, since the island takes its size before the panel exists: a
    // heading, then titled sections — the level, the applications playing,
    // and the outputs. The microphone's page is the same shape, for the
    // applications recording and the inputs.
    readonly property int panelWidth: 440
    readonly property int panelHeight: 2 * Theme.panelPadding + Theme.detailHeader
        + Theme.detailSection(1)
        + (root.streams.length > 0 ? Theme.detailSection(root.streams.length) : 0)
        + Theme.detailSection(root.outputs.length)
    readonly property int microphoneHeight: 2 * Theme.panelPadding + Theme.detailHeader
        + Theme.detailSection(1)
        + (root.captures.length > 0 ? Theme.detailSection(root.captures.length) : 0)
        + Theme.detailSection(Math.max(1, root.inputs.length))

    function setVolume(percent: int): void {
        if (!root.ready)
            return
        root.sink.audio.volume = Math.max(0, Math.min(100, percent)) / 100
    }

    function toggleMute(): void {
        if (!root.ready)
            return
        root.sink.audio.muted = !root.sink.audio.muted
    }

    function toggleSourceMute(): void {
        if (!root.sourceReady)
            return
        root.source.audio.muted = !root.source.audio.muted
    }
}
