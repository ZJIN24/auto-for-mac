import AppKit
import Foundation

final class WindowOperationRecorderService {
    typealias OperationHandler = @MainActor (RecordedWindowOperation) -> Void

    private struct ActiveGesture {
        var targetWindow: WindowInfo
        var startScreenPoint: CGPoint
        var startRelativePoint: PixelPoint
        var latestScreenPoint: CGPoint
        var latestRelativePoint: PixelPoint
        var beganAt: Date
        var moved = false
    }

    private let windowService = WindowInspectorService()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var target: WindowTarget?
    private var startedAt: Date?
    private var lastEventAt: Date?
    private var onOperation: OperationHandler?
    private var activeGesture: ActiveGesture?

    private let dragThreshold: CGFloat = 6
    private let longPressThresholdMs = 420

    var isRecording: Bool {
        globalMonitor != nil || localMonitor != nil
    }

    @MainActor
    func start(target: WindowTarget, onOperation: @escaping OperationHandler) {
        stop()

        self.target = target
        self.onOperation = onOperation

        let now = Date()
        startedAt = now
        lastEventAt = now

        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    @MainActor
    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }

        target = nil
        startedAt = nil
        lastEventAt = nil
        onOperation = nil
        activeGesture = nil
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            handleMouseDown(event)
        case .leftMouseDragged:
            handleMouseDragged(event)
        case .leftMouseUp:
            handleMouseUp(event)
        default:
            break
        }
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let target, let screenPoint = event.cgEvent?.location ?? Optional(NSEvent.mouseLocation) else {
            return
        }
        guard let window = windowService.window(at: screenPoint), matches(window, target: target) else {
            return
        }

        let relativePoint = relativePoint(for: screenPoint, in: window)
        activeGesture = ActiveGesture(
            targetWindow: window,
            startScreenPoint: screenPoint,
            startRelativePoint: relativePoint,
            latestScreenPoint: screenPoint,
            latestRelativePoint: relativePoint,
            beganAt: Date(),
            moved: false
        )
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard var gesture = activeGesture else {
            return
        }

        let screenPoint = event.cgEvent?.location ?? NSEvent.mouseLocation
        let distance = distance(from: gesture.startScreenPoint, to: screenPoint)
        gesture.moved = gesture.moved || distance >= dragThreshold
        gesture.latestScreenPoint = screenPoint
        gesture.latestRelativePoint = relativePoint(for: screenPoint, in: gesture.targetWindow)
        activeGesture = gesture
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard let target, let startedAt, let gesture = activeGesture else {
            activeGesture = nil
            return
        }
        activeGesture = nil

        guard matches(gesture.targetWindow, target: target) else {
            return
        }

        let releasePoint = event.cgEvent?.location ?? NSEvent.mouseLocation
        let releaseRelativePoint = relativePoint(for: releasePoint, in: gesture.targetWindow)
        let now = Date()
        let delayMs = Int(max(0, now.timeIntervalSince(lastEventAt ?? startedAt)) * 1000)
        let createdAtOffsetMs = Int(max(0, now.timeIntervalSince(startedAt)) * 1000)
        let durationMs = Int(max(0, now.timeIntervalSince(gesture.beganAt)) * 1000)
        lastEventAt = now

        let operationKind: RecordedWindowOperationKind
        if gesture.moved || distance(from: gesture.startScreenPoint, to: releasePoint) >= dragThreshold {
            operationKind = .drag
        } else if durationMs >= longPressThresholdMs {
            operationKind = .longPress
        } else {
            operationKind = .leftClick
        }

        let operation = RecordedWindowOperation(
            kind: operationKind,
            relativePoint: gesture.startRelativePoint,
            absolutePoint: absolutePoint(for: gesture.startScreenPoint),
            endRelativePoint: operationKind == .drag ? releaseRelativePoint : nil,
            endAbsolutePoint: operationKind == .drag ? absolutePoint(for: releasePoint) : nil,
            delayMs: delayMs,
            durationMs: operationKind == .leftClick ? nil : durationMs,
            createdAtOffsetMs: createdAtOffsetMs
        )

        guard let onOperation else {
            return
        }

        Task { @MainActor in
            onOperation(operation)
        }
    }

    private func relativePoint(for screenPoint: CGPoint, in window: WindowInfo) -> PixelPoint {
        PixelPoint(
            x: max(0, min(Int(screenPoint.x - window.screenBounds.minX), max(0, Int(window.screenBounds.width) - 1))),
            y: max(0, min(Int(window.screenBounds.maxY - screenPoint.y), max(0, Int(window.screenBounds.height) - 1)))
        )
    }

    private func absolutePoint(for screenPoint: CGPoint) -> PixelPoint {
        PixelPoint(
            x: max(0, Int(screenPoint.x.rounded())),
            y: max(0, Int(screenPoint.y.rounded()))
        )
    }

    private func distance(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt((dx * dx) + (dy * dy))
    }

    private func matches(_ info: WindowInfo, target: WindowTarget) -> Bool {
        if info.pid == target.pid && info.ownerName == target.ownerName && !target.title.isEmpty {
            return info.title == target.title
        }
        if info.windowID == target.windowID {
            return true
        }
        return info.pid == target.pid && info.ownerName == target.ownerName
    }
}
