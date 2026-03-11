import SwiftUI
import AppKit

enum GrabberWindowController {
    @MainActor
    static func window() -> NSWindow? {
        NSApp.windows.first(where: { $0.identifier?.rawValue == AppSceneID.grabber })
            ?? NSApp.windows.first(where: { $0.title == "抓抓" })
    }

    @MainActor
    static func miniaturize() {
        window()?.miniaturize(nil)
    }

    @MainActor
    static func captureScreen(using store: StudioStore) {
        let targetWindow = window()
        store.statusMessage = "正在截图..."
        targetWindow?.orderOut(nil)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            store.captureScreen()
            try? await Task.sleep(for: .milliseconds(140))
            if let targetWindow {
                targetWindow.makeKeyAndOrderFront(nil)
            }
            WindowActivationController.bringAppToFront(after: 0)
        }
    }

    @MainActor
    static func captureSelectedWindow(using store: StudioStore) {
        let targetWindow = window()
        store.statusMessage = "正在截取目标窗口..."
        targetWindow?.orderOut(nil)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            store.captureSelectedWindow()
            try? await Task.sleep(for: .milliseconds(260))
            if let targetWindow {
                targetWindow.makeKeyAndOrderFront(nil)
            }
            WindowActivationController.bringAppToFront(after: 0)
        }
    }
}

enum AppSceneID {
    static let main = "main"
    static let grabber = "grabber"
}

enum MainWorkspaceSection: String, CaseIterable, Identifiable {
    case home
    case script
    case recording
    case library
    case logs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "开始"
        case .script: return "脚本"
        case .recording: return "录制"
        case .library: return "函数库"
        case .logs: return "日志"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .script: return "terminal"
        case .recording: return "record.circle"
        case .library: return "books.vertical"
        case .logs: return "text.alignleft"
        }
    }

    var requiresWorkspace: Bool {
        switch self {
        case .home, .library:
            return false
        case .script, .recording, .logs:
            return true
        }
    }
}

