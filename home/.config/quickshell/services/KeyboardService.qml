// ╭──────────────────────────────────────────────────────────────────────────╮
// │                                                                          │
// │   K E Y B O A R D   S E R V I C E                                        │
// │   the layout in use · read from hyprctl, followed by the event           │
// │                                                                          │
// │   github.com/andreumassanet/impasto                                      │
// │                                                                          │
// ╰──────────────────────────────────────────────────────────────────────────╯

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The layout of Hyprland's main keyboard, for the bar's layout piece. It only
// reads and switches the live layout; the input settings (`keyboard` in
// SettingsService) are what the compositor is configured with.
Singleton {
    id: root

    // xkb's description of the layout in use ("English (US)").
    property string layout: ""
    property string keyboard: ""
    // The configured layouts and variants, in Hyprland's order ("us", "fr").
    property var codes: []
    property var variants: []
    // xkb's description for each layout, "us" or "us(intl)": "English (US)".
    property var descriptions: ({})

    // `{ code, name }` per configured layout, in the order `select` counts.
    readonly property var layoutList: root.codes.map((code, position) => {
        const variant = root.variants[position] ?? ""
        const key = variant !== "" ? `${code}(${variant})` : code
        return { code: code, name: root.descriptions[key] ?? code.toUpperCase() }
    })

    readonly property int activeIndex: root.layoutList.findIndex(entry => entry.name === root.layout)

    // The figure on the bar: the layout's code ("US", "FR"). When the layout
    // is not among the configured ones, the bracket in its name, or its start.
    readonly property string shortCode: {
        if (root.activeIndex >= 0)
            return root.layoutList[root.activeIndex].code.toUpperCase()
        const inside = /\(([^),]+)/.exec(root.layout)
        return inside ? inside[1].slice(0, 3).toUpperCase() : root.layout.slice(0, 2).toUpperCase()
    }

    function refresh(): void {
        reader.running = true
    }

    function select(index: int): void {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", root.keyboard || "main", String(index)])
    }

    // xkb's names, once: a layout line is "us<TAB>English (US)", a variant
    // line "us(intl)<TAB>English (US, intl., with dead keys)".
    Process {
        running: true
        command: ["awk",
            '/^! layout/{s="l";next} /^! variant/{s="v";next} /^!/{s="";next} '
            + 's=="l"{code=$1;$1="";sub(/^ +/,"");print code "\\t" $0} '
            + 's=="v"{lay=$2;sub(/:$/,"",lay);name=$0;sub(/^[^:]*: */,"",name);print lay "(" $1 ")\\t" name}',
            "/usr/share/X11/xkb/rules/evdev.lst"]
        stdout: StdioCollector {
            onStreamFinished: {
                const names = {}
                for (const line of text.split("\n")) {
                    const [key, name] = line.split("\t")
                    if (key && name)
                        names[key] = name
                }
                root.descriptions = names
            }
        }
    }

    Process {
        id: reader

        command: ["hyprctl", "devices", "-j"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text).keyboards ?? []
                    const main = keyboards.find(keyboard => keyboard.main) ?? keyboards[0]
                    root.layout = main?.active_keymap ?? ""
                    root.keyboard = main?.name ?? ""
                    root.codes = String(main?.layout ?? "").split(",").filter(code => code !== "")
                    // Kept in step with `codes`, so an empty variant keeps its place.
                    root.variants = String(main?.variant ?? "").split(",")
                } catch (error) {
                    console.warn("Cannot parse the hyprctl response:", error)
                }
            }
        }
    }

    // `KEYBOARD,LAYOUT`, sent whenever any keyboard changes layout, a key
    // bind's included. Another device's change is not the main keyboard's.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name !== "activelayout")
                return
            const [device, ...name] = String(event.data).split(",")
            if (root.keyboard === "" || device === root.keyboard)
                root.layout = name.join(",")
        }
    }
}
