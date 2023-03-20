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
    print("ID\tUUID                             \tHDR Control\tName")
    for panel in displays {
        print("\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.hasHDRModes)      \t\(panel.displayName ?? "Unknown name")")
    }
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays as? [MPDisplay] else { return }
    printDisplays(displays)

    guard CommandLine.arguments.count >= 2 else {
        print("\nUsage: \(CommandLine.arguments[0]) <id-uuid-or-name> [on/off]")
        return
    }

    let arg = CommandLine.arguments[1]

    guard let display = mgr.matchDisplay(filter: arg) else {
        print("\nNo display found for query: \(arg)")

        return
    }

    if CommandLine.arguments.count >= 3 {
        let arg = CommandLine.arguments[2].lowercased()
        toggleHDR(display: display, enabled: ["on", "1", "true", "yes"].contains(arg) || arg.starts(with: "enable"))
    } else {
        toggleHDR(display: display)
    }
}

main()
