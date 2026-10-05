// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M A C H I N E S   P A N E L                                            │
// │   virtual machines · the ones there are, and the catalogue               │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../theme"
import "../../services"
import "../../components"

// Two views behind one switch. Machines: a row each, its mark, its
// resources and its state, with the answers that state allows, and one
// opened out below it for its numbers, snapshots and removal. New: the
// catalogue, a system on the left and on the right its versions, editions
// and what the machine gets, then the fetch, whose progress takes the top of
// Machines until it is done.
ColumnLayout {
    id: root

    signal closed()

    property string view: VmService.machines.length === 0 && VmService.fetching === null
        ? "new" : "machines"

    spacing: 14

    Component.onCompleted: VmService.subscribe()
    Component.onDestruction: VmService.release()

    onViewChanged: if (root.view === "new") VmService.loadCatalog()

    readonly property int rowHeight: 76

    function gigabytes(bytes: real): string {
        return `${Math.round(bytes / 1073741824)} GB`
    }

    function cores(count: string): string {
        const number = parseInt(count) || 0
        return number === 0 ? "" : `${number} ${Tr.t(number === 1 ? "core" : "cores")}`
    }

    // A round answer: its glyph, lit under the pointer.
    component Round: Rectangle {
        id: round

        property string glyph: ""
        property bool primary: false
        property bool danger: false
        property bool live: true
        signal pressed()

        implicitWidth: 34
        implicitHeight: 34
        radius: width / 2
        opacity: round.live ? 1 : 0.35
        color: round.primary ? Theme.accent
            : press.containsMouse && round.live ? Theme.islandSurfaceHover : Theme.island

        Behavior on color { ColorAnimation { duration: Theme.durationFast } }

        Text {
            anchors.centerIn: parent
            text: round.glyph
            font.family: Theme.fontMono
            font.pixelSize: 15
            color: round.primary ? Theme.accentText : round.danger ? Theme.indicatorBad : Theme.text
        }

        MouseArea {
            id: press

            anchors.fill: parent
            enabled: round.live
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: round.pressed()
        }
    }

    // A system's mark on a square of the island's black.
    component Mark: Rectangle {
        id: markBox

        property string system: ""
        property int size: 52

        implicitWidth: markBox.size
        implicitHeight: markBox.size
        radius: Math.round(markBox.size * 0.28)
        color: Theme.island

        Text {
            anchors.centerIn: parent
            text: VmService.mark(markBox.system)
            font.family: Theme.fontMono
            font.pixelSize: Math.round(markBox.size * 0.5)
            color: Theme.text
        }
    }

    // A chip that is picked or not.
    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool picked: false
        signal pressed()

        implicitWidth: chipText.implicitWidth + 24
        implicitHeight: 28
        radius: height / 2
        color: chip.picked ? Theme.accent : chipPress.containsMouse ? Theme.islandSurfaceHover : Theme.island

        Text {
            id: chipText

            anchors.centerIn: parent
            text: chip.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            color: chip.picked ? Theme.accentText : Theme.text
        }

        MouseArea {
            id: chipPress

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.pressed()
        }
    }

    // A number nudged within limits.
    component Nudge: RowLayout {
        id: nudge

        property string glyph: ""
        property string label: ""
        property int value: 1
        property int from: 1
        property int to: 8
        property int step: 1
        property string unit: ""
        signal changed(int value)

        spacing: 10

        Text {
            text: nudge.glyph
            font.family: Theme.fontMono
            font.pixelSize: 14
            color: Theme.textMuted
        }

        Text {
            Layout.fillWidth: true
            text: nudge.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.text
        }

        Round {
            implicitWidth: 26
            implicitHeight: 26
            glyph: "󰍴"
            live: nudge.value > nudge.from
            onPressed: nudge.changed(Math.max(nudge.from, nudge.value - nudge.step))
        }

        Text {
            Layout.preferredWidth: 52
            horizontalAlignment: Text.AlignHCenter
            text: `${nudge.value}${nudge.unit}`
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.text
        }

        Round {
            implicitWidth: 26
            implicitHeight: 26
            glyph: "󰐕"
            live: nudge.value < nudge.to
            onPressed: nudge.changed(Math.min(nudge.to, nudge.value + nudge.step))
        }
    }

    // ── HEAD ────────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        spacing: 12

        Column {
            Layout.fillWidth: true
            visible: root.view === "machines"
            spacing: 2

            Text {
                text: Tr.t("Machines")
                font.family: Theme.fontFamily
                font.pixelSize: 20
                font.weight: Font.Bold
                color: Theme.text
            }

            Text {
                text: VmService.running.length === 0 ? Tr.t("None running")
                    : `${VmService.running.length} ${Tr.t("running")} · `
                      + `${VmService.coresInUse} / ${VmService.hostCores} ${Tr.t("cores")} · `
                      + `${VmService.memoryInUse} / ${Math.round(VmService.hostMemory / 1073741824)} GB`
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.textMuted
            }
        }

        Text {
            visible: root.view === "new"
            text: "󰍉"
            font.family: Theme.fontMono
            font.pixelSize: 17
            color: Theme.accent
        }

        TextInput {
            id: search

            Layout.fillWidth: true
            visible: root.view === "new"
            font.family: Theme.fontFamily
            font.pixelSize: 16
            color: Theme.text
            clip: true
            selectByMouse: true
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            onTextEdited: catalogList.currentIndex = 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: search.text === ""
                text: Tr.t("Find a system…")
                color: Theme.textMuted
                font: search.font
            }
        }

        SegmentedControl {
            Layout.alignment: Qt.AlignVCenter
            current: root.view
            options: [
                { id: "machines", label: VmService.machines.length > 0
                    ? `${Tr.t("Machines")} · ${VmService.machines.length}` : Tr.t("Machines") },
                { id: "new", label: Tr.t("New") }
            ]
            onSelected: id => {
                root.view = id
                if (id === "new")
                    search.forceActiveFocus()
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.borderIn(QsWindow.window)
    }

    // ── MACHINES ────────────────────────────────────────────────────────────

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.view === "machines"

        Text {
            anchors.centerIn: parent
            visible: VmService.loaded && !VmService.ready
            width: parent.width * 0.7
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: Tr.t("Machines need quickemu, which ./setup packages installs.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.textMuted
        }

        Text {
            anchors.centerIn: parent
            visible: VmService.ready && VmService.machines.length === 0 && VmService.fetching === null
            text: Tr.t("No machines yet. Pick a system in New.")
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSizeRegular
            color: Theme.textMuted
        }

        ListView {
            id: machineList

            anchors.fill: parent
            visible: VmService.ready
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds

            // The one opened out, by name.
            property string open: ""

            header: Item {
                width: machineList.width
                height: VmService.fetching !== null ? root.rowHeight + 8 : 0
                visible: VmService.fetching !== null

                Rectangle {
                    width: parent.width
                    height: root.rowHeight
                    radius: 20
                    color: Theme.islandSurface

                    Mark {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        system: VmService.fetching?.os ?? ""
                    }

                    Column {
                        x: 78
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 78 - 60
                        spacing: 6

                        Text {
                            text: VmService.fetching?.title ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.text
                        }

                        Rectangle {
                            width: parent.width
                            height: 6
                            radius: 3
                            color: Theme.island

                            Rectangle {
                                width: parent.width * (VmService.fetching?.progress ?? 0)
                                height: parent.height
                                radius: 3
                                color: Theme.accent

                                Behavior on width { NumberAnimation { duration: Theme.durationMedium } }
                            }
                        }

                        Text {
                            text: `${Tr.t("Downloading")} · ${Math.round((VmService.fetching?.progress ?? 0) * 100)}%`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    Round {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰅖"
                        onPressed: VmService.cancelCreate()
                    }
                }
            }

            model: VmService.machines

            delegate: Rectangle {
                id: machine

                required property var modelData

                readonly property bool on: machine.modelData.running
                readonly property bool paused: machine.modelData.paused
                readonly property bool opened: machineList.open === machine.modelData.name
                readonly property bool busy: VmService.busy === machine.modelData.name
                // Asked to shut down and not gone yet: the next press ends it.
                property bool asked: false

                width: machineList.width
                height: root.rowHeight + (machine.opened && !machine.on ? details.implicitHeight + 14 : 0)
                radius: 20
                color: machine.on ? Theme.islandSurfaceHover : Theme.islandSurface
                clip: true

                Behavior on height { NumberAnimation { duration: Theme.durationMedium; easing.type: Theme.easing } }

                onOnChanged: if (!machine.on) machine.asked = false

                Item {
                    width: parent.width
                    height: root.rowHeight

                    Mark {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        system: machine.modelData.os
                    }

                    Column {
                        x: 78
                        anchors.verticalCenter: parent.verticalCenter
                        width: 260
                        spacing: 3

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: machine.modelData.title
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.text
                        }

                        Text {
                            text: [root.cores(machine.modelData.cores),
                                   machine.modelData.ram ? machine.modelData.ram.replace("G", " GB") : "",
                                   machine.modelData.disk ? `${machine.modelData.disk.replace("G", " GB")} ${Tr.t("disk")}`
                                       : root.gigabytes(machine.modelData.used)]
                                .filter(part => part !== "").join(" · ")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }

                    Row {
                        x: 360
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: !machine.on ? Theme.indicatorDim
                                : machine.paused ? Theme.indicatorWarn : Theme.indicatorGood
                        }

                        Text {
                            text: !machine.on ? (machine.modelData.snapshots.length > 0
                                    ? `${Tr.t("Off")} · ${machine.modelData.snapshots.length} ${Tr.t("snapshots")}` : Tr.t("Off"))
                                : machine.paused ? Tr.t("Paused")
                                : machine.asked ? Tr.t("Shutting down")
                                : `${Tr.t("Running")} · ${VmService.uptime(machine.modelData.started)}`
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            color: machine.on ? Theme.text : Theme.textMuted
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Round {
                            visible: machine.on
                            glyph: "󰍹"
                            live: !machine.busy
                            onPressed: VmService.open(machine.modelData.name)
                        }

                        Round {
                            visible: machine.on
                            glyph: machine.paused ? "󰐊" : "󰏤"
                            live: !machine.busy
                            onPressed: machine.paused ? VmService.resume(machine.modelData.name)
                                                      : VmService.pause(machine.modelData.name)
                        }

                        // Shut down as a power button does; pressed again, end it.
                        Round {
                            visible: machine.on
                            glyph: machine.asked ? "󰚦" : "󰐥"
                            danger: true
                            live: !machine.busy
                            onPressed: {
                                if (machine.asked) {
                                    VmService.kill(machine.modelData.name)
                                } else {
                                    machine.asked = true
                                    VmService.stop(machine.modelData.name)
                                }
                            }
                        }

                        Round {
                            visible: !machine.on
                            glyph: machine.opened ? "󰅃" : "󰇘"
                            onPressed: machineList.open = machine.opened ? "" : machine.modelData.name
                        }

                        Round {
                            visible: !machine.on
                            glyph: "󰐊"
                            primary: true
                            live: !machine.busy
                            onPressed: VmService.start(machine.modelData.name)
                        }
                    }
                }

                // ── OPENED OUT ──────────────────────────────────────────────

                ColumnLayout {
                    id: details

                    x: 78
                    y: root.rowHeight
                    width: parent.width - 78 - 16
                    visible: machine.opened && !machine.on
                    spacing: 10

                    Nudge {
                        Layout.fillWidth: true
                        glyph: "󰘚"
                        label: Tr.t("Cores")
                        value: parseInt(machine.modelData.cores) || 2
                        to: VmService.hostCores
                        onChanged: value => VmService.setCores(machine.modelData.name, value)
                    }

                    Nudge {
                        Layout.fillWidth: true
                        glyph: "󰍛"
                        label: Tr.t("Memory")
                        value: parseInt(machine.modelData.ram) || 4
                        to: Math.max(1, Math.floor(VmService.hostMemory / 1073741824) - 2)
                        unit: " GB"
                        onChanged: value => VmService.setMemory(machine.modelData.name, value)
                    }

                    // Snapshots: one to take now, and each kept to go back to.
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6

                        Chip {
                            label: `󰄄  ${Tr.t("Take a snapshot")}`
                            onPressed: VmService.snapshot(machine.modelData.name, "create",
                                Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH.mm"))
                        }

                        Repeater {
                            model: machine.modelData.snapshots

                            Chip {
                                required property var modelData

                                label: `󰑐  ${modelData.tag}`
                                onPressed: VmService.snapshot(machine.modelData.name, "apply", modelData.tag)
                            }
                        }
                    }

                    // Removal arms on the first press.
                    RowLayout {
                        Layout.fillWidth: true

                        Item { Layout.fillWidth: true }

                        PillButton {
                            id: removal

                            property bool armed: false

                            text: removal.armed ? Tr.t("Delete it and its disk") : Tr.t("Delete")
                            icon: "󰆴"
                            active: removal.armed
                            implicitHeight: 30
                            onClicked: {
                                if (removal.armed)
                                    VmService.remove(machine.modelData.name)
                                removal.armed = !removal.armed
                            }
                        }
                    }
                }
            }
        }
    }

    // ── NEW ─────────────────────────────────────────────────────────────────

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: root.view === "new"
        spacing: 16

        readonly property var systems: VmService.catalog.filter(system =>
            search.text === "" || system.name.toLowerCase().includes(search.text.toLowerCase()))

        ListView {
            id: catalogList

            Layout.preferredWidth: 280
            Layout.fillHeight: true
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: parent.systems
            currentIndex: 0

            Text {
                anchors.centerIn: parent
                visible: VmService.catalogLoading
                text: Tr.t("Reading the catalogue…")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeRegular
                color: Theme.textMuted
            }

            delegate: Rectangle {
                id: system

                required property var modelData
                required property int index

                readonly property bool current: ListView.isCurrentItem

                width: catalogList.width
                height: 44
                radius: 14
                color: system.current ? Theme.islandSurfaceHover : systemPress.containsMouse ? Theme.islandSurface : "transparent"
                border.width: system.current ? 1 : 0
                border.color: Theme.accent

                Text {
                    x: 12
                    width: 24
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: VmService.mark(system.modelData.os)
                    font.family: Theme.fontMono
                    font.pixelSize: 18
                    color: Theme.text
                }

                Column {
                    x: 46
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: system.modelData.name
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeRegular
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: system.modelData.releases.slice().reverse().slice(0, 3)
                            .map(entry => entry.release).join(" · ")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.textMuted
                    }
                }

                MouseArea {
                    id: systemPress

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: catalogList.currentIndex = system.index
                }
            }
        }

        // The one chosen.
        Rectangle {
            id: chosen

            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 22
            color: Theme.islandSurface
            visible: chosen.system !== null

            readonly property var system: catalogList.model[catalogList.currentIndex] ?? null
            readonly property var releases: chosen.system ? chosen.system.releases.slice().reverse() : []
            property int releaseIndex: 0
            readonly property var release: chosen.releases[chosen.releaseIndex] ?? null
            readonly property var editions: chosen.release?.editions ?? []
            property string edition: ""

            onSystemChanged: {
                chosen.releaseIndex = 0
                chosen.edition = ""
            }
            onReleaseChanged: {
                const editions = chosen.release?.editions ?? []
                if (editions.indexOf(chosen.edition) < 0)
                    chosen.edition = editions[0] ?? ""
            }

            property int cores: Math.min(4, Math.max(1, Math.floor(VmService.hostCores / 2)))
            property int memory: Math.min(8, Math.max(2, Math.floor(VmService.hostMemory / 1073741824 / 2)))
            property int disk: chosen.system?.os === "windows" ? 64 : 32

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 12

                RowLayout {
                    spacing: 14

                    Mark {
                        system: chosen.system?.os ?? ""
                        size: 56
                    }

                    Column {
                        spacing: 2

                        Text {
                            text: chosen.system?.name ?? ""
                            font.family: Theme.fontFamily
                            font.pixelSize: 20
                            font.weight: Font.Bold
                            color: Theme.text
                        }

                        Text {
                            text: [chosen.release?.release ?? "", chosen.edition].filter(part => part !== "").join(" · ")
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.textMuted
                        }
                    }
                }

                Text {
                    text: Tr.t("Version")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: chosen.releases.slice(0, 8)

                        Chip {
                            required property var modelData
                            required property int index

                            label: modelData.release
                            picked: chosen.releaseIndex === index
                            onPressed: chosen.releaseIndex = index
                        }
                    }
                }

                Text {
                    visible: chosen.editions.length > 0
                    text: Tr.t("Edition")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textMuted
                }

                // Editions can be many (Windows has a language each), so they
                // scroll in a band of their own.
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(editionFlow.implicitHeight, 64)
                    visible: chosen.editions.length > 0
                    contentHeight: editionFlow.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Flow {
                        id: editionFlow

                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: chosen.editions

                            Chip {
                                required property string modelData

                                label: modelData
                                picked: chosen.edition === modelData
                                onPressed: chosen.edition = modelData
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Nudge {
                    Layout.fillWidth: true
                    glyph: "󰘚"
                    label: Tr.t("Cores")
                    value: chosen.cores
                    to: VmService.hostCores
                    onChanged: value => chosen.cores = value
                }

                Nudge {
                    Layout.fillWidth: true
                    glyph: "󰍛"
                    label: Tr.t("Memory")
                    value: chosen.memory
                    to: Math.max(1, Math.floor(VmService.hostMemory / 1073741824) - 2)
                    unit: " GB"
                    onChanged: value => chosen.memory = value
                }

                Nudge {
                    Layout.fillWidth: true
                    glyph: "󰋊"
                    label: Tr.t("Disk")
                    value: chosen.disk
                    from: 8
                    to: 512
                    step: 8
                    unit: " GB"
                    onChanged: value => chosen.disk = value
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: VmService.error
                        elide: Text.ElideRight
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.indicatorBad
                    }

                    PillButton {
                        text: Tr.t("Download and create")
                        icon: "󰇚"
                        active: true
                        enabled: VmService.ready && VmService.fetching === null && chosen.release !== null
                        implicitHeight: 34
                        onClicked: {
                            VmService.create(chosen.system, chosen.release.release, chosen.edition,
                                             chosen.cores, chosen.memory, chosen.disk)
                            root.view = "machines"
                        }
                    }
                }
            }
        }
    }

    // ── FOOT ────────────────────────────────────────────────────────────────

    Text {
        Layout.fillWidth: true
        text: root.view === "new" ? Tr.t("Systems from quickget")
            : VmService.error !== "" ? VmService.error : Tr.t("Close a machine's window and it keeps running")
        elide: Text.ElideRight
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: VmService.error !== "" && root.view !== "new" ? Theme.indicatorBad : Theme.textMuted
    }
}
