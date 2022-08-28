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

func swap(firstDisplay: CGDirectDisplayID, secondDisplay: CGDirectDisplayID) {
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
}

let macBookDisplay = CGMainDisplayID()
let ids = NSScreen.onlineDisplayIDs
let externalIDs = ids.filter { $0 != macBookDisplay }
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

func main() {
    if CommandLine.arguments.count == 2, ["ids", "-h", "--help", "print-ids"].contains(CommandLine.arguments[1].lowercased()) {
        if ["-h", "--help"].contains(CommandLine.arguments[1].lowercased()) {
            print("Usage: \(CommandLine.arguments[0]) ID1 ID2 ")
            print("IDs are optional if there are only 2 monitors with the same name\n")
        }

        let sortedIDs = externalIDs.sorted { d1, d2 in
            CGDisplayBounds(d1).origin.x < CGDisplayBounds(d2).origin.x
        }

        print("IDs of monitors in order of appearance from left to right: \(sortedIDs)")
        print("Names of monitors in order of appearance from left to right: \(sortedIDs.map { NSScreen.name(for: $0) ?? "Unknown" })")

        return
    }
    if CommandLine.arguments.count == 3, let first = Int(CommandLine.arguments[1]), let second = Int(CommandLine.arguments[2]) {
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
        swap(firstDisplay: firstDisplay, secondDisplay: secondDisplay)
        return
    }

    if let screensWithSameName = screenGroupsByName.values.first(where: { $0.count == 2 }),
       let firstDisplay = screensWithSameName[0].displayID, let secondDisplay = screensWithSameName[1].displayID
    {
        swap(firstDisplay: firstDisplay, secondDisplay: secondDisplay)
        return
    }

    if let screensWithSameName = screenGroupsByName.first(where: { $0.value.count > 2 }) {
        print("Found \(screensWithSameName.value.count) external displays with the same name: \(screensWithSameName.key)")

        let sortedIDs = screensWithSameName.value.compactMap(\.displayID).sorted { d1, d2 in
            CGDisplayBounds(d1).origin.x < CGDisplayBounds(d2).origin.x
        }
        print("IDs of monitors in order of appearance from left to right: \(sortedIDs)")

        print("\nPass the IDs of the display that you want to swap as arguments")
        print("Example: \(CommandLine.arguments[0]) \(sortedIDs.first!) \(sortedIDs.last!)")
        return
    }

    guard let firstDisplay = externalIDs.first,
          let secondDisplay = externalIDs.first(where: { $0 != firstDisplay })
    else {
        print("At least two external displays are needed")
        return
    }

    swap(firstDisplay: firstDisplay, secondDisplay: secondDisplay)
}

main()
