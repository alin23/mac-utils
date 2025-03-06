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

MRMediaRemoteGetNowPlayingInfo(DispatchQueue.main) { info in
    guard var info else {
        print("No info")
        exit(1)
    }

    // set kMRMediaRemoteNowPlayingInfoArtworkData to "exists" to avoid crash
    if info["kMRMediaRemoteNowPlayingInfoArtworkData"] != nil {
        info["kMRMediaRemoteNowPlayingInfoArtworkData"] = "exists"
    }

    print(info)
}

RunLoop.main.run(until: Date() + 0.1)
