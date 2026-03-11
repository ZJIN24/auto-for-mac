import Foundation
import AppKit
import SwiftUI

struct PixelPoint: Codable, Hashable, Identifiable {
    var x: Int
    var y: Int

    var id: String {
        "\(x),\(y)"
    }

    static let zero = PixelPoint(x: 0, y: 0)

    func adding(_ point: PixelPoint) -> PixelPoint {
        PixelPoint(x: x + point.x, y: y + point.y)
    }

    func clamped(maxWidth: Int, maxHeight: Int) -> PixelPoint {
        PixelPoint(
            x: max(0, min(x, maxWidth - 1)),
            y: max(0, min(y, maxHeight - 1))
        )
    }
}

struct PixelRect: Codable, Hashable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var isValid: Bool {
        width > 0 && height > 0
    }

    var topLeft: PixelPoint {
        PixelPoint(x: x, y: y)
    }

    var bottomRight: PixelPoint {
        PixelPoint(x: x + width - 1, y: y + height - 1)
    }

    var center: PixelPoint {
        PixelPoint(x: x + width / 2, y: y + height / 2)
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func contains(_ point: PixelPoint) -> Bool {
        point.x >= x && point.y >= y && point.x < x + width && point.y < y + height
    }

    func clamped(maxWidth: Int, maxHeight: Int) -> PixelRect {
        let minX = Swift.max(0, Swift.min(x, maxWidth - 1))
        let minY = Swift.max(0, Swift.min(y, maxHeight - 1))
        let maxX = Swift.max(minX, Swift.min(x + width, maxWidth))
        let maxY = Swift.max(minY, Swift.min(y + height, maxHeight))
        return PixelRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func between(_ start: PixelPoint, _ end: PixelPoint) -> PixelRect {
        let minX = Swift.min(start.x, end.x)
        let minY = Swift.min(start.y, end.y)
        let width = Swift.abs(start.x - end.x) + 1
        let height = Swift.abs(start.y - end.y) + 1
        return PixelRect(x: minX, y: minY, width: width, height: height)
    }
}

struct PixelColor: Codable, Hashable {
    var red: Int
    var green: Int
    var blue: Int
    var alpha: Int = 255

    init(red: Int, green: Int, blue: Int, alpha: Int = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init?(hexString: String) {
        let cleaned = hexString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            red: (value >> 16) & 0xFF,
            green: (value >> 8) & 0xFF,
            blue: value & 0xFF
        )
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    var detailText: String {
        "R\(red) G\(green) B\(blue)"
    }

    func matches(_ other: PixelColor, tolerance: Int) -> Bool {
        abs(red - other.red) <= tolerance
            && abs(green - other.green) <= tolerance
            && abs(blue - other.blue) <= tolerance
    }
}

struct ColorSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var point: PixelPoint
    var color: PixelColor
    var tolerance: Int
}

enum TemplateProcessingMode: String, Codable, CaseIterable, Identifiable {
    case original
    case grayscale
    case binary

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .original:
            return "原图"
        case .grayscale:
            return "灰度"
        case .binary:
            return "高对比"
        }
    }
}

struct ImageTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var rect: PixelRect
    var pngData: Data
    var preferredSimilarity: Double = 0.94
    var processingMode: TemplateProcessingMode = .original

    var previewImage: NSImage? {
        NSImage(data: pngData)
    }
}

struct WindowTarget: Codable, Hashable {
    var windowID: UInt32
    var ownerName: String
    var title: String
    var pid: Int32

    var displayTitle: String {
        title.isEmpty ? ownerName : "\(ownerName) · \(title)"
    }
}

struct WindowInfo: Identifiable, Hashable {
    var windowID: UInt32
    var ownerName: String
    var title: String
    var pid: Int32
    var layer: Int
    var screenBounds: CGRect

    var id: UInt32 {
        windowID
    }

    var target: WindowTarget {
        WindowTarget(windowID: windowID, ownerName: ownerName, title: title, pid: pid)
    }

