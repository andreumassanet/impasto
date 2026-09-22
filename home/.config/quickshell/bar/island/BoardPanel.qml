// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   B O A R D   P A N E L                                                  │
// │   task board · three lanes and the task editor                           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The tasks as a kanban: to do, doing, done, with a card per task dragged
// between and within lanes, and New at the top of the first lane. Opening a
// card fills the panel with the task: its line, notes, day and lane.
//
// Opens with the keyboard ring on New. A task closed without a line is
// discarded. Arrows move between cards, Enter opens one, Space moves it a lane
// along; Escape goes from the task to the board, then closes.
FocusScope {
    id: root

    signal closed()

    readonly property string opened: TasksService.opened
    readonly property var task: TasksService.entry(root.opened)

    readonly property int gap: 12

    // Laid out at the declared size from the first frame, whatever size the
    // island is animating through.
    readonly property int roomWidth: TasksService.panelWidth - 2 * Theme.panelPadding
    readonly property int roomHeight: TasksService.panelHeight - 2 * Theme.panelPadding

    Component.onCompleted: root.forceActiveFocus()
    Component.onDestruction: TasksService.leave()

    // Escape returns to the board when the task was opened there, and closes
    // the island when it came from the calendar.
    Keys.onEscapePressed: event => {
        if (root.opened === "" || TasksService.direct) {
            event.accepted = false
            return
        }
        TasksService.leave()
    }

    function back(): void {
        if (TasksService.direct)
            root.closed()
        else
            TasksService.leave()
    }

    Loader {
        focus: true
        sourceComponent: root.opened === "" ? board : editor
    }

    // ── BOARD ───────────────────────────────────────────────────────────────

    Component {
        id: board

        ColumnLayout {
            id: page

            width: root.roomWidth
            height: root.roomHeight

            // Where the keyboard's ring is: a lane and a card in it. Index
            // -1 in the first lane is New.
            property int cursorLane: 0
            property int cursorIndex: -1

            // What is being dragged, and where it would land.
            property string dragging: ""
            property int dropLane: -1
            property int dropIndex: -1

            // The lanes' lists by index, filled as the lanes are built, so a
            // drop can be placed in one.
            property var lists: ({})

            spacing: 12

            Component.onCompleted: lanes.forceActiveFocus()

            function laneCards(lane: int): var {
                const state = TasksService.states[lane]
                return state ? TasksService.inState(state.id) : []
            }

            function cardUnderCursor(): var {
                return page.laneCards(page.cursorLane)[page.cursorIndex] ?? null
            }

            function lowest(lane: int): int {
                return lane === 0 ? -1 : 0
            }

            function walkLane(delta: int): void {
                const lane = Math.max(0, Math.min(TasksService.states.length - 1, page.cursorLane + delta))
                page.cursorLane = lane
                page.cursorIndex = Math.max(page.lowest(lane),
                    Math.min(page.laneCards(lane).length - 1, page.cursorIndex))
            }

            function walkCard(delta: int): void {
                const count = page.laneCards(page.cursorLane).length
                page.cursorIndex = Math.max(page.lowest(page.cursorLane),
                    Math.min(count - 1, page.cursorIndex + delta))
            }

            function openCurrent(): void {
                if (page.cursorLane === 0 && page.cursorIndex === -1) {
                    TasksService.create(true)
                    return
                }
                const card = page.cardUnderCursor()
                if (card)
                    TasksService.open(card.key, true)
            }

            // ── DRAGGING ────────────────────────────────────────────────

            function aim(scene: point): void {
                const point = lanes.mapFromItem(null, scene.x, scene.y)
                const lane = Math.max(0, Math.min(TasksService.states.length - 1,
                    Math.floor(point.x / (lanes.laneWidth + root.gap))))
                const list = page.lists[lane]
                let index = page.laneCards(lane).length
                if (list) {
                    const local = list.mapFromItem(lanes, point.x, point.y)
                    const under = list.indexAt(local.x, local.y + list.contentY)
                    if (under >= 0)
                        index = under
                    else if (local.y < 0)
                        index = 0
                }
                page.dropLane = lane
                page.dropIndex = index
                ghost.x = point.x - ghost.width / 2
                ghost.y = point.y - 24
            }

            function drop(): void {
                const key = page.dragging
                const lane = page.dropLane
                const index = page.dropIndex
                page.dragging = ""
                page.dropLane = -1
                page.dropIndex = -1
                const state = TasksService.states[lane]
                if (key === "" || !state)
                    return
                TasksService.place(key, state.id, index)
            }

            // ── LANES ───────────────────────────────────────────────────

            Item {
                id: lanes

                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property real laneWidth:
                    (lanes.width - (TasksService.states.length - 1) * root.gap) / TasksService.states.length

                Keys.onLeftPressed: page.walkLane(-1)
                Keys.onRightPressed: page.walkLane(1)
                Keys.onDownPressed: page.walkCard(1)
                Keys.onUpPressed: page.walkCard(-1)
                Keys.onReturnPressed: page.openCurrent()
                Keys.onEnterPressed: page.openCurrent()
                Keys.onSpacePressed: {
                    const card = page.cardUnderCursor()
                    if (!card)
                        return
                    TasksService.setState(card.key,
                        card.state === "done" ? "todo" : TasksService.stateAfter(card.state))
                }

                Row {
                    anchors.fill: parent
                    spacing: root.gap

                    Repeater {
                        model: TasksService.states

                        Item {
                            id: lane

                            required property var modelData
                            required property int index

                            readonly property string stateId: lane.modelData.id
                            readonly property var cards: TasksService.inState(lane.stateId)
                            readonly property bool receiving:
                                page.dragging !== "" && page.dropLane === lane.index
                            readonly property bool first: lane.index === 0

                            width: lanes.laneWidth
                            height: lanes.height

                            Component.onCompleted: {
                                const next = Object.assign({}, page.lists)
                                next[lane.index] = list
                                page.lists = next
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusMedium
                                color: Theme.islandSurface
                                border.color: lane.receiving ? Theme.accent : Theme.islandBorder
                                border.width: 1

                                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
                            }

                            RowLayout {
                                id: head

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 12
                                anchors.bottomMargin: 0
                                spacing: 8

                                Text {
                                    text: lane.modelData.icon
                                    font.family: Theme.fontMono
                                    font.pixelSize: 13
                                    color: lane.stateId === "done" ? Theme.green : Theme.accent
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: lane.modelData.label
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }

                                Text {
                                    text: `${lane.cards.length}`
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    color: Theme.textMuted
                                }
                            }

                            ListView {
                                id: list

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: head.bottom
                                anchors.bottom: parent.bottom
                                anchors.margins: 8
                                anchors.topMargin: 10
                                clip: true
                                spacing: 6
                                model: ScriptModel {
                                    values: lane.cards
                                    objectProp: "key"
                                }
                                boundsBehavior: Flickable.StopAtBounds

                                // New, at the top of the first lane: an empty
                                // card, ringed when the keyboard is on it.
                                header: Item {
                                    width: list.width
                                    height: lane.first ? 46 : 0
                                    visible: lane.first

                                    readonly property bool current: lanes.activeFocus
                                        && page.cursorLane === 0 && page.cursorIndex === -1

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.bottomMargin: 6
                                        radius: Theme.radiusSmall
                                        color: freshMouse.containsMouse ? Theme.islandSurfaceHover : Theme.island
                                        border.color: parent.current ? Theme.accent : Theme.hairline
                                        border.width: 1

                                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 8

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "󰐕"
                                                font.family: Theme.fontMono
                                                font.pixelSize: 13
                                                color: Theme.accent
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "New task"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.weight: Font.DemiBold
                                                color: Theme.text
                                            }
                                        }

                                        MouseArea {
                                            id: freshMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: TasksService.create(true)
                                        }
                                    }
                                }

                                // Room after the last card for a drop there,
                                // with its indicator line.
                                footer: Item {
                                    width: list.width
                                    height: 8

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 2
                                        radius: 1
                                        visible: lane.receiving && page.dropIndex >= lane.cards.length
                                        color: Theme.accent
                                    }
                                }

                                delegate: Item {
                                    id: card

                                    required property var modelData
                                    required property int index

                                    readonly property var task: card.modelData
                                    readonly property bool done: card.task.state === "done"
                                    readonly property bool overdue: TasksService.isOverdue(card.task)
                                    readonly property bool held: page.dragging === card.task.key
                                    readonly property bool current: lanes.activeFocus
                                        && page.cursorLane === lane.index
                                        && page.cursorIndex === card.index
                                    readonly property bool landing:
                                        lane.receiving && page.dropIndex === card.index
                                    readonly property string more: NotesService.firstLine(card.task.body)

                                    width: list.width
                                    height: body.implicitHeight + 18

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.topMargin: -4
                                        height: 2
                                        radius: 1
                                        visible: card.landing
                                        color: Theme.accent
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.radiusSmall
                                        color: cardHover.hovered && !card.held
                                            ? Theme.islandSurfaceHover : Theme.island
                                        border.color: card.current ? Theme.accent : Theme.hairline
                                        border.width: 1
                                        opacity: card.held ? 0.35 : 1

                                        Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                                    }

                                    RowLayout {
                                        id: body

                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: 9
                                        anchors.rightMargin: 9
                                        spacing: 8

                                        // The tick: done, or back to the first
                                        // lane. A child, so its tap wins over
                                        // the card's.
                                        Item {
                                            Layout.preferredWidth: 18
                                            Layout.preferredHeight: 18
                                            Layout.alignment: Qt.AlignTop
                                            Layout.topMargin: 1

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 15
                                                height: 15
                                                radius: 7.5
                                                color: card.done ? Theme.green : "transparent"
                                                border.color: card.done ? Theme.green : Theme.textMuted
                                                border.width: 1.5

                                                Behavior on color { ColorAnimation { duration: Theme.durationFast } }

                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: card.done
                                                    text: "󰄬"
                                                    font.family: Theme.fontMono
                                                    font.pixelSize: 9
                                                    color: Theme.island
                                                }
                                            }

                                            HoverHandler { cursorShape: Qt.PointingHandCursor }

                                            TapHandler {
                                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                                onTapped: TasksService.toggle(card.task.key)
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            Text {
                                                Layout.fillWidth: true
                                                text: card.task.text
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 2
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeSmall
                                                font.strikeout: card.done
                                                color: card.done ? Theme.textMuted : Theme.text
                                            }

                                            // The first line of the notes.
                                            Text {
                                                Layout.fillWidth: true
                                                visible: card.more !== ""
                                                text: card.more
                                                elide: Text.ElideRight
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontSizeLabel
                                                color: Theme.textMuted
                                            }

                                            Text {
                                                visible: card.task.due !== ""
                                                text: `󰃭 ${TasksService.dueLabel(card.task.due)}`
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeLabel
                                                color: card.overdue ? Theme.red : Theme.textMuted
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: cardHover
                                        cursorShape: card.held ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        gesturePolicy: TapHandler.ReleaseWithinBounds
                                        onTapped: TasksService.open(card.task.key, true)
                                    }

                                    DragHandler {
                                        id: pull

                                        target: null

                                        onActiveChanged: {
                                            if (pull.active) {
                                                page.dragging = card.task.key
                                                page.aim(pull.centroid.scenePosition)
                                                return
                                            }
                                            page.drop()
                                        }

                                        onCentroidChanged: {
                                            if (pull.active)
                                                page.aim(pull.centroid.scenePosition)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // The card being dragged. Parented to the lanes rather than
                // its list, so it can leave its lane.
                Rectangle {
                    id: ghost

                    readonly property var task: TasksService.entry(page.dragging)

                    z: 10
                    visible: page.dragging !== ""
                    width: lanes.laneWidth - 16
                    height: ghostLine.implicitHeight + 18
                    radius: Theme.radiusSmall
                    color: Theme.island
                    border.color: Theme.accent
                    border.width: 1
                    opacity: 0.92

                    Text {
                        id: ghostLine

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: 9
                        text: ghost.task ? ghost.task.text : ""
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.text
                    }
                }
            }

            // ── FOOTER ──────────────────────────────────────────────────

            Text {
                Layout.fillWidth: true
                text: {
                    const pending = TasksService.pending
                    const over = TasksService.overdue.length
                    const today = TasksService.pendingOn(TasksService.todayKey)
                    if (TasksService.count === 0)
                        return "Nothing on the board yet"
                    const parts = [`${pending} ${pending === 1 ? "task" : "tasks"} open`]
                    if (today > 0)
                        parts.push(`${today} due today`)
                    if (over > 0)
                        parts.push(`${over} overdue`)
                    return parts.join(" · ")
                }
                elide: Text.ElideRight
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                color: TasksService.overdue.length > 0 ? Theme.red : Theme.textMuted
            }
        }
    }

    // ── TASK ────────────────────────────────────────────────────────────────

    Component {
        id: editor

        Item {
            id: sheet

            width: root.roomWidth
            height: root.roomHeight

            readonly property string key: root.opened
            readonly property string due: root.task ? root.task.due : ""

            // Whether the month is open over the day's button.
            property bool picking: false

            // Read from the service, not `root.task`: this runs inside the
            // change that built the sheet, before the binding re-evaluates.
            // A new task focuses its line.
            Component.onCompleted: {
                const task = TasksService.entry(root.opened)
                line.text = task ? task.text : ""
                more.text = task ? (task.body ?? "") : ""
                line.cursorPosition = line.length
                line.forceActiveFocus()
            }

            function pick(day: string): void {
                TasksService.setDue(sheet.key, day)
                sheet.picking = false
                line.forceActiveFocus()
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                // The line, and when it was added beside it.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 12

                    TextInput {
                        id: line

                        Layout.fillWidth: true
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.DemiBold
                        color: Theme.text
                        clip: true
                        selectByMouse: true
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText

                        onTextEdited: TasksService.update(sheet.key, { text: line.text.trim() })
                        // Enter moves on to the notes.
                        Keys.onReturnPressed: more.forceActiveFocus()
                        Keys.onEnterPressed: more.forceActiveFocus()

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: line.text === ""
                            text: "What has to be done"
                            font: line.font
                            color: Theme.textMuted
                        }
                    }

                    Text {
                        text: {
                            if (!root.task)
                                return ""
                            const finished = root.task.state === "done" && root.task.finished > 0
                            const age = NotesService.ageOf(finished ? root.task.finished : root.task.created)
                            return `${finished ? "done" : "added"} ${age === "just now" ? age : age + " ago"}`
                        }
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.textMuted
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Theme.islandBorder
                }

                // The task's notes.
                Flickable {
                    id: scroller

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: more.contentHeight + 8
                    boundsBehavior: Flickable.StopAtBounds

                    function follow(rectangle: rect): void {
                        if (rectangle.y < scroller.contentY)
                            scroller.contentY = rectangle.y
                        else if (rectangle.y + rectangle.height > scroller.contentY + scroller.height)
                            scroller.contentY = rectangle.y + rectangle.height - scroller.height
                    }

                    TextEdit {
                        id: more

                        width: scroller.width
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        color: Theme.text
                        selectByMouse: true
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText

                        onTextChanged: {
                            if (root.task && more.text !== (root.task.body ?? ""))
                                TasksService.update(sheet.key, { body: more.text })
                        }
                        onCursorRectangleChanged: scroller.follow(more.cursorRectangle)

                        Text {
                            visible: more.text === ""
                            text: "Anything else about it"
                            font: more.font
                            color: Theme.textMuted
                        }
                    }
                }

                // ── ACTIONS ─────────────────────────────────────────────

                // Back, the day as a button, the lane, and Delete. No Done
                // button: the lane is the state. The month opens over the day
                // button; click a day, scroll to page, Escape or click
                // outside to cancel.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    IconButton {
                        icon: "󰁍"
                        iconSize: 14
                        onClicked: root.back()
                    }

                    PillButton {
                        id: dayButton

                        Layout.leftMargin: 6
                        icon: "󰃭"
                        text: sheet.due !== "" ? TasksService.dueLabel(sheet.due) : "Pick a day"
                        active: sheet.picking
                        onClicked: {
                            sheet.picking = !sheet.picking
                            if (!sheet.picking)
                                line.forceActiveFocus()
                        }
                    }

                    SegmentedControl {
                        options: TasksService.states.map(item => ({ id: item.id, label: item.label }))
                        current: root.task ? root.task.state : "todo"
                        onSelected: id => TasksService.setState(sheet.key, id)
                    }

                    Item { Layout.fillWidth: true }

                    PillButton {
                        text: "Delete"
                        icon: "󰆴"
                        onClicked: {
                            const direct = TasksService.direct
                            TasksService.remove(sheet.key)
                            if (direct)
                                root.closed()
                        }
                    }
                }
            }

            // ── MONTH ───────────────────────────────────────────────────

            // Over the form while picking a day: a click outside the month
            // closes it, and the month takes the keys so Escape closes it
            // rather than the task.
            MouseArea {
                anchors.fill: parent
                visible: sheet.picking
                z: 5
                onPressed: {
                    sheet.picking = false
                    line.forceActiveFocus()
                }
            }

            Loader {
                id: month

                z: 6
                active: sheet.picking
                sourceComponent: DayPicker {
                    selected: sheet.due
                    onPicked: day => sheet.pick(day)
                    onDismissed: {
                        sheet.picking = false
                        line.forceActiveFocus()
                    }
                }

                // Placed above the button, flush with its left edge, once the
                // month has a size, and grown from there rather than faded in
                // from its last position.
                onLoaded: {
                    const plate = month.item as Item
                    const at = dayButton.mapToItem(sheet, 0, 0)
                    month.x = at.x
                    month.y = at.y - plate.height - 8
                    plate.forceActiveFocus()
                    arrive.restart()
                }

                opacity: 0
                transform: Scale {
                    id: grow
                    origin.x: 0
                    origin.y: month.height
                    xScale: 1
                    yScale: 1
                }

                ParallelAnimation {
                    id: arrive
                    NumberAnimation { target: month; property: "opacity"; from: 0; to: 1; duration: Theme.durationFast; easing.type: Theme.easing }
                    NumberAnimation { target: grow; property: "yScale"; from: 0.94; to: 1; duration: Theme.durationFast; easing.type: Theme.easing }
                    NumberAnimation { target: grow; property: "xScale"; from: 0.98; to: 1; duration: Theme.durationFast; easing.type: Theme.easing }
                }
            }
        }
    }
}
