import Cocoa
import ColorSync
import Foundation

func enableHDR(display: MPDisplay) {
    let id = display.displayID
    let name = display.displayName ?? ""

    guard display.hasHDRModes else {
        print("\nThe display does not support HDR control: \(name) [ID: \(id)]")
        return
    }

    display.setPreferHDRModes(true)
}

func printDisplays(_ displays: [MPDisplay]) {
    print("ID\tUUID                             \tHDR Control\tName")
    for panel in displays {
        print("\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.hasHDRModes)      \t\(panel.displayName ?? "Unknown name")")
    }
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays as? [MPDisplay] else { return }

    for display in displays {
        enableHDR(display: display)
    }
    
}

main()
