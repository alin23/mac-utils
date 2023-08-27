import Cocoa
import Foundation

guard CommandLine.arguments.count >= 2, let bl = Float(CommandLine.arguments[1]) else {
    print("Usage: \(CommandLine.arguments[0]) <backlight (0.0-1.0)>")
    exit(1)
}

let kbc = KeyboardBrightnessClient()
kbc.setBrightness(bl, forKeyboard: 1)
