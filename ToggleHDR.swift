import Cocoa
import ColorSync
import Foundation

extension NSScreen {
    var hasMouse: Bool {
        let mouseLocation = NSEvent.mouseLocation
        if NSMouseInRect(mouseLocation, frame, false) {
            return true
        }

        guard let event = CGEvent(source: nil) else {
            return false
        }

        let maxDisplays: UInt32 = 1
        var displaysWithCursor = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let _ = CGGetDisplaysWithPoint(event.location, maxDisplays, &displaysWithCursor, &displayCount)
        guard let id = displaysWithCursor.first else {
            return false
        }
        return id == displayID
    }

    static var withMouse: NSScreen? {
        screens.first { $0.hasMouse }
    }

    var displayID: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDirectDisplayID(id.uint32Value)
    }
}

func toggleHDR(display: MPDisplay) {
    let id = display.displayID
    let name = display.displayName ?? ""

    guard display.hasHDRModes else {
        print("\nThe display does not support HDR control: \(name) [ID: \(id)]")
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
        print("\nUsage: toggle-hdr <id-uuid-or-name>")
        return
    }

    let arg = CommandLine.arguments[1]

    if ["cursor", "current", "main"].contains(arg.lowercased()),
       let cursorDisplayID = NSScreen.withMouse?.displayID,
       let display = displays.first(where: { $0.displayID == cursorDisplayID })
    {
        toggleHDR(display: display)
        return
    }
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
