import Cocoa
import ColorSync
import Foundation

let userDefaultsSuiteName = "com.alin23.ToggleHDR"

func toggleHDR(display: MPDisplay, enabled: Bool? = nil) {
    let id = display.displayID
    let name = display.displayName ?? ""
	let origPreferHDRModes = display.preferHDRModes()

	if !display.hasHDRModes, display.currentMode.scanRate as? Int != 60 {
		// TODO?: It is only possible to get here if the user either specifies
		// a specific display, or doesn't specify anything at all on the command
		// line. That is because the code paths that iterate all displays only
		// iterate displays with HDR support. I'm not sure if going through all
		// of them and switching them to 60 Hertz to check if they support HDR
		// and then back if they don't is a good idea. (It would skip any that
		// don't support HDR and are already at 60 Hertz.)

		// For some reason, switching to 60 Hertz can also SOMETIMES (but not
		// ALWAYS) switch to HDR. If that happens, the stored value for
		// origPreferHDRModes above will prevent us from immediately switching
		// back to SDR.
		check60Hertz(display: display)
	}

    guard display.hasHDRModes else {
        print("The display does not support HDR control: \(name) [ID: \(id)]")
        return
    }

    if let enabled {
		updatePreferHDR(display: display, enabled: enabled)
        return
    }

	updatePreferHDR(display: display, enabled: !origPreferHDRModes)
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
		let udKey = "SDRModeNumber-\(display.name)"
		if let sdrModeNumber = ud.value(forKey: udKey) as? Int32,
		   let newMode = display.mode(withNumber: sdrModeNumber) {
			// Switch to the stored mode.
			display.setMode(newMode)
			// Clear out the stored mode number so it won't get improperly used
			// at some later date.
			ud.removeObject(forKey: udKey)
			return
		}
	}
	display.setPreferHDRModes(enabled)
}

func check60Hertz(display: MPDisplay) {
	guard let ud = UserDefaults(suiteName: userDefaultsSuiteName) else {
		return
	}
	// macOS doesn't think this display supports HDR; see if it supports HDR
	// when set to 60 Hertz
	guard let scanRates = display.scanRates else {
		return
	}
	if scanRates.contains(where: { $0 as? Int == 60 }) {
		guard let newMode = display.mode(matchingResolutionOfMode: display.currentMode, withScanRate: 60) as? MPDisplayMode else {
			return
		}
		// We found a 60 Hertz version of the current display mode. Before
		// we make any changes, store the CURRENT display mode in User
		// Defaults so that we can restore it later.
		let modeNumber = display.currentMode.modeNumber
		ud.setValue(modeNumber, forKey: "SDRModeNumber-\(display.name)")
        // Store the current mode so that if the 60 Hertz mode doesn't support
        // HDR we can switch back.
		let originalMode = display.currentMode
		// Now switch to the 60 Hertz version of the current display mode.
		display.setMode(newMode)
		if !display.hasHDRModes {
			// Even at 60 Hertz, HDR isn't supported; reset back to the
			// original mode.
			display.setMode(originalMode)
		}
	}
}

func main() {
    guard let mgr = MPDisplayMgr(), let displays = mgr.displays else { return }

	guard CommandLine.arguments.count >= 2 else {
		if displays.count == 1 {
			// If there is only one display, toggle the HDR on that display.
			toggleHDR(display: displays[0])
			return
		}
        printDisplays(displays)
        print("\nUsage: \(CommandLine.arguments[0]) [id/uuid/name/all] [on/off]")
        return
    }

    defer {
        print("")
        printDisplays(displays)
    }
    let arg = CommandLine.arguments[1].lowercased()

    // Example: `ToggleHDR on` or `ToggleHDR off`
    if let enabled = bool(arg) {
        for display in displays.filter(\.hasHDRModes) {
            toggleHDR(display: display, enabled: enabled)
        }
        return
    }

    let enabled = CommandLine.arguments.count >= 3 ? bool(CommandLine.arguments[2].lowercased()) : nil

    // Example: `ToggleHDR all` or `ToggleHDR all on`
    if arg == "all" {
        for display in displays.filter(\.hasHDRModes) {
            toggleHDR(display: display, enabled: enabled)
        }
        return
    }

    // Example: `ToggleHDR DELL` or `ToggleHDR DELL on`
    guard let display = mgr.matchDisplay(filter: arg) else {
        print("No display found for query: \(arg)")

        return
    }

    toggleHDR(display: display, enabled: enabled)
}

main()
