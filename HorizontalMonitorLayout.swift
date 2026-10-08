#!/usr/bin/env swift
import Cocoa
import Foundation

let args = CommandLine.arguments.dropFirst().map { $0.lowercased() }
guard args.allSatisfy({ ["left", "right"].contains($0) }) else {
    print("Usage: \(CommandLine.arguments[0]) [left|right] (default: right)")
    exit(args.contains("-h") || args.contains("--help") ? 0 : 1)
}

configure { config in
    let macBookDisplay = builtinOrMainDisplayID
    guard let otherDisplay = NSScreen.onlineDisplayIDs.first(where: { $0 != macBookDisplay && CGDisplayMirrorsDisplay($0) == kCGNullDirectDisplay }) else {
        fputs("No external display detected\n", stderr)
        return false
    }

    let macBookBounds = CGDisplayBounds(macBookDisplay)
    let monitorBounds = CGDisplayBounds(otherDisplay)
    print(
        "MacBook Display: x=\(macBookBounds.origin.x) y=\(macBookBounds.origin.y) width=\(macBookBounds.width) height=\(macBookBounds.height)"
    )
    print(
        "External Display: x=\(monitorBounds.origin.x) y=\(monitorBounds.origin.y) width=\(monitorBounds.width) height=\(monitorBounds.height)"
    )

    // Origins are relative to the main display, so position against the MacBook's own origin
    let monitorX = args.contains("left") ? macBookBounds.minX - monitorBounds.width : macBookBounds.maxX
    let monitorY = macBookBounds.minY + (macBookBounds.height - monitorBounds.height) / 2

    print("\nNew external display coordinates: x=\(monitorX) y=\(monitorY)")
    CGConfigureDisplayOrigin(config, otherDisplay, Int32(monitorX.rounded()), Int32(monitorY.rounded()))
    return true
}
