// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S O L I T A I R E                                                      │
// │   klondike, draw one · a click picks up, the next puts down              │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../theme"

// Klondike: seven columns, one card more in each, top cards face up, the rest
// in the stock. The stock deals one card at a time to the waste, and a click
// on an empty stock turns the waste over. No dragging: a click picks up a
// face-up card and everything below it, the next click puts them down (on a
// column one rank higher in the other colour, on an empty column if it is a
// King, or on a foundation if it is a single card next in its suit). Clicking
// a single held card again sends it to a foundation if possible. A face-down
// top card turns over automatically.
//
// The score is the move count, lower is better; dealing from the stock and
// turning the waste count as moves. The round ends when all four foundations
// are complete. A stuck game stays on the table until redealt.
FocusScope {
    id: root

    // ── CONTRACT ────────────────────────────────────────────────────────────

    property int score: 0
    property bool over: false
    property color tint: Theme.accent

    signal finished(int score)

    function restart(): void {
        const deck = []
        for (let suit = 0; suit < 4; suit++)
            for (let rank = 1; rank <= 13; rank++)
                deck.push({ suit: suit, rank: rank, faceUp: false })
        for (let index = deck.length - 1; index > 0; index--) {
            const other = Math.floor(Math.random() * (index + 1))
            const held = deck[index]
            deck[index] = deck[other]
            deck[other] = held
        }
        const dealt = []
        for (let column = 0; column < 7; column++) {
            const pile = deck.splice(0, column + 1)
            pile[column] = root.turned(pile[column])
            dealt.push(pile)
        }
        root.tableau = dealt
        root.stock = deck
        root.waste = []
        root.foundations = [[], [], [], []]
        root.select(-1, -1)
        root.score = 0
        root.over = false
    }

    // ── TABLE ───────────────────────────────────────────────────────────────

    // Pile indices, so one tap handler covers them all: the seven columns, then
    // the waste, the stock and the four foundations.
    readonly property int wastePile: 7
    readonly property int stockPile: 8
    readonly property int foundationPile: 9

    // A card is `{ suit, rank, faceUp }` and a pile is an array, bottom first.
    // Every change reassigns the array.
    property var stock: []
    property var waste: []
    property var foundations: [[], [], [], []]
    property var tableau: [[], [], [], [], [], [], []]

    // The held selection: a pile and the card from which everything below moves
    // with it. Only the waste's top card can be picked up there.
    property int selectedPile: -1
    property int selectedIndex: -1

    readonly property var suitGlyphs: ["♠", "♥", "♦", "♣"]
    readonly property var rankLabels: ["A", "2", "3", "4", "5", "6", "7", "8",
                                       "9", "10", "J", "Q", "K"]

    // Cards are 72×100 at the frame's 760×560 and shrink with the width; every
    // other measurement derives from the card.
    readonly property int margin: 24
    readonly property int street: 26
    readonly property int cardWidth: Math.max(1, Math.floor(Math.min(72,
        (root.width - 2 * root.margin - 6 * root.street) / 7)))
    readonly property int cardHeight: Math.floor(root.cardWidth * 25 / 18)
    readonly property int cardInset: Math.round(root.cardWidth / 12)
    readonly property int pitch: root.cardWidth + root.street
    readonly property int tableLeft: Math.floor((root.width - 7 * root.pitch + root.street) / 2)
    readonly property int topRow: root.margin
    readonly property int tableauTop: root.margin + root.cardHeight + root.margin
    readonly property int downStep: 24
    readonly property int upStep: 26

    // Placeholder for a delegate whose source list is shrinking under it.
    readonly property var nothing: ({ card: { suit: 0, rank: 1, faceUp: false },
                                      pile: -1, index: -1, x: 0, y: 0 })

    focus: true

    Component.onCompleted: root.restart()

    function slotX(column: int): int {
        return root.tableLeft + column * root.pitch
    }

    function turned(card: var): var {
        return { suit: card.suit, rank: card.rank, faceUp: true }
    }

    // The thirteen slots, drawn under the cards so empty piles are still
    // clickable.
    readonly property var slots: {
        const out = [{ pile: root.stockPile, x: root.slotX(0), y: root.topRow },
                     { pile: root.wastePile, x: root.slotX(1), y: root.topRow }]
        for (let slot = 0; slot < 4; slot++)
            out.push({ pile: root.foundationPile + slot, x: root.slotX(3 + slot), y: root.topRow })
        for (let column = 0; column < 7; column++)
            out.push({ pile: column, x: root.slotX(column), y: root.tableauTop })
        return out
    }

    // Every card with its position (only the top card for waste, stock and
    // foundations), so one Repeater draws them all. A column that would
    // overflow tightens its overlap.
    readonly property var placed: {
        const out = []
        const top = (pile, id, x) => {
            if (pile.length > 0)
                out.push({ card: pile[pile.length - 1], pile: id,
                           index: pile.length - 1, x: x, y: root.topRow })
        }
        top(root.stock, root.stockPile, root.slotX(0))
        top(root.waste, root.wastePile, root.slotX(1))
        root.foundations.forEach((pile, slot) =>
            top(pile, root.foundationPile + slot, root.slotX(3 + slot)))
        const room = Math.max(0, root.height - root.tableauTop - root.margin - root.cardHeight)
        root.tableau.forEach((pile, column) => {
            const downs = pile.filter(card => !card.faceUp).length
            const natural = downs * root.downStep
                + Math.max(0, pile.length - downs - 1) * root.upStep
            const squeeze = natural > room ? room / natural : 1
            let y = root.tableauTop
            pile.forEach((card, index) => {
                out.push({ card: card, pile: column, index: index,
                           x: root.slotX(column), y: Math.round(y) })
                y += (card.faceUp ? root.upStep : root.downStep) * squeeze
            })
        })
        return out
    }

    // ── RULES ───────────────────────────────────────────────────────────────

    function isRed(card: var): bool {
        return card.suit === 1 || card.suit === 2
    }

    function select(pile: int, index: int): void {
        root.selectedPile = pile
        root.selectedIndex = index
    }

    function isSelected(pile: int, index: int): bool {
        return pile === root.selectedPile && index >= root.selectedIndex
    }

    function inHand(): var {
        if (root.selectedPile < 0)
            return []
        if (root.selectedPile === root.wastePile)
            return root.waste.slice(-1)
        return root.tableau[root.selectedPile].slice(root.selectedIndex)
    }

    function fitsColumn(cards: var, column: int): bool {
        if (cards.length === 0)
            return false
        const pile = root.tableau[column]
        const head = cards[0]
        if (pile.length === 0)
            return head.rank === 13
        const top = pile[pile.length - 1]
        return top.faceUp && root.isRed(top) !== root.isRed(head) && top.rank === head.rank + 1
    }

    function fitsFoundation(cards: var, slot: int): bool {
        if (cards.length !== 1)
            return false
        const pile = root.foundations[slot]
        if (pile.length === 0)
            return cards[0].rank === 1
        const top = pile[pile.length - 1]
        return top.suit === cards[0].suit && top.rank === cards[0].rank - 1
    }

    // Removes the held cards from their pile, turning over the card left on top
    // if it is face down, and returns them.
    function lift(): var {
        const cards = root.inHand()
        if (root.selectedPile === root.wastePile) {
            root.waste = root.waste.slice(0, -1)
        } else {
            const column = root.selectedPile
            let rest = root.tableau[column].slice(0, root.selectedIndex)
            const last = rest.length - 1
            if (last >= 0 && !rest[last].faceUp)
                rest = rest.slice(0, last).concat([root.turned(rest[last])])
            root.tableau = root.tableau.map((pile, index) => index === column ? rest : pile)
        }
        return cards
    }

    // Places cards on a column or foundation, counts the move, and ends the
    // round if it completed the foundations.
    function drop(cards: var, pile: int): void {
        if (pile >= root.foundationPile) {
            const slot = pile - root.foundationPile
            root.foundations = root.foundations.map((stack, index) =>
                index === slot ? stack.concat(cards) : stack)
        } else {
            root.tableau = root.tableau.map((stack, index) =>
                index === pile ? stack.concat(cards) : stack)
        }
        root.score += 1
        root.select(-1, -1)
        if (root.foundations.every(stack => stack.length === 13)) {
            root.over = true
            root.finished(root.score)
        }
    }

    function sendHome(): void {
        const cards = root.inHand()
        for (let slot = 0; slot < 4; slot++) {
            if (root.fitsFoundation(cards, slot)) {
                root.drop(root.lift(), root.foundationPile + slot)
                return
            }
        }
    }

    // Deals one card from the stock, or turns the waste over when the stock is
    // empty.
    function turnStock(): void {
        if (root.over)
            return
        root.select(-1, -1)
        if (root.stock.length > 0) {
            const top = root.stock[root.stock.length - 1]
            root.stock = root.stock.slice(0, -1)
            root.waste = root.waste.concat([root.turned(top)])
        } else if (root.waste.length > 0) {
            root.stock = root.waste.map(card =>
                ({ suit: card.suit, rank: card.rank, faceUp: false })).reverse()
            root.waste = []
        } else {
            return
        }
        root.score += 1
    }

    // All table clicks land here (`index` -1 for an empty pile). A valid
    // destination takes the held cards; otherwise a pickable card is picked up;
    // otherwise the selection is cleared.
    function tap(pile: int, index: int): void {
        if (root.over)
            return
        if (pile === root.stockPile) {
            root.turnStock()
            return
        }
        const held = root.inHand()
        if (pile === root.selectedPile && index === root.selectedIndex) {
            // A single held card clicked again goes to a foundation if it can.
            if (held.length === 1)
                root.sendHome()
            return
        }
        if (pile >= root.foundationPile) {
            if (root.fitsFoundation(held, pile - root.foundationPile))
                root.drop(root.lift(), pile)
            return
        }
        if (pile === root.wastePile) {
            root.select(index >= 0 ? pile : -1, index)
            return
        }
        if (root.fitsColumn(held, pile)) {
            root.drop(root.lift(), pile)
            return
        }
        const card = index >= 0 ? root.tableau[pile][index] : null
        if (card && card.faceUp)
            root.select(pile, index)
        else
            root.select(-1, -1)
    }

    Keys.onPressed: event => {
        if (event.key !== Qt.Key_Space)
            return
        root.turnStock()
        event.accepted = true
    }

    // ── TABLE BACKGROUND ────────────────────────────────────────────────────

    Rectangle {
        id: ground

        anchors.centerIn: parent
        width: root.width
        height: root.height
        radius: Theme.radiusMedium
        color: Theme.islandSurface
        border.color: Theme.islandBorder
        border.width: 1

        Repeater {
            model: root.slots.length

            Rectangle {
                id: slot

                required property int index
                readonly property var entry: root.slots[index]

                x: entry.x
                y: entry.y
                width: root.cardWidth
                height: root.cardHeight
                radius: Theme.radiusSmall
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
                border.color: Theme.hairline
                border.width: 1

                // A ring on the empty stock, where the waste turns over.
                Rectangle {
                    anchors.centerIn: parent
                    visible: slot.entry.pile === root.stockPile
                    width: Math.round(root.cardWidth / 3)
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: Theme.textMuted
                    border.width: 2
                    opacity: 0.5
                }

                // An ace marker on each foundation.
                Text {
                    anchors.centerIn: parent
                    visible: slot.entry.pile >= root.foundationPile
                    text: root.rankLabels[0]
                    color: Theme.textMuted
                    opacity: 0.5
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.tap(slot.entry.pile, -1)
                }
            }
        }

        // Cards in placement order, so a column's top card draws last.
        Repeater {
            model: root.placed.length

            Item {
                id: card

                required property int index
                readonly property var entry: root.placed[index] ?? root.nothing
                readonly property var face: entry.card
                readonly property bool selected: root.isSelected(entry.pile, entry.index)
                readonly property color ink: root.isRed(face) ? Theme.red : Theme.island

                x: entry.x
                y: entry.y
                width: root.cardWidth
                height: root.cardHeight

                // What the card casts on the one under it: overlapping cards
                // are a stack rather than a printed column.
                Rectangle {
                    x: 1
                    y: 3
                    width: parent.width
                    height: parent.height
                    radius: Theme.radiusSmall
                    color: Qt.rgba(0, 0, 0, 0.45)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusSmall
                    // Card faces are white in every palette: `scrimText` is the
                    // fixed white, and a light palette's dark `text` would make
                    // dark cards.
                    color: card.face.faceUp ? Theme.scrimText : root.tint
                    border.width: card.selected ? 2 : 1
                    border.color: card.selected ? Theme.accent
                        : card.face.faceUp
                            ? Qt.rgba(Theme.island.r, Theme.island.g, Theme.island.b, 0.35)
                            : Theme.islandBorder

                    // Card back: the tint with a faint inner frame and a
                    // lattice of diamonds in it.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.cardInset
                        visible: !card.face.faceUp
                        radius: Math.max(2, Theme.radiusSmall - root.cardInset / 2)
                        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.14)
                        clip: true

                        Grid {
                            anchors.centerIn: parent
                            columns: 3
                            spacing: Math.round(root.cardWidth * 0.14)

                            Repeater {
                                model: 12

                                Rectangle {
                                    width: Math.round(root.cardWidth * 0.12)
                                    height: width
                                    rotation: 45
                                    opacity: 0.35
                                    color: Qt.rgba(Theme.text.r, Theme.text.g,
                                                   Theme.text.b, 0.3)
                                }
                            }
                        }
                    }

                    // The light across the face.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.14) }
                            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
                        }
                    }

                    // Rank and suit in the corner, visible under the overlap.
                    Text {
                        x: root.cardInset
                        y: Math.round(root.cardInset / 2)
                        visible: card.face.faceUp
                        text: root.rankLabels[card.face.rank - 1] + root.suitGlyphs[card.face.suit]
                        color: card.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: card.face.faceUp
                        text: root.suitGlyphs[card.face.suit]
                        color: card.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(root.cardHeight / 3)
                        opacity: 0.9
                    }

                    // The same corner upside down in the other one, the way a
                    // card is printed. Only the bottom of a card shows when
                    // nothing is on it.
                    Text {
                        x: parent.width - width - root.cardInset
                        y: parent.height - height - Math.round(root.cardInset / 2)
                        visible: card.face.faceUp
                        rotation: 180
                        text: root.rankLabels[card.face.rank - 1] + root.suitGlyphs[card.face.suit]
                        color: card.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.tap(card.entry.pile, card.entry.index)
                }
            }
        }
    }
}
