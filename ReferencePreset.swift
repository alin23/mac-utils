import Cocoa
import Foundation

extension MPDisplay {
    /// `presets` is implicitly unwrapped in the private header and nil on displays without any
    var presetList: [MPDisplayPreset] { (presets as [MPDisplayPreset]?) ?? [] }
}

func presetStrings(_ display: MPDisplay) -> [String] {
    display.presetList.filter(\.isValid).map { preset in
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

@discardableResult
func setReferencePreset(display: MPDisplay, presetFilter: String) -> Bool {
    let displayName = display.displayName ?? "display"

    if let index = Int(presetFilter) {
        guard let preset = display.presetList.first(where: { $0.presetIndex == index }) else {
            fputs("No preset with index \(index) for \(displayName)\n", stderr)
            return false
        }
        print("Activating preset \"\(preset.presetName ?? presetFilter)\" for \(displayName)")
        display.setActivePreset(preset)
        return true
    }

    let preset = display.presetList.first { $0.presetName == presetFilter }
        ?? display.presetList.first { $0.presetName?.caseInsensitiveCompare(presetFilter) == .orderedSame }
    guard let preset else {
        fputs("No preset with name \(presetFilter) for \(displayName)\n", stderr)
        return false
    }
    print("Activating preset \"\(preset.presetName ?? presetFilter)\" for \(displayName)")
    display.setActivePreset(preset)
    return true
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else {
        fputs("No displays\n", stderr)
        exit(1)
    }

    guard CommandLine.arguments.count >= 3 else {
        printDisplays(displays)
        print("\nUsage: \(CommandLine.arguments[0]) <id/uuid/name/all> <preset-name-or-index>")
        exit(CommandLine.arguments.count == 1 ? 0 : 1)
    }

    defer {
        print("")
        printDisplays(displays)
    }

    let display = CommandLine.arguments[1]
    let preset = CommandLine.arguments[2]

    // Example: `ReferencePreset all 2`
    if display.lowercased() == "all" {
        let withPresets = displays.filter(\.hasPresets)
        guard !withPresets.isEmpty else {
            fputs("No connected display has reference presets\n", stderr)
            exit(1)
        }
        for display in withPresets {
            setReferencePreset(display: display, presetFilter: preset)
        }
        return
    }

    // Example: `ReferencePreset DELL 2`
    guard let display = mgr.matchDisplay(filter: display) else {
        fputs("No display found for query: \(display)\n", stderr)
        exit(1)
    }

    if !setReferencePreset(display: display, presetFilter: preset) { exit(1) }
}

main()
