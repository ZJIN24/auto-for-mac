import Foundation
import ApplicationServices
import AppKit

struct AutomationService {
    private let matcher = TemplateMatcher()

    func click(
        pixelPoint: PixelPoint,
        snapshot: DisplaySnapshot,
        deliveryMode: EventDeliveryMode = .systemWide,
        targetPID: pid_t? = nil
    ) throws {
        let screenPoint = snapshot.screenPoint(from: pixelPoint)
        try moveAndPress(
            at: screenPoint,
            holdDurationMs: 25,
            deliveryMode: deliveryMode,
            targetPID: targetPID
        )
    }

    func longPress(
        pixelPoint: PixelPoint,
        snapshot: DisplaySnapshot,
        durationMs: Int,
        deliveryMode: EventDeliveryMode = .systemWide,
        targetPID: pid_t? = nil
    ) throws {
        let screenPoint = snapshot.screenPoint(from: pixelPoint)
        try moveAndPress(
            at: screenPoint,
            holdDurationMs: max(80, durationMs),
            deliveryMode: deliveryMode,
            targetPID: targetPID
        )
    }

    func drag(
        from startPoint: PixelPoint,
        to endPoint: PixelPoint,
        snapshot: DisplaySnapshot,
        durationMs: Int,
        deliveryMode: EventDeliveryMode = .systemWide,
        targetPID: pid_t? = nil
    ) throws {
        let startScreenPoint = snapshot.screenPoint(from: startPoint)
        let endScreenPoint = snapshot.screenPoint(from: endPoint)
        let steps = max(8, min(28, Int(distance(from: startScreenPoint, to: endScreenPoint) / 24)))
        let totalDurationMs = max(120, durationMs)
        let stepSleep = max(8, totalDurationMs / max(steps, 1))

        try postMouseEvent(type: .mouseMoved, at: startScreenPoint, deliveryMode: deliveryMode, targetPID: targetPID)
        usleep(20_000)
        try postMouseEvent(type: .leftMouseDown, at: startScreenPoint, deliveryMode: deliveryMode, targetPID: targetPID)
        usleep(20_000)

        for index in 1...steps {
            let progress = CGFloat(index) / CGFloat(steps)
            let point = CGPoint(
                x: startScreenPoint.x + ((endScreenPoint.x - startScreenPoint.x) * progress),
                y: startScreenPoint.y + ((endScreenPoint.y - startScreenPoint.y) * progress)
            )
            try postMouseEvent(type: .leftMouseDragged, at: point, deliveryMode: deliveryMode, targetPID: targetPID)
            usleep(useconds_t(stepSleep * 1_000))
        }

        try postMouseEvent(type: .leftMouseUp, at: endScreenPoint, deliveryMode: deliveryMode, targetPID: targetPID)
    }

    func waitForMultiColor(
        samples: [ColorSample],
        timeoutMs: Int,
        captureService: ScreenCaptureService
    ) async throws {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)

        while Date() <= deadline {
            let snapshot = try captureService.captureMainDisplay()
            if samples.allSatisfy({ sample in
                guard let current = snapshot.rgba.color(at: sample.point) else {
                    return false
                }
                return current.matches(sample.color, tolerance: sample.tolerance)
            }) {
                return
            }

            try await Task.sleep(for: .milliseconds(160))
        }

        throw StudioError.timeout("多点比色等待超时。")
    }

    func locateTemplate(
        template: ImageTemplate,
        in snapshot: DisplaySnapshot,
        searchRect: PixelRect?,
        minimumSimilarity: Double
    ) throws -> TemplateMatch? {
        guard let image = template.previewImage,
              let cgImage = image.cgImageRepresentation,
              let templateImage = RGBAImage(cgImage: cgImage) else {
            throw StudioError.templateMissing
        }

        let processedTemplate = templateImage.processed(template.processingMode)
        let processedFrame = snapshot.rgba.processed(template.processingMode)
        return matcher.find(
            template: processedTemplate,
            in: processedFrame,
            searchRect: searchRect,
            minimumSimilarity: minimumSimilarity
        )
    }

    func findTemplate(
        template: ImageTemplate,
        searchRect: PixelRect?,
        minimumSimilarity: Double,
        timeoutMs: Int,
        captureService: ScreenCaptureService
    ) async throws -> (match: TemplateMatch, snapshot: DisplaySnapshot) {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() <= deadline {
            let snapshot = try captureService.captureMainDisplay()
            if let match = try locateTemplate(
                template: template,
                in: snapshot,
                searchRect: searchRect,
                minimumSimilarity: minimumSimilarity
            ) {
                return (match, snapshot)
            }

            try await Task.sleep(for: .milliseconds(180))
        }

        throw StudioError.timeout("区域找图超时，没有找到足够相似的模板。")
    }

    func findColor(
        targetColor: PixelColor,
        searchRect: PixelRect?,
        tolerance: Int,
        in snapshot: DisplaySnapshot
    ) -> PixelPoint? {
        snapshot.rgba.firstPoint(matching: targetColor, in: searchRect, tolerance: tolerance)
    }

    func waitForColor(
        targetColor: PixelColor,
        searchRect: PixelRect?,
        tolerance: Int,
        timeoutMs: Int,
        captureService: ScreenCaptureService
    ) async throws -> (point: PixelPoint, snapshot: DisplaySnapshot) {
        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        while Date() <= deadline {
            let snapshot = try captureService.captureMainDisplay()
            if let point = findColor(
                targetColor: targetColor,
                searchRect: searchRect,
                tolerance: tolerance,
                in: snapshot
            ) {
                return (point, snapshot)
            }

            try await Task.sleep(for: .milliseconds(150))
        }

        throw StudioError.timeout("区域找色超时，没有找到目标颜色。")
    }

    private func moveAndPress(
        at screenPoint: CGPoint,
        holdDurationMs: Int,
        deliveryMode: EventDeliveryMode,
        targetPID: pid_t?
    ) throws {
        try postMouseEvent(type: .mouseMoved, at: screenPoint, deliveryMode: deliveryMode, targetPID: targetPID)
        usleep(25_000)
        try postMouseEvent(type: .leftMouseDown, at: screenPoint, deliveryMode: deliveryMode, targetPID: targetPID)
        usleep(useconds_t(max(1, holdDurationMs) * 1_000))
        try postMouseEvent(type: .leftMouseUp, at: screenPoint, deliveryMode: deliveryMode, targetPID: targetPID)
    }

    private func postMouseEvent(
        type: CGEventType,
        at screenPoint: CGPoint,
        deliveryMode: EventDeliveryMode,
        targetPID: pid_t?
    ) throws {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: screenPoint,
            mouseButton: .left
        ) else {
            throw StudioError.actionUnavailable("无法创建鼠标事件，请确认已授予辅助功能权限。")
        }

        switch deliveryMode {
        case .systemWide:
            event.post(tap: .cghidEventTap)
        case .targetPID:
            guard let targetPID else {
                throw StudioError.windowMissing("没有目标进程 PID，无法做定向投递。")
            }
            event.postToPid(targetPID)
        }
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt((dx * dx) + (dy * dy))
    }
}
