// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   S C R E E N   T I M E   P A N E L                                      │
// │   screen time · a day, a week or a month of what was in front            │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// The total and how it compares, a chart of when, the day as a ribbon of
// sessions or the week as a grid of hours, and what took the time. A bar of
// the week or the month opens that day.
ColumnLayout {
    id: root

    signal closed()

    readonly property var report: ScreenTimeService.report
    readonly property string view: ScreenTimeService.view
    readonly property bool daily: root.view === "day"

    // What the pointer is on, said in the chart's corner.
    property string readout: ""

    // Apps or groups in the list on the right.
    property bool byGroup: false

    spacing: 14

    Component.onCompleted: ScreenTimeService.subscribe()
    Component.onDestruction: ScreenTimeService.release()

    Keys.onLeftPressed: ScreenTimeService.step(-1)
    Keys.onRightPressed: if (ScreenTimeService.canGoForward) ScreenTimeService.step(1)

    component Caps: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        font.capitalization: Font.AllUppercase
        color: Theme.textMuted
    }

    component Muted: Text {
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeLabel
        color: Theme.textMuted
    }

    // ── WORDS ───────────────────────────────────────────────────────────────

    function dayName(day: string): string {
        const today = ScreenTimeService.today()
        const date = ScreenTimeService.dateOf(day)
        if (day === today)
            return Tr.t("Today")
        const yesterday = new Date()
        yesterday.setDate(yesterday.getDate() - 1)
        if (day === ScreenTimeService.key(yesterday))
            return Tr.t("Yesterday")
        return Tr.date(date, "dddd d MMMM")
    }

    readonly property string periodName: {
        if (!root.report)
            return ""
        if (root.daily)
            return root.dayName(root.report.date)
        const from = ScreenTimeService.dateOf(root.report.from)
        const to = ScreenTimeService.dateOf(root.report.to)
        if (root.view === "month")
            return Tr.date(from, "MMMM yyyy")
        if (ScreenTimeService.current)
            return Tr.t("This week")
        return from.getMonth() === to.getMonth()
            ? `${from.getDate()} – ${Tr.date(to, "d MMMM")}`
            : `${Tr.date(from, "d MMM")} – ${Tr.date(to, "d MMM")}`
    }

    // The day against the week before it; a week or a month against the last.
    readonly property string comparison: {
        if (!root.report)
            return ""
        if (root.daily) {
            const base = root.report.baseline
            if (base <= 0)
                return ""
            const gap = root.report.total - base
            if (Math.abs(gap) < 60)
                return Tr.t("About your daily average")
            return `${ScreenTimeService.duration(Math.abs(gap))} `
                + Tr.t(gap > 0 ? "more than your daily average" : "less than your daily average")
        }
        const before = root.report.previousAverage
        const total = `${ScreenTimeService.duration(root.report.total)} ${Tr.t("in total")}`
        if (before <= 0)
            return total
        const change = Math.round((root.report.average - before) / before * 100)
        const last = Tr.t(root.view === "week" ? "than last week" : "than last month")
        return `${Math.abs(change)}% ${Tr.t(change >= 0 ? "more" : "less")} ${last} · ${total}`
    }

    readonly property bool rising: root.report
        ? (root.daily ? root.report.total > root.report.baseline
            : root.report.average > root.report.previousAverage)
        : false

    // ── HEAD ────────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            spacing: 2

            Caps {
                text: root.daily ? root.periodName
                    : `${root.periodName} · ${Tr.t("Daily average")}`
            }

            Text {
                text: root.report
                    ? ScreenTimeService.duration(root.daily ? root.report.total : root.report.average)
                    : " "
                font.family: Theme.fontDisplay
                font.pixelSize: 38
                font.weight: Font.Bold
                color: Theme.text
            }

            RowLayout {
                spacing: 6
                visible: root.comparison !== ""

                Text {
                    visible: !root.daily || (root.report?.baseline ?? 0) > 0
                    text: root.rising ? "↑" : "↓"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Muted {
                    text: root.comparison
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        Item { Layout.fillWidth: true }

        SegmentedControl {
            Layout.alignment: Qt.AlignTop
            options: [
                { id: "day", label: Tr.t("Day") },
                { id: "week", label: Tr.t("Week") },
                { id: "month", label: Tr.t("Month") }
            ]
            current: root.view
            onSelected: id => ScreenTimeService.show(id, ScreenTimeService.date)
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            icon: "󰅁"
            enabled: ScreenTimeService.canGoBack
            opacity: enabled ? 1 : 0.3
            onClicked: ScreenTimeService.step(-1)
        }

        IconButton {
            Layout.alignment: Qt.AlignTop
            Layout.leftMargin: -6
            icon: "󰅂"
            enabled: ScreenTimeService.canGoForward
            opacity: enabled ? 1 : 0.3
            onClicked: ScreenTimeService.step(1)
        }
    }

    // ── BODY ────────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 14

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 18

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Repeater {
                        model: ScreenTimeService.ranked

                        Row {
                            id: key

                            required property string modelData
                            required property int index

                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8
                                height: 8
                                radius: 4
                                color: Theme.rankColor(key.index)
                            }

                            Muted {
                                text: Tr.t(ScreenTimeService.categoryNames[key.modelData])
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Muted {
                        text: root.readout
                        color: Theme.text
                    }
                }

                Chart {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }

                Ribbon {
                    Layout.fillWidth: true
                    visible: root.daily
                }

                Heat {
                    Layout.fillWidth: true
                    visible: !root.daily
                }
            }

            Muted {
                anchors.centerIn: parent
                visible: ScreenTimeService.empty
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: Tr.t("Screen time counts from now on, while the session is in use. Come back in a while.")
                font.pixelSize: Theme.fontSizeRegular
            }
        }

        Card {
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            padding: 18

            ColumnLayout {
                anchors.fill: parent
                spacing: 13

                RowLayout {
                    Layout.fillWidth: true

                    Caps { text: Tr.t("Most used") }

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: [false, true]

                        Caps {
                            id: choice

                            required property bool modelData

                            text: Tr.t(choice.modelData ? "Groups" : "Apps")
                            color: root.byGroup === choice.modelData ? Theme.text : Theme.textMuted

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.byGroup = choice.modelData
                            }
                        }
                    }
                }

                Repeater {
                    model: (root.byGroup ? ScreenTimeService.categories : ScreenTimeService.apps).slice(0, 7)

                    UsageRow {
                        required property var modelData

                        Layout.fillWidth: true
                        entry: modelData
                        group: root.byGroup
                        maximum: (root.byGroup ? ScreenTimeService.categories : ScreenTimeService.apps)[0]?.seconds ?? 1
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // ── FACTS ───────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        spacing: 36

        Fact {
            visible: root.daily
            caps: Tr.t("First use")
            value: root.report && root.report.days[0].first > 0
                ? ScreenTimeService.clock(root.report.days[0].first) : "—"
        }

        Fact {
            visible: !root.daily
            caps: Tr.t("Total")
            value: root.report ? ScreenTimeService.duration(root.report.total) : "—"
        }

        Fact {
            caps: Tr.t("Unlocks")
            value: root.report ? String(root.report.unlocks) : "—"
        }

        Fact {
            readonly property var loudest: {
                const counts = root.report ? root.report.notifications : ({})
                const names = Object.keys(counts).sort((a, b) => counts[b] - counts[a])
                return names.length > 0 ? { name: names[0], count: counts[names[0]] } : null
            }
            caps: Tr.t("Notifications")
            value: root.report ? String(Object.values(root.report.notifications).reduce((a, b) => a + b, 0)) : "—"
            note: loudest ? `${loudest.count} ${Tr.t("from")} ${loudest.name}` : ""
        }

        Fact {
            readonly property var longest: root.report ? root.report.longest : null
            caps: Tr.t("Longest session")
            value: longest ? ScreenTimeService.duration(longest.seconds) : "—"
            note: longest
                ? (ScreenTimeService.lookup[longest.class]?.name ?? Tr.t("Desktop"))
                    + (root.daily ? ` · ${ScreenTimeService.clock(longest.start)}` : "")
                : ""
        }

        Item { Layout.fillWidth: true }
    }

    component Fact: ColumnLayout {
        id: fact

        property string caps: ""
        property string value: ""
        property string note: ""

        spacing: 2

        Caps { text: fact.caps }

        Text {
            text: fact.value
            font.family: Theme.fontDisplay
            font.pixelSize: 20
            font.weight: Font.DemiBold
            color: Theme.text
        }

        Muted {
            text: fact.note === "" ? " " : fact.note
        }
    }

    // One application or group: what it is, a bar against the first, the time.
    component UsageRow: RowLayout {
        id: usage

        property var entry: ({})
        property bool group: false
        property real maximum: 1

        readonly property int rank: usage.group
            ? ScreenTimeService.ranked.indexOf(usage.entry.id)
            : ScreenTimeService.ranked.indexOf(usage.entry.category)

        spacing: 10

        Item {
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22

            Image {
                id: icon

                anchors.fill: parent
                visible: !usage.group && status === Image.Ready
                source: !usage.group && (usage.entry.icon ?? "") !== ""
                    ? Theme.appIcon(usage.entry.icon) : ""
                sourceSize: Qt.size(44, 44)
                asynchronous: true
            }

            Rectangle {
                anchors.fill: parent
                visible: !icon.visible
                radius: Theme.radiusSmall
                color: usage.group ? Theme.rankColor(usage.rank) : Theme.islandSurfaceHover

                Text {
                    anchors.centerIn: parent
                    visible: !usage.group
                    text: (usage.entry.name ?? "?").charAt(0).toUpperCase()
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: usage.group ? Tr.t(usage.entry.name) : usage.entry.name
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall + 1
                    font.weight: Font.Medium
                    color: Theme.text
                }

                Text {
                    text: ScreenTimeService.duration(usage.entry.seconds)
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 4

                Rectangle {
                    width: Math.max(4, parent.width * usage.entry.seconds / Math.max(1, usage.maximum))
                    height: parent.height
                    radius: 2
                    color: Theme.rankColor(usage.rank)

                    Behavior on width {
                        NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                    }
                }
            }
        }
    }

    // ── CHART ───────────────────────────────────────────────────────────────

    // A bar per hour of the day, or per day of the week or the month, stacked
    // by group, with the daily average dashed across a week or a month.
    component Chart: Item {
        id: chart

        readonly property var stacks: ScreenTimeService.stacks
        readonly property int count: chart.stacks.length
        readonly property real gap: root.daily ? 4 : root.view === "week" ? 14 : 3
        readonly property real slot: (plot.width + chart.gap) / Math.max(1, chart.count)
        readonly property real average: !root.daily && root.report ? root.report.average : 0

        // An hour holds an hour; a day is scaled to the busiest, in whole hours.
        readonly property real ceiling: {
            if (root.daily)
                return 3600
            let most = chart.average
            for (const parts of chart.stacks)
                most = Math.max(most, parts.reduce((a, b) => a + b, 0))
            return Math.max(3600, Math.ceil(most * 1.08 / 3600) * 3600)
        }

        property int hovered: -1

        function bucketDay(index: int): string {
            const date = ScreenTimeService.dateOf(root.report.from)
            date.setDate(date.getDate() + index)
            return ScreenTimeService.key(date)
        }

        function label(index: int): string {
            if (root.daily)
                return index % 6 === 0 ? String(index).padStart(2, "0") : ""
            const date = ScreenTimeService.dateOf(chart.bucketDay(index))
            if (root.view === "week")
                return Tr.date(date, "ddd")
            const day = date.getDate()
            return day === 1 || day % 5 === 0 ? String(day) : ""
        }

        function describe(index: int): string {
            if (index < 0 || !root.report)
                return ""
            const seconds = chart.stacks[index].reduce((a, b) => a + b, 0)
            const when = root.daily
                ? `${String(index).padStart(2, "0")}:00`
                : Tr.date(ScreenTimeService.dateOf(chart.bucketDay(index)), "ddd d")
            return `${when} · ${ScreenTimeService.duration(seconds)}`
        }

        onHoveredChanged: root.readout = chart.describe(chart.hovered)

        Item {
            id: plot

            anchors.fill: parent
            anchors.bottomMargin: 18

            Repeater {
                model: chart.count

                Item {
                    id: bar

                    required property int index

                    readonly property var parts: chart.stacks[bar.index]

                    x: bar.index * chart.slot
                    width: chart.slot - chart.gap
                    height: plot.height
                    opacity: chart.hovered < 0 || chart.hovered === bar.index ? 1 : 0.6

                    Behavior on opacity { NumberAnimation { duration: Theme.durationFast } }

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(4, width / 2)
                        color: Theme.islandSurfaceHover
                        opacity: 0.6
                    }

                    // Bottom up: the first group on the floor, the rest on top.
                    Column {
                        anchors.bottom: parent.bottom
                        width: parent.width

                        Repeater {
                            model: bar.parts.length

                            Rectangle {
                                required property int index

                                readonly property int rank: bar.parts.length - 1 - index

                                width: bar.width
                                height: Math.round(plot.height * Math.min(1, bar.parts[rank] / chart.ceiling))
                                color: Theme.rankColor(rank < ScreenTimeService.shades ? rank : -1)

                                Behavior on height {
                                    NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing }
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.leftMargin: -chart.gap / 2
                        anchors.rightMargin: -chart.gap / 2
                        hoverEnabled: true
                        cursorShape: root.daily ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onEntered: chart.hovered = bar.index
                        onExited: if (chart.hovered === bar.index) chart.hovered = -1
                        onClicked: {
                            if (!root.daily)
                                ScreenTimeService.show("day", chart.bucketDay(bar.index))
                        }
                    }
                }
            }

            Shape {
                id: line

                readonly property real level: plot.height * (1 - chart.average / chart.ceiling)

                anchors.fill: parent
                visible: chart.average > 0

                ShapePath {
                    strokeColor: Theme.text
                    strokeWidth: 1
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 3]
                    fillColor: "transparent"
                    startX: 0
                    startY: line.level

                    PathLine { x: plot.width; y: line.level }
                }
            }

            Muted {
                visible: line.visible
                x: plot.width - width
                y: line.level - height - 2
                text: Tr.t("avg")
                font.pixelSize: 9
            }
        }

        Repeater {
            model: chart.count

            Muted {
                required property int index

                y: chart.height - height
                x: index * chart.slot + (chart.slot - chart.gap - width) / 2
                text: chart.label(index)
                font.pixelSize: 9
            }
        }
    }

    // ── RIBBON ──────────────────────────────────────────────────────────────

    // The day's sessions in order, across the hours the machine was used.
    component Ribbon: ColumnLayout {
        id: ribbon

        readonly property var sessions: root.report && root.daily ? root.report.sessions : []
        readonly property real from: {
            if (ribbon.sessions.length === 0)
                return 0
            const start = new Date(ribbon.sessions[0][0] * 1000)
            start.setMinutes(0, 0, 0)
            return start.getTime() / 1000
        }
        readonly property real to: {
            if (ribbon.sessions.length === 0)
                return 1
            const last = ribbon.sessions[ribbon.sessions.length - 1][1]
            return Math.max(ribbon.from + 6 * 3600, Math.ceil(last / 3600) * 3600)
        }

        property int hovered: -1

        spacing: 6

        onHoveredChanged: {
            const session = ribbon.sessions[ribbon.hovered]
            root.readout = session
                ? `${ScreenTimeService.lookup[session[2]]?.name ?? Tr.t("Desktop")} · `
                    + `${ScreenTimeService.clock(session[0])}–${ScreenTimeService.clock(session[1])}`
                : ""
        }

        RowLayout {
            Layout.fillWidth: true

            Caps { text: Tr.t("Sessions") }

            Item { Layout.fillWidth: true }

            Muted {
                visible: ribbon.sessions.length > 0
                text: `${ScreenTimeService.clock(ribbon.from)} – ${ScreenTimeService.clock(ribbon.to)}`
                font.pixelSize: 9
            }
        }

        Item {
            id: track

            Layout.fillWidth: true
            Layout.preferredHeight: 14

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Theme.islandSurfaceHover
                opacity: 0.6
            }

            Repeater {
                model: ribbon.sessions

                Rectangle {
                    id: piece

                    required property var modelData
                    required property int index

                    readonly property real span: ribbon.to - ribbon.from

                    x: track.width * (piece.modelData[0] - ribbon.from) / piece.span
                    width: Math.max(2, track.width * (piece.modelData[1] - piece.modelData[0]) / piece.span - 1)
                    height: track.height
                    radius: 2
                    color: Theme.rankColor(ScreenTimeService.rankOf(piece.modelData[2]))
                    opacity: ribbon.hovered < 0 || ribbon.hovered === piece.index ? 1 : 0.6

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: ribbon.hovered = piece.index
                        onExited: if (ribbon.hovered === piece.index) ribbon.hovered = -1
                    }
                }
            }
        }
    }

    // ── HEAT ────────────────────────────────────────────────────────────────

    // Weekday by hour: when in the week the time goes.
    component Heat: ColumnLayout {
        id: heat

        readonly property var rows: root.report && !root.daily ? (root.report.heat ?? []) : []
        readonly property real most: {
            let found = 1
            for (const row of heat.rows)
                for (const value of row)
                    found = Math.max(found, value)
            return found
        }

        spacing: 6

        Caps { text: Tr.t("When") }

        Repeater {
            model: heat.rows.length

            RowLayout {
                id: line

                required property int index

                Layout.fillWidth: true
                spacing: 6

                Muted {
                    Layout.preferredWidth: 14
                    // Monday first: 5 January 1970 was one.
                    text: Tr.initial(new Date(1970, 0, 5 + line.index))
                    font.pixelSize: 8
                }

                Row {
                    id: cells

                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: 24

                        Rectangle {
                            required property int index

                            readonly property real level: heat.rows[line.index][index] / heat.most

                            width: Math.max(1, (cells.width - 23 * cells.spacing) / 24)
                            height: 7
                            radius: 2
                            color: level <= 0 ? Theme.islandSurfaceHover
                                : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15 + 0.85 * level)
                        }
                    }
                }
            }
        }
    }
}