    var displayTitle: String {
        title.isEmpty ? ownerName : "\(ownerName) · \(title)"
    }

    var shortBoundsText: String {
        "x:\(Int(screenBounds.minX)) y:\(Int(screenBounds.minY)) w:\(Int(screenBounds.width)) h:\(Int(screenBounds.height))"
    }
}


enum RecordedWindowOperationKind: String, Codable, CaseIterable, Identifiable {
    case leftClick
    case longPress
    case drag

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftClick:
            return "左键点击"
        case .longPress:
            return "长按"
        case .drag:
            return "拖动"
        }
    }
}

struct RecordedWindowOperation: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: RecordedWindowOperationKind = .leftClick
    var relativePoint: PixelPoint
    var absolutePoint: PixelPoint
    var endRelativePoint: PixelPoint?
    var endAbsolutePoint: PixelPoint?
    var delayMs: Int
    var durationMs: Int?
    var createdAtOffsetMs: Int

    var summary: String {
        let waitText = delayMs > 0 ? "等待 \(delayMs)ms → " : ""
        switch kind {
        case .leftClick:
            return "\(waitText)\(kind.title) (\(relativePoint.x), \(relativePoint.y))"
        case .longPress:
            return "\(waitText)\(kind.title) (\(relativePoint.x), \(relativePoint.y)) \(durationMs ?? 0)ms"
        case .drag:
            let endPoint = endRelativePoint ?? relativePoint
            return "\(waitText)\(kind.title) (\(relativePoint.x), \(relativePoint.y)) → (\(endPoint.x), \(endPoint.y)) \(durationMs ?? 0)ms"
        }
    }
}

struct AccessibilityElementInfo: Hashable {
    var role: String
    var subrole: String
    var title: String
    var value: String
    var identifier: String
    var descriptionText: String

    var summary: String {
        [role, subrole, title, value, identifier]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

enum CoordinateMode: String, Codable, CaseIterable, Identifiable {
    case screenAbsolute
    case selectedWindowRelative

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .screenAbsolute:
            return "屏幕绝对坐标"
        case .selectedWindowRelative:
            return "窗口相对坐标"
        }
    }
}

enum EventDeliveryMode: String, Codable, CaseIterable, Identifiable {
    case systemWide
    case targetPID

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .systemWide:
            return "系统前台投递"
        case .targetPID:
            return "目标进程投递"
        }
    }
}

enum ScriptStepKind: String, Codable, CaseIterable, Identifiable {
    case wait
    case clickPoint
    case longPressPoint
    case dragPoints
    case multiColorCheck
    case findImageAndClick
    case findColorAndClick

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .wait:
            return "等待"
        case .clickPoint:
            return "点击"
        case .longPressPoint:
            return "长按"
        case .dragPoints:
            return "拖动"
        case .multiColorCheck:
            return "多点比色"
        case .findImageAndClick:
            return "找图点击"
        case .findColorAndClick:
            return "找色点击"
        }
    }
}

struct ScriptStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var kind: ScriptStepKind
    var isEnabled: Bool = true
    var milliseconds: Int = 500
    var point: PixelPoint?
    var endPoint: PixelPoint?
    var coordinateMode: CoordinateMode = .screenAbsolute
    var windowTarget: WindowTarget?
    var eventDeliveryMode: EventDeliveryMode = .systemWide
    var sampleIDs: [UUID] = []
    var templateID: UUID?
    var searchRect: PixelRect?
    var similarityThreshold: Double = 0.94
    var timeoutMs: Int = 2500
    var continueOnFailure: Bool = false
    var targetColor: PixelColor?
    var colorTolerance: Int = 12
}

extension ScriptStep {
    static func wait(milliseconds: Int) -> ScriptStep {
        ScriptStep(
            name: "等待 \(milliseconds)ms",
            kind: .wait,
            milliseconds: milliseconds
        )
    }

