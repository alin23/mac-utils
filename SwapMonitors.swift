#!/usr/bin/env swift
import Cocoa
import Foundation

func configure(_ action: (CGDisplayConfigRef) -> Bool) {
    var configRef: CGDisplayConfigRef?
    var err = CGBeginDisplayConfiguration(&configRef)
    guard err == .success, let config = configRef else {
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
    var displayID: CGDirectDisplayID? {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return nil }
        return CGDirectDisplayID(id.uint32Value)
    }

    static func name(for id: CGDirectDisplayID) -> String? {
        screen(with: id)?.localizedName
    }

    static func screen(with id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { $0.hasDisplayID(id) }
    }

    func hasDisplayID(_ id: CGDirectDisplayID) -> Bool {
        guard let screenNumber = displayID else { return false }
        return id == screenNumber
    }

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

let NAME_STRIP_REGEX = try! NSRegularExpression(pattern: #"(.+)\s+\(\s*\d+\s*\)\s*$"#)

func swap(firstDisplay: CGDirectDisplayID, secondDisplay: CGDirectDisplayID, rotation: Bool = true) {
    if let firstName = NSScreen.name(for: firstDisplay), let secondName = NSScreen.name(for: secondDisplay) {
        print("Swapping \(firstName) [ID: \(firstDisplay)] with \(secondName) [ID: \(secondDisplay)]\n")
    } else {
        print("Swapping \(firstDisplay) with \(secondDisplay)\n")
    }

    configure { config in
        let firstMonitorBounds = CGDisplayBounds(firstDisplay)
        let secondMonitorBounds = CGDisplayBounds(secondDisplay)
        print(
            "External Display 1: x=\(firstMonitorBounds.origin.x) y=\(firstMonitorBounds.origin.y) width=\(firstMonitorBounds.width) height=\(firstMonitorBounds.height)"
        )
        print("\tMoving to: x=\(secondMonitorBounds.origin.x) y=\(secondMonitorBounds.origin.y)\n")
        print(
            "External Display 2: x=\(secondMonitorBounds.origin.x) y=\(secondMonitorBounds.origin.y) width=\(secondMonitorBounds.width) height=\(secondMonitorBounds.height)"
        )
        print("\tMoving to: x=\(firstMonitorBounds.origin.x) y=\(firstMonitorBounds.origin.y)\n")

        CGConfigureDisplayOrigin(
            config,
            firstDisplay,
            Int32(secondMonitorBounds.origin.x.rounded()),
            Int32(secondMonitorBounds.origin.y.rounded())
        )
        CGConfigureDisplayOrigin(
            config,
            secondDisplay,
            Int32(firstMonitorBounds.origin.x.rounded()),
            Int32(firstMonitorBounds.origin.y.rounded())
        )
        return true
    }

    guard rotation, let mgr = mgr, let displays = displays,
          let display1 = displays.first(where: { $0.displayID == firstDisplay }),
          let display2 = displays.first(where: { $0.displayID == secondDisplay })
    else { return }

    guard display1.canChangeOrientation(), display2.canChangeOrientation()
    else {
        print("The monitors don't have the ability to change orientation")
        return
    }
    guard display1.orientation != display2.orientation
    else {
        print("Orientation is the same for both monitors")
        return
    }
    let rotation1 = display1.orientation
    let rotation2 = display2.orientation

    mgr.reconfigure { _ in
        print("Swapping orientation for \(display1.displayName ?? firstDisplay.s): \(rotation1) -> \(rotation2)")
        display1.orientation = rotation2
        print("Swapping orientation for \(display2.displayName ?? secondDisplay.s): \(rotation2) -> \(rotation1)")
        display2.orientation = rotation1
    }
}

extension BinaryInteger {
    var s: String { String(self) }
}

extension MPDisplayMgr {
    func reconfigure(tries: Int = 10, _ action: (MPDisplayMgr) -> Void) {
        guard tryLock(tries: tries) else {
            return
        }

        notifyWillReconfigure()
        action(self)
        notifyReconfigure()
        unlockAccess()
    }

    func tryLock(tries: Int = 10) -> Bool {
        for i in 1 ... tries {
            if tryLockAccess() { return true }
            print("Failed to acquire display manager lock (try: \(i))")
            Thread.sleep(forTimeInterval: 0.05)
        }
        return false
    }
}

extension Int32 {
    var cg: CGDirectDisplayID {
        CGDirectDisplayID(self)
    }
}

let mgr = MPDisplayMgr()
let displays = mgr?.displays as? [MPDisplay]

let builtinDisplay = displays?.first(where: \.isBuiltIn)?.displayID.cg ?? CGMainDisplayID()
let ids = NSScreen.onlineDisplayIDs
let externalIDs = ids.filter { $0 != builtinDisplay }
let screenMapping = [CGDirectDisplayID: NSScreen](uniqueKeysWithValues: ids.compactMap { id in
    guard let screen = NSScreen.screen(with: id) else { return nil }
    return (id, screen)
})
let screenGroupsByName = [String: [NSScreen]](
    grouping: NSScreen.screens, by: { screen in
        let s = screen.localizedName
        return NAME_STRIP_REGEX.stringByReplacingMatches(in: s, range: NSMakeRange(0, s.count), withTemplate: "$1")
    }
)

func printDisplays(_ displays: [MPDisplay]) {
    print("ID\tUUID                             \tOrientation\tName")
    for panel in displays {
        print("\(panel.displayID)\t\(panel.uuid?.uuidString ?? "")\t\(panel.orientation)°        \t\(panel.displayName ?? "Unknown name")")
    }
    print("")
}

let ROTATION_ARG_SET: NSOrderedSet = ["--no-rotation", "--no-orientation", "-nr"]
let PRINT_IDS_ARG_SET: NSOrderedSet = ["ids", "print-ids"]
let HELP_ARG_SET: NSOrderedSet = ["-h", "--help"]

func main() {
    let args = CommandLine.arguments
    let argSet = Set(args)
    let noSwapRotation = ROTATION_ARG_SET.intersectsSet(argSet)
    let arg1 = args.count == 2 ? args[1].lowercased() : ""

    if let displays = displays {
        printDisplays(displays)
    }

    if args.count == 2, PRINT_IDS_ARG_SET.contains(arg1) || HELP_ARG_SET.contains(arg1) {
        if HELP_ARG_SET.contains(arg1) {
            print("Usage: \(args[0]) [-nr|--no-rotation] ID1 ID2\n")
            print("IDs are optional if there are only 2 monitors with the same name\n")
        }

        let sortedIDs = externalIDs.sorted { d1, d2 in
            CGDisplayBounds(d1).origin.x < CGDisplayBounds(d2).origin.x
        }

        print("IDs of monitors in order of appearance from left to right: \(sortedIDs)")
        print("Names of monitors in order of appearance from left to right: \(sortedIDs.map { NSScreen.name(for: $0) ?? "Unknown" })")

        return
    }
    if args.count >= 3, let first = Int(args[args.count - 2]), let second = Int(args[args.count - 1]) {
        let firstDisplay = CGDirectDisplayID(first)
        let secondDisplay = CGDirectDisplayID(second)

        guard ids.contains(firstDisplay) else {
            print("Display \(firstDisplay) not found")
            return
        }
        guard ids.contains(secondDisplay) else {
            print("Display \(secondDisplay) not found")
            return
        }
        swap(firstDisplay: firstDisplay, secondDisplay: secondDisplay, rotation: !noSwapRotation)
        return
    }

    if let screensWithSameName = screenGroupsByName.values.first(where: { $0.count == 2 }),
       let firstDisplay = screensWithSameName[0].displayID, let secondDisplay = screensWithSameName[1].displayID
    {
        swap(firstDisplay: firstDisplay, secondDisplay: secondDisplay, rotation: !noSwapRotation)
        return
    }

    if let screensWithSameName = screenGroupsByName.first(where: { $0.value.count > 2 }) {
        print("Found \(screensWithSameName.value.count) external displays with the same name: \(screensWithSameName.key)")

        let sortedIDs = screensWithSameName.value.compactMap(\.displayID).sorted { d1, d2 in
            CGDisplayBounds(d1).origin.x < CGDisplayBounds(d2).origin.x
        }
        print("IDs of monitors in order of appearance from left to right: \(sortedIDs)")

        print("\nPass the IDs of the display that you want to swap as arguments")
        print("Example: \(args[0]) \(sortedIDs.first!) \(sortedIDs.last!)")
        return
    }

    guard let firstDisplay = externalIDs.first,
          let secondDisplay = externalIDs.first(where: { $0 != firstDisplay })
    else {
        print("At least two external displays are needed")
        return
    }

    swap(firstDisplay: firstDisplay, secondDisplay: secondDisplay, rotation: !noSwapRotation)
}

main()
