import Foundation

private final class LockedStringLines: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ value: String) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }

    func joinedSuffix(_ count: Int, separator: String = "\n") -> String {
        lock.lock()
        let value = storage.suffix(count).joined(separator: separator)
        lock.unlock()
        return value
    }
}

private final class LockedResultBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Result<T, Error>?

    func set(_ newValue: Result<T, Error>) {
        lock.lock()
        value = newValue
        lock.unlock()
    }

    func get() -> Result<T, Error>? {
        lock.lock()
        let current = value
        lock.unlock()
        return current
    }
}

struct PythonRuntimeExecutor {
    private static let bridgePrefix = "__MCS_BRIDGE__:"
    private static let pythonCandidatePaths = [
        "/opt/homebrew/bin/python3",
        "/usr/local/bin/python3",
        "/usr/bin/python3",
        "/Library/Developer/CommandLineTools/usr/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/Current/bin/python3"
    ]

    private static let pythonPrelude = #"""
import base64
import json
import os
import sys
import time

_BRIDGE_PREFIX = "__MCS_BRIDGE__:"

def _bridge_request(command, **params):
    payload = json.dumps({"command": command, "params": params}, ensure_ascii=False)
    sys.stdout.write(_BRIDGE_PREFIX + payload + "\n")
    sys.stdout.flush()

    line = sys.stdin.readline()
    if not line:
        raise RuntimeError("MacClickStudio bridge closed")
    if not line.startswith(_BRIDGE_PREFIX):
        raise RuntimeError("MacClickStudio bridge protocol error")

