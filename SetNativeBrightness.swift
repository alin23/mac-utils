import Cocoa
import Foundation

guard CommandLine.arguments.count >= 3, let id = UInt32(CommandLine.arguments[1]), let br = Float(CommandLine.arguments[2]) else {
    print("Usage: \(CommandLine.arguments[0]) <id> <brightness>")
    exit(1)
}

DisplayServicesSetBrightness(id, br)
DisplayServicesBrightnessChanged(id, Double(br))
