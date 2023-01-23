#!/usr/bin/env swift

// Inspired by: https://eclecticlight.co/2021/09/14/how-to-run-commands-and-scripts-on-efficiency-cores/

// Run directly:
//    chmod +x runbg.swift
//    ./runbg.swift
//
// Compile to static binary:
//    swiftc runbg.swift -o runbg
//    ./runbg
//
// Or download already compiled binary:
//    curl https://files.alinpanaitiu.com/runbg > /usr/local/bin/runbg
//    chmod +x /usr/local/bin/runbg
//    runbg

// Usage examples:
//    Optimize all images on the desktop: runbg imageoptim ~/Desktop
//    Re-encode video with ffmpeg to squeeze more bytes: runbg ffmpeg -i big-video.mp4 smaller-video.mp4
//    Compile project in background: runbg make -j 4

import Foundation

if CommandLine.arguments.count <= 1 {
    print(CommandLine.arguments[0], "executable args...")
    exit(1)
}

let SHELL = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
let FM = FileManager()

@discardableResult func asyncNow(timeout: TimeInterval, _ action: @escaping () -> Void) -> DispatchTimeoutResult {
    let task = DispatchWorkItem { action() }
    DispatchQueue.global().async(execute: task)

    let result = task.wait(timeout: DispatchTime.now() + timeout)
    if result == .timedOut {
        task.cancel()
    }

    return result
}

// MARK: - ProcessStatus

struct ProcessStatus {
    var output: Data?
    var error: Data?
    var success: Bool

    var o: String? {
        output?.s?.trimmed
    }

    var e: String? {
        error?.s?.trimmed
    }
}

func stdout(of process: Process) -> Data? {
    let stdout = process.standardOutput as! FileHandle
    try? stdout.close()

    guard let path = process.environment?["__swift_stdout"],
          let stdoutFile = FileHandle(forReadingAtPath: path) else { return nil }
    return try! stdoutFile.readToEnd()
}

func stderr(of process: Process) -> Data? {
    let stderr = process.standardOutput as! FileHandle
    try? stderr.close()

    guard let path = process.environment?["__swift_stderr"],
          let stderrFile = FileHandle(forReadingAtPath: path) else { return nil }
    return try! stderrFile.readToEnd()
}

func shellProc(_ launchPath: String = "/bin/zsh", args: [String], env: [String: String]? = nil) -> Process? {
    let outputDir = try! FM.url(
        for: .itemReplacementDirectory,
        in: .userDomainMask,
        appropriateFor: FM.homeDirectoryForCurrentUser,
        create: true
    )

    let stdoutFilePath = outputDir.appendingPathComponent("stdout").path
    FM.createFile(atPath: stdoutFilePath, contents: nil, attributes: nil)

    let stderrFilePath = outputDir.appendingPathComponent("stderr").path
    FM.createFile(atPath: stderrFilePath, contents: nil, attributes: nil)

    guard let stdoutFile = FileHandle(forWritingAtPath: stdoutFilePath),
          let stderrFile = FileHandle(forWritingAtPath: stderrFilePath)
    else {
        return nil
    }

    let task = Process()
    task.standardOutput = stdoutFile
    task.standardError = stderrFile
    task.launchPath = launchPath
    task.arguments = args

    var env = env ?? ProcessInfo.processInfo.environment
    env["__swift_stdout"] = stdoutFilePath
    env["__swift_stderr"] = stderrFilePath
    task.environment = env

    do {
        try task.run()
    } catch {
        print("Error running \(launchPath) \(args): \(error)")
        return nil
    }

    return task
}

func shell(
    _ launchPath: String = "/bin/zsh",
    command: String,
    timeout: TimeInterval? = nil,
    env _: [String: String]? = nil
) -> ProcessStatus {
    shell(launchPath, args: ["-c", command], timeout: timeout)
}

func shell(
    _ launchPath: String = "/bin/zsh",
    args: [String],
    timeout: TimeInterval? = nil,
    env: [String: String]? = nil
) -> ProcessStatus {
    guard let task = shellProc(launchPath, args: args, env: env) else {
        return ProcessStatus(output: nil, error: nil, success: false)
    }

    guard let timeout else {
        task.waitUntilExit()
        return ProcessStatus(
            output: stdout(of: task),
            error: stderr(of: task),
            success: task.terminationStatus == 0
        )
    }

    let result = asyncNow(timeout: timeout) {
        task.waitUntilExit()
    }
    if result == .timedOut {
        task.terminate()
    }

    return ProcessStatus(
        output: stdout(of: task),
        error: stderr(of: task),
        success: task.terminationStatus == 0
    )
}

extension String {
    @inline(__always) var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Data {
    var s: String? { String(data: self, encoding: .utf8) }
}

var executable = (CommandLine.arguments[1] as NSString).expandingTildeInPath
if !FM.fileExists(atPath: executable) {
    let which = shell(SHELL, command: "which '\(CommandLine.arguments[1])'")
    guard which.success, let output = which.o else {
        if let err = which.e {
            print(err)
        }
        print("\(executable) not found")
        exit(1)
    }
    executable = output
}

let p = Process()
p.qualityOfService = .background
p.executableURL = URL(fileURLWithPath: executable)
p.arguments = CommandLine.arguments.suffix(from: 2).map { $0 }

try! p.run()

signal(SIGINT) { _ in p.terminate() }
signal(SIGTERM) { _ in p.terminate() }
signal(SIGKILL) { _ in p.terminate() }

p.waitUntilExit()

exit(p.terminationStatus)
