#!/usr/bin/env swift

// Run directly:
//    chmod +x runfg.swift
//    ./runfg.swift
//
// Compile to static binary:
//    swiftc runfg.swift -o runfg
//    ./runfg
//
// Or download already compiled binary:
//    curl https://files.alinpanaitiu.com/runfg > /usr/local/bin/runfg
//    chmod +x /usr/local/bin/runfg
//    runfg

// Usage examples:
//    Optimize all images on the desktop: runfg imageoptim ~/Desktop
//    Re-encode video with ffmpeg to squeeze more bytes: runfg ffmpeg -i big-video.mp4 smaller-video.mp4
//    Compile project in background: runfg make -j 4

import Foundation

let args = CommandLine.arguments
if args.count <= 1 || ["-h", "--help"].contains(args[1]) {
    print("Usage: \((args[0] as NSString).lastPathComponent) <executable> [args...]")
    exit(args.count <= 1 ? 1 : 0)
}

let FM = FileManager.default

/// Resolves a command like the shell would: paths are used as they are, bare names are looked up in $PATH.
func resolve(_ command: String) -> String? {
    let expanded = (command as NSString).expandingTildeInPath
    if expanded.contains("/") {
        return FM.isExecutableFile(atPath: expanded) ? expanded : nil
    }
    let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
    for dir in path.split(separator: ":") {
        let candidate = (String(dir) as NSString).appendingPathComponent(expanded)
        var isDir: ObjCBool = false
        if FM.fileExists(atPath: candidate, isDirectory: &isDir), !isDir.boolValue, FM.isExecutableFile(atPath: candidate) {
            return candidate
        }
    }
    return nil
}

guard let executable = resolve(args[1]) else {
    fputs("\(args[1]): command not found\n", stderr)
    exit(127)
}

let p = Process()
p.qualityOfService = .userInteractive
p.executableURL = URL(fileURLWithPath: executable)
p.arguments = Array(args.dropFirst(2))

// Forward the signals that stop us to the child, so it gets a chance to clean up
for sig in [SIGINT, SIGTERM, SIGHUP] {
    signal(sig) { s in kill(p.processIdentifier, s) }
}

do {
    try p.run()
} catch {
    fputs("\(args[1]): \(error.localizedDescription)\n", stderr)
    exit(126)
}

p.waitUntilExit()

// Same convention as the shell: 128 + signal number when the child was killed by a signal
exit(p.terminationReason == .uncaughtSignal ? 128 + p.terminationStatus : p.terminationStatus)
