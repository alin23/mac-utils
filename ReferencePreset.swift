import Cocoa
import Foundation

func presetStrings(_ display: MPDisplay) -> [String] {
    display.presets.filter(\.isValid).map { preset in
        "\(preset.presetIndex). \(preset.presetName ?? "NO NAME")"
    }
}

func printDisplays(_ displays: [MPDisplay]) {
    for panel in displays {
        print("""
        \(panel.displayName ?? "Unknown display")
            ID: \(panel.displayID)
            UUID: \(panel.uuid?.uuidString ?? "")
            Preset: \(panel.activePreset?.presetName ?? "No preset")
            Presets:
            \t\(presetStrings(panel).joined(separator: "\n\t"))
        """)
    }
}

func setReferencePreset(display: MPDisplay, presetFilter: String) {
    let displayName = display.displayName ?? "display"

    if let index = Int(presetFilter) {
        guard let preset = display.presets.first(where: { $0.presetIndex == index }) else {
            print("No preset with index \(index) for \(displayName)")
            return
        }
        print("Activating preset \"\(preset.presetName ?? presetFilter)\" for \(displayName)")
        display.setActivePreset(preset)
        return
    }

    guard let preset = display.presets.first(where: { $0.presetName == presetFilter }) else {
        print("No preset with name \(presetFilter) for \(displayName)")
        return
    }
    print("Activating preset \"\(preset.presetName ?? presetFilter)\" for \(displayName)")
    display.setActivePreset(preset)
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else {
        print("No displays")
        return
    }

    guard CommandLine.arguments.count >= 3 else {
        printDisplays(displays)
        print("\nUsage: \(CommandLine.arguments[0]) <id/uuid/name/all> <preset-name-or-index>")
        return
    }

    defer {
        print("")
        printDisplays(displays)
    }

    let display = CommandLine.arguments[1]
    let preset = CommandLine.arguments[2]

    // Example: `ReferencePreset all 2`
    if display.lowercased() == "all" {
        for display in mgr.displays.filter(\.hasPresets) {
            setReferencePreset(display: display, presetFilter: preset)
        }
        return
    }

    // Example: `ReferencePreset DELL 2`
    guard let display = mgr.matchDisplay(filter: display) else {
        print("No display found for query: \(display)")

        return
    }

    setReferencePreset(display: display, presetFilter: preset)
}

main()
