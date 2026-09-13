// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   D E C K   S E R V I C E                                                │
// │   edge notes · tab positions and contents                                │
// │   hand                                                                   │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell

import "../theme"

// Geometry and pointer state for the note decks on the screen edges.
//
// `DesktopService` stores which notes sit on which edge; this turns them into
// the boxes the surface draws and cuts its input mask from, so drawing, mask
// and drop targets agree in the same frame. Tabs run top to bottom on the
// sides and left to right along the bottom.
Singleton {
    id: root

    // The decks with their notes resolved, for the surface to repeat over.
    readonly property var decks: DesktopService.shownDecks.map(deck => ({
        key: deck.key,
        edge: deck.edge,
        along: DesktopService.alongOf(deck),
        notes: DesktopService.deckNotes(deck)
            .map(key => NotesService.entry(key))
            .filter(note => note !== null)
    }))

    readonly property int count: root.decks.reduce((sum, deck) => sum + deck.notes.length, 0)

    // Hidden under a fullscreen window, as the dock is.
    readonly property bool covered: HyprlandService.clients.some(
        client => (client.fullscreen ?? 0) >= 2
            && client.workspace && client.workspace.id === HyprlandService.activeId)

    // With `deckOnEmpty`, also hidden on any workspace that has windows.
    readonly property bool onEmptyOnly: SettingsService.deckOnEmpty
    readonly property bool workspaceEmpty:
        HyprlandService.occupiedIds.indexOf(HyprlandService.activeId) < 0
    readonly property bool away: root.covered || (root.onEmptyOnly && !root.workspaceEmpty)

    // ── GEOMETRY ────────────────────────────────────────────────────────────
    //
    // At rest each note is a sliver on the edge; on hover the tabs extend to
    // `tabDepth` and the hovered note slides out beside its tab.
    readonly property int sliver: 5
    readonly property int tabDepth: 26
    readonly property int tabLength: 112
    readonly property int tabGap: 8
    readonly property int peekWidth: 250
    readonly property int peekHeight: 200

    readonly property int margin: Theme.desktopGutter

    // Distance from an edge that still counts as a drop onto it.
    readonly property int reach: 72

    // Handle for sliding a deck along its edge while arranging.
    readonly property int grip: 24

    function vertical(edge: string): bool {
        return edge !== "bottom"
    }

    function stripLength(count: int): real {
        return Math.max(0, count * (root.tabLength + root.tabGap) - root.tabGap)
    }

    // Free travel along the edge: its length minus the strip and both margins.
    function runOf(edge: string, count: int, width: real, height: real): real {
        const length = edge === "bottom" ? width : height
        return Math.max(0, length - root.stripLength(count) - 2 * root.margin)
    }

    // `along` is a 0–1 fraction of the run, so a deck keeps its relative
    // position across screen sizes.
    function startOf(edge: string, count: int, along: real, width: real, height: real): real {
        return root.margin + Math.max(0, Math.min(1, along)) * root.runOf(edge, count, width, height)
    }

    // Inverse of `startOf`.
    function alongAt(edge: string, count: int, start: real, width: real, height: real): real {
        const run = root.runOf(edge, count, width, height)
        return run <= 0 ? 0 : Math.max(0, Math.min(1, (start - root.margin) / run))
    }

    function tabAt(start: real, index: int): real {
        return start + index * (root.tabLength + root.tabGap)
    }

    // A tab's box at the current reveal depth.
    function tabBox(edge: string, index: int, start: real, depth: real, width: real, height: real): var {
        if (edge === "bottom")
            return { x: root.tabAt(start, index), y: height - depth, width: root.tabLength, height: depth }
        return {
            x: edge === "right" ? width - depth : 0,
            y: root.tabAt(start, index), width: depth, height: root.tabLength
        }
    }

    // The whole deck at full depth; used for the input mask and the inspector.
    function stripBox(edge: string, count: int, start: real, width: real, height: real): var {
        const length = root.stripLength(count)
        if (edge === "bottom")
            return { x: start, y: height - root.tabDepth, width: length, height: root.tabDepth }
        return {
            x: edge === "right" ? width - root.tabDepth : 0,
            y: start, width: root.tabDepth, height: length
        }
    }

    // Just before the first tab, centred on the depth.
    function gripBox(edge: string, start: real, width: real, height: real): var {
        const before = start - root.grip / 2 - 4
        if (edge === "bottom")
            return { x: before, y: height - root.tabDepth / 2 - root.grip / 2, width: root.grip, height: root.grip }
        return {
            x: edge === "right" ? width - root.tabDepth / 2 - root.grip / 2 : root.tabDepth / 2 - root.grip / 2,
            y: before, width: root.grip, height: root.grip
        }
    }

    // The peeked note, beside its tab and clamped to the screen.
    function peekBox(edge: string, index: int, start: real, width: real, height: real): var {
        const gap = 6
        if (edge === "bottom") {
            const x = root.tabAt(start, index) + root.tabLength / 2 - root.peekWidth / 2
            return {
                x: Math.max(root.margin, Math.min(width - root.margin - root.peekWidth, x)),
                y: height - root.tabDepth - gap - root.peekHeight,
                width: root.peekWidth, height: root.peekHeight
            }
        }
        const y = root.tabAt(start, index)
        return {
            x: edge === "right" ? width - root.tabDepth - gap - root.peekWidth : root.tabDepth + gap,
            y: Math.max(root.margin, Math.min(height - root.margin - root.peekHeight, y)),
            width: root.peekWidth, height: root.peekHeight
        }
    }

    // The edge a point is against, or "". Sides take precedence in corners.
    function edgeAt(x: real, y: real, width: real, height: real): string {
        if (x <= root.reach)
            return "left"
        if (x >= width - root.reach)
            return "right"
        if (y >= height - root.reach)
            return "bottom"
        return ""
    }

    // Drop index for a point. The point is the dragged tab's centre, so it is
    // compared against tab centres; a tab dropped in place keeps its index.
    function indexAt(edge: string, x: real, y: real, count: int, start: real): int {
        const position = edge === "bottom" ? x : y
        return Math.max(0, Math.min(count,
            Math.round((position - start - root.tabLength / 2) / (root.tabLength + root.tabGap))))
    }

    // ── POINTER STATE ───────────────────────────────────────────────────────

    property bool revealed: false

    // Note whose tab is hovered, or "".
    property string peeked: ""

    // Note being dragged while arranging.
    property string dragging: ""

    // Deck whose grip is being dragged.
    property string sliding: ""

    // Tab or grip under a pressed button, set on press before any drag
    // starts so the surface can widen its input region (see `Deck`).
    property string held: ""

    // Edge that would receive the widget or tray tile currently being dragged
    // from the desktop, or "". Set by the desktop, drawn by the deck.
    property string receiving: ""

    // The edges' window, published by `Deck` for the desktop's focus grab.
    property var surface: null
}
