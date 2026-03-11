import SwiftUI

enum WorkspaceSceneID {
    static let launchpad = "launchpad"
    static let studio = "studio"
    static let grabber = "grabber"
    static let windowLab = "window-lab"
    static let scriptCenter = "script-center"
}

struct LaunchpadView: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                quickActions
                workspaceCards
                summary
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("MacClickStudio")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MacClickStudio 启动台")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("把抓抓、窗口实验室和脚本中心拆成多个工作区，更适合长期盯一个程序做自动化。")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var quickActions: some View {
        GroupBox("快捷操作") {
            HStack {
                Button("申请权限") { store.requestPermissions() }
                Button("截图") { store.captureScreen() }
                Button("截当前窗口") { store.captureSelectedWindow() }
                    .disabled(store.selectedWindow == nil)
                Button("打开项目") { store.openProjectDocument() }
                Button("保存项目") { store.saveProjectDocument() }
                Button("刷新窗口") { store.refreshWindows() }
                Button("OCR") { store.runOCR() }
                Spacer()
            }
        }
    }

    private var workspaceCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("工作区")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                workspaceCard(
                    title: "全景工作台",
                    systemImage: "square.grid.3x3.fill",
                    description: "一个窗口里看全：抓抓、窗口、步骤脚本、脚本编辑器、日志。",
                    action: { openWorkspace(WorkspaceSceneID.studio) }
                )
                workspaceCard(
                    title: "抓抓",
                    systemImage: "scope",
                    description: "专注截图、找点、找色、框区域、模板制作和 OCR。",
                    action: { openWorkspace(WorkspaceSceneID.grabber) }
                )
            }

            HStack(spacing: 12) {
                workspaceCard(
                    title: "窗口实验室",
                    systemImage: "macwindow.on.rectangle",
                    description: "锁定窗口、看 PID / 窗口 ID、取相对坐标、探测控件。",
                    action: { openWorkspace(WorkspaceSceneID.windowLab) }
                )
                workspaceCard(
                    title: "脚本中心",
                    systemImage: "terminal",
                    description: "步骤脚本和 Python 3 / JavaScript 两套脚本一起写、一起跑。",
                    action: { openWorkspace(WorkspaceSceneID.scriptCenter) }
                )
            }
        }
    }

    private var summary: some View {
        GroupBox("项目概览") {
            VStack(alignment: .leading, spacing: 10) {
                metricRow(title: "比色点", value: "\(store.samples.count)")
                metricRow(title: "模板图", value: "\(store.templates.count)")
                metricRow(title: "步骤数", value: "\(store.scriptSteps.count)")
                metricRow(title: "窗口数", value: "\(store.windows.count)")
                metricRow(title: "当前锁定窗口", value: store.selectedWindow?.displayTitle ?? "-")
                metricRow(title: "状态", value: store.statusMessage)
            }
        }
    }

    private func workspaceCard(title: String, systemImage: String, description: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Text("打开")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .studioCardSurface()
        }
        .buttonStyle(.plain)
    }

    private func metricRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func openWorkspace(_ id: String) {
        openWindow(id: id)
        WindowActivationController.bringAppToFront()
    }
}

struct GrabberWorkspaceView: View {
    @EnvironmentObject private var store: StudioStore
    @State private var canvasZoom: CGFloat = 1.0
    @State private var showCaptureSection = true
    @State private var showInteractionSection = true
    @State private var showZoomSection = true
    @State private var showSplitSection = true
    @State private var showOCRSection = true
    @State private var showPointInfoSection = true

    var body: some View {
        HSplitView {
            leftSidebar
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 430)

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
                            Text("先从左侧选择截图、窗口截图或导入图片，再开始抓点。")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 620, minHeight: 420, idealHeight: 560, maxHeight: .infinity)

                GroupBox {
                    DisclosureGroup(isExpanded: $showPointInfoSection) {
                        VStack(alignment: .leading, spacing: 12) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], alignment: .leading, spacing: 10) {
                                infoLine("点击坐标", value: pointText(store.selectedPoint))
                                infoLine("窗口相对坐标", value: pointText(store.selectedRelativePoint))
                                infoLine("取色坐标", value: pointText(store.selectedSamplePoint))
                                infoLine("颜色", value: store.selectedColor?.hexString ?? "-")
                                infoLine("选区", value: rectText(store.selectedRect))
                                infoLine("缩放", value: "\(Int(canvasZoom * 100))%")
                            }

