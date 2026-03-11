import Foundation
import JavaScriptCore

@MainActor
@objc protocol ScriptBridgeExports: JSExport {
    func log(_ message: String)
    func sleepMs(_ milliseconds: Int)
    func click(_ x: Double, _ y: Double) -> Bool
    func longPress(_ x: Double, _ y: Double, _ milliseconds: Int) -> Bool
    func drag(_ startX: Double, _ startY: Double, _ endX: Double, _ endY: Double, _ milliseconds: Int) -> Bool
    func getColorHex(_ x: Double, _ y: Double) -> String
    func colorMatch(_ x: Double, _ y: Double, _ hex: String, _ tolerance: Int) -> Bool
    func ocr(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> String
    func findImage(_ templateName: String, _ x: Double, _ y: Double, _ width: Double, _ height: Double, _ threshold: Double) -> String
    func findColor(_ hex: String, _ x: Double, _ y: Double, _ width: Double, _ height: Double, _ tolerance: Int) -> String
    func windowBounds(_ ownerName: String, _ title: String) -> String
    func currentWindow() -> String
}

@preconcurrency
@MainActor
final class ScriptBridge: NSObject, ScriptBridgeExports {
    private unowned let store: StudioStore
    private let captureService = ScreenCaptureService()
    private let automationService = AutomationService()
    private let ocrService = OCRService()
    private let windowService = WindowInspectorService()

    init(store: StudioStore) {
        self.store = store
    }

    func log(_ message: String) {
        store.appendLogMessage("[Script] \(message)")
    }

    func sleepMs(_ milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(max(0, milliseconds)) / 1000)
    }

    func click(_ x: Double, _ y: Double) -> Bool {
        do {
            let snapshot = try captureService.captureMainDisplay()
            let point = PixelPoint(x: Int(x), y: Int(y)).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
            let pid = store.selectedWindow?.pid
            try automationService.click(
                pixelPoint: point,
                snapshot: snapshot,
                deliveryMode: store.deliveryMode,
                targetPID: store.deliveryMode == .targetPID ? pid : nil
            )
            return true
        } catch {
            store.appendLogMessage("[Script] 点击失败：\(error.localizedDescription)")
            return false
        }
    }

    func longPress(_ x: Double, _ y: Double, _ milliseconds: Int) -> Bool {
        do {
            let snapshot = try captureService.captureMainDisplay()
            let point = PixelPoint(x: Int(x), y: Int(y)).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
            let pid = store.selectedWindow?.pid
            try automationService.longPress(
                pixelPoint: point,
                snapshot: snapshot,
                durationMs: milliseconds,
                deliveryMode: store.deliveryMode,
                targetPID: store.deliveryMode == .targetPID ? pid : nil
            )
            return true
        } catch {
            store.appendLogMessage("[Script] 长按失败：\(error.localizedDescription)")
            return false
        }
    }

    func drag(_ startX: Double, _ startY: Double, _ endX: Double, _ endY: Double, _ milliseconds: Int) -> Bool {
        do {
            let snapshot = try captureService.captureMainDisplay()
            let startPoint = PixelPoint(x: Int(startX), y: Int(startY)).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
            let endPoint = PixelPoint(x: Int(endX), y: Int(endY)).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
            let pid = store.selectedWindow?.pid
            try automationService.drag(
                from: startPoint,
                to: endPoint,
                snapshot: snapshot,
                durationMs: milliseconds,
                deliveryMode: store.deliveryMode,
                targetPID: store.deliveryMode == .targetPID ? pid : nil
            )
            return true
        } catch {
            store.appendLogMessage("[Script] 拖动失败：\(error.localizedDescription)")
            return false
        }
    }

    func getColorHex(_ x: Double, _ y: Double) -> String {
        do {
            let snapshot = try captureService.captureMainDisplay()
            let point = PixelPoint(x: Int(x), y: Int(y)).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
            return snapshot.rgba.color(at: point)?.hexString ?? ""
        } catch {
            store.appendLogMessage("[Script] 取色失败：\(error.localizedDescription)")
            return ""
        }
    }