    static func click(
        point: PixelPoint,
        coordinateMode: CoordinateMode,
        windowTarget: WindowTarget?,
        deliveryMode: EventDeliveryMode
    ) -> ScriptStep {
        ScriptStep(
            name: coordinateMode == .screenAbsolute
                ? "点击 (\(point.x), \(point.y))"
                : "点击窗口相对点 (\(point.x), \(point.y))",
            kind: .clickPoint,
            point: point,
            coordinateMode: coordinateMode,
            windowTarget: windowTarget,
            eventDeliveryMode: deliveryMode
        )
    }

    static func longPress(
        point: PixelPoint,
        coordinateMode: CoordinateMode,
        durationMs: Int,
        windowTarget: WindowTarget?,
        deliveryMode: EventDeliveryMode
    ) -> ScriptStep {
        ScriptStep(
            name: coordinateMode == .screenAbsolute
                ? "长按 (\(point.x), \(point.y))"
                : "长按窗口相对点 (\(point.x), \(point.y))",
            kind: .longPressPoint,
            milliseconds: durationMs,
            point: point,
            coordinateMode: coordinateMode,
            windowTarget: windowTarget,
            eventDeliveryMode: deliveryMode
        )
    }

    static func drag(
        from startPoint: PixelPoint,
        to endPoint: PixelPoint,
        coordinateMode: CoordinateMode,
        durationMs: Int,
        windowTarget: WindowTarget?,
        deliveryMode: EventDeliveryMode
    ) -> ScriptStep {
        ScriptStep(
            name: coordinateMode == .screenAbsolute
                ? "拖动 (\(startPoint.x), \(startPoint.y)) → (\(endPoint.x), \(endPoint.y))"
                : "拖动窗口相对点 (\(startPoint.x), \(startPoint.y)) → (\(endPoint.x), \(endPoint.y))",
            kind: .dragPoints,
            milliseconds: durationMs,
            point: startPoint,
            endPoint: endPoint,
            coordinateMode: coordinateMode,
            windowTarget: windowTarget,
            eventDeliveryMode: deliveryMode
        )
    }

    static func multiColor(sampleIDs: [UUID], timeoutMs: Int) -> ScriptStep {
        ScriptStep(
            name: "等待多点比色通过",
            kind: .multiColorCheck,
            sampleIDs: sampleIDs,
            timeoutMs: timeoutMs
        )
    }

    static func findImage(
        templateID: UUID,
        searchRect: PixelRect?,
        threshold: Double,
        timeoutMs: Int,
        windowTarget: WindowTarget?,
        deliveryMode: EventDeliveryMode
    ) -> ScriptStep {
        ScriptStep(
            name: searchRect == nil ? "全屏找图点击" : "区域找图点击",
            kind: .findImageAndClick,
            windowTarget: windowTarget,
            eventDeliveryMode: deliveryMode,
            templateID: templateID,
            searchRect: searchRect,
            similarityThreshold: threshold,
            timeoutMs: timeoutMs
        )
    }

    static func findColor(
        targetColor: PixelColor,
        searchRect: PixelRect?,
        tolerance: Int,
        timeoutMs: Int,
        windowTarget: WindowTarget?,
        deliveryMode: EventDeliveryMode
    ) -> ScriptStep {
        ScriptStep(
            name: searchRect == nil ? "全屏找色点击" : "区域找色点击",
            kind: .findColorAndClick,
            windowTarget: windowTarget,
            eventDeliveryMode: deliveryMode,
            searchRect: searchRect,
            timeoutMs: timeoutMs,
            targetColor: targetColor,
            colorTolerance: tolerance
        )
    }
}

enum InteractionMode: String, CaseIterable, Identifiable {
    case point
    case region

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .point:
            return "点位"
        case .region:
            return "区域"
        }
    }
}

struct HoverSnapshot {
    var rawPoint: PixelPoint
    var sampledPoint: PixelPoint
    var color: PixelColor
}

struct DisplaySnapshot {
    let rgba: RGBAImage
    let displayBounds: CGRect

