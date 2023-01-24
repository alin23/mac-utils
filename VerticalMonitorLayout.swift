#!/usr/bin/env swift
import Cocoa
import Foundation

configure { config in
    let mainDisplay = CGMainDisplayID()
    var macBookDisplay: CGDirectDisplayID
    var externalDisplay: CGDirectDisplayID
    if CGDisplayIsBuiltin(mainDisplay) != 0 {
        macBookDisplay = mainDisplay
        guard let otherDisplay = NSScreen.onlineDisplayIDs.first(where: { $0 != macBookDisplay }) else {
            print("No external display detected")
            return false
        }
        externalDisplay = otherDisplay
    } else {
        externalDisplay = mainDisplay
        guard let otherDisplay = NSScreen.onlineDisplayIDs.first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            print("No internal display detected")
            return false
        }
        macBookDisplay = otherDisplay
    }

    let macBookBounds = CGDisplayBounds(macBookDisplay)
    let monitorBounds = CGDisplayBounds(externalDisplay)
    print(
        "Main Display: x=\(macBookBounds.origin.x) y=\(macBookBounds.origin.y) width=\(macBookBounds.width) height=\(macBookBounds.height)"
    )
    print(
        "External Display: x=\(monitorBounds.origin.x) y=\(monitorBounds.origin.y) width=\(monitorBounds.width) height=\(monitorBounds.height)"
    )

    if macBookDisplay == mainDisplay {
        let monitorX = (max(monitorBounds.width, macBookBounds.width) - min(monitorBounds.width, macBookBounds.width)) / -2
        let monitorY = -monitorBounds.height

        print("\nNew external display coordinates: x=\(monitorX) y=\(monitorY)")
        CGConfigureDisplayOrigin(config, externalDisplay, Int32(monitorX.rounded()), Int32(monitorY.rounded()))
    } else {
        let monitorX = (max(macBookBounds.width, monitorBounds.width) - min(macBookBounds.width, monitorBounds.width)) / 2
        let monitorY = monitorBounds.height

        print("\nNew internal display coordinates: x=\(monitorX) y=\(monitorY)")
        CGConfigureDisplayOrigin(config, macBookDisplay, Int32(monitorX.rounded()), Int32(monitorY.rounded()))
    }

    return true
}