                            ViewThatFits(in: .horizontal) {
                                pointActionRowInline
                                pointActionRowStacked
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.top, 8)
                    } label: {
                        Text("点位信息")
                    }
                }
            }
        }
        .padding(12)
    }

    private var leftSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                captureSection
                interactionSection
                zoomSection
                splitSection
                ocrSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
        }
    }

    private var captureSection: some View {
        CollapsibleToolSection(title: "截图与窗口", isExpanded: $showCaptureSection) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("申请权限") { store.requestPermissions() }
                    Button("截图") { store.captureScreen() }
                    Button("截目标窗口") { store.captureSelectedWindow() }
                        .disabled(store.selectedWindow == nil)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("申请权限") { store.requestPermissions() }
                    Button("截图") { store.captureScreen() }
                    Button("截目标窗口") { store.captureSelectedWindow() }
                        .disabled(store.selectedWindow == nil)
                }
            }
            .buttonStyle(.bordered)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("导入截图") { store.importScreenshotImage() }
                    Button("保存当前截图") { store.exportCurrentScreenshotImage() }
                    Button("刷新窗口") { store.refreshWindows() }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("导入截图") { store.importScreenshotImage() }
                    Button("保存当前截图") { store.exportCurrentScreenshotImage() }
                    Button("刷新窗口") { store.refreshWindows() }
                }
            }
            .buttonStyle(.bordered)

            WindowTargetPickerBar(title: "抓抓目标窗口")
            infoLine("当前来源", value: store.currentCaptureSource)
        }
    }

    private var interactionSection: some View {
        CollapsibleToolSection(title: "取点与识别", isExpanded: $showInteractionSection) {
            Picker("模式", selection: $store.interactionMode) {
                ForEach(InteractionMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Stepper("偏移 X：\(store.captureOffsetX)", value: $store.captureOffsetX, in: -30...30)
                Stepper("偏移 Y：\(store.captureOffsetY)", value: $store.captureOffsetY, in: -30...30)
            }

            Picker("模板预处理", selection: $store.templateProcessingMode) {
                ForEach(TemplateProcessingMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("按点位锁定窗口") { store.lockWindowFromSelectedPoint() }
                    Button("保存模板") { store.saveTemplateFromSelection() }
                        .disabled(store.selectedRect == nil)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("按点位锁定窗口") { store.lockWindowFromSelectedPoint() }
                    Button("保存模板") { store.saveTemplateFromSelection() }
                        .disabled(store.selectedRect == nil)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var zoomSection: some View {
        CollapsibleToolSection(title: "图片缩放", isExpanded: $showZoomSection) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("50%") { canvasZoom = 0.5 }
                    Button("100%") { canvasZoom = 1.0 }
                    Button("适合画布") { canvasZoom = 1.0 }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("50%") { canvasZoom = 0.5 }
                    Button("100%") { canvasZoom = 1.0 }
                    Button("适合画布") { canvasZoom = 1.0 }
                }
            }
            .buttonStyle(.bordered)

            Slider(value: $canvasZoom, in: 0.4...4.0)

            HStack(spacing: 8) {
                Button("缩小") { canvasZoom = max(0.4, canvasZoom - 0.1) }
                Button("放大") { canvasZoom = min(4.0, canvasZoom + 0.1) }
                Spacer()
                Text("\(Int(canvasZoom * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.bordered)

            Text("鼠标停在画布上滚动滚轮，就能直接缩放图片。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var splitSection: some View {
        CollapsibleToolSection(title: "分割与保存", isExpanded: $showSplitSection) {
            Text("分割会把当前选区裁成多张 PNG 图片，并保存到你选择的文件夹。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("保存选区截图") { store.exportSelectionScreenshotImage() }
                    Button("清空选区") { store.clearSelection() }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("保存选区截图") { store.exportSelectionScreenshotImage() }
                    Button("清空选区") { store.clearSelection() }
                }
            }
            .buttonStyle(.bordered)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("左右 2 分") { store.exportSelectionSlices(rows: 1, columns: 2) }
                    Button("上下 2 分") { store.exportSelectionSlices(rows: 2, columns: 1) }
                    Button("2 × 2 分") { store.exportSelectionSlices(rows: 2, columns: 2) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("左右 2 分") { store.exportSelectionSlices(rows: 1, columns: 2) }
                    Button("上下 2 分") { store.exportSelectionSlices(rows: 2, columns: 1) }
                    Button("2 × 2 分") { store.exportSelectionSlices(rows: 2, columns: 2) }
                }
            }
            .buttonStyle(.bordered)

            Button("3 × 3 九宫格") { store.exportSelectionSlices(rows: 3, columns: 3) }
                .buttonStyle(.bordered)
        }
    }

    private var ocrSection: some View {
        CollapsibleToolSection(title: "OCR 结果", isExpanded: $showOCRSection) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Button("识别当前选区") { store.runOCR() }
                    Button("复制 OCR") { store.copyOCRResult() }
                        .disabled(store.ocrResult.isEmpty)
                    Button("清空 OCR") { store.clearOCRResult() }
                        .disabled(store.ocrResult.isEmpty)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Button("识别当前选区") { store.runOCR() }
                    Button("复制 OCR") { store.copyOCRResult() }
                        .disabled(store.ocrResult.isEmpty)
                    Button("清空 OCR") { store.clearOCRResult() }
                        .disabled(store.ocrResult.isEmpty)
                }
            }
            .buttonStyle(.bordered)

            ScrollView {
                Text(store.ocrResult.isEmpty ? "先框一个区域，再点 OCR。" : store.ocrResult)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(store.ocrResult.isEmpty ? .secondary : .primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120)
        }
    }

    private var pointActionRowInline: some View {
        HStack(spacing: 8) {
            Button("加入比色点") { store.addSampleFromSelectedPoint() }
            Button("保存模板") { store.saveTemplateFromSelection() }
            Button("复制点击坐标") { store.copySelectedCoordinate() }
            Button("复制取色坐标") { store.copySelectedSampleCoordinate() }
            Button("复制颜色") { store.copySelectedColor() }
            Button("清空选区") { store.clearSelection() }
        }
    }

    private var pointActionRowStacked: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("加入比色点") { store.addSampleFromSelectedPoint() }
                Button("保存模板") { store.saveTemplateFromSelection() }
                Button("复制点击坐标") { store.copySelectedCoordinate() }
            }
            HStack(spacing: 8) {
                Button("复制取色坐标") { store.copySelectedSampleCoordinate() }
                Button("复制颜色") { store.copySelectedColor() }
                Button("清空选区") { store.clearSelection() }
            }
        }
    }

    private func pointText(_ point: PixelPoint?) -> String {
        guard let point else { return "-" }
        return "(\(point.x), \(point.y))"
    }

    private func rectText(_ rect: PixelRect?) -> String {
        guard let rect else { return "-" }
        return "x:\(rect.x) y:\(rect.y) w:\(rect.width) h:\(rect.height)"
    }

    private func infoLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct CollapsibleToolSection<Content: View>: View {
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

struct WindowLabView: View {
    @EnvironmentObject private var store: StudioStore

    var body: some View {
        HSplitView {
            GroupBox("窗口列表") {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(store.windows) { window in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(window.displayTitle)
                                        .font(.headline)
                                    Text("handle=\(window.windowID) pid=\(window.pid)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Text(window.shortBoundsText)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(store.selectedWindowID == window.windowID ? "已选中" : "选中") {
                                    store.selectWindow(window.windowID)
                                }
                                .disabled(store.selectedWindowID == window.windowID)
                            }
                            Divider()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(minWidth: 360, idealWidth: 420)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    GroupBox("窗口控制") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button("刷新窗口") { store.refreshWindows() }
                                Button("按点位锁定窗口") { store.lockWindowFromSelectedPoint() }
                                Button("截当前窗口") { store.captureSelectedWindow() }
                                    .disabled(store.selectedWindow == nil)
                                Button("探测控件") { store.inspectElementAtSelectedPoint() }
                            }

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
                        }
                    }

                    GroupBox("当前窗口") {
                        VStack(alignment: .leading, spacing: 8) {
                            infoLine("窗口", value: store.selectedWindow?.displayTitle ?? "-")
                            infoLine("窗口 ID", value: store.selectedWindow.map { "\($0.windowID)" } ?? "-")
                            infoLine("PID", value: store.selectedWindow.map { "\($0.pid)" } ?? "-")
                            infoLine("相对坐标", value: pointText(store.selectedRelativePoint))
                            infoLine("状态", value: store.statusMessage)

                            Button("复制窗口信息") {
                                store.copySelectedWindowInfo()
                            }
                            Button("截取当前窗口") {
                                store.captureSelectedWindow()
                            }
                            .disabled(store.selectedWindow == nil)
                        }
                    }

                    FixedWindowRecordingPanel()

                    GroupBox("控件探测") {
                        VStack(alignment: .leading, spacing: 8) {
                            infoLine("摘要", value: store.selectedElementInfo?.summary ?? "-")
                            infoLine("描述", value: store.selectedElementInfo?.descriptionText ?? "-")
                        }
                    }

                    GroupBox("日志") {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(store.logs.enumerated()), id: \.offset) { entry in
                                    Text(entry.element)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(minHeight: 180)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minWidth: 420)
        }
        .padding(12)
    }

    private func pointText(_ point: PixelPoint?) -> String {
        guard let point else { return "-" }
        return "(\(point.x), \(point.y))"
    }

    private func infoLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct ScriptCenterView: View {
    @EnvironmentObject private var store: StudioStore
    @AppStorage("scriptCenter.showSteps") private var showSteps = true
    @AppStorage("scriptCenter.showLog") private var showLog = true
    @AppStorage("scriptCenter.showFunctionLibrary") private var showFunctionLibrary = true

    var body: some View {
        VStack(spacing: 10) {
            WorkspaceLayoutBar(
                title: "脚本中心布局",
                subtitle: "拖动分割线调节模块大小；写脚本时可以把步骤、函数库、日志先收起来。"
            ) {
                VisibilityToggleChip(title: "步骤", systemImage: "list.bullet.rectangle", isOn: $showSteps)
                VisibilityToggleChip(title: "函数库", systemImage: "books.vertical", isOn: $showFunctionLibrary)
                VisibilityToggleChip(title: "日志", systemImage: "text.alignleft", isOn: $showLog)
            }

            if showSteps {
                HSplitView {
                    stepsPanel
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
                    editorAndLogArea
                }
            } else {
                editorAndLogArea
            }
        }
        .padding(12)
    }

    private var stepsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            FixedWindowRecordingPanel()

            GroupBox("步骤脚本") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button(store.isRunningScript ? "执行中..." : "运行步骤") { store.startRunScript() }
                            .disabled(store.isRunningScript)
                        Button("复制 JSON") { store.copyScriptJSON() }
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if store.scriptSteps.isEmpty {
                                Text("还没有步骤。你可以回到抓抓或全景工作台添加。")
                                    .foregroundStyle(.secondary)
                            }
                            ForEach(store.scriptSteps) { step in
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(step.kind.title)
                                            .font(.headline)
                                        Text(store.stepSummary(step))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button(step.isEnabled ? "禁用" : "启用") {
                                        store.toggleStep(step.id)
                                    }
                                }
                                Divider()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var editorAndLogArea: some View {
        if showLog {
            VSplitView {
                ScriptEditorWorkspaceView(showLibrary: $showFunctionLibrary)
                    .frame(minHeight: 460, idealHeight: 620)

                GroupBox("日志") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(store.statusMessage)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("清空") { store.clearLogs() }
                        }
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(store.logs.enumerated()), id: \.offset) { entry in
                                    Text(entry.element)
                                        .font(.system(size: 12, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(minHeight: 180, idealHeight: 220)
            }
        } else {
            ScriptEditorWorkspaceView(showLibrary: $showFunctionLibrary)
        }
    }
}

struct MenuBarPanelView: View {
    @EnvironmentObject private var store: StudioStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MacClickStudio")
                        .font(.title3.weight(.bold))
                    Text(store.selectedWindow?.displayTitle ?? "还没有锁定窗口")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(store.currentProjectDisplayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioCardSurface()

                GroupBox("工作区") {
                    VStack(alignment: .leading, spacing: 8) {
                        actionButton("打开启动台", systemImage: "square.grid.2x2") { openWorkspace(WorkspaceSceneID.launchpad) }
                        actionButton("打开全景工作台", systemImage: "square.grid.3x3.fill") { openWorkspace(WorkspaceSceneID.studio) }
                        actionButton("打开抓抓", systemImage: "scope") { openWorkspace(WorkspaceSceneID.grabber) }
                        actionButton("打开窗口实验室", systemImage: "macwindow.on.rectangle") { openWorkspace(WorkspaceSceneID.windowLab) }
                        actionButton("打开脚本中心", systemImage: "terminal") { openWorkspace(WorkspaceSceneID.scriptCenter) }
                    }
                }

                GroupBox("项目与截图") {
                    VStack(alignment: .leading, spacing: 8) {
                        actionButton("截图", systemImage: "camera") { store.captureScreen() }
                        actionButton("截当前窗口", systemImage: "uiwindow.split.2x1", enabled: store.selectedWindow != nil) { store.captureSelectedWindow() }
                        actionButton("打开项目", systemImage: "folder") { store.openProjectDocument() }
                        actionButton("保存项目", systemImage: "square.and.arrow.down") { store.saveProjectDocument() }
                        actionButton("刷新窗口", systemImage: "arrow.clockwise") { store.refreshWindows() }
                    }
                }

                FixedWindowRecordingPanel(compact: true)

                GroupBox("运行") {
                    VStack(alignment: .leading, spacing: 8) {
                        actionButton("OCR", systemImage: "text.viewfinder") { store.runOCR() }
                        actionButton("运行步骤脚本", systemImage: "list.bullet.rectangle.portrait") { store.startRunScript() }
                        actionButton("运行当前脚本", systemImage: "play.fill") { store.runScriptSource() }
                    }
                }

                GroupBox("状态") {
                    VStack(alignment: .leading, spacing: 8) {
                        statusLine("截图源", value: store.currentCaptureSource)
                        statusLine("窗口", value: store.selectedWindow?.displayTitle ?? "-")
                        statusLine("脚本", value: store.currentScriptPathDisplay)
                        statusLine("项目", value: store.currentProjectPathDisplay)
                        statusLine("状态", value: store.statusMessage)
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 340, height: 560)
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
                .font(.system(size: 13, weight: .medium, design: .default))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func openWorkspace(_ id: String) {
        openWindow(id: id)
        WindowActivationController.bringAppToFront()
    }
}

struct StudioCommands: Commands {
    @ObservedObject var store: StudioStore
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("工作台") {
            Button("打开启动台") { openWorkspace(WorkspaceSceneID.launchpad) }
                .keyboardShortcut("1", modifiers: [.command, .option])
            Button("打开全景工作台") { openWorkspace(WorkspaceSceneID.studio) }
                .keyboardShortcut("2", modifiers: [.command, .option])
            Button("打开抓抓") { openWorkspace(WorkspaceSceneID.grabber) }
                .keyboardShortcut("3", modifiers: [.command, .option])
            Button("打开窗口实验室") { openWorkspace(WorkspaceSceneID.windowLab) }
                .keyboardShortcut("4", modifiers: [.command, .option])
            Button("打开脚本中心") { openWorkspace(WorkspaceSceneID.scriptCenter) }
                .keyboardShortcut("5", modifiers: [.command, .option])

            Divider()

            Button("截图") { store.captureScreen() }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Button("截当前窗口") { store.captureSelectedWindow() }
                .keyboardShortcut("r", modifiers: [.command, .option, .shift])
                .disabled(store.selectedWindow == nil)
            Button("运行 OCR") { store.runOCR() }
                .keyboardShortcut("o", modifiers: [.command, .option])
            Button("刷新窗口") { store.refreshWindows() }
                .keyboardShortcut("w", modifiers: [.command, .option])
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

        CommandMenu("录制") {
            Button("开始固定窗口录制") { store.startWindowOperationRecording() }
                .disabled(store.selectedWindow == nil || store.isRecordingWindowOperations)
            Button("停止固定窗口录制") { store.stopWindowOperationRecording() }
                .disabled(!store.isRecordingWindowOperations)
            Button("清空固定窗口录制") { store.clearRecordedWindowOperations() }
                .disabled(store.recordedWindowOperations.isEmpty)

            Divider()

            Button("导入录制到步骤") { store.importRecordedOperationsToSteps() }
                .disabled(store.recordedWindowOperations.isEmpty)
            Button("把录制追加到脚本") { store.appendRecordedOperationsToScriptSource() }
                .disabled(store.recordedWindowOperations.isEmpty)
        }

        CommandMenu("脚本") {
            Button("新建脚本") { store.newScriptDocument() }
            Button("打开脚本…") { store.openScriptDocument() }
            Button("保存脚本") { store.saveScriptDocument() }
            Button("脚本另存为…") { store.saveScriptDocumentAs() }

            Divider()

            Button("填充默认模板") { store.fillDefaultScriptTemplate() }
            Button(store.isRunningCode ? "执行中..." : "运行当前脚本") { store.runScriptSource() }
                .disabled(store.isRunningCode)
            Button("复制当前脚本") { store.copyScriptSource() }
        }
    }

    private func openWorkspace(_ id: String) {
        openWindow(id: id)
        WindowActivationController.bringAppToFront()
    }
}
