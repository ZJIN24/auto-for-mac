import Foundation
import ApplicationServices

struct ScreenCaptureService {
    @MainActor
    func hasScreenCaptureAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    @MainActor
    func requestScreenCaptureAccess(prompt: Bool = true) -> Bool {
        if hasScreenCaptureAccess() {
            return true
        }
        guard prompt else {
            return false
        }
        _ = CGRequestScreenCaptureAccess()
        return hasScreenCaptureAccess()
    }

    @MainActor
    func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrusted()
    }

    @MainActor
    func requestAccessibilityAccess(prompt: Bool = true) -> Bool {
        if hasAccessibilityAccess() {
            return true
        }
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        return hasAccessibilityAccess()
    }

    func captureMainDisplay() throws -> DisplaySnapshot {
        let displayID = CGMainDisplayID()
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            throw StudioError.captureFailed
        }

        guard let rgba = RGBAImage(cgImage: cgImage) else {
            throw StudioError.imageDecodeFailed
        }

        return DisplaySnapshot(rgba: rgba, displayBounds: CGDisplayBounds(displayID))
    }

    func captureWindow(_ window: WindowInfo) async throws -> DisplaySnapshot {
        let bounds = window.screenBounds.integral
        guard bounds.width > 1, bounds.height > 1 else {
            throw StudioError.windowMissing("目标窗口范围无效。")
        }

        let image = try captureWindowImage(window, bounds: bounds)
        guard let rgba = RGBAImage(cgImage: image) else {
            throw StudioError.imageDecodeFailed
        }

        return DisplaySnapshot(rgba: rgba, displayBounds: bounds)
    }

    private func captureWindowImage(_ window: WindowInfo, bounds: CGRect) throws -> CGImage {
        let imageOptions: CGWindowImageOption = [.boundsIgnoreFraming, .bestResolution]

        if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowID), imageOptions), image.width > 1, image.height > 1 {
            return image
        }

        if let image = CGWindowListCreateImage(bounds, .optionIncludingWindow, CGWindowID(window.windowID), imageOptions), image.width > 1, image.height > 1 {
            return image
        }

        throw StudioError.windowMissing("无法按独立窗口截图。请确认目标窗口仍然存在，并已授予屏幕录制权限。")
    }
}
