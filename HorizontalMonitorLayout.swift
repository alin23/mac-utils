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
    guard let otherDisplay = NSScreen.onlineDisplayIDs.first(where: { $0 != macBookDisplay }) else {
        print("No external display detected")
        return false
    }

    let macBookBounds = CGDisplayBounds(macBookDisplay)
    let monitorBounds = CGDisplayBounds(otherDisplay)
    print(
        "Main Display: x=\(macBookBounds.origin.x) y=\(macBookBounds.origin.y) width=\(macBookBounds.width) height=\(macBookBounds.height)"
    )
    print(
        "External Display: x=\(monitorBounds.origin.x) y=\(monitorBounds.origin.y) width=\(monitorBounds.width) height=\(monitorBounds.height)"
    )

    let monitorX = monitorBounds.width
    let monitorY = (max(monitorBounds.height, macBookBounds.height) - min(monitorBounds.height, macBookBounds.height)) / -2

    print("\nNew external display coordinates: x=\(monitorX) y=\(monitorY)")
    CGConfigureDisplayOrigin(config, otherDisplay, Int32(monitorX.rounded()), Int32(monitorY.rounded()))
    return true
}
