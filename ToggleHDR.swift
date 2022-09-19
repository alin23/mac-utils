import Cocoa
import ColorSync
import Foundation

let maxDisplays: UInt32 = 16
var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
var displayCount: UInt32 = 0

let err = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
let displayIDs = onlineDisplays.prefix(Int(displayCount))

func toggleHDR(display: MPDisplay) {
    let id = display.displayID
    let name = display.displayName != nil ? " (\(display.displayName!))" : ""

    guard display.hasHDRModes else {
        print("\nThe display does not support HDR control: \(id)\(name)")
        return
    }

    if display.preferHDRModes() {
        print("\nDisabling HDR for \(id)\(name)")
        display.setPreferHDRModes(false)
    } else {
        print("\nEnabling HDR for \(id)\(name)")
        display.setPreferHDRModes(true)
    }
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays as? [MPDisplay] else { return }
    print("ID\tUUID                             \tSupports HDR Control\tName")
    for panel in displays {
        print("\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.hasHDRModes)\t\(panel.displayName ?? "Unknown name")")
    }

    guard CommandLine.arguments.count >= 2 else {
        print("\nUsage: toggle-hdr <id-uuid-or-name>")
        return
    }

    let arg = CommandLine.arguments[1]

    if let id = Int(arg), let display = displays.first(where: { $0.displayID == id }) {
        toggleHDR(display: display)
        return
    }
    if let uuid = UUID(uuidString: arg.uppercased()), let display = displays.first(where: { $0.uuid == uuid }) {
        toggleHDR(display: display)
        return
    }
    if let display = displays.first(where: { $0.displayName?.lowercased() == arg.lowercased() }) {
        toggleHDR(display: display)
        return
    }

    print("\nNo display found for query: \(arg)")
}

main()