    func colorMatch(_ x: Double, _ y: Double, _ hex: String, _ tolerance: Int) -> Bool {
        guard let expected = PixelColor(hexString: hex) else {
            return false
        }

        do {
            let snapshot = try captureService.captureMainDisplay()
            let point = PixelPoint(x: Int(x), y: Int(y)).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
            guard let actual = snapshot.rgba.color(at: point) else {
                return false
            }
            return actual.matches(expected, tolerance: tolerance)
        } catch {
            store.appendLogMessage("[Script] 比色失败：\(error.localizedDescription)")
            return false
        }
    }

    func ocr(_ x: Double, _ y: Double, _ width: Double, _ height: Double) -> String {
        do {
            let snapshot = try captureService.captureMainDisplay()
            let rect = normalizedRect(x: x, y: y, width: width, height: height)
            return try ocrService.recognizeText(in: snapshot, rect: rect)
        } catch {
            store.appendLogMessage("[Script] OCR 失败：\(error.localizedDescription)")
            return ""
        }
    }

    func findImage(_ templateName: String, _ x: Double, _ y: Double, _ width: Double, _ height: Double, _ threshold: Double) -> String {
        guard let template = store.template(named: templateName) else {
            return ""
        }

        do {
            let snapshot = try captureService.captureMainDisplay()
            let rect = normalizedRect(x: x, y: y, width: width, height: height)
            guard let match = try automationService.locateTemplate(
                template: template,
                in: snapshot,
                searchRect: rect,
                minimumSimilarity: threshold
            ) else {
                return ""
            }
            return jsonString([
                "x": match.rect.center.x,
                "y": match.rect.center.y,
                "score": match.score,
                "left": match.rect.x,
                "top": match.rect.y,
                "width": match.rect.width,
                "height": match.rect.height
            ])
        } catch {
            store.appendLogMessage("[Script] 找图失败：\(error.localizedDescription)")
            return ""
        }
    }

    func findColor(_ hex: String, _ x: Double, _ y: Double, _ width: Double, _ height: Double, _ tolerance: Int) -> String {
        guard let color = PixelColor(hexString: hex) else {
            return ""
        }

        do {
            let snapshot = try captureService.captureMainDisplay()
            let rect = normalizedRect(x: x, y: y, width: width, height: height)
            guard let point = automationService.findColor(
                targetColor: color,
                searchRect: rect,
                tolerance: tolerance,
                in: snapshot
            ) else {
                return ""
            }
            return jsonString([
                "x": point.x,
                "y": point.y
            ])
        } catch {
            store.appendLogMessage("[Script] 找色失败：\(error.localizedDescription)")
            return ""
        }
    }

    func windowBounds(_ ownerName: String, _ title: String) -> String {
        let windows = windowService.listWindows()
        let match = windows.first {
            $0.ownerName == ownerName && (title.isEmpty || $0.title == title)
        }
        guard let match else {
            return ""
        }

        return serializedWindowRect(for: match)
    }

    func currentWindow() -> String {
        guard let selectedWindow = store.selectedWindow else {
            return ""
        }

        return serializedWindowRect(for: selectedWindow, includeIdentity: true)
    }

    private func serializedWindowRect(for window: WindowInfo, includeIdentity: Bool = false) -> String {
        guard let snapshot = try? captureService.captureMainDisplay() else {
            return ""
        }

        let rect = snapshot.pixelRect(fromScreenRect: window.screenBounds)
        var payload: [String: Any] = [
            "x": rect.x,
            "y": rect.y,
            "width": rect.width,
            "height": rect.height
        ]

        if includeIdentity {
            payload["windowID"] = Int(window.windowID)
            payload["pid"] = Int(window.pid)
            payload["ownerName"] = window.ownerName
            payload["title"] = window.title
        } else {
            payload["windowID"] = Int(window.windowID)
            payload["pid"] = Int(window.pid)
        }

        return jsonString(payload)
    }

    private func normalizedRect(x: Double, y: Double, width: Double, height: Double) -> PixelRect? {
        guard width > 0, height > 0 else {
            return nil
        }
        return PixelRect(x: Int(x), y: Int(y), width: Int(width), height: Int(height))
    }

