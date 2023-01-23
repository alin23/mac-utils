#!/usr/bin/env swift
import Cocoa
import Foundation

configure { config in
    let macBookDisplay = CGMainDisplayID()
    guard let firstDisplay = NSScreen.onlineDisplayIDs.first(where: { $0 != macBookDisplay }) else {
        print("No external display found")
        return false
    }

    if CGDisplayIsInMirrorSet(macBookDisplay) != 0 {
        print("Disabling mirroring")
        CGConfigureDisplayMirrorOfDisplay(config, macBookDisplay, kCGNullDirectDisplay)
    } else {
        print("Mirroring MacBook contents to the external monitor")
        CGConfigureDisplayMirrorOfDisplay(config, firstDisplay, macBookDisplay)
    }
    return true
}
