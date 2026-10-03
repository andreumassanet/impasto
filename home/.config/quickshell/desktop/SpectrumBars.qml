// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S P E C T R U M   B A R S                                              │
// │   sound bars rising from one edge of a box                               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../theme"
import "../services"

// Bars rising from one edge of this box, as many as fit, centred, in one of
// the looks a strip can take (`DesktopService.spectrumOf`).
//
// One shader draws every bar (`spectrum.frag`), rather than a scene graph
// node per bar on every one of cava's frames. The bars step with cava's
// frames rather than gliding between them, since a glide redraws at the
// screen's rate instead of cava's.
//
// Listens to cava while `listening`. A `sample` draws a fixed spectrum
// instead, for a tile that has to show a look in silence.
ShaderEffect {
    id: root

    property string edge: "bottom"
    property string style: "rounded"
    property string fillStyle: "fade"
    property color color: Theme.accent
    property color color2: Theme.text
    property real barWidth: Theme.spectrumBar
    property real gap: Theme.spectrumGap
    property real floorLength: Theme.spectrumFloor
    property string lowsAt: "corners"
    property bool peaks: false
    property bool listening: true
    property bool sample: false

    // The shader's uniforms, by the names it reads them.
    readonly property vector2d area: Qt.vector2d(root.width, root.height)
    readonly property real side: root.edge === "left" ? 1 : root.edge === "right" ? 2 : 0
    readonly property real look: Math.max(0,
        DesktopService.spectrumLooks.findIndex(entry => entry.id === root.style))
    readonly property real fill: Math.max(0,
        DesktopService.spectrumFills.findIndex(entry => entry.id === root.fillStyle))
    readonly property real lows: root.lowsAt === "along" ? 1 : 0
    readonly property real peaksOn: root.peaks ? 1 : 0
    readonly property real pitch: root.barWidth + root.gap
    readonly property real curve: Theme.spectrumCurve
    readonly property real base: Theme.spectrumBase
    readonly property real tip: Theme.spectrumTip

    // Strong lows, a bump in the middle, falling highs, with a little
    // unevenness so neighbours differ.
    readonly property var still: Array.from({ length: CavaService.bandCount }, (_, index) => {
        const x = index / (CavaService.bandCount - 1)
        const shape = 0.85 * Math.exp(-Math.pow((x - 0.06) / 0.14, 2))
            + 0.5 * Math.exp(-Math.pow((x - 0.4) / 0.16, 2)) + 0.12
        return Math.min(1, shape * (0.75 + 0.25 * Math.sin(index * 2.3)))
    })

    readonly property var levels: root.sample ? root.still : CavaService.bands
    readonly property var highs: root.sample ? root.still.map(value => Math.min(1, value + 0.12))
        : root.peaks ? CavaService.peaks : root.nothing
    readonly property var nothing: new Array(CavaService.bandCount).fill(0)

    // Four bands a uniform.
    function four(list: var, first: int): vector4d {
        return Qt.vector4d(list[first], list[first + 1], list[first + 2], list[first + 3])
    }

    readonly property vector4d b0: root.four(root.levels, 0)
    readonly property vector4d b1: root.four(root.levels, 4)
    readonly property vector4d b2: root.four(root.levels, 8)
    readonly property vector4d b3: root.four(root.levels, 12)
    readonly property vector4d b4: root.four(root.levels, 16)
    readonly property vector4d b5: root.four(root.levels, 20)
    readonly property vector4d b6: root.four(root.levels, 24)
    readonly property vector4d b7: root.four(root.levels, 28)
    readonly property vector4d b8: root.four(root.levels, 32)
    readonly property vector4d b9: root.four(root.levels, 36)
    readonly property vector4d b10: root.four(root.levels, 40)
    readonly property vector4d b11: root.four(root.levels, 44)
    readonly property vector4d b12: root.four(root.levels, 48)
    readonly property vector4d b13: root.four(root.levels, 52)
    readonly property vector4d b14: root.four(root.levels, 56)
    readonly property vector4d b15: root.four(root.levels, 60)

    readonly property vector4d p0: root.four(root.highs, 0)
    readonly property vector4d p1: root.four(root.highs, 4)
    readonly property vector4d p2: root.four(root.highs, 8)
    readonly property vector4d p3: root.four(root.highs, 12)
    readonly property vector4d p4: root.four(root.highs, 16)
    readonly property vector4d p5: root.four(root.highs, 20)
    readonly property vector4d p6: root.four(root.highs, 24)
    readonly property vector4d p7: root.four(root.highs, 28)
    readonly property vector4d p8: root.four(root.highs, 32)
    readonly property vector4d p9: root.four(root.highs, 36)
    readonly property vector4d p10: root.four(root.highs, 40)
    readonly property vector4d p11: root.four(root.highs, 44)
    readonly property vector4d p12: root.four(root.highs, 48)
    readonly property vector4d p13: root.four(root.highs, 52)
    readonly property vector4d p14: root.four(root.highs, 56)
    readonly property vector4d p15: root.four(root.highs, 60)

    // Resolved here: a bare name resolves against whichever file uses this one.
    // A running shell keeps a shader by its URL across reloads, so a changed
    // shader needs a URL it has not seen: raise `revision` with every
    // recompile.
    readonly property int revision: 3
    fragmentShader: `${Qt.resolvedUrl("spectrum.frag.qsb")}?r=${root.revision}`

    // Subscribed at most once, whatever `listening` does in between.
    property bool subscribed: false

    function listen(on: bool): void {
        if (on === root.subscribed)
            return
        root.subscribed = on
        if (on)
            CavaService.subscribe()
        else
            CavaService.release()
    }

    readonly property bool hearing: root.listening && !root.sample

    onHearingChanged: root.listen(root.hearing)
    Component.onCompleted: root.listen(root.hearing)
    Component.onDestruction: root.listen(false)
}
