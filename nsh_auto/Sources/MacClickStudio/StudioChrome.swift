import SwiftUI
import AppKit

enum AppVisualTheme: String, CaseIterable, Identifiable {
    case defaultUI
    case frosted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .defaultUI:
            return "默认 UI"
        case .frosted:
            return "磨砂玻璃"
        }
    }

    var subtitle: String {
        switch self {
        case .defaultUI:
            return "更接近标准 macOS 工作台"
        case .frosted:
            return "高对比浅色玻璃，更适合长时间阅读"
        }
    }

    var workspaceBackground: LinearGradient {
        switch self {
        case .defaultUI:
            return LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .underPageBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .frosted:
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.97, blue: 1.00),
                    Color(red: 0.91, green: 0.94, blue: 0.98),
                    Color(red: 0.96, green: 0.97, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var panelFill: AnyShapeStyle {
        switch self {
        case .defaultUI:
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(0.98))
        case .frosted:
            return AnyShapeStyle(Color.white.opacity(0.82))
        }
    }

    var toolbarFill: AnyShapeStyle {
        switch self {
        case .defaultUI:
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(0.92))
        case .frosted:
            return AnyShapeStyle(Color.white.opacity(0.72))
        }
    }

    var cardFill: AnyShapeStyle {
        switch self {
        case .defaultUI:
            return AnyShapeStyle(Color(nsColor: .windowBackgroundColor).opacity(0.96))
        case .frosted:
            return AnyShapeStyle(Color.white.opacity(0.74))
        }
    }

    var floatingBarFill: AnyShapeStyle {
        switch self {
        case .defaultUI:
            return AnyShapeStyle(Color.black.opacity(0.74))
        case .frosted:
            return AnyShapeStyle(Color.white.opacity(0.70))
        }
    }

    var secondaryControlFill: AnyShapeStyle {
        switch self {
        case .defaultUI:
            return AnyShapeStyle(Color.white.opacity(0.10))
        case .frosted:
            return AnyShapeStyle(Color.black.opacity(0.06))
        }
    }

    var borderColor: Color {
        switch self {
        case .defaultUI:
            return Color.black.opacity(0.10)
        case .frosted:
            return Color.black.opacity(0.10)
        }
    }

    var highlightStrokeColor: Color {
        switch self {
        case .defaultUI:
            return Color.white.opacity(0.35)
        case .frosted:
            return Color.white.opacity(0.55)
        }
    }

    var shadowColor: Color {
        switch self {
        case .defaultUI:
            return Color.black.opacity(0.10)
        case .frosted:
            return Color.black.opacity(0.12)
        }
    }

    var ambientHighlightColor: Color {
        switch self {
        case .defaultUI:
            return Color.white.opacity(0.02)
        case .frosted:
            return Color.white.opacity(0.55)
        }
    }

    var windowBackgroundColor: NSColor {
        switch self {
        case .defaultUI:
            return NSColor.windowBackgroundColor
        case .frosted:
            return NSColor.white.withAlphaComponent(0.84)
        }
    }

    var regularWindowAlpha: CGFloat {
        switch self {
        case .defaultUI:
            return 1
        case .frosted:
            return 1
        }
    }

    var compactWindowAlpha: CGFloat {
        switch self {
        case .defaultUI:
            return 0.97
        case .frosted:
            return 0.97
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .defaultUI:
            return nil
        case .frosted:
            return .light
        }
    }

    var windowAppearance: NSAppearance? {
        switch self {
        case .defaultUI:
            return nil
        case .frosted:
            return NSAppearance(named: .aqua)
        }
    }

    static func resolve(_ rawValue: String) -> AppVisualTheme {
        AppVisualTheme(rawValue: rawValue) ?? .defaultUI
    }
}

struct StudioPanelGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        StudioPanelGroupBoxBody(configuration: configuration)
    }

    private struct StudioPanelGroupBoxBody: View {
        @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue
        let configuration: StudioPanelGroupBoxStyle.Configuration

        private var visualTheme: AppVisualTheme {
            .resolve(visualThemeRaw)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                    .font(.headline)
                configuration.content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(visualTheme.panelFill)
                    .shadow(color: visualTheme.shadowColor, radius: 18, x: 0, y: 8)
                    .shadow(color: visualTheme.ambientHighlightColor, radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(visualTheme.borderColor, lineWidth: 1)
            )
        }
    }
}

