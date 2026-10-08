import Cocoa
import Foundation

guard CommandLine.arguments.count >= 2, let bl = Float(CommandLine.arguments[1]), (0 ... 1).contains(bl) else {
    fputs("Usage: \(CommandLine.arguments[0]) <backlight (0.0-1.0)>\n", stderr)
    exit(1)
}

let kbc = KeyboardBrightnessClient()
// Keyboard IDs differ between Mac models, so ask for the backlit ones instead of assuming 1
let ids = kbc.copyKeyboardBacklightIDs()?.map(\.uint64Value) ?? []
let keyboards = ids.filter { kbc.isKeyboardBuilt(in: $0) }.nilIfEmpty ?? ids.nilIfEmpty ?? [1]

var failed = false
for id in keyboards where !kbc.setBrightness(bl, forKeyboard: id) {
    fputs("Failed to set the backlight of keyboard \(id)\n", stderr)
    failed = true
}
exit(failed ? 1 : 0)

extension Array {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
