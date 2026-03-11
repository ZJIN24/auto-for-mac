import Foundation
import ApplicationServices

struct AccessibilityInspectorService {
    func inspectElement(at screenPoint: CGPoint, pid: Int32) -> AccessibilityElementInfo? {
        let application = AXUIElementCreateApplication(pid_t(pid))
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(
            application,
            Float(screenPoint.x),
            Float(screenPoint.y),
            &element
        )

        guard result == .success, let element else {
            return nil
        }

        return AccessibilityElementInfo(
            role: stringAttribute(kAXRoleAttribute, from: element),
            subrole: stringAttribute(kAXSubroleAttribute, from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            value: stringAttribute(kAXValueAttribute, from: element),
            identifier: stringAttribute("AXIdentifier", from: element),
            descriptionText: stringAttribute(kAXDescriptionAttribute, from: element)
        )
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let value else {
            return ""
        }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let attributedString as NSAttributedString:
            return attributedString.string
        default:
            return ""
        }
    }
}