struct VisibilityToggleChip: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Group {
            if isOn {
                Button {
                    isOn.toggle()
                } label: {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    isOn.toggle()
                } label: {
                    Label(title, systemImage: systemImage)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.bordered)
            }
        }
        .controlSize(.regular)
    }
}

struct WorkspaceLayoutBar<Accessory: View>: View {
    @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue
    let title: String
    let subtitle: String
    @ViewBuilder let accessory: Accessory

    private var visualTheme: AppVisualTheme {
        .resolve(visualThemeRaw)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    accessory
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: 700)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(visualTheme.toolbarFill)
                .shadow(color: visualTheme.shadowColor, radius: 12, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(visualTheme.borderColor, lineWidth: 1)
        )
    }
}

struct StudioWorkspaceChromeModifier: ViewModifier {
    @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue

    private var visualTheme: AppVisualTheme {
        .resolve(visualThemeRaw)
    }

    func body(content: Content) -> some View {
        content
            .groupBoxStyle(StudioPanelGroupBoxStyle())
            .background(visualTheme.workspaceBackground.ignoresSafeArea())
            .preferredColorScheme(visualTheme.preferredColorScheme)
    }
}

enum WindowActivationController {
    @MainActor
    static func bringAppToFront(after delay: TimeInterval = 0.05) {
        let activate: @MainActor () -> Void = {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                NSApp.windows
                    .filter { $0.isVisible }
                    .forEach { $0.orderFrontRegardless() }
            }
        }

        Task { @MainActor in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            activate()
        }
    }
}

struct BringAppToFrontOnAppearModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onAppear {
            WindowActivationController.bringAppToFront()
        }
    }
}

struct StudioCardSurfaceModifier: ViewModifier {
    @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue

    private var visualTheme: AppVisualTheme {
        .resolve(visualThemeRaw)
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(visualTheme.cardFill)
                    .shadow(color: visualTheme.shadowColor, radius: 14, x: 0, y: 6)
                    .shadow(color: visualTheme.ambientHighlightColor, radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(visualTheme.borderColor, lineWidth: 1)
            )
    }
}

private struct WindowAccessorView: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                onResolve(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                onResolve(window)
            }
        }
    }
}

@MainActor
private final class CompactWindowSnapCoordinator: ObservableObject {
    private weak var window: NSWindow?
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private var snapWorkItem: DispatchWorkItem?
    private var isCompactMode = false
    private var isProgrammaticMove = false
    private var targetSize: CGSize = .zero
    private var snapAction: (@MainActor (NSWindow, CGSize) -> Void)?

    func bind(
        window: NSWindow,
        isCompactMode: Bool,
        targetSize: CGSize,
        snapAction: @escaping @MainActor (NSWindow, CGSize) -> Void
    ) {
        if self.window !== window {
            detachObservers()
            self.window = window
            moveObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.windowDidMove()
                }
            }
            screenObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.scheduleSnap(after: 0.05)
                }
            }
        }

        self.isCompactMode = isCompactMode
        self.targetSize = targetSize
        self.snapAction = snapAction

        if isCompactMode {
            scheduleSnap(after: 0.05)
        } else {
            snapWorkItem?.cancel()
        }
    }

    private func windowDidMove() {
        guard isCompactMode, !isProgrammaticMove else {
            return
        }
        scheduleSnap(after: 0.18)
    }

    private func scheduleSnap(after delay: TimeInterval) {
        guard isCompactMode, let window, let snapAction else {
            return
        }

        snapWorkItem?.cancel()
        let targetSize = self.targetSize
        let workItem = DispatchWorkItem { [weak self, weak window] in
            guard let self, let window else {
                return
            }

            DispatchQueue.main.async {
                self.isProgrammaticMove = true
                snapAction(window, targetSize)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                    self?.isProgrammaticMove = false
                }
            }
        }

        snapWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func detachObservers() {
        snapWorkItem?.cancel()
        if let moveObserver {
            NotificationCenter.default.removeObserver(moveObserver)
        }
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        moveObserver = nil
        screenObserver = nil
    }
}

