#!/usr/bin/env swift
import Foundation

// Lists every Now Playing client (one per playing/paused media app) with its
// per-client info, and can send a transport command to a specific client.
//
// Subcommands:
//     list            (default) print every client, one per line (--json for JSON)
//     watch [filter]  poll ~1s and print pid/bundle/state/elapsed; pass a
//                     bundle-id substring (e.g. "spotify") to filter
//     play|pause|playpause|stop|next|previous <bundleID>   send that command
//     seek <bundleID> <seconds>   seek the client to an absolute position

let bundle = CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))!
func fn(_ name: String) -> UnsafeMutableRawPointer? { CFBundleGetFunctionPointerForName(bundle, name as CFString) }

typealias GetClientsFn = @convention(c) (DispatchQueue, @escaping (NSArray?) -> Void) -> Void
typealias ClientPIDFn = @convention(c) (AnyObject?) -> Int32
typealias ClientStrFn = @convention(c) (AnyObject?) -> Unmanaged<CFString>?
typealias InfoForClientFn = @convention(c) (AnyObject?, AnyObject?, Int32, DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
typealias SendToClientFn = @convention(c) (Int32, CFDictionary?, AnyObject?, AnyObject?, CFDictionary?, DispatchQueue?, @convention(block) (AnyObject?) -> Void) -> Bool
typealias GetLocalOriginFn = @convention(c) () -> AnyObject?

let getClients = unsafeBitCast(fn("MRMediaRemoteGetNowPlayingClients")!, to: GetClientsFn.self)
let getPID = fn("MRNowPlayingClientGetProcessIdentifier").map { unsafeBitCast($0, to: ClientPIDFn.self) }
let getBundle = fn("MRNowPlayingClientGetBundleIdentifier").map { unsafeBitCast($0, to: ClientStrFn.self) }
let getInfoForClient = unsafeBitCast(fn("MRMediaRemoteGetNowPlayingInfoForClient")!, to: InfoForClientFn.self)

struct ClientLine { let pid: Int32; let bundle: String; let title: String; let rate: Double; let elapsed: Double; let duration: Double }

func mmss(_ s: Double) -> String {
    guard s.isFinite, s >= 0 else { return "0:00" }
    let t = Int(s); return String(format: "%d:%02d", t / 60, t % 60)
}

func humanLine(_ l: ClientLine) -> String {
    let state = (l.rate > 0 ? "playing" : "paused").padding(toLength: 7, withPad: " ", startingAt: 0)
    let bundle = l.bundle.padding(toLength: 34, withPad: " ", startingAt: 0)
    return "\(bundle)  \(state)  \(mmss(l.elapsed)) / \(mmss(l.duration))  \(l.title)"
}

func snapshot(_ done: @escaping ([ClientLine]) -> Void) {
    getClients(.main) { clients in
        let arr = (clients as? [AnyObject]) ?? []
        guard !arr.isEmpty else { done([]); return }
        var out = [ClientLine?](repeating: nil, count: arr.count)
        let group = DispatchGroup()
        for (i, c) in arr.enumerated() {
            let pid = getPID?(c) ?? 0
            let bid = getBundle?(c)?.takeUnretainedValue() as String? ?? "?"
            group.enter()
            getInfoForClient(c, nil, 0, .main) { info in
                out[i] = ClientLine(
                    pid: pid, bundle: bid,
                    title: info?["kMRMediaRemoteNowPlayingInfoTitle"] as? String ?? "",
                    rate: info?["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0,
                    elapsed: info?["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0,
                    duration: info?["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0)
                group.leave()
            }
        }
        group.notify(queue: .main) { done(out.compactMap { $0 }.sorted { $0.pid < $1.pid }) }
    }
}

// Resolve a client by bundle id. Wrapping getClients in a function (rather than
// calling it at top-level script scope) is required: a closure passed to the
// Obj-C completion block from top-level code bridges as no-escape and traps when
// MediaRemote calls it back asynchronously.
func withClient(_ bundleID: String, _ body: @escaping (AnyObject) -> Void) {
    getClients(.main) { clients in
        let arr = (clients as? [AnyObject]) ?? []
        guard let c = arr.first(where: { (getBundle?($0)?.takeUnretainedValue() as String?) == bundleID }) else {
            print("\(bundleID) is not a Now Playing client right now"); exit(1)
        }
        body(c)
    }
}

// Line buffered, so `watch` output reaches a pipe as it happens instead of in 4 KB chunks
setvbuf(stdout, nil, _IOLBF, 0)

let raw = Array(CommandLine.arguments.dropFirst())
let asJSON = raw.contains("--json")
let positional = raw.filter { !$0.hasPrefix("-") }
let command = positional.first ?? "list"

func printUsage() {
    print("""
    Usage: NowPlayingClients [command]

      list [--json]            list every Now Playing client (default)
      watch [filter]           poll ~1s; optional bundle-id substring filter
      play <bundleID>          resume playback
      pause <bundleID>         pause playback
      playpause <bundleID>     toggle play/pause
      stop <bundleID>          stop playback
      next <bundleID>          next track
      previous <bundleID>      previous track
      seek <bundleID> <secs>   seek to an absolute position
      help, -h, --help         show this help
    """)
}

if command == "help" || raw.contains("-h") || raw.contains("--help") {
    printUsage(); exit(0)
}

func needBundle() -> String {
    guard positional.count > 1 else {
        FileHandle.standardError.write(Data("usage: \(command) <bundleID>\n".utf8)); exit(64)
    }
    return positional[1]
}

func sendCommand(_ code: Int32, to bundleID: String, userInfo: CFDictionary? = nil, note: String? = nil) {
    let send = unsafeBitCast(fn("MRMediaRemoteSendCommandToClient")!, to: SendToClientFn.self)
    let origin = unsafeBitCast(fn("MRMediaRemoteGetLocalOrigin")!, to: GetLocalOriginFn.self)()
    // The command is delivered asynchronously. Exit only when MediaRemote calls the
    // completion (after it has forwarded the command), not the instant send()
    // returns: exiting early invalidates the connection and aborts the relay
    // mid-flight. Binding the completion to a @convention(block) `let` keeps it a
    // real heap block (a closure literal would trap as an escaped no-escape block).
    let done: @convention(block) (AnyObject?) -> Void = { _ in exit(0) }
    withClient(bundleID) { client in
        let ret = send(code, userInfo, origin, client, nil, nil, done)
        print("\(bundleID): \(note ?? command) (\(ret))")
        if !ret { exit(1) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { exit(0) }  // safety net
    RunLoop.main.run(until: Date() + 3.0); exit(0)
}

switch command {
case "list":
    snapshot { lines in
        if asJSON {
            let json = lines.map { ["pid": $0.pid, "bundle": $0.bundle, "title": $0.title, "rate": $0.rate, "elapsed": $0.elapsed, "duration": $0.duration] as [String: Any] }
            if let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
               let s = String(data: data, encoding: .utf8) { print(s) }
        } else if lines.isEmpty {
            print("Nothing playing")
        } else {
            for l in lines { print(humanLine(l) + "  (pid \(l.pid))") }
        }
        exit(0)
    }
    RunLoop.main.run(until: Date() + 3.0)
    FileHandle.standardError.write(Data("MediaRemote did not answer within 3 seconds\n".utf8))
    exit(1)

case "watch":
    let filter = positional.count > 1 ? positional[1].lowercased() : nil
    func tick() {
        snapshot { lines in
            let stamp = ISO8601DateFormatter().string(from: Date())
            for l in lines where filter == nil || l.bundle.lowercased().contains(filter!) {
                print("\(stamp)  \(humanLine(l))")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { tick() }
        }
    }
    tick()
    RunLoop.main.run()

case "play": sendCommand(0, to: needBundle())
case "pause": sendCommand(1, to: needBundle())
case "playpause": sendCommand(2, to: needBundle())
case "stop": sendCommand(3, to: needBundle())
case "next": sendCommand(4, to: needBundle())
case "previous", "prev": sendCommand(5, to: needBundle())

case "seek":
    guard positional.count > 2, let pos = Double(positional[2]) else {
        FileHandle.standardError.write(Data("usage: seek <bundleID> <seconds>\n".utf8)); exit(64)
    }
    guard let keyPtr = CFBundleGetDataPointerForName(bundle, "kMRMediaRemoteOptionPlaybackPosition" as CFString) else {
        print("missing playback-position key"); exit(1)
    }
    let userInfo = [keyPtr.load(as: CFString.self): pos] as CFDictionary
    sendCommand(24, to: positional[1], userInfo: userInfo, note: "seek -> \(mmss(pos))")  // 24 = SeekToPlaybackPosition

default:
    FileHandle.standardError.write(Data("unknown command: \(command)\n".utf8)); exit(64)
}