    response = json.loads(line[len(_BRIDGE_PREFIX):])
    if not response.get("ok", False):
        raise RuntimeError(response.get("error") or "Unknown bridge error")
    return response.get("value")


def log(*items):
    sys.stdout.write(" ".join(str(item) for item in items) + "\n")
    sys.stdout.flush()


print = log


def sleep_ms(milliseconds):
    time.sleep(max(0, int(milliseconds)) / 1000.0)


def sleep(milliseconds):
    sleep_ms(milliseconds)


def rect(x, y, width, height):
    return {
        "x": int(x),
        "y": int(y),
        "width": int(width),
        "height": int(height),
    }


def point(x, y):
    return {
        "x": int(x),
        "y": int(y),
    }


def _normalize_rect(value):
    if not value:
        return None
    return {
        "x": int(value.get("x", 0)),
        "y": int(value.get("y", 0)),
        "width": int(value.get("width", 0)),
        "height": int(value.get("height", 0)),
    }


def click(x, y):
    return bool(_bridge_request("click", x=float(x), y=float(y)))


def long_press(x, y, milliseconds=700):
    return bool(_bridge_request("longPress", x=float(x), y=float(y), milliseconds=int(milliseconds)))


def longPress(x, y, milliseconds=700):
    return long_press(x, y, milliseconds)


def drag(start_x, start_y, end_x, end_y, milliseconds=280):
    return bool(_bridge_request(
        "drag",
        startX=float(start_x),
        startY=float(start_y),
        endX=float(end_x),
        endY=float(end_y),
        milliseconds=int(milliseconds),
    ))


def drag_to(start_x, start_y, end_x, end_y, milliseconds=280):
    return drag(start_x, start_y, end_x, end_y, milliseconds)


def get_color(x, y):
    return _bridge_request("getColorHex", x=float(x), y=float(y)) or ""


def getColor(x, y):
    return get_color(x, y)


def wait_until(predicate, timeout_ms=3000, interval_ms=120):
    start = time.time()
    while (time.time() - start) * 1000 < timeout_ms:
        if predicate():
            return True
        sleep_ms(interval_ms)
    return False


def wait_color(x, y, hex, tolerance=8, timeout_ms=3000, interval_ms=120):
    return wait_until(
        lambda: bool(_bridge_request("colorMatch", x=float(x), y=float(y), hex=str(hex), tolerance=int(tolerance))),
        timeout_ms,
        interval_ms,
    )


def waitColor(x, y, hex, tolerance=8, timeoutMs=3000, intervalMs=120):
    return wait_color(x, y, hex, tolerance, timeoutMs, intervalMs)


def ocr_text(x, y, width, height):
    return _bridge_request("ocr", x=float(x), y=float(y), width=float(width), height=float(height)) or ""


def find_image(template_name, search_rect=None, threshold=0.94):
    return _bridge_request(
        "findImage",
        templateName=str(template_name),
        rect=_normalize_rect(search_rect),
        threshold=float(threshold),
    )


def findImage(template_name, search_rect=None, threshold=0.94):
    return find_image(template_name, search_rect, threshold)


def find_color(hex, search_rect=None, tolerance=12):
    return _bridge_request(
        "findColor",
        hex=str(hex),
        rect=_normalize_rect(search_rect),
        tolerance=int(tolerance),
    )


def findColor(hex, search_rect=None, tolerance=12):
    return find_color(hex, search_rect, tolerance)


def click_template(template_name, search_rect=None, threshold=0.94):
    match = find_image(template_name, search_rect, threshold)
    if not match:
        return False
    return click(match["x"], match["y"])


def clickTemplate(template_name, search_rect=None, threshold=0.94):
    return click_template(template_name, search_rect, threshold)


def click_color(hex, search_rect=None, tolerance=12):
    match = find_color(hex, search_rect, tolerance)
    if not match:
        return False
    return click(match["x"], match["y"])


def clickColor(hex, search_rect=None, tolerance=12):
    return click_color(hex, search_rect, tolerance)


def window_bounds(owner_name, title=""):
    return _bridge_request("windowBounds", ownerName=str(owner_name), title=str(title))


def current_window():
    return _bridge_request("currentWindow")


def currentWindow():
    return current_window()


def current_window_rect():
    win = current_window()
    if not win:
        return None
    return rect(win["x"], win["y"], win["width"], win["height"])


def currentWindowRect():
    return current_window_rect()


def click_relative(x, y):
    win = current_window()
    if not win:
        return False
    return click(win["x"] + x, win["y"] + y)


def clickRelative(x, y):
    return click_relative(x, y)


def long_press_relative(x, y, milliseconds=700):
    win = current_window()
    if not win:
        return False
    return long_press(win["x"] + x, win["y"] + y, milliseconds)


def longPressRelative(x, y, milliseconds=700):
    return long_press_relative(x, y, milliseconds)


def drag_relative(start_x, start_y, end_x, end_y, milliseconds=280):
    win = current_window()
    if not win:
        return False
    return drag(
        win["x"] + start_x,
        win["y"] + start_y,
        win["x"] + end_x,
        win["y"] + end_y,
        milliseconds,
    )


def dragRelative(start_x, start_y, end_x, end_y, milliseconds=280):
    return drag_relative(start_x, start_y, end_x, end_y, milliseconds)


def get_color_relative(x, y):
    win = current_window()
    if not win:
        return ""
    return get_color(win["x"] + x, win["y"] + y)


def getColorRelative(x, y):
    return get_color_relative(x, y)


def find_image_in_window(template_name, threshold=0.94):
    return find_image(template_name, current_window_rect(), threshold)


def findImageInWindow(template_name, threshold=0.94):
    return find_image_in_window(template_name, threshold)


def find_color_in_window(hex, tolerance=12):
    return find_color(hex, current_window_rect(), tolerance)


def findColorInWindow(hex, tolerance=12):
    return find_color_in_window(hex, tolerance)


def wait_color_relative(x, y, hex, tolerance=8, timeout_ms=3000, interval_ms=120):
    win = current_window()
    if not win:
        return False
    return wait_color(win["x"] + x, win["y"] + y, hex, tolerance, timeout_ms, interval_ms)


def waitColorRelative(x, y, hex, tolerance=8, timeoutMs=3000, intervalMs=120):
    return wait_color_relative(x, y, hex, tolerance, timeoutMs, intervalMs)


def ocr_window():
    area = current_window_rect()
    if not area:
        return ""
    return ocr_text(area["x"], area["y"], area["width"], area["height"])


def ocrWindow():
    return ocr_window()


def click_template_in_window(template_name, threshold=0.94):
    match = find_image_in_window(template_name, threshold)
    if not match:
        return False
    return click(match["x"], match["y"])


def clickTemplateInWindow(template_name, threshold=0.94):
    return click_template_in_window(template_name, threshold)


def click_color_in_window(hex, tolerance=12):
    match = find_color_in_window(hex, tolerance)
    if not match:
        return False
    return click(match["x"], match["y"])


def clickColorInWindow(hex, tolerance=12):
    return click_color_in_window(hex, tolerance)


def _execute_user_source(encoded_source):
    source = base64.b64decode(encoded_source).decode("utf-8")
    globals_dict = globals()
    exec(compile(source, "<MacClickStudio>", "exec"), globals_dict, globals_dict)
"""#

    func run(source: String, store: StudioStore) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try runBlocking(source: source, store: store)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func runBlocking(source: String, store: StudioStore) throws {
        let pythonExecutable = try locatePythonExecutable()
        let workingDirectory = try mainActorSync {
            store.currentScriptURL?.deletingLastPathComponent()
                ?? store.currentProjectURL?.deletingLastPathComponent()
                ?? FileManager.default.homeDirectoryForCurrentUser
        }

        let scriptURL = try writeBootstrapScript(source: source)
        defer {
            try? FileManager.default.removeItem(at: scriptURL)
        }

        let process = Process()
        process.executableURL = pythonExecutable
        process.arguments = ["-u", scriptURL.path]
        process.currentDirectoryURL = workingDirectory
        process.environment = ProcessInfo.processInfo.environment.merging([
            "PYTHONIOENCODING": "utf-8",
            "PYTHONUNBUFFERED": "1"
        ]) { _, new in new }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stderrLines = LockedStringLines()

        let readGroup = DispatchGroup()
        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            self.readLines(from: stdoutPipe.fileHandleForReading) { line in
                self.handleStandardOutputLine(
                    line,
                    store: store,
                    stdin: stdinPipe.fileHandleForWriting
                )
            }
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            self.readLines(from: stderrPipe.fileHandleForReading) { line in
                guard !line.isEmpty else { return }
                stderrLines.append(line)
                self.mainActorFireAndForget {
                    store.appendLogMessage("[Python] \(line)")
                }
            }
            readGroup.leave()
        }

        do {
            try process.run()
        } catch {
            throw StudioError.scriptError("无法启动 Python 3：\(error.localizedDescription)")
        }

        process.waitUntilExit()
        try? stdinPipe.fileHandleForWriting.close()
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
        readGroup.wait()

        guard process.terminationStatus == 0 else {
            let message = stderrLines.joinedSuffix(6)

            if !message.isEmpty {
                throw StudioError.scriptError(message)
            }
            throw StudioError.scriptError("Python 脚本执行失败，退出码 \(process.terminationStatus)。")
        }
    }

    private func locatePythonExecutable() throws -> URL {
        for path in Self.pythonCandidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        let pathValues = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)

        for directory in pathValues {
            let path = URL(fileURLWithPath: directory).appendingPathComponent("python3").path
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        throw StudioError.scriptError("没有找到可用的 Python 3 解释器。请先安装 python3。")
    }

    private func writeBootstrapScript(source: String) throws -> URL {
        let encodedSource = Data(source.utf8).base64EncodedString()
        let bootstrap = Self.pythonPrelude + "\n\n_execute_user_source(\"" + encodedSource + "\")\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("macclickstudio-python-\(UUID().uuidString).py")
        try bootstrap.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func readLines(from handle: FileHandle, onLine: (String) -> Void) {
        var buffer = Data()

        while true {
            let chunk = handle.availableData
            if chunk.isEmpty {
                break
            }
            buffer.append(chunk)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(...newlineIndex)
                onLine(decodeLine(from: lineData))
            }
        }

        if !buffer.isEmpty {
            onLine(decodeLine(from: buffer))
        }
    }

    private func decodeLine(from data: Data) -> String {
        var line = String(decoding: data, as: UTF8.self)
        line.removeAll { $0 == "\n" || $0 == "\r" }
        return line
    }

    private func handleStandardOutputLine(_ line: String, store: StudioStore, stdin: FileHandle) {
        guard !line.isEmpty else {
            return
        }

        if line.hasPrefix(Self.bridgePrefix) {
            let payload = String(line.dropFirst(Self.bridgePrefix.count))
            let responseLine = bridgeResponse(for: payload, store: store)
            if let data = (Self.bridgePrefix + responseLine + "\n").data(using: .utf8) {
                stdin.write(data)
            }
            return
        }

        mainActorFireAndForget {
            store.appendLogMessage("[Python] \(line)")
        }
    }

    private func bridgeResponse(for payload: String, store: StudioStore) -> String {
        do {
            let value = try handleBridgePayload(payload, store: store)
            return makeResponse(ok: true, value: value, error: nil)
        } catch {
            return makeResponse(ok: false, value: nil, error: error.localizedDescription)
        }
    }

    private func handleBridgePayload(_ payload: String, store: StudioStore) throws -> Any? {
        guard let data = payload.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let command = object["command"] as? String else {
            throw StudioError.scriptError("Python 桥接请求无效。")
        }

        let params = object["params"] as? [String: Any] ?? [:]

        switch command {
        case "click":
            return try mainActorSync {
                ScriptBridge(store: store).click(doubleParam(params, "x"), doubleParam(params, "y"))
            }
        case "longPress":
            return try mainActorSync {
                ScriptBridge(store: store).longPress(
                    doubleParam(params, "x"),
                    doubleParam(params, "y"),
                    intParam(params, "milliseconds", defaultValue: 700)
                )
            }
        case "drag":
            return try mainActorSync {
                ScriptBridge(store: store).drag(
                    doubleParam(params, "startX"),
                    doubleParam(params, "startY"),
                    doubleParam(params, "endX"),
                    doubleParam(params, "endY"),
                    intParam(params, "milliseconds", defaultValue: 280)
                )
            }
        case "getColorHex":
            return try mainActorSync {
                ScriptBridge(store: store).getColorHex(doubleParam(params, "x"), doubleParam(params, "y"))
            }
        case "colorMatch":
            return try mainActorSync {
                ScriptBridge(store: store).colorMatch(
                    doubleParam(params, "x"),
                    doubleParam(params, "y"),
                    stringParam(params, "hex"),
                    intParam(params, "tolerance", defaultValue: 8)
                )
            }
        case "ocr":
            return try mainActorSync {
                ScriptBridge(store: store).ocr(
                    doubleParam(params, "x"),
                    doubleParam(params, "y"),
                    doubleParam(params, "width"),
                    doubleParam(params, "height")
                )
            }
        case "findImage":
            return try mainActorSync {
                let rect = rectPayload(params["rect"])
                let raw = ScriptBridge(store: store).findImage(
                    stringParam(params, "templateName"),
                    rect?.x ?? 0,
                    rect?.y ?? 0,
                    rect?.width ?? 0,
                    rect?.height ?? 0,
                    doubleParam(params, "threshold", defaultValue: 0.94)
                )
                return jsonValue(from: raw)
            }
        case "findColor":
            return try mainActorSync {
                let rect = rectPayload(params["rect"])
                let raw = ScriptBridge(store: store).findColor(
                    stringParam(params, "hex"),
                    rect?.x ?? 0,
                    rect?.y ?? 0,
                    rect?.width ?? 0,
                    rect?.height ?? 0,
                    intParam(params, "tolerance", defaultValue: 12)
                )
                return jsonValue(from: raw)
            }
        case "windowBounds":
            return try mainActorSync {
                let raw = ScriptBridge(store: store).windowBounds(
                    stringParam(params, "ownerName"),
                    stringParam(params, "title")
                )
                return jsonValue(from: raw)
            }
        case "currentWindow":
            return try mainActorSync {
                let raw = ScriptBridge(store: store).currentWindow()
                return jsonValue(from: raw)
            }
        default:
            throw StudioError.scriptError("不支持的 Python 桥接命令：\(command)")
        }
    }

    private func rectPayload(_ value: Any?) -> (x: Double, y: Double, width: Double, height: Double)? {
        guard let payload = value as? [String: Any] else {
            return nil
        }
        return (
            doubleValue(payload["x"]),
            doubleValue(payload["y"]),
            doubleValue(payload["width"]),
            doubleValue(payload["height"])
        )
    }

    private func jsonValue(from raw: String) -> Any? {
        guard !raw.isEmpty,
              let data = raw.data(using: .utf8) else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private func makeResponse(ok: Bool, value: Any?, error: String?) -> String {
        var payload: [String: Any] = ["ok": ok]
        payload["value"] = value ?? NSNull()
        if let error {
            payload["error"] = error
        }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return #"{"ok":false,"error":"bridge serialization failed"}"#
        }
        return string
    }

    private func stringParam(_ params: [String: Any], _ key: String) -> String {
        if let value = params[key] as? String {
            return value
        }
        return ""
    }

    private func doubleParam(_ params: [String: Any], _ key: String, defaultValue: Double = 0) -> Double {
        doubleValue(params[key], defaultValue: defaultValue)
    }

    private func intParam(_ params: [String: Any], _ key: String, defaultValue: Int = 0) -> Int {
        intValue(params[key], defaultValue: defaultValue)
    }

    private func doubleValue(_ value: Any?, defaultValue: Double = 0) -> Double {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let text as String:
            return Double(text) ?? defaultValue
        default:
            return defaultValue
        }
    }

    private func intValue(_ value: Any?, defaultValue: Int = 0) -> Int {
        switch value {
        case let number as Int:
            return number
        case let number as Double:
            return Int(number.rounded())
        case let number as NSNumber:
            return number.intValue
        case let text as String:
            return Int(text) ?? defaultValue
        default:
            return defaultValue
        }
    }

    private func mainActorSync<T>(_ work: @escaping @MainActor () throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = LockedResultBox<T>()

        Task { @MainActor in
            do {
                box.set(.success(try work()))
            } catch {
                box.set(.failure(error))
            }
            semaphore.signal()
        }

        semaphore.wait()
        guard let result = box.get() else {
            throw StudioError.scriptError("主线程桥接失败。")
        }
        return try result.get()
    }

    private func mainActorFireAndForget(_ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            work()
        }
    }
}
