import Cocoa
import ColorSync
import Foundation

let userDefaultsSuiteName = "com.alin23.ToggleHDR"

func toggleHDR(display: MPDisplay, enabled: Bool? = nil, try60Hz: Bool = false) {
    let id = display.displayID
    let name = display.displayName ?? ""

    let hdrIsCurrentlyEnabled = display.preferHDRModes()
    let newHDRState = enabled ?? !hdrIsCurrentlyEnabled
    guard newHDRState != hdrIsCurrentlyEnabled else {
        print("HDR is already \(newHDRState ? "enabled" : "disabled") for \(name) [ID: \(id)]")
        return
    }

    if try60Hz, newHDRState, !display.hasHDRModes, let scanRate = display.currentMode.scanRate,
       scanRate.intValue > 60, forceEnableHDR60Hertz(display: display)
    {
        display.setPreferHDRModes(true)
        return
    }

    guard display.hasHDRModes else {
        print("The display does not support HDR control: \(name) [ID: \(id)]")
        return
    }

    updatePreferHDR(display: display, enabled: newHDRState)
}

func printDisplays(_ displays: [MPDisplay]) {
    print("ID\tUUID                             \tSupports HDR\tHDR Enabled\tName")
    for panel in displays {
        print(
            "\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.hasHDRModes)      \t\(panel.preferHDRModes())    \t\(panel.displayName ?? "Unknown name")"
        )
    }
}

func bool(_ arg: String) -> Bool? {
    if ["on", "true", "yes"].contains(arg) || arg.starts(with: "enable") {
        return true
    }
    if ["off", "false", "no"].contains(arg) || arg.starts(with: "disable") {
        return false
    }
    return nil
}

func updatePreferHDR(display: MPDisplay, enabled: Bool) {
    let id = display.displayID
    let name = display.displayName ?? ""

    print("\(enabled ? "Enabling" : "Disabling") HDR for \(name) [ID: \(id)]")
    if !enabled, let ud = UserDefaults(suiteName: userDefaultsSuiteName) {
        // We are currently in HDR mode. Check to see if we have a stored SDR
        // mode number for the current display, and if that mode number can
        // successfully be used to create an MPDisplayMode.
        let uuid = display.uuid?.uuidString ?? name
        let udKey = "SDRModeNumber-\(uuid)"
        let sdrModeNumber = ud.integer(forKey: udKey).i32
        if sdrModeNumber > 0, let newMode = display.mode(withNumber: sdrModeNumber) {
            display.setMode(newMode)
            ud.removeObject(forKey: udKey)
            return
        }
    }
    display.setPreferHDRModes(enabled)
}

func forceEnableHDR60Hertz(display: MPDisplay) -> Bool {
    // macOS doesn't think this display supports HDR; see if it supports HDR when set to 60 Hertz
    guard let ud = UserDefaults(suiteName: userDefaultsSuiteName),
          let scanRates = display.scanRates, scanRates.contains(where: { $0 == 60 }),
          let newMode = display.mode(matchingResolutionOf: display.currentMode, withScanRate: 60)
    else {
        return false
    }
    // We found a 60 Hertz version of the current display mode. Before
    // we make any changes, store the CURRENT display mode in User
    // Defaults so that we can restore it later.
    let modeNumber = display.currentMode.modeNumber
    let uuid = display.uuid?.uuidString ?? display.displayName ?? ""
    ud.setValue(modeNumber, forKey: "SDRModeNumber-\(uuid)")

    // Store the current mode so that if the 60 Hertz mode doesn't support HDR we can switch back.
    let originalMode = display.currentMode

    // Now switch to the 60 Hertz version of the current display mode.
    display.setMode(newMode)

    guard display.hasHDRModes else {
        // Even at 60 Hertz, HDR isn't supported; reset back to the original mode.
        display.setMode(originalMode)
        return false
    }
    return true
}

func printHelp() {
    print("""
    Usage: \(CommandLine.arguments[0]) [id/uuid/name/all] [on/off] [--try-60-hz]

    Options:
    • id/uuid/name: The display to toggle HDR on/off for.
    • all: Toggle HDR on/off for all displays that support it.
    • on/off: Enable or disable HDR. If not provided, the opposite of the current state is used.
    • --try-60-hz: If the display doesn't support HDR at the current refresh rate, it will try switching to 60 Hertz.

    """)
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else { return }

    let try60Hz = CommandLine.arguments.contains("--try-60-hz")
    let args = CommandLine.arguments.filter { arg in !["--try-60-hz"].contains(arg) }

    guard args.count >= 2 else {
        if displays.count == 1, displays[0].hasHDRModes || try60Hz {
            // If there is only one display, toggle the HDR on that display.
            toggleHDR(display: displays[0], try60Hz: try60Hz)
            return
        }
        printHelp()
        printDisplays(displays)
        return
    }

    if args.contains("--help") || args.contains("-h") {
        printHelp()
        printDisplays(displays)
        return
    }

    defer {
        print("")
        printDisplays(displays)
    }
    let arg = args[1].lowercased()

    // Example: `ToggleHDR on` or `ToggleHDR off`
    if let enabled = bool(arg) {
        for display in displays.filter({ $0.hasHDRModes || try60Hz }) {
            toggleHDR(display: display, enabled: enabled, try60Hz: try60Hz)
        }
        return
    }

    let enabled = args.count >= 3 ? bool(args[2].lowercased()) : nil

    // Example: `ToggleHDR all` or `ToggleHDR all on`
    if arg == "all" {
        for display in displays.filter({ $0.hasHDRModes || try60Hz }) {
            toggleHDR(display: display, enabled: enabled, try60Hz: try60Hz)
        }
        return
    }

    // Example: `ToggleHDR DELL` or `ToggleHDR DELL on`
    guard let display = mgr.matchDisplay(filter: arg) else {
        print("No display found for query: \(arg)")
        return
    }

    toggleHDR(display: display, enabled: enabled, try60Hz: try60Hz)
}

main()
