import Cocoa
import Foundation

func mediaKey(for key: String) -> Int32? {
    switch key.lowercased().replacingOccurrences(of: "[^a-z]", with: "", options: .regularExpression) {
    case "soundup", "volumeup":
        NX_KEYTYPE_SOUND_UP
    case "sounddown", "volumedown":
        NX_KEYTYPE_SOUND_DOWN
    case "play", "pause", "playpause":
        NX_KEYTYPE_PLAY
    case "next":
        NX_KEYTYPE_NEXT
    case "previous", "prev":
        NX_KEYTYPE_PREVIOUS
    case "fast":
        NX_KEYTYPE_FAST
    case "rewind":
        NX_KEYTYPE_REWIND
    case "brightnessup":
        NX_KEYTYPE_BRIGHTNESS_UP
    case "brightnessdown":
        NX_KEYTYPE_BRIGHTNESS_DOWN
    case "mute":
        NX_KEYTYPE_MUTE
    default:
        nil
    }
}

func printUsage() {
    print("Usage: SendMediaKey <key>")
    print("Available keys: volumeUp, volumeDown, playPause, next, previous, fast, rewind, brightnessUp, brightnessDown, mute")
}

let arguments = CommandLine.arguments
guard arguments.count > 1, !(arguments.contains("-h") || arguments.contains("--help")) else {
    printUsage()
    exit(1)
}

let keyString = arguments[1]
guard let mediaKey = mediaKey(for: keyString) else {
    print("Error: Invalid key name '\(keyString)'")
    printUsage()
    exit(1)
}

func HIDPostAuxKey(key: Int32) {
    func doKey(down: Bool) {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
        let data1 = Int((key << 16) | (down ? 0xA00 : 0xB00))

        let ev = NSEvent.otherEvent(
            with: NSEvent.EventType.systemDefined,
            location: NSPoint(x: 0, y: 0),
            modifierFlags: flags,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        let cev = ev?.cgEvent
        cev?.post(tap: CGEventTapLocation.cghidEventTap)
    }
    doKey(down: true)
    doKey(down: false)
}

HIDPostAuxKey(key: mediaKey)
RunLoop.main.run(until: Date() + 0.1)
