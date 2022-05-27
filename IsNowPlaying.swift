#!/usr/bin/env swift
import Foundation

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

    if playing {
        exit(0)
    } else {
        exit(1)
    }
}

RunLoop.main.run(until: .now + 0.1)