struct GrabberUtilityWindowModifier: ViewModifier {
    @AppStorage("grabber.compactMode") private var isCompactMode = false
    @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue
    @StateObject private var snapCoordinator = CompactWindowSnapCoordinator()
    @State private var configuredWindowIdentifier: ObjectIdentifier?
    @State private var lastAppliedCompactMode: Bool?
    let initialSize: CGSize
    private let compactSize = CGSize(width: 252, height: 64)

    private var visualTheme: AppVisualTheme {
        .resolve(visualThemeRaw)
    }

    func body(content: Content) -> some View {
        content.background(
            WindowAccessorView { window in
                configure(window)
            }
        )
    }

    @MainActor
    private func configure(_ window: NSWindow) {
        let identifier = ObjectIdentifier(window)
        let targetSize = isCompactMode ? compactSize : initialSize
        let shouldRelayout = configuredWindowIdentifier != identifier || lastAppliedCompactMode != isCompactMode

        window.identifier = NSUserInterfaceItemIdentifier(AppSceneID.grabber)
        window.isReleasedWhenClosed = false
        window.backgroundColor = visualTheme.windowBackgroundColor
        window.appearance = visualTheme.windowAppearance
        window.isOpaque = false
        window.alphaValue = isCompactMode ? visualTheme.compactWindowAlpha : visualTheme.regularWindowAlpha
        window.hasShadow = true
        window.tabbingMode = .disallowed
        window.isMovableByWindowBackground = isCompactMode
        window.hidesOnDeactivate = false
        if isCompactMode {
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        } else {
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        }
        window.level = isCompactMode ? .floating : .normal
        window.titleVisibility = isCompactMode ? .hidden : .visible
        window.titlebarAppearsTransparent = isCompactMode
        window.standardWindowButton(.closeButton)?.isHidden = isCompactMode
        window.standardWindowButton(.miniaturizeButton)?.isHidden = isCompactMode
        window.standardWindowButton(.zoomButton)?.isHidden = isCompactMode

        if isCompactMode {
            window.styleMask.remove(.resizable)
            window.contentMinSize = compactSize
            window.contentMaxSize = compactSize
        } else {
            window.styleMask.insert(.resizable)
            window.contentMinSize = CGSize(width: 820, height: 620)
            window.contentMaxSize = CGSize(width: 10_000, height: 10_000)
        }

        snapCoordinator.bind(window: window, isCompactMode: isCompactMode, targetSize: targetSize) { snapWindow, size in
            snapWindowToEdge(snapWindow, targetSize: size)
        }

        guard shouldRelayout else {
            return
        }

        configuredWindowIdentifier = identifier
        lastAppliedCompactMode = isCompactMode
        window.setContentSize(targetSize)

        if isCompactMode {
            snapWindowToEdge(window, targetSize: targetSize)
        }
    }

    @MainActor
    private func snapWindowToEdge(_ window: NSWindow, targetSize: CGSize) {
        guard let visibleFrame = (window.screen ?? NSScreen.main)?.visibleFrame else {
            return
        }

        let dockToLeft = window.frame.midX < visibleFrame.midX
        let originX = dockToLeft
            ? visibleFrame.minX + 8
            : visibleFrame.maxX - targetSize.width - 8

        let originY = visibleFrame.maxY - targetSize.height - (isCompactMode ? 12 : 24)
        let frame = NSRect(x: originX, y: originY, width: targetSize.width, height: targetSize.height)
        window.setFrame(frame, display: true, animate: true)
    }
}

extension View {
    func studioWorkspaceChrome() -> some View {
        modifier(StudioWorkspaceChromeModifier())
    }

    func studioCardSurface() -> some View {
        modifier(StudioCardSurfaceModifier())
    }

    func bringAppToFrontOnAppear() -> some View {
        modifier(BringAppToFrontOnAppearModifier())
    }

    func grabberUtilityWindowStyle(initialSize: CGSize = CGSize(width: 900, height: 660)) -> some View {
        modifier(GrabberUtilityWindowModifier(initialSize: initialSize))
    }
}
