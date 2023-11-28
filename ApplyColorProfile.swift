import Cocoa
import ColorSync
import CoreGraphics
import Foundation

let FACTORY_PROFILES = kColorSyncFactoryProfiles.takeUnretainedValue() as String
let DEVICE_PROFILE_URL = kColorSyncDeviceProfileURL.takeUnretainedValue() as String
let DEVICE_CLASS = kColorSyncDisplayDeviceClass.takeUnretainedValue()
let DEFAULT_PROFILE = kColorSyncDeviceDefaultProfileID.takeUnretainedValue()

extension UUID {
    var cfUUID: CFUUID {
        let b = uuid
        return CFUUIDCreateWithBytes(nil, b.0, b.1, b.2, b.3, b.4, b.5, b.6, b.7, b.8, b.9, b.10, b.11, b.12, b.13, b.14, b.15)
    }
}

func setDisplayProfile(_ path: String, _ display: MPDisplay) {
    if path == "factory" {
        print("Resetting profile for \(display.displayName ?? "display") to factory default")

        let profileDict = [DEFAULT_PROFILE: nil] as CFDictionary
        guard ColorSyncDeviceSetCustomProfiles(DEVICE_CLASS, display.uuid.cfUUID, profileDict) else {
            print("Failed to set factory profile")
            return
        }
        return
    }

    print("Setting profile \(path) for \(display.displayName ?? "display")")
    let iccURL = URL(fileURLWithPath: path)
    let uuid = display.uuid.cfUUID

    var err: Unmanaged<CFError>?
    guard let profile = ColorSyncProfileCreateWithURL(iccURL as CFURL, &err)?.takeRetainedValue() else {
        print("Failed to create profile from \(path)")
        return
    }

    let profileName = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String? ?? iccURL.deletingPathExtension().lastPathComponent
    print("Profile name: \(profileName)")

    guard let deviceInfo = ColorSyncDeviceCopyDeviceInfo(DEVICE_CLASS, uuid)?.takeRetainedValue() else {
        print("Failed to get device info for \(uuid)")
        return
    }
    print("Device info: \(deviceInfo)")

    print("Setting profile \(profileName) for \(uuid)")
    let profileDict = [DEFAULT_PROFILE: iccURL] as CFDictionary
    guard ColorSyncDeviceSetCustomProfiles(DEVICE_CLASS, uuid, profileDict) else {
        print("Failed to set custom profile")
        return
    }
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else {
        print("No displays")
        return
    }

    guard CommandLine.arguments.count >= 3 else {
        print("""
        Usage: \(CommandLine.arguments[0]) <display> <profile>

        display: Can be a display ID, UUID, or name. Use "all" to apply to all displays.
        profile: Path to an ICC profile. Use "factory" to reset to default.
        """)
        return
    }

    let display = CommandLine.arguments[1]
    let profilePath = CommandLine.arguments[2]
    guard FileManager.default.fileExists(atPath: profilePath) || profilePath == "factory" else {
        print("File not found: \(profilePath)")
        return
    }

    // Example: `ApplyColorProfile all HighAmbientLight.icc`
    if display.lowercased() == "all" {
        for display in displays.filter(\.hasPresets) {
            setDisplayProfile(profilePath, display)
        }
        return
    }

    // Example: `ApplyColorProfile DELL HighAmbientLight.icc`
    guard let display = mgr.matchDisplay(filter: display) else {
        print("No display found for query: \(display)")

        return
    }

    setDisplayProfile(profilePath, display)
}

main()
