import Foundation
import CoreGraphics

struct WindowInspectorService {
    func listWindows() -> [WindowInfo] {
        guard let rawList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawList.compactMap(parseWindowInfo)
    }

    func bounds(for target: WindowTarget) -> CGRect? {
        listWindows().first(where: { matches($0, target: target) })?.screenBounds
    }

    func window(for target: WindowTarget) -> WindowInfo? {
        listWindows().first(where: { matches($0, target: target) })
    }

    func window(at screenPoint: CGPoint) -> WindowInfo? {
        listWindows().first(where: { $0.screenBounds.contains(screenPoint) })
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

    private func parseWindowInfo(_ dictionary: [String: Any]) -> WindowInfo? {
        guard let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
              let ownerPID = dictionary[kCGWindowOwnerPID as String] as? Int,
              let windowNumber = dictionary[kCGWindowNumber as String] as? UInt32,
              let boundsDictionary = dictionary[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDictionary) else {
            return nil
        }

        let alpha = dictionary[kCGWindowAlpha as String] as? Double ?? 1
        let layer = dictionary[kCGWindowLayer as String] as? Int ?? 0
        let title = dictionary[kCGWindowName as String] as? String ?? ""

        guard alpha > 0, layer == 0, bounds.width >= 32, bounds.height >= 24 else {
            return nil
        }

        return WindowInfo(
            windowID: windowNumber,
            ownerName: ownerName,
            title: title,
            pid: Int32(ownerPID),
            layer: layer,
            screenBounds: bounds
        )
    }
}
