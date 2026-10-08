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

@discardableResult
func setDisplayProfile(_ path: String, _ display: MPDisplay) -> Bool {
    let displayName = display.displayName ?? "display"
    // `uuid` is implicitly unwrapped in the private header, and nil for some virtual displays
    guard let displayUUID = display.uuid as UUID? else {
        fputs("\(displayName) has no UUID, ColorSync can't target it\n", stderr)
        return false
    }
    let uuid = displayUUID.cfUUID

    if path == "factory" {
        print("Resetting profile for \(displayName) to factory default")

        let profileDict = [DEFAULT_PROFILE: nil] as CFDictionary
        guard ColorSyncDeviceSetCustomProfiles(DEVICE_CLASS, uuid, profileDict) else {
            fputs("Failed to set factory profile for \(displayName)\n", stderr)
            return false
        }
        return true
    }

    // ColorSync keeps the URL, so a path relative to the current directory has to be made absolute
    let iccURL = URL(fileURLWithPath: path).absoluteURL.standardizedFileURL

    var err: Unmanaged<CFError>?
    guard let profile = ColorSyncProfileCreateWithURL(iccURL as CFURL, &err)?.takeRetainedValue() else {
        fputs("Failed to create profile from \(path)\(err.map { ": \($0.takeRetainedValue())" } ?? "")\n", stderr)
        return false
    }

    let profileName = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() as String? ?? iccURL.deletingPathExtension().lastPathComponent
    print("Setting profile \"\(profileName)\" for \(displayName)")

    guard ColorSyncDeviceCopyDeviceInfo(DEVICE_CLASS, uuid) != nil else {
        fputs("ColorSync doesn't know \(displayName) [\(displayUUID)]\n", stderr)
        return false
    }

    let profileDict = [DEFAULT_PROFILE: iccURL] as CFDictionary
    guard ColorSyncDeviceSetCustomProfiles(DEVICE_CLASS, uuid, profileDict) else {
        fputs("Failed to set custom profile for \(displayName)\n", stderr)
        return false
    }
    return true
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else {
        fputs("No displays\n", stderr)
        exit(1)
    }

    guard CommandLine.arguments.count >= 3 else {
        print("""
        Usage: \(CommandLine.arguments[0]) <display> <profile>

        display: Can be a display ID, UUID, or name. Use "all" to apply to all displays.
        profile: Path to an ICC profile. Use "factory" to reset to default.
        """)
        exit(CommandLine.arguments.count == 1 ? 0 : 1)
    }

    let display = CommandLine.arguments[1]
    let profilePath = CommandLine.arguments[2]
    guard FileManager.default.fileExists(atPath: profilePath) || profilePath == "factory" else {
        fputs("File not found: \(profilePath)\n", stderr)
        exit(1)
    }

    // Example: `ApplyColorProfile all HighAmbientLight.icc`
    if display.lowercased() == "all" {
        var failed = false
        for display in displays where !setDisplayProfile(profilePath, display) {
            failed = true
        }
        exit(failed ? 1 : 0)
    }

    // Example: `ApplyColorProfile DELL HighAmbientLight.icc`
    guard let display = mgr.matchDisplay(filter: display) else {
        fputs("No display found for query: \(display)\n", stderr)
        exit(1)
    }

    if !setDisplayProfile(profilePath, display) { exit(1) }
}

main()
