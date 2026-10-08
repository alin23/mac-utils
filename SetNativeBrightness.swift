import Cocoa
import Foundation

guard CommandLine.arguments.count >= 3, let id = UInt32(CommandLine.arguments[1]), let br = Float(CommandLine.arguments[2]), (0 ... 1).contains(br) else {
    fputs("Usage: \(CommandLine.arguments[0]) <id> <brightness (0.0-1.0)>\n", stderr)
    fputs("\nDisplays:\n", stderr)
    for screen in NSScreen.screens {
        guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else { continue }
        fputs("  \(id)\t\(screen.localizedName.isEmpty ? "Unknown" : screen.localizedName)\(DisplayServicesCanChangeBrightness(id) ? "" : " (brightness not controllable)")\n", stderr)
    }
    exit(1)
}

guard DisplayServicesCanChangeBrightness(id) else {
    fputs("Display \(id) does not support native brightness control\n", stderr)
    exit(1)
}

let err = DisplayServicesSetBrightness(id, br)
guard err == 0 else {
    fputs("Failed to set brightness for display \(id) (error \(err))\n", stderr)
    exit(1)
}
