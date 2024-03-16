import Foundation

let TRUE_VALUES = ["enable", "on", "true", "yes", "1"]

guard CommandLine.arguments.count >= 2 else {
    print("Usage: \(CommandLine.arguments[0]) [on|off]")
    exit(1)
}
let shouldEnable = TRUE_VALUES.contains(CommandLine.arguments[1])

CGSEnableHDR(1, shouldEnable, 0, 0)
