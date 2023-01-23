#!/usr/bin/env swift
import Cocoa
import Foundation

configure { config in
    print("Usage: \(CommandLine.arguments[0]) [left|right] (default: right)\n")

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

    let monitorX = CommandLine.arguments.contains("left") ? -monitorBounds.width : monitorBounds.width
    let monitorY = (max(monitorBounds.height, macBookBounds.height) - min(monitorBounds.height, macBookBounds.height)) / -2

    print("\nNew external display coordinates: x=\(monitorX) y=\(monitorY)")
    CGConfigureDisplayOrigin(config, otherDisplay, Int32(monitorX.rounded()), Int32(monitorY.rounded()))
    return true
}