struct MainWorkspaceView: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.openWindow) private var openWindow
    @AppStorage("main.selectedSection") private var selectedSectionRaw = MainWorkspaceSection.home.rawValue
    @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue

    private var selectedSection: MainWorkspaceSection {
        get { MainWorkspaceSection(rawValue: selectedSectionRaw) ?? .home }
        nonmutating set { selectedSectionRaw = newValue.rawValue }
    }

    private var hasWorkspace: Bool {
        store.hasStartedWorkspaceSession
    }

    private var visualTheme: AppVisualTheme {
        .resolve(visualThemeRaw)
    }

    var body: some View {
        VStack(spacing: 14) {
            topBar

            if selectedSection == .home {
                ProjectWelcomeCenterView(
                    hasWorkspace: hasWorkspace,
                    onNewProject: startNewProject,
                    onOpenProject: openProject,
                    onOpenScript: openScript,
                    onShowLibrary: { selectedSection = .library }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if selectedSection.requiresWorkspace && !hasWorkspace {
                WorkspaceLockedPlaceholderView(
                    title: selectedSection.title,
                    onNewProject: startNewProject,
                    onOpenProject: openProject,
                    onOpenScript: openScript
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    sectionContent
                        .frame(minWidth: 860, maxWidth: .infinity, maxHeight: .infinity)

                    workspaceSummarySidebar
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                }
            }

            statusStrip
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MacClickStudio")
                        .font(.system(size: 26, weight: .bold))
                    Text(topSubtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 20)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        projectActionButtons
                        themeMenu
                        grabberActionButton
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        HStack(spacing: 8) {
                            projectActionButtons
                            themeMenu
                        }
                        grabberActionButton
                    }
                }
                .buttonStyle(.bordered)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MainWorkspaceSection.allCases) { section in
                        sectionTab(section)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .studioCardSurface()
    }

    @ViewBuilder
    private var projectActionButtons: some View {
        Button("新建项目", action: startNewProject)
        Button("打开项目…", action: openProject)
        Button("保存项目", action: saveProject)
            .disabled(!hasWorkspace)
    }

    private var themeMenu: some View {
        Menu {
            ForEach(AppVisualTheme.allCases) { theme in
                Button {
                    visualThemeRaw = theme.rawValue
                } label: {
                    Label(theme.title, systemImage: theme == visualTheme ? "checkmark.circle.fill" : "circle")
                }
            }

            Divider()

            Text(visualTheme.subtitle)
                .foregroundStyle(.secondary)
        } label: {
            Label(visualTheme.title, systemImage: visualTheme == .frosted ? "sparkles" : "macwindow")
        }
        .help("切换默认 UI / 磨砂玻璃")
    }

    private var grabberActionButton: some View {
        Button(action: openGrabber) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .frame(width: 34, height: 34)
                    Image(systemName: "scope")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("打开抓抓")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("角落截图、锁窗、录制")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(visualTheme.toolbarFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(visualTheme.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .home:
            EmptyView()

        case .script:
            ScriptEditorWorkspaceView(
                showLibrary: .constant(false),
                allowLibraryToggle: false,
                allowProjectActions: false
            )

        case .recording:
            RecordingWorkspaceView()
                .environmentObject(store)

        case .library:
            ScriptFunctionLibraryPanel()

        case .logs:
            ProjectLogsWorkspaceView()
                .environmentObject(store)
        }
    }

    private var workspaceSummarySidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                GroupBox("当前项目") {
                    VStack(alignment: .leading, spacing: 8) {
                        summaryLine("项目", value: store.currentProjectDisplayName)
                        summaryLine("脚本", value: store.currentScriptDisplayName)
                        summaryLine("路径", value: store.currentProjectPathDisplay)
                        summaryLine("状态", value: store.statusMessage)
                    }
                }

                GroupBox("当前目标") {
                    VStack(alignment: .leading, spacing: 8) {
                        summaryLine("窗口", value: store.selectedWindow?.displayTitle ?? "-")
                        summaryLine("PID", value: store.selectedWindow.map { "\($0.pid)" } ?? "-")
                        summaryLine("录制", value: store.recordingSummaryText)
                        summaryLine("坐标系", value: store.coordinateMode.title)
                        summaryLine("投递", value: store.deliveryMode.title)
                    }
                }

                GroupBox("项目资源") {
                    VStack(alignment: .leading, spacing: 8) {
                        resourceMetric("比色点", value: "\(store.samples.count)")
                        resourceMetric("模板图", value: "\(store.templates.count)")
                        resourceMetric("步骤数", value: "\(store.scriptSteps.count)")
                        resourceMetric("录制条目", value: "\(store.recordedWindowOperations.count)")
                        resourceMetric("窗口数", value: "\(store.windows.count)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 6)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            Label(store.statusMessage, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer()

            Text(store.currentScriptDisplayName)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Text(store.selectedWindow?.displayTitle ?? "未锁定窗口")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(visualTheme.toolbarFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(visualTheme.borderColor, lineWidth: 1)
        )
    }

    private var topSubtitle: String {
        if hasWorkspace {
            return "当前项目：\(store.currentProjectDisplayName) · 脚本：\(store.currentScriptDisplayName)"
        }
        return "主页面负责项目、脚本、录制和函数库；抓抓通过顶部按钮以角落子窗口打开。"
    }

    private func sectionTab(_ section: MainWorkspaceSection) -> some View {
        Group {
            if selectedSection == section {
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(minWidth: 82)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(minWidth: 82)
                }
                .buttonStyle(.bordered)
            }
        }
        .disabled(section.requiresWorkspace && !hasWorkspace && section != .logs)
    }

    private func startNewProject() {
        store.newProject()
        selectedSection = .script
    }

    private func openProject() {
        store.openProjectDocument()
        if store.hasStartedWorkspaceSession {
            selectedSection = .script
        }
    }

    private func openScript() {
        store.openScriptDocument()
        if store.hasStartedWorkspaceSession {
            selectedSection = .script
        }
    }

    private func saveProject() {
        store.saveProjectDocument()
    }

    private func openGrabber() {
        openWindow(id: AppSceneID.grabber)
        WindowActivationController.bringAppToFront()
    }

    private func summaryLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resourceMetric(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

private struct ProjectWelcomeCenterView: View {
    let hasWorkspace: Bool
    let onNewProject: () -> Void
    let onOpenProject: () -> Void
    let onOpenScript: () -> Void
    let onShowLibrary: () -> Void

    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("开始")
                        .font(.system(size: 34, weight: .bold))
                    Text("像 VS Code 一样从这里开始：先新建或打开项目；抓抓改成顶部入口，作为角落辅助窗口使用。")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    welcomeCard(
                        title: "新建项目",
                        subtitle: "创建一个空项目，然后在主页面继续写脚本和整理录制。",
                        systemImage: "folder.badge.plus",
                        accent: .accentColor,
                        action: onNewProject
                    )
                    welcomeCard(
                        title: "打开项目",
                        subtitle: "继续已有 `.mcstudio` 项目，直接回到脚本与录制工作流。",
                        systemImage: "folder",
                        accent: .blue,
                        action: onOpenProject
                    )
                    welcomeCard(
                        title: "打开脚本",
                        subtitle: "只打开脚本文件，也会直接进入脚本工作区。",
                        systemImage: "doc.text",
                        accent: .green,
                        action: onOpenScript
                    )
                    welcomeCard(
                        title: "函数库",
                        subtitle: "直接查看常用函数、示例和搜索结果，先熟悉脚本能力。",
                        systemImage: "books.vertical",
                        accent: .purple,
                        action: onShowLibrary
                    )
                }

                GroupBox("推荐流程") {
                    VStack(alignment: .leading, spacing: 10) {
                        stepRow(1, text: "点顶部“打开抓抓”，锁定目标窗口，完成截图、找点、录制。")
                        stepRow(2, text: "回到主页面，在“录制”里整理录制结果，导入步骤或转成脚本。")
                        stepRow(3, text: "在“脚本”里继续写 Python 3 / JavaScript 脚本，必要时查“函数库”。")
                        stepRow(4, text: "用“日志”检查运行状态，再保存项目。")
                    }
                }

                if hasWorkspace {
                    GroupBox("当前会话") {
                        Text("当前已有一个打开中的工作会话。你也可以直接切到上方“脚本 / 录制 / 日志 / 函数库”继续工作。")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func welcomeCard(
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("打开")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
            .studioCardSurface()
        }
        .buttonStyle(.plain)
    }

    private func stepRow(_ index: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.headline)
                .frame(width: 22, height: 22)
                .background(Color.accentColor.opacity(0.12), in: Circle())
            Text(text)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WorkspaceLockedPlaceholderView: View {
    let title: String
    let onNewProject: () -> Void
    let onOpenProject: () -> Void
    let onOpenScript: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("先新建或打开项目")
                .font(.title3.weight(.semibold))
            Text("“\(title)”页面依赖项目上下文。你可以先创建一个新项目，或打开已有项目 / 脚本。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Button("新建项目", action: onNewProject)
                Button("打开项目", action: onOpenProject)
                Button("打开脚本", action: onOpenScript)
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.14), lineWidth: 1)
        )
    }
}

private struct RecordingWorkspaceView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HSplitView {
            FixedWindowRecordingPanel(includeCaptureButton: false)
                .frame(minWidth: 520, idealWidth: 640)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("录制设置") {
                        VStack(alignment: .leading, spacing: 10) {
                            Picker("坐标系", selection: $store.coordinateMode) {
                                ForEach(CoordinateMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }

                            Picker("事件投递", selection: $store.deliveryMode) {
                                ForEach(EventDeliveryMode.allCases) { mode in
                                    Text(mode.title).tag(mode)
                                }
                            }

                            settingLine("当前窗口", value: store.selectedWindow?.displayTitle ?? "-")
                            settingLine("录制摘要", value: store.recordingSummaryText)
                            settingLine("相对坐标", value: pointText(store.selectedRelativePoint))
                        }
                    }

                    GroupBox("使用说明") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("窗口锁定、截图、找点和控件探测已经合并到抓抓子窗口。")
                            Text("在抓抓里锁定窗口并完成录制后，回到这里整理录制结果。")
                            Text("如果要后台回放固定窗口，建议把事件投递切到“目标进程投递”。")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }

                    GroupBox("当前控件摘要") {
                        VStack(alignment: .leading, spacing: 8) {
                            settingLine("摘要", value: store.selectedElementInfo?.summary ?? "-")
                            settingLine("描述", value: store.selectedElementInfo?.descriptionText ?? "-")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 6)
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
        }
    }

    private func settingLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func pointText(_ point: PixelPoint?) -> String {
        guard let point else { return "-" }
        return "(\(point.x), \(point.y))"
    }
}

private struct ProjectLogsWorkspaceView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        VSplitView {
            GroupBox("运行状态") {
                VStack(alignment: .leading, spacing: 10) {
                    statusLine("状态", value: store.statusMessage)
                    statusLine("项目", value: store.currentProjectPathDisplay)
                    statusLine("脚本", value: store.currentScriptPathDisplay)
                    statusLine("窗口", value: store.selectedWindow?.displayTitle ?? "-")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 160, idealHeight: 200)

            GroupBox("日志") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("共 \(store.logs.count) 条")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("清空日志") { store.clearLogs() }
                    }
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            if store.logs.isEmpty {
                                Text("还没有日志输出。")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(Array(store.logs.enumerated()), id: \.offset) { entry in
                                    Text(entry.element)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 240, idealHeight: 360)

            GroupBox("项目导出 JSON") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button("复制 JSON") { store.copyScriptJSON() }
                    }
                    ScrollView {
                        Text(store.exportScriptJSON())
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 220, idealHeight: 320)
        }
    }

    private func statusLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct GrabberUtilityWindowView: View {
    @EnvironmentObject private var store: StudioStore
    @AppStorage("grabber.compactMode") private var isCompactMode = false
    @AppStorage("app.visualTheme") private var visualThemeRaw = AppVisualTheme.defaultUI.rawValue
    @State private var canvasZoom: CGFloat = 1.0
    @State private var showCaptureSection = true
    @State private var showPointSection = true
    @State private var showRecordingSection = true
    @State private var showOCRSection = true

    private var visualTheme: AppVisualTheme {
        .resolve(visualThemeRaw)
    }

    var body: some View {
        Group {
            if isCompactMode {
                compactBody
            } else {
                VStack(spacing: 12) {
                    grabberHeader
                    expandedBody
                    grabberInfoLine("状态", value: store.statusMessage)
                }
            }
        }
        .padding(isCompactMode ? 6 : 12)
        .padding(.top, isCompactMode ? 0 : 6)
        .frame(
            minWidth: isCompactMode ? 252 : 820,
            idealWidth: isCompactMode ? 252 : 980,
            maxWidth: isCompactMode ? 252 : .infinity,
            minHeight: isCompactMode ? 64 : 620,
            idealHeight: isCompactMode ? 64 : 760,
            maxHeight: isCompactMode ? 64 : .infinity
        )
        .animation(.easeInOut(duration: 0.18), value: isCompactMode)
    }

    private var expandedBody: some View {
        HSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GrabberExpandableSection(title: "截图与窗口", isExpanded: $showCaptureSection) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button("申请权限") { store.requestPermissions() }
                                Button("截图") { captureScreenFromGrabber() }
                                Button("导入截图") { store.importScreenshotImage() }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("申请权限") { store.requestPermissions() }
                                Button("截图") { captureScreenFromGrabber() }
                                Button("导入截图") { store.importScreenshotImage() }
                            }
                        }
                        .buttonStyle(.bordered)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button("截目标窗口") { captureSelectedWindowFromGrabber() }
                                    .disabled(store.selectedWindow == nil)
                                Button("保存当前截图") { store.exportCurrentScreenshotImage() }
                                Button("刷新窗口") { store.refreshWindows() }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("截目标窗口") { captureSelectedWindowFromGrabber() }
                                    .disabled(store.selectedWindow == nil)
                                Button("保存当前截图") { store.exportCurrentScreenshotImage() }
                                Button("刷新窗口") { store.refreshWindows() }
                            }
                        }
                        .buttonStyle(.bordered)

                        WindowTargetPickerBar(title: "抓抓目标窗口", includeCaptureButton: false, compact: true)

                        Picker("坐标系", selection: $store.coordinateMode) {
                            ForEach(CoordinateMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("事件投递", selection: $store.deliveryMode) {
                            ForEach(EventDeliveryMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        grabberInfoLine("当前来源", value: store.currentCaptureSource)
                        grabberInfoLine("当前窗口", value: store.selectedWindow?.displayTitle ?? "-")
                    }

                    GrabberExpandableSection(title: "抓点与模板", isExpanded: $showPointSection) {
                        Picker("模式", selection: $store.interactionMode) {
                            ForEach(InteractionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260, alignment: .leading)

                        HStack {
                            Stepper("偏移 X：\(store.captureOffsetX)", value: $store.captureOffsetX, in: -30...30)
                            Stepper("偏移 Y：\(store.captureOffsetY)", value: $store.captureOffsetY, in: -30...30)
                        }

                        Picker("模板预处理", selection: $store.templateProcessingMode) {
                            ForEach(TemplateProcessingMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button("保存模板") { store.saveTemplateFromSelection() }
                                    .disabled(store.selectedRect == nil)
                                Button("保存选区图") { store.exportSelectionScreenshotImage() }
                                    .disabled(store.selectedRect == nil)
                                Button("清空选区") { store.clearSelection() }
                                    .disabled(store.selectedRect == nil)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("保存模板") { store.saveTemplateFromSelection() }
                                    .disabled(store.selectedRect == nil)
                                Button("保存选区图") { store.exportSelectionScreenshotImage() }
                                    .disabled(store.selectedRect == nil)
                                Button("清空选区") { store.clearSelection() }
                                    .disabled(store.selectedRect == nil)
                            }
                        }
                        .buttonStyle(.bordered)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button("2 分") { store.exportSelectionSlices(rows: 1, columns: 2) }
                                    .disabled(store.selectedRect == nil)
                                Button("2 × 2") { store.exportSelectionSlices(rows: 2, columns: 2) }
                                    .disabled(store.selectedRect == nil)
                                Button("3 × 3") { store.exportSelectionSlices(rows: 3, columns: 3) }
                                    .disabled(store.selectedRect == nil)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("2 分") { store.exportSelectionSlices(rows: 1, columns: 2) }
                                    .disabled(store.selectedRect == nil)
                                Button("2 × 2") { store.exportSelectionSlices(rows: 2, columns: 2) }
                                    .disabled(store.selectedRect == nil)
                                Button("3 × 3") { store.exportSelectionSlices(rows: 3, columns: 3) }
                                    .disabled(store.selectedRect == nil)
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    GrabberExpandableSection(title: "固定窗口录制", isExpanded: $showRecordingSection) {
                        FixedWindowRecordingPanel(compact: true, includeCaptureButton: false, showTargetPicker: false)
                    }

                    GrabberExpandableSection(title: "OCR 与控件", isExpanded: $showOCRSection) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button("OCR") { store.runOCR() }
                                Button("复制 OCR") { store.copyOCRResult() }
                                    .disabled(store.ocrResult.isEmpty)
                                Button("清空 OCR") { store.clearOCRResult() }
                                    .disabled(store.ocrResult.isEmpty)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("OCR") { store.runOCR() }
                                Button("复制 OCR") { store.copyOCRResult() }
                                    .disabled(store.ocrResult.isEmpty)
                                Button("清空 OCR") { store.clearOCRResult() }
                                    .disabled(store.ocrResult.isEmpty)
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("探测当前点位控件") { store.inspectElementAtSelectedPoint() }
                            .buttonStyle(.bordered)

                        grabberInfoLine("控件摘要", value: store.selectedElementInfo?.summary ?? "-")
                        grabberInfoLine("控件描述", value: store.selectedElementInfo?.descriptionText ?? "-")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 8)
            }
            .frame(minWidth: 300, idealWidth: 340, maxWidth: 360)

            VStack(spacing: 12) {
                GroupBox("抓抓画布") {
                    if let image = store.snapshot?.nsImage {
                        ScreenshotCanvasView(image: image, zoomScale: $canvasZoom)
                            .environmentObject(store)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "scope")
                                .font(.system(size: 42))
                                .foregroundStyle(.secondary)
                            Text("还没有截图")
                                .font(.headline)
                            Text("在左侧选择截图、导入截图或截取目标窗口。")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minHeight: 390)

                GroupBox("点位信息") {
                    VStack(alignment: .leading, spacing: 12) {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], alignment: .leading, spacing: 10) {
                            grabberInfoLine("点击坐标", value: pointText(store.selectedPoint))
                            grabberInfoLine("窗口相对", value: pointText(store.selectedRelativePoint))
                            grabberInfoLine("取色坐标", value: pointText(store.selectedSamplePoint))
                            grabberInfoLine("颜色", value: store.selectedColor?.hexString ?? "-")
                            grabberInfoLine("选区", value: rectText(store.selectedRect))
                            grabberInfoLine("缩放", value: "\(Int(canvasZoom * 100))%")
                        }

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                Button("加入比色点") { store.addSampleFromSelectedPoint() }
                                Button("复制坐标") { store.copySelectedCoordinate() }
                                Button("复制颜色") { store.copySelectedColor() }
                                Button("复制窗口信息") { store.copySelectedWindowInfo() }
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Button("加入比色点") { store.addSampleFromSelectedPoint() }
                                Button("复制坐标") { store.copySelectedCoordinate() }
                                Button("复制颜色") { store.copySelectedColor() }
                                Button("复制窗口信息") { store.copySelectedWindowInfo() }
                            }
                        }
                        .buttonStyle(.bordered)

                        HStack(spacing: 8) {
                            Button("50%") { canvasZoom = 0.5 }
                            Button("100%") { canvasZoom = 1.0 }
                            Button("放大") { canvasZoom = min(4.0, canvasZoom + 0.1) }
                            Button("缩小") { canvasZoom = max(0.4, canvasZoom - 0.1) }
                            Spacer()
                            Text("滚轮可缩放")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var grabberHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Button(action: {
                    isCompactMode.toggle()
                    if isCompactMode {
                        resizeWindowToCompact()
                    } else {
                        resizeWindowToExpanded()
                    }
                }) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
                .help("切换小浮条")
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("抓抓")
                    .font(.headline)
                Text(isCompactMode ? "缩小模式" : "截图、锁窗、录制都在这里")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("最小化") {
                GrabberWindowController.miniaturize()
            }
            .buttonStyle(.bordered)
        }
    }

    private func resizeWindowToCompact() {
        guard let window = GrabberWindowController.window() else { return }
        let newSize = NSSize(width: 252, height: 64)
        window.setContentSize(newSize)
    }

    private func resizeWindowToExpanded() {
        guard let window = GrabberWindowController.window() else { return }
        let newSize = NSSize(width: 860, height: 620)
        window.setContentSize(newSize)
    }

    private var compactBody: some View {
        HStack(spacing: 6) {
            floatingBarButton(title: "截图", systemImage: "camera.fill", primary: true) {
                captureScreenFromGrabber()
            }

            floatingBarButton(title: "开始", systemImage: "record.circle.fill") {
                store.startWindowOperationRecording()
            }
            .disabled(store.selectedWindow == nil || store.isRecordingWindowOperations)
            .help("开始录制")

            floatingBarButton(title: "结束", systemImage: "stop.circle.fill") {
                store.stopWindowOperationRecording()
            }
            .disabled(!store.isRecordingWindowOperations)
            .help("结束录制")

            floatingBarButton(title: "恢复", systemImage: "arrow.up.left.and.arrow.down.right") {
                isCompactMode = false
                resizeWindowToExpanded()
                WindowActivationController.bringAppToFront(after: 0)
            }
            .help("恢复原窗口")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(visualTheme.floatingBarFill, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(visualTheme.highlightStrokeColor, lineWidth: 1)
        )
        .shadow(color: visualTheme.shadowColor, radius: 18, x: 0, y: 10)
        .frame(width: 240, height: 52, alignment: .center)
    }

    @ViewBuilder
    private func floatingBarButton(
        title: String,
        systemImage: String,
        primary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(primary ? Color.white : (visualTheme == .frosted ? Color.primary : Color.white.opacity(0.92)))
            .frame(width: 50, height: 38)
            .background(
                Capsule(style: .continuous)
                    .fill(primary ? AnyShapeStyle(Color.accentColor.gradient) : visualTheme.secondaryControlFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(primary ? Color.clear : visualTheme.borderColor.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func captureScreenFromGrabber() {
        GrabberWindowController.captureScreen(using: store)
    }

    private func captureSelectedWindowFromGrabber() {
        GrabberWindowController.captureSelectedWindow(using: store)
    }

    private func pointText(_ point: PixelPoint?) -> String {
        guard let point else { return "-" }
        return "(\(point.x), \(point.y))"
    }

    private func rectText(_ rect: PixelRect?) -> String {
        guard let rect else { return "-" }
        return "x:\(rect.x) y:\(rect.y) w:\(rect.width) h:\(rect.height)"
    }

    private func grabberInfoLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GrabberExpandableSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    let content: () -> Content

    init(title: String, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self._isExpanded = isExpanded
        self.content = content
    }

    var body: some View {
        GroupBox {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    content()
                }
                .padding(.top, 8)
            } label: {
                Text(title)
            }
        }
    }
}

struct AppMenuBarPanelView: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MacClickStudio")
                        .font(.title3.weight(.bold))
                    Text(store.currentProjectDisplayName)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(store.selectedWindow?.displayTitle ?? "还没有锁定窗口")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioCardSurface()

                GroupBox("工作区") {
                    VStack(alignment: .leading, spacing: 8) {
                        actionButton("打开主页", systemImage: "house") { openMain() }
                        actionButton("打开抓抓", systemImage: "scope") { openGrabber() }
                    }
                }

                GroupBox("项目") {
                    VStack(alignment: .leading, spacing: 8) {
                        actionButton("新建项目", systemImage: "folder.badge.plus") { store.newProject() }
                        actionButton("打开项目", systemImage: "folder") { store.openProjectDocument() }
                        actionButton("保存项目", systemImage: "square.and.arrow.down", enabled: store.hasStartedWorkspaceSession) { store.saveProjectDocument() }
                        actionButton("打开脚本", systemImage: "doc.text") { store.openScriptDocument() }
                    }
                }

                GroupBox("状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        statusLine("脚本", value: store.currentScriptDisplayName)
                        statusLine("录制", value: store.recordingSummaryText)
                        statusLine("状态", value: store.statusMessage)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 320, height: 460)
        .controlSize(.large)
    }

    private func actionButton(_ title: String, systemImage: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .disabled(!enabled)
    }

    private func statusLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openMain() {
        openWindow(id: AppSceneID.main)
        WindowActivationController.bringAppToFront()
    }

    private func openGrabber() {
        openWindow(id: AppSceneID.grabber)
        WindowActivationController.bringAppToFront()
    }
}

struct MainAppCommands: Commands {
    @ObservedObject var store: StudioStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("工作区") {
            Button("打开主页") { openMain() }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("打开抓抓") { openGrabber() }
                .keyboardShortcut("2", modifiers: [.command, .option])
        }

        CommandMenu("项目") {
            Button("新建项目") { store.newProject() }
                .keyboardShortcut("n", modifiers: [.command])
            Button("打开项目…") { store.openProjectDocument() }
                .keyboardShortcut("o", modifiers: [.command])
            Button("保存项目") { store.saveProjectDocument() }
                .keyboardShortcut("s", modifiers: [.command])
            Button("项目另存为…") { store.saveProjectDocumentAs() }
                .keyboardShortcut("S", modifiers: [.command, .shift])
        }

        CommandMenu("脚本") {
            Button("新建脚本") { store.newScriptDocument() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("打开脚本…") { store.openScriptDocument() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button("保存脚本") { store.saveScriptDocument() }
                .keyboardShortcut("s", modifiers: [.command, .option])
            Button("脚本另存为…") { store.saveScriptDocumentAs() }
                .keyboardShortcut("S", modifiers: [.command, .option, .shift])
            Divider()
            Button(store.isRunningCode ? "执行中..." : "运行当前脚本") { store.runScriptSource() }
                .disabled(store.isRunningCode)
                .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandMenu("录制") {
            Button("开始固定窗口录制") { store.startWindowOperationRecording() }
                .disabled(store.selectedWindow == nil || store.isRecordingWindowOperations)
            Button("停止固定窗口录制") { store.stopWindowOperationRecording() }
                .disabled(!store.isRecordingWindowOperations)
            Button("导入录制到步骤") { store.importRecordedOperationsToSteps() }
                .disabled(store.recordedWindowOperations.isEmpty)
            Button("把录制追加到脚本") { store.appendRecordedOperationsToScriptSource() }
                .disabled(store.recordedWindowOperations.isEmpty)
        }
    }

    private func openMain() {
        openWindow(id: AppSceneID.main)
        WindowActivationController.bringAppToFront()
    }

    private func openGrabber() {
        openWindow(id: AppSceneID.grabber)
        WindowActivationController.bringAppToFront()
    }
}