    private func jsonString(_ object: Any) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

struct ScriptEngine {
    private let pythonExecutor = PythonRuntimeExecutor()

    static let runtimePrelude = #"""
    const log = (...items) => bot.log(items.join(' '));
    const print = log;
    const sleep = (ms) => bot.sleepMs(ms);
    const sleep_ms = (ms) => bot.sleepMs(ms);
    const click = (x, y) => bot.click(x, y);
    const longPress = (x, y, milliseconds = 700) => bot.longPress(x, y, milliseconds);
    const long_press = (x, y, milliseconds = 700) => bot.longPress(x, y, milliseconds);
    const drag = (startX, startY, endX, endY, milliseconds = 280) => bot.drag(startX, startY, endX, endY, milliseconds);
    const drag_to = (startX, startY, endX, endY, milliseconds = 280) => bot.drag(startX, startY, endX, endY, milliseconds);
    const getColor = (x, y) => bot.getColorHex(x, y);
    const get_color = (x, y) => bot.getColorHex(x, y);
    const rect = (x, y, width, height) => ({ x, y, width, height });
    const point = (x, y) => ({ x, y });
    const len = (value) => value ? value.length : 0;

    function waitUntil(predicate, timeoutMs = 3000, intervalMs = 120) {
      const start = Date.now();
      while ((Date.now() - start) < timeoutMs) {
        if (predicate()) return true;
        sleep(intervalMs);
      }
      return false;
    }

    function waitColor(x, y, hex, tolerance = 8, timeoutMs = 3000, intervalMs = 120) {
      return waitUntil(() => bot.colorMatch(x, y, hex, tolerance), timeoutMs, intervalMs);
    }

    function wait_color(x, y, hex, tolerance = 8, timeout_ms = 3000, interval_ms = 120) {
      return waitUntil(() => bot.colorMatch(x, y, hex, tolerance), timeout_ms, interval_ms);
    }

    function findImage(templateName, rect = null, threshold = 0.94) {
      const x = rect ? rect.x : 0;
      const y = rect ? rect.y : 0;
      const width = rect ? rect.width : 0;
      const height = rect ? rect.height : 0;
      const raw = bot.findImage(templateName, x, y, width, height, threshold);
      return raw ? JSON.parse(raw) : null;
    }

    function find_image(templateName, rect = null, threshold = 0.94) {
      return findImage(templateName, rect, threshold);
    }

    function findColor(hex, rect = null, tolerance = 12) {
      const x = rect ? rect.x : 0;
      const y = rect ? rect.y : 0;
      const width = rect ? rect.width : 0;
      const height = rect ? rect.height : 0;
      const raw = bot.findColor(hex, x, y, width, height, tolerance);
      return raw ? JSON.parse(raw) : null;
    }

    function find_color(hex, rect = null, tolerance = 12) {
      return findColor(hex, rect, tolerance);
    }

    function clickTemplate(templateName, rect = null, threshold = 0.94) {
      const match = findImage(templateName, rect, threshold);
      if (!match) return false;
      return click(match.x, match.y);
    }

    function click_template(templateName, rect = null, threshold = 0.94) {
      return clickTemplate(templateName, rect, threshold);
    }

    function clickColor(hex, rect = null, tolerance = 12) {
      const match = findColor(hex, rect, tolerance);
      if (!match) return false;
      return click(match.x, match.y);
    }

    function click_color(hex, rect = null, tolerance = 12) {
      return clickColor(hex, rect, tolerance);
    }

    function ocr_text(x, y, width, height) {
      return bot.ocr(x, y, width, height);
    }

    function window_bounds(ownerName, title = '') {
      const raw = bot.windowBounds(ownerName, title);
      return raw ? JSON.parse(raw) : null;
    }

    function current_window() {
      const raw = bot.currentWindow();
      return raw ? JSON.parse(raw) : null;
    }

    function currentWindow() {
      return current_window();
    }

    function current_window_rect() {
      const win = current_window();
      return win ? rect(win.x, win.y, win.width, win.height) : null;
    }

