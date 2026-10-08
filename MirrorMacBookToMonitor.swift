#!/usr/bin/env swift
import Cocoa
import Foundation

configure { config in
    let online = NSScreen.onlineDisplayIDs

    // Mirroring is undone on the displays that mirror another one, not on the source
    let mirroring = online.filter { CGDisplayMirrorsDisplay($0) != kCGNullDirectDisplay }
    if !mirroring.isEmpty {
        print("Disabling mirroring")
        for id in mirroring {
            CGConfigureDisplayMirrorOfDisplay(config, id, kCGNullDirectDisplay)
        }
        return true
    }

    guard let macBookDisplay = online.first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
        fputs("No built-in display found (is the lid closed?)\n", stderr)
        return false
    }
    guard let externalDisplay = online.first(where: { $0 != macBookDisplay }) else {
        fputs("No external display found\n", stderr)
        return false
    }

    print("Mirroring MacBook contents to the external monitor")
    CGConfigureDisplayMirrorOfDisplay(config, externalDisplay, macBookDisplay)
    return true
}
