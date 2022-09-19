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

func rotateDisplay(display: MPDisplay, orientation: Int32) {
    let id = display.displayID
    let name = display.displayName ?? ""

    guard display.canChangeOrientation() else {
        print("\nThe display does not support changing orientation: \(name) [ID: \(id)]")
        return
    }

    print("\nChanging orientation for \(name) [ID: \(id)]: \(display.orientation) -> \(orientation)")
    display.orientation = orientation
}

func printDisplays(_ displays: [MPDisplay]) {
    print("ID\tUUID                             \tCan Change Orientation\tOrientation\tName")
    for panel in displays {
        print(
            "\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.canChangeOrientation())                \t\(panel.orientation)°        \t\(panel.displayName ?? "Unknown name")"
        )
    }
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays as? [MPDisplay] else { return }
    printDisplays(displays)

    guard CommandLine.arguments.count >= 3, let orientation = Int32(CommandLine.arguments[2]),
          [0, 90, 180, 270].contains(orientation)
    else {
        print("\nUsage: \(CommandLine.arguments[0]) <id-uuid-or-name> 0|90|180|270")
        return
    }

    let arg = CommandLine.arguments[1]

    if ["cursor", "current", "main"].contains(arg.lowercased()),
       let cursorDisplayID = NSScreen.withMouse?.displayID,
       let display = displays.first(where: { $0.displayID == cursorDisplayID })
    {
        rotateDisplay(display: display, orientation: orientation)
        return
    }
    if let id = Int(arg), let display = displays.first(where: { $0.displayID == id }) {
        rotateDisplay(display: display, orientation: orientation)
        return
    }
    if let uuid = UUID(uuidString: arg.uppercased()), let display = displays.first(where: { $0.uuid == uuid }) {
        rotateDisplay(display: display, orientation: orientation)
        return
    }
    if let display = displays.first(where: { $0.displayName?.lowercased() == arg.lowercased() }) {
        rotateDisplay(display: display, orientation: orientation)
        return
    }

    print("\nNo display found for query: \(arg)")
}

main()