    function currentWindowRect() {
      return current_window_rect();
    }

    function click_relative(x, y) {
      const win = current_window();
      if (!win) return false;
      return click(win.x + x, win.y + y);
    }

    function clickRelative(x, y) {
      return click_relative(x, y);
    }

    function long_press_relative(x, y, milliseconds = 700) {
      const win = current_window();
      if (!win) return false;
      return long_press(win.x + x, win.y + y, milliseconds);
    }

    function longPressRelative(x, y, milliseconds = 700) {
      return long_press_relative(x, y, milliseconds);
    }

    function drag_relative(startX, startY, endX, endY, milliseconds = 280) {
      const win = current_window();
      if (!win) return false;
      return drag(win.x + startX, win.y + startY, win.x + endX, win.y + endY, milliseconds);
    }

    function dragRelative(startX, startY, endX, endY, milliseconds = 280) {
      return drag_relative(startX, startY, endX, endY, milliseconds);
    }

    function get_color_relative(x, y) {
      const win = current_window();
      if (!win) return '';
      return get_color(win.x + x, win.y + y);
    }

    function getColorRelative(x, y) {
      return get_color_relative(x, y);
    }

    function find_image_in_window(templateName, threshold = 0.94) {
      return find_image(templateName, current_window_rect(), threshold);
    }

    function findImageInWindow(templateName, threshold = 0.94) {
      return find_image_in_window(templateName, threshold);
    }

    function find_color_in_window(hex, tolerance = 12) {
      return find_color(hex, current_window_rect(), tolerance);
    }

    function findColorInWindow(hex, tolerance = 12) {
      return find_color_in_window(hex, tolerance);
    }

    function wait_color_relative(x, y, hex, tolerance = 8, timeout_ms = 3000, interval_ms = 120) {
      const win = current_window();
      if (!win) return false;
      return wait_color(win.x + x, win.y + y, hex, tolerance, timeout_ms, interval_ms);
    }

    function waitColorRelative(x, y, hex, tolerance = 8, timeoutMs = 3000, intervalMs = 120) {
      return wait_color_relative(x, y, hex, tolerance, timeoutMs, intervalMs);
    }

    function ocr_window() {
      const area = current_window_rect();
      return area ? ocr_text(area.x, area.y, area.width, area.height) : '';
    }

    function ocrWindow() {
      return ocr_window();
    }

    function click_template_in_window(templateName, threshold = 0.94) {
      const match = find_image_in_window(templateName, threshold);
      if (!match) return false;
      return click(match.x, match.y);
    }

    function clickTemplateInWindow(templateName, threshold = 0.94) {
      return click_template_in_window(templateName, threshold);
    }

    function click_color_in_window(hex, tolerance = 12) {
      const match = find_color_in_window(hex, tolerance);
      if (!match) return false;
      return click(match.x, match.y);
    }

    function clickColorInWindow(hex, tolerance = 12) {
      return click_color_in_window(hex, tolerance);
    }
    """#

    func run(source: String, language: ScriptLanguage, store: StudioStore) async throws {
        switch language {
        case .pythonLike:
            try await pythonExecutor.run(source: source, store: store)
        case .javaScript:
            try await MainActor.run {
                try runJavaScript(source: source, store: store)
            }
        }
    }

    @MainActor
    private func runJavaScript(source: String, store: StudioStore) throws {
        guard let context = JSContext() else {
            throw StudioError.scriptError("无法创建脚本运行时。")
        }

        var scriptErrorMessage: String?
        context.exceptionHandler = { _, exception in
            scriptErrorMessage = exception?.toString() ?? "未知脚本错误"
        }

        let bridge = ScriptBridge(store: store)
        context.setObject(bridge, forKeyedSubscript: "bot" as NSString)
        _ = context.evaluateScript(Self.runtimePrelude)
        if let scriptErrorMessage {
            throw StudioError.scriptError(scriptErrorMessage)
        }

        _ = context.evaluateScript(source)
        if let scriptErrorMessage {
            throw StudioError.scriptError(scriptErrorMessage)
        }
    }
}
