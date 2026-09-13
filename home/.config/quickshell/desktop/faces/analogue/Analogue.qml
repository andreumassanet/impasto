// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   A   N   A   L   O   G   U   E                                          │
// │   analogue widget theme · one drawn object per module                    │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../../services"

// The Analogue theme's registry: one row per module. A single registry rather
// than one per family, because each face scales itself to the family it is
// given. Faces read services and draw in `ink`; the bar modules know nothing
// about this theme.
Item {
    id: root

    property string moduleId: ""
    property string family: "2x2"
    property var ink: DesktopService.inkFor(null)

    // The desktop row, for the one face that draws what the row names.
    property var row: null

    readonly property var components: ({
        clock: clockFace,
        weather: weatherFace,
        github: githubFace,
        battery: batteryFace,
        stats: statsFace,
        claude: claudeFace,
        media: mediaFace,
        calendar: calendarFace,
        timer: timerFace,
        volume: volumeFace,
        brightness: brightnessFace,
        tasks: tasksFace,
        updates: updatesFace,
        network: networkFace,
        bluetooth: bluetoothFace,
        pet: creatureFace,
        games: gamesFace,
        photo: photoFace
    })

    Loader {
        anchors.fill: parent
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component { id: clockFace;      ClockFace      { family: root.family; ink: root.ink } }
    Component { id: weatherFace;    WeatherFace    { family: root.family; ink: root.ink } }
    Component { id: githubFace;     GithubFace     { family: root.family; ink: root.ink } }
    Component { id: batteryFace;    BatteryFace    { family: root.family; ink: root.ink } }
    Component { id: statsFace;      StatsFace      { family: root.family; ink: root.ink } }
    Component { id: claudeFace;     ClaudeFace     { family: root.family; ink: root.ink } }
    Component { id: mediaFace;      MediaFace      { family: root.family; ink: root.ink } }
    Component { id: calendarFace;   CalendarFace   { family: root.family; ink: root.ink } }
    Component { id: timerFace;      TimerFace      { family: root.family; ink: root.ink } }
    Component { id: volumeFace;     VolumeFace     { family: root.family; ink: root.ink } }
    Component { id: brightnessFace; BrightnessFace { family: root.family; ink: root.ink } }
    Component { id: tasksFace;      TasksFace      { family: root.family; ink: root.ink } }
    Component { id: updatesFace;    UpdatesFace    { family: root.family; ink: root.ink } }
    Component { id: networkFace;    NetworkFace    { family: root.family; ink: root.ink } }
    Component { id: bluetoothFace;  BluetoothFace  { family: root.family; ink: root.ink } }
    Component { id: creatureFace;   CreatureFace   { family: root.family; ink: root.ink } }
    Component { id: gamesFace;      GamesFace      { family: root.family; ink: root.ink } }
    Component { id: photoFace;      PhotoFace      { family: root.family; ink: root.ink; row: root.row } }
}
