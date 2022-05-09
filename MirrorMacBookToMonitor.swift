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
