// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   M O D U L E                                                            │
// │   maps a module id to its component                                      │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

import QtQuick

import "../../theme"
import "../../services"

// Maps a module id to its component, so the bar, the island and the services
// pass ids around as strings.
//
// `compact` is the ring face for modules that have one
// (`ModuleService.ringed`); otherwise the detail is built. A new module needs a
// row here and one in the catalogue.
Item {
    id: root

    property string moduleId: ""
    property bool compact: false

    readonly property var components: ({
        clock: clockModule,
        calendar: calendarModule,
        media: mediaModule,
        timer: timerModule,
        claude: claudeModule,
        battery: batteryModule,
        volume: volumeModule,
        brightness: brightnessModule,
        network: networkModule,
        bluetooth: bluetoothModule,
        weather: weatherModule,
        github: githubModule,
        stats: statsModule,
        updates: updatesModule,
        pet: petModule,
        games: gamesModule,
        notes: notesModule,
        tasks: tasksModule,
        notifications: notificationsModule
    })

    implicitWidth: holder.implicitWidth
    implicitHeight: holder.implicitHeight

    Loader {
        id: holder
        anchors.fill: parent
        active: root.moduleId !== ""
        sourceComponent: root.components[root.moduleId] ?? null
    }

    Component { id: clockModule;   ClockModule {} }
    Component { id: calendarModule; CalendarModule {} }
    Component { id: mediaModule;   MediaModule { compact: root.compact } }
    Component { id: timerModule;   TimerModule { compact: root.compact } }
    Component { id: claudeModule;  ClaudeModule { compact: root.compact } }
    Component { id: batteryModule; BatteryModule { compact: root.compact } }
    Component { id: volumeModule;     VolumeModule { compact: root.compact } }
    Component { id: brightnessModule; BrightnessModule { compact: root.compact } }
    Component { id: networkModule;    NetworkModule {} }
    Component { id: bluetoothModule;  BluetoothModule {} }
    Component { id: weatherModule;    WeatherModule {} }
    Component { id: githubModule;     GithubModule {} }
    Component { id: statsModule;      StatsModule { compact: root.compact } }
    Component { id: updatesModule;    UpdatesModule {} }
    Component { id: petModule;        PetModule { compact: root.compact } }
    Component { id: gamesModule;      GamesModule {} }
    Component { id: notesModule;      NotesModule {} }
    Component { id: tasksModule;      TasksModule {} }
    Component { id: notificationsModule; NotificationsModule {} }
}