    var size: CGSize {
        CGSize(width: rgba.width, height: rgba.height)
    }

    var scaleX: CGFloat {
        CGFloat(rgba.width) / max(displayBounds.width, 1)
    }

    var scaleY: CGFloat {
        CGFloat(rgba.height) / max(displayBounds.height, 1)
    }

    var nsImage: NSImage? {
        guard let cgImage = rgba.cgImage else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: size)
    }

    func screenPoint(from pixel: PixelPoint) -> CGPoint {
        CGPoint(
            x: displayBounds.minX + CGFloat(pixel.x) / scaleX,
            y: displayBounds.maxY - CGFloat(pixel.y) / scaleY
        )
    }

    func pixelPoint(fromScreenPoint point: CGPoint) -> PixelPoint {
        PixelPoint(
            x: Int((point.x - displayBounds.minX) * scaleX),
            y: Int((displayBounds.maxY - point.y) * scaleY)
        ).clamped(maxWidth: rgba.width, maxHeight: rgba.height)
    }

    func pixelRect(fromScreenRect rect: CGRect) -> PixelRect {
        let topLeft = pixelPoint(fromScreenPoint: CGPoint(x: rect.minX, y: rect.maxY))
        let bottomRight = pixelPoint(fromScreenPoint: CGPoint(x: rect.maxX, y: rect.minY))
        return PixelRect(
            x: min(topLeft.x, bottomRight.x),
            y: min(topLeft.y, bottomRight.y),
            width: max(1, abs(bottomRight.x - topLeft.x)),
            height: max(1, abs(bottomRight.y - topLeft.y))
        )
    }
}

struct StudioProjectExport: Codable {
    var createdAt: Date = .now
    var samples: [ColorSample]
    var templates: [ImageTemplate]
    var selectedTemplateID: UUID?
    var scriptSteps: [ScriptStep]
    var scriptLanguage: ScriptLanguage = .pythonLike
    var scriptSource: String
    var scriptDraftName: String?
    var lockedWindowTarget: WindowTarget?
    var recordedWindowTarget: WindowTarget?
    var recordedWindowOperations: [RecordedWindowOperation] = []
    var defaultTolerance: Int = 16
    var defaultTimeoutMs: Int = 2500
    var defaultWaitMs: Int = 500
    var defaultSimilarityThreshold: Double = 0.94
    var templateProcessingMode: TemplateProcessingMode = .original
    var useSelectionAsSearchArea: Bool = false
    var captureOffsetX: Int = 0
    var captureOffsetY: Int = 0
    var coordinateMode: CoordinateMode = .screenAbsolute
    var deliveryMode: EventDeliveryMode = .systemWide
}

enum StudioError: LocalizedError {
    case captureFailed
    case imageDecodeFailed
    case invalidSelection(String)
    case templateMissing
    case timeout(String)
    case actionUnavailable(String)
    case windowMissing(String)
    case ocrFailed(String)
    case scriptError(String)
    case projectError(String)

    var errorDescription: String? {
        switch self {
        case .captureFailed:
            return "截图失败，请确认已经授予屏幕录制权限。"
        case .imageDecodeFailed:
            return "图像解码失败。"
        case .invalidSelection(let message):
            return message
        case .templateMissing:
            return "找不到对应模板，请先保存模板。"
        case .timeout(let message):
            return message
        case .actionUnavailable(let message):
            return message
        case .windowMissing(let message):
            return message
        case .ocrFailed(let message):
            return message
        case .scriptError(let message):
            return message
        case .projectError(let message):
            return message
        }
    }
}

extension Color {
    init(pixelColor: PixelColor) {
        self.init(
            nsColor: NSColor(
                calibratedRed: CGFloat(pixelColor.red) / 255,
                green: CGFloat(pixelColor.green) / 255,
                blue: CGFloat(pixelColor.blue) / 255,
                alpha: CGFloat(pixelColor.alpha) / 255
            )
        )
    }
}

extension NSImage {
    var cgImageRepresentation: CGImage? {
        cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
