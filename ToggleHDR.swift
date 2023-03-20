import Cocoa
import ColorSync
import Foundation

func toggleHDR(display: MPDisplay, enabled: Bool? = nil) {
    let id = display.displayID
    let name = display.displayName ?? ""

    guard display.hasHDRModes else {
        print("\nThe display does not support HDR control: \(name) [ID: \(id)]")
        return
    }

    if let enabled {
        print("\n\(enabled ? "Enabling" : "Disabling") HDR for \(name) [ID: \(id)]")
        display.setPreferHDRModes(enabled)
        return
    }

    if display.preferHDRModes() {
        print("\nDisabling HDR for \(name) [ID: \(id)]")
        display.setPreferHDRModes(false)
    } else {
        print("\nEnabling HDR for \(name) [ID: \(id)]")
        display.setPreferHDRModes(true)
    }
}

func printDisplays(_ displays: [MPDisplay]) {
    print("ID\tUUID                             \tSupports HDR\tHDR Enabled\tName")
    for panel in displays {
        print(
            "\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.hasHDRModes)      \t\(panel.preferHDRModes())    \t\(panel.displayName ?? "Unknown name")"
        )
    }
}

func bool(_ arg: String) -> Bool? {
    if ["on", "true", "yes"].contains(arg) || arg.starts(with: "enable") {
        return true
    }
    if ["off", "false", "no"].contains(arg) || arg.starts(with: "disable") {
        return false
    }
    return nil
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else { return }
    printDisplays(displays)

    guard CommandLine.arguments.count >= 2 else {
        print("\nUsage: \(CommandLine.arguments[0]) [id/uuid/name/all] [on/off]")
        return
    }

    let arg = CommandLine.arguments[1].lowercased()

    // Example: `ToggleHDR on` or `ToggleHDR off`
    if let enabled = bool(arg) {
        for display in mgr.displays.filter(\.hasHDRModes) {
            toggleHDR(display: display, enabled: enabled)
        }
        return
    }

    let enabled = CommandLine.arguments.count >= 3 ? bool(CommandLine.arguments[2].lowercased()) : nil

    // Example: `ToggleHDR all` or `ToggleHDR all on`
    if arg == "all" {
        for display in mgr.displays.filter(\.hasHDRModes) {
            toggleHDR(display: display, enabled: enabled)
        }
        return
    }

    // Example: `ToggleHDR DELL` or `ToggleHDR DELL on`
    guard let display = mgr.matchDisplay(filter: arg) else {
        print("\nNo display found for query: \(arg)")

        return
    }

    toggleHDR(display: display, enabled: enabled)
}

main()
