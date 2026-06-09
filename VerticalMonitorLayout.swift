#!/usr/bin/env swift
import Cocoa
import Foundation

configure { config in
    print("Usage: \(CommandLine.arguments[0]) [--external-main|--macbook-main] (default: preserve current main display)\n")

    let makeExternalMain = CommandLine.arguments.contains("--external-main")
    let makeMacBookMain = CommandLine.arguments.contains("--macbook-main")

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

    if makeExternalMain || !makeMacBookMain && externalDisplay == mainDisplay {
        print("\nNew external display coordinates: x=0 y=0")
        CGConfigureDisplayOrigin(config, externalDisplay, 0, 0)

        let macBookX = (monitorBounds.width - macBookBounds.width) / 2
        let macBookY = monitorBounds.height

        print("\nNew internal display coordinates: x=\(macBookX) y=\(macBookY)")
        CGConfigureDisplayOrigin(config, macBookDisplay, Int32(macBookX.rounded()), Int32(macBookY.rounded()))
    } else {
        print("\nNew internal display coordinates: x=0 y=0")
        CGConfigureDisplayOrigin(config, macBookDisplay, 0, 0)

        let monitorX = (macBookBounds.width - monitorBounds.width) / 2
        let monitorY = -monitorBounds.height

        print("\nNew external display coordinates: x=\(monitorX) y=\(monitorY)")
        CGConfigureDisplayOrigin(config, externalDisplay, Int32(monitorX.rounded()), Int32(monitorY.rounded()))
    }

    return true
}
