#!/usr/bin/env swift
import Cocoa
import Foundation

func configure(_ action: (CGDisplayConfigRef) -> Bool) {
    var config: CGDisplayConfigRef?
    var err = CGBeginDisplayConfiguration(&config)
    guard err == .success, let config = config else {
        print("Error with CGBeginDisplayConfiguration: \(err)")
        return
    }

    guard action(config) else {
        _ = CGCancelDisplayConfiguration(config)
        return
    }

    err = CGCompleteDisplayConfiguration(config, .permanently)
    guard err == .success else {
        print("Error with CGCompleteDisplayConfiguration")
        _ = CGCancelDisplayConfiguration(config)
        return
    }
}

extension NSScreen {
    static var onlineDisplayIDs: [CGDirectDisplayID] {
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let err = CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount)
        if err != .success {
            print("Error on getting online displays: \(err)")
        }

        return Array(onlineDisplays.prefix(Int(displayCount)))
    }
}

configure { config in
    let macBookDisplay = CGMainDisplayID()
    guard let firstDisplay = NSScreen.onlineDisplayIDs.first(where: { $0 != macBookDisplay }),
          let secondDisplay = NSScreen.onlineDisplayIDs.first(where: { $0 != macBookDisplay && $0 != firstDisplay })
    else {
        print("Two external displays are needed")
        return false
    }

    let macBookBounds = CGDisplayBounds(macBookDisplay)
    let firstMonitorBounds = CGDisplayBounds(firstDisplay)
    let secondMonitorBounds = CGDisplayBounds(secondDisplay)
    print(
        "Main Display: x=\(macBookBounds.origin.x) y=\(macBookBounds.origin.y) width=\(macBookBounds.width) height=\(macBookBounds.height)\n"
    )
    print(
        "External Display 1: x=\(firstMonitorBounds.origin.x) y=\(firstMonitorBounds.origin.y) width=\(firstMonitorBounds.width) height=\(firstMonitorBounds.height)"
    )
    print("\tMoving to: x=\(secondMonitorBounds.origin.x) y=\(secondMonitorBounds.origin.y)\n")
    print(
        "External Display 2: x=\(secondMonitorBounds.origin.x) y=\(secondMonitorBounds.origin.y) width=\(secondMonitorBounds.width) height=\(secondMonitorBounds.height)"
    )
    print("\tMoving to: x=\(firstMonitorBounds.origin.x) y=\(firstMonitorBounds.origin.y)\n")

    CGConfigureDisplayOrigin(
        config,
        firstDisplay,
        Int32(secondMonitorBounds.origin.x.rounded()),
        Int32(secondMonitorBounds.origin.y.rounded())
    )
    CGConfigureDisplayOrigin(
        config,
        secondDisplay,
        Int32(firstMonitorBounds.origin.x.rounded()),
        Int32(firstMonitorBounds.origin.y.rounded())
    )
    return true
}
