// OCRRegion: select a screen region, OCR it with Vision's document recognizer and copy the text,
// keeping line breaks, indentation, list markers and tables (as tab separated rows).
//
// Run with --help for usage.

import AppKit
import Carbon.HIToolbox
import NaturalLanguage
import SwiftUI
import Vision

typealias Container = DocumentObservation.Container

/// One line of text, or a whole list or table, positioned in normalized image coordinates (y up).
struct Unit {
    let rect: CGRect
    let text: String
    var paragraph = -1  // index of the Vision paragraph a line came from, -1 for lists and tables
    var indentable = false
    var top: CGFloat { rect.maxY }
    var bottom: CGFloat { rect.minY }
}

func median(_ xs: [CGFloat]) -> CGFloat? { xs.isEmpty ? nil : xs.sorted()[xs.count / 2] }

func render(list: Container.List, indent: String = "") -> String {
    list.items.map { item in
        let marker = item.markerString.trimmingCharacters(in: .whitespaces)
        var body = item.itemString.trimmingCharacters(in: .whitespacesAndNewlines)
        // itemString sometimes already starts with the marker
        if !marker.isEmpty, body.hasPrefix(marker) {
            body = String(body.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        }
        let continuation = indent + String(repeating: " ", count: marker.count + 1)
        body = body.replacingOccurrences(of: "\n", with: "\n" + continuation)
        return indent + (marker.isEmpty ? "" : marker + " ") + body
    }.joined(separator: "\n")
}

func render(table: Container.Table) -> String {
    // Tab separated so it pastes into a spreadsheet as cells
    table.rows.map { row in
        row.map { cell in
            cell.content.text.transcript
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\t")
    }.joined(separator: "\n")
}

/// Vision reads Romanian ș/ț as the Turkish cedilla forms ş/ţ, which look the same but break search and spellcheck.
func fixDiacritics(_ s: String) -> String {
    guard s.contains(where: { "şţŞŢ".contains($0) }), NLLanguageRecognizer.dominantLanguage(for: s) == .romanian else { return s }
    return s.replacingOccurrences(of: "ş", with: "ș").replacingOccurrences(of: "ţ", with: "ț")
        .replacingOccurrences(of: "Ş", with: "Ș").replacingOccurrences(of: "Ţ", with: "Ț")
}

func render(_ doc: Container) -> String {
    var units: [Unit] = []
    let structured = (doc.lists.map(\.boundingRegion) + doc.tables.map(\.boundingRegion)).map(\.boundingBox.cgRect)

    for list in doc.lists {
        units.append(Unit(rect: list.boundingRegion.boundingBox.cgRect, text: render(list: list)))
    }
    for table in doc.tables {
        units.append(Unit(rect: table.boundingRegion.boundingBox.cgRect, text: render(table: table)))
    }
    for (i, p) in doc.paragraphs.enumerated() {
        for line in p.lines {
            let r = line.boundingBox.cgRect
            // Paragraphs repeat the text of lists and tables, drop lines that sit inside one
            let centre = CGPoint(x: r.midX, y: r.midY)
            guard !structured.contains(where: { $0.insetBy(dx: -0.01, dy: -r.height / 2).contains(centre) }) else { continue }
            guard let text = line.topCandidates(1).first?.string, !text.isEmpty else { continue }
            units.append(Unit(rect: r, text: text, paragraph: i, indentable: p.textAlignment != .center))
        }
    }
    guard !units.isEmpty else { return "" }

    // Rows top to bottom; units sharing a row (columns, table-like layouts) go left to right
    units.sort { abs($0.rect.midY - $1.rect.midY) > min($0.rect.height, $1.rect.height) / 2 ? $0.top > $1.top : $0.rect.minX < $1.rect.minX }

    let lines = units.filter { $0.paragraph >= 0 }
    let lineHeight = median(lines.map(\.rect.height)) ?? 0.03
    let charWidth = median(lines.filter { $0.text.count >= 4 }.map { $0.rect.width / CGFloat($0.text.count) }) ?? 0.01
    let minX = lines.map(\.rect.minX).min() ?? 0

    var out = ""
    var prev: Unit?
    for u in units {
        var text = fixDiacritics(u.text)
        if u.indentable {
            // Leading whitespace from the x offset, so code and nested text keep their shape
            let spaces = Int(((u.rect.minX - minX) / charWidth).rounded())
            if spaces >= 2 { text = String(repeating: " ", count: spaces) + text }
        }
        if let p = prev {
            let sameRow = abs(p.rect.midY - u.rect.midY) < min(p.rect.height, u.rect.height) / 2
            if sameRow {
                out += "\t"
                text = text.trimmingCharacters(in: .whitespaces)
            } else if p.paragraph >= 0, p.paragraph == u.paragraph || p.bottom - u.top < lineHeight * 0.5 {
                out += "\n"
            } else {
                out += p.bottom - u.top < lineHeight * 0.5 && (p.paragraph < 0) == (u.paragraph < 0) ? "\n" : "\n\n"
            }
        }
        out += text
        prev = u
    }
    return out
}

/// Plain line OCR, for snippets the document recognizer finds no structure in.
func plainLines(_ url: URL) async throws -> String {
    var req = RecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.automaticallyDetectsLanguage = true
    req.usesLanguageCorrection = false
    let obs = try await req.perform(on: url)
    return obs
        .sorted { $0.boundingBox.cgRect.maxY > $1.boundingBox.cgRect.maxY }
        .compactMap { $0.topCandidates(1).first?.string }
        .joined(separator: "\n")
}

func ocr(_ url: URL, debug: Bool = false) async throws -> String {
    var req = RecognizeDocumentsRequest()
    req.textRecognitionOptions.automaticallyDetectLanguage = true
    // Correction rewrites code (`greet(` becomes `greet (`) and drops diacritics it does not expect
    req.textRecognitionOptions.useLanguageCorrection = false
    req.barcodeDetectionOptions.enabled = false
    let docs = try await req.perform(on: url)

    if debug {
        for d in docs {
            let c = d.document
            print("== paragraphs: \(c.paragraphs.count), lists: \(c.lists.count), tables: \(c.tables.count), title: \(c.title?.transcript ?? "-")")
            for p in c.paragraphs { print("-- P top=\(p.boundingRegion.boundingBox.cgRect.maxY) lines=\(p.lines.count)\n\(p.transcript)") }
            for l in c.lists { for i in l.items { print("-- LI marker=\(i.markerString.debugDescription) type=\(String(describing: i.markerType)) item=\(i.itemString.debugDescription)") } }
        }
    }

    let text = docs.map { render($0.document) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    return text.isEmpty ? try await plainLines(url) : text
}

struct Code {
    let payload: String
    let isQR: Bool
    let area: CGFloat  // fraction of the image
}

func codes(_ url: URL) async throws -> [Code] {
    let obs = try await DetectBarcodesRequest().perform(on: url)
    var seen = Set<String>()
    return obs
        .sorted { $0.boundingBox.cgRect.maxY > $1.boundingBox.cgRect.maxY }
        .compactMap { o -> Code? in
            // Binary payloads (some Data Matrix and Aztec codes) are copied as hex
            guard let payload = o.payloadString ?? o.payloadData.map({ $0.map { String(format: "%02x", $0) }.joined() }),
                  !payload.isEmpty, seen.insert(payload).inserted else { return nil }
            let r = o.boundingBox.cgRect
            return Code(payload: payload, isQR: o.symbology == .qr || o.symbology == .microQR, area: r.width * r.height)
        }
}

/// What to copy: codes win when the selection is mostly code or holds little text besides them,
/// otherwise the text is copied with any decoded payloads after it.
func recognize(_ url: URL) async throws -> (copied: String, toast: Toast) {
    async let textResult = ocr(url)
    async let codeResult = codes(url)
    let text = try await textResult.trimmingCharacters(in: .whitespacesAndNewlines)
    let found = (try? await codeResult) ?? []

    if !found.isEmpty, found.reduce(0, { $0 + $1.area }) > 0.1 || text.count < 40 {
        let payload = found.map(\.payload).joined(separator: "\n")
        let title = found.count > 1 ? "Copied \(found.count) codes" : found[0].isQR ? "Copied QR code" : "Copied barcode"
        return (payload, Toast(kind: found[0].isQR ? .qr : .barcode, title: title, detail: payload))
    }
    guard !text.isEmpty else { return ("", Toast(kind: .nothing, title: "No text found")) }
    let copied = found.isEmpty ? text : text + "\n\n" + found.map(\.payload).joined(separator: "\n")
    return (copied, Toast(kind: .text, title: "Copied", detail: copied))
}

// MARK: - Toast
struct Toast {
    enum Kind { case text, qr, barcode, nothing, failed }

    let kind: Kind
    let title: String
    var detail: String?

    var icon: String {
        switch kind {
        case .text: "checkmark"
        case .qr: "qrcode"
        case .barcode: "barcode"
        case .nothing: "text.magnifyingglass"
        case .failed: "exclamationmark"
        }
    }

    /// Badge fill and glyph ink. The glass turns light or dark by itself depending on what is behind it,
    /// so neither colour follows the system appearance: a deep glyph on a pastel badge reads on both.
    var colors: (fill: Color, ink: Color) {
        switch kind {
        case .text: (.hex(0xB7EBCF), .hex(0x1F6B47))         // mint
        case .qr, .barcode: (.hex(0xC9D0FF), .hex(0x3443A8)) // periwinkle
        case .nothing: (.hex(0xDAD6E8), .hex(0x4E4966))      // lilac grey
        case .failed: (.hex(0xFFD0BF), .hex(0x9A3A1C))       // peach
        }
    }

    var succeeded: Bool { kind == .text || kind == .qr || kind == .barcode }
}

extension Color {
    static func hex(_ v: Int) -> Color {
        Color(.sRGB, red: Double(v >> 16 & 0xFF) / 255, green: Double(v >> 8 & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

/// Whitespace runs (line breaks included) become single spaces, the view truncates the middle.
func snippet(_ s: String) -> String {
    s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

struct ToastView: View {
    let toast: Toast
    let done: () -> Void

    @State private var shown = false
    @State private var bounce = 0

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(toast.colors.ink)
                .symbolEffect(.bounce.up.byLayer, value: toast.succeeded ? bounce : 0)
                .symbolEffect(.wiggle, value: toast.succeeded ? 0 : bounce)
                .frame(width: 28, height: 28)
                .background(toast.colors.fill, in: .circle)
                // Keeps the badge edge visible on very light glass
                .overlay(Circle().strokeBorder(toast.colors.ink.opacity(0.18), lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                if let detail = toast.detail, !detail.isEmpty {
                    Text(snippet(detail))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 380, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(toast.colors.fill.opacity(0.2)), in: .capsule)
        .scaleEffect(shown ? 1 : 0.7, anchor: .bottom)
        .offset(y: shown ? 0 : 24)
        .blur(radius: shown ? 0 : 10)
        .opacity(shown ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 12)
        .task {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { shown = true }
            try? await Task.sleep(for: .milliseconds(120))
            bounce += 1
            let hold = toast.succeeded ? 1.4 : 2.2
            try? await Task.sleep(for: .seconds(hold))
            withAnimation(.easeIn(duration: 0.22)) { shown = false }
            try? await Task.sleep(for: .milliseconds(260))
            done()
        }
    }
}

/// Shows the toast at the bottom middle of the screen under the pointer, then calls `done` once it has faded out.
@MainActor
func showToast(_ toast: Toast, done: @escaping () -> Void) {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
    // Larger than the pill so the spring overshoot, blur and glass shadow are never clipped
    let size = NSSize(width: 560, height: 140)
    let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.minY + 40)

    let panel = NSPanel(contentRect: NSRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.level = .statusBar
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.contentView = NSHostingView(rootView: ToastView(toast: toast, done: { panel.orderOut(nil); done() }))
    panel.orderFrontRegardless()
}

// MARK: - Main

func copy(_ s: String) {
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.setString(s, forType: .string)
}

func capture(to file: URL) async throws {
    let cap = Process()
    cap.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    cap.arguments = ["-i", "-x", "-r", file.path]
    try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
        cap.terminationHandler = { _ in c.resume() }
        do { try cap.run() } catch { c.resume(throwing: error) }
    }
}

// MARK: - Hotkey

let keyCodes: [String: Int] = [
    "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G,
    "h": kVK_ANSI_H, "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L, "m": kVK_ANSI_M, "n": kVK_ANSI_N,
    "o": kVK_ANSI_O, "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U,
    "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X, "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
    "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3, "4": kVK_ANSI_4,
    "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal, "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
    ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote, ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period,
    "/": kVK_ANSI_Slash, "\\": kVK_ANSI_Backslash, "`": kVK_ANSI_Grave, "space": kVK_Space,
    "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
    "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
]

/// Parses shortcuts like `cmd+shift+2` or `ctrl+alt+o` into a Carbon key code and modifier mask.
func parseShortcut(_ spec: String) -> (key: UInt32, modifiers: UInt32)? {
    var key: Int?
    var modifiers = 0
    for part in spec.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
        switch part {
        case "cmd", "command": modifiers |= cmdKey
        case "shift": modifiers |= shiftKey
        case "alt", "opt", "option": modifiers |= optionKey
        case "ctrl", "control": modifiers |= controlKey
        default:
            guard key == nil, let code = keyCodes[part] else { return nil }
            key = code
        }
    }
    guard let key else { return nil }
    return (UInt32(key), UInt32(modifiers))
}

nonisolated(unsafe) var hotKeyAction: (() -> Void)?
nonisolated(unsafe) var hotKeyRef: EventHotKeyRef?

/// Carbon hotkeys need no Accessibility permission and fire even while another app is focused.
func registerHotKey(_ shortcut: (key: UInt32, modifiers: UInt32), action: @escaping () -> Void) -> Bool {
    hotKeyAction = action
    var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        DispatchQueue.main.async { hotKeyAction?() }
        return noErr
    }, 1, &type, nil, nil)
    let id = EventHotKeyID(signature: OSType(0x4F43_5252), id: 1) // "OCRR"
    return RegisterEventHotKey(shortcut.key, shortcut.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef) == noErr
}

// MARK: - Login item

let agentLabel = "com.github.alin23.mac-utils.OCRRegion"
let agentPlist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(agentLabel).plist")

@discardableResult
func launchctl(_ args: String...) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    p.standardError = FileHandle.nullDevice
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
}

/// Writes a LaunchAgent that runs `OCRRegion --listen <shortcut>` at login, and starts it now.
func installAgent(shortcut: String) throws {
    let exe = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().standardizedFileURL.path
    let plist: [String: Any] = [
        "Label": agentLabel,
        "ProgramArguments": [exe, "--listen", shortcut],
        "RunAtLoad": true,
        "ProcessType": "Interactive",
    ]
    try FileManager.default.createDirectory(at: agentPlist.deletingLastPathComponent(), withIntermediateDirectories: true)
    try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: agentPlist)
    let domain = "gui/\(getuid())"
    launchctl("bootout", "\(domain)/\(agentLabel)")
    guard launchctl("bootstrap", domain, agentPlist.path) == 0 else {
        throw NSError(domain: "OCRRegion", code: 1, userInfo: [NSLocalizedDescriptionKey: "launchctl bootstrap failed for \(agentPlist.path)"])
    }
}

func uninstallAgent() {
    launchctl("bootout", "gui/\(getuid())/\(agentLabel)")
    try? FileManager.default.removeItem(at: agentPlist)
}

// MARK: - Entry point

func fail(_ message: String) -> Never {
    FileHandle.standardError.write("OCRRegion: \(message)\n".data(using: .utf8)!)
    exit(1)
}

/// Captures a region and copies what is in it. Returns nil when the capture was cancelled with Esc.
@MainActor
func captureAndCopy() async -> Toast? {
    let file = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("OCRRegion-\(UUID().uuidString).png")
    defer { try? FileManager.default.removeItem(at: file) }
    do { try await capture(to: file) } catch { return Toast(kind: .failed, title: "Recognition failed", detail: error.localizedDescription) }
    guard FileManager.default.fileExists(atPath: file.path) else { return nil }

    do {
        let result = try await recognize(file)
        if !result.copied.isEmpty {
            copy(result.copied)
            NSSound(named: "Tink")?.play()
        }
        return result.toast
    } catch {
        return Toast(kind: .failed, title: "Recognition failed", detail: error.localizedDescription)
    }
}

let usage = """
    Usage:
      OCRRegion                       select a region, copy its text or decoded codes
      OCRRegion --listen [shortcut]   stay running and capture on a global shortcut (default cmd+shift+2)
      OCRRegion --install [shortcut]  run --listen at login through a LaunchAgent, starting now
      OCRRegion --uninstall           remove that LaunchAgent
      OCRRegion <image>               print what an image file contains
      OCRRegion --debug <image>       also dump the blocks Vision found
      OCRRegion --toast <image>       show the toast for an image file, clipboard untouched
    """

@MainActor
func run(_ args: [String]) async {
    var args = args
    switch args.first {
    case "-h", "--help":
        print(usage)
        exit(0)

    case "--listen":
        let spec = args.count > 1 ? args[1] : "cmd+shift+2"
        guard let shortcut = parseShortcut(spec) else { fail("can't parse shortcut \(spec)\n\n\(usage)") }
        var busy = false
        let registered = registerHotKey(shortcut) {
            guard !busy else { return }
            busy = true
            Task { @MainActor in
                guard let toast = await captureAndCopy() else { busy = false; return }
                showToast(toast) { busy = false }
            }
        }
        guard registered else { fail("\(spec) is already taken by another app") }
        return // keep running

    case "--install":
        let spec = args.count > 1 ? args[1] : "cmd+shift+2"
        guard parseShortcut(spec) != nil else { fail("can't parse shortcut \(spec)\n\n\(usage)") }
        do { try installAgent(shortcut: spec) } catch { fail(error.localizedDescription) }
        print("Installed \(agentPlist.path), listening on \(spec)")
        exit(0)

    case "--uninstall":
        uninstallAgent()
        exit(0)

    default: break
    }

    let debug = args.first == "--debug"
    if debug { args.removeFirst() }
    let toastOnly = args.first == "--toast"
    if toastOnly { args.removeFirst() }

    guard let path = args.first else {
        guard let toast = await captureAndCopy() else { exit(0) }
        showToast(toast) { exit(toast.succeeded ? 0 : 1) }
        return
    }

    let file = URL(fileURLWithPath: path)
    do {
        if toastOnly {
            let toast = try await recognize(file).toast
            showToast(toast) { exit(0) }
            return
        }
        if debug { _ = try await ocr(file, debug: true) }
        print(try await recognize(file).copied)
        exit(0)
    } catch {
        fail("\(error)")
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in await run(Array(CommandLine.arguments.dropFirst())) }
app.run()
