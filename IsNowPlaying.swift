#!/usr/bin/env swift
import Foundation

if CommandLine.arguments.count >= 2, ["-h", "--help"].contains(CommandLine.arguments[1]) {
    print("Usage: \(CommandLine.arguments[0]) [-q (exits with non-zero status code if not playing)] [-v (prints now playing info)]")
    exit(0)
}

let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))!

let MRMediaRemoteGetNowPlayingApplicationIsPlayingPointer = CFBundleGetFunctionPointerForName(
    bundle,
    "MRMediaRemoteGetNowPlayingApplicationIsPlaying" as CFString
)!
typealias MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
let MRMediaRemoteGetNowPlayingApplicationIsPlaying = unsafeBitCast(
    MRMediaRemoteGetNowPlayingApplicationIsPlayingPointer,
    to: MRMediaRemoteGetNowPlayingApplicationIsPlayingFunction.self
)

MRMediaRemoteGetNowPlayingApplicationIsPlaying(DispatchQueue.main) { playing in
    guard CommandLine.arguments.count >= 2, CommandLine.arguments[1] == "-q" else {
        print(playing)
        return
    }

    exit(playing ? 0 : 1)
}

guard CommandLine.arguments.count >= 2, !CommandLine.arguments.contains("-q"), CommandLine.arguments.contains("-v") else {
    RunLoop.main.run(until: Date() + 0.1)
    exit(0)
}

let MRMediaRemoteGetNowPlayingInfoPointer = CFBundleGetFunctionPointerForName(
    bundle,
    "MRMediaRemoteGetNowPlayingInfo" as CFString
)!
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
let MRMediaRemoteGetNowPlayingInfo = unsafeBitCast(
    MRMediaRemoteGetNowPlayingInfoPointer,
    to: MRMediaRemoteGetNowPlayingInfoFunction.self
)

let iso8601 = ISO8601DateFormatter()

// Recursively convert MediaRemote values into JSON-serializable ones,
// since the info dict contains Date, Data and other non-JSON types.
func jsonSerializable(_ value: Any) -> Any {
    switch value {
    case let date as Date:
        return iso8601.string(from: date)
    case let data as Data:
        return "<\(data.count) bytes>"
    case let array as [Any]:
        return array.map(jsonSerializable)
    case let dict as [String: Any]:
        return dict.mapValues(jsonSerializable)
    case let number as NSNumber:
        return number
    case let string as String:
        return string
    default:
        return String(describing: value)
    }
}

MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { info in
    guard var info else {
        print("No info")
        exit(1)
    }

    // set kMRMediaRemoteNowPlayingInfoArtworkData to "exists" to avoid crash
    if info["kMRMediaRemoteNowPlayingInfoArtworkData"] != nil {
        info["kMRMediaRemoteNowPlayingInfoArtworkData"] = "exists"
    }

    let sanitized = info.mapValues(jsonSerializable)
    if let data = try? JSONSerialization.data(
        withJSONObject: sanitized,
        options: [.prettyPrinted, .sortedKeys]
    ), let json = String(data: data, encoding: .utf8) {
        print(json)
    } else {
        print(info)
    }
}

RunLoop.main.run(until: Date() + 0.1)
