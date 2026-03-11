import Foundation
import AppKit

@MainActor
final class StudioStore: ObservableObject {
    @Published var interactionMode: InteractionMode = .point
    @Published private(set) var snapshot: DisplaySnapshot?
    @Published private(set) var hover: HoverSnapshot?
    @Published private(set) var selectedPoint: PixelPoint?
    @Published private(set) var selectedRect: PixelRect?
    @Published var samples: [ColorSample] = []
    @Published var templates: [ImageTemplate] = []
    @Published var selectedTemplateID: UUID?
    @Published var scriptSteps: [ScriptStep] = []
    @Published var defaultTolerance: Int = 16
    @Published var defaultTimeoutMs: Int = 2500
    @Published var defaultWaitMs: Int = 500
    @Published var defaultSimilarityThreshold: Double = 0.94
    @Published var templateProcessingMode: TemplateProcessingMode = .original
    @Published var useSelectionAsSearchArea = false
    @Published var captureOffsetX = 0
    @Published var captureOffsetY = 0
    @Published var coordinateMode: CoordinateMode = .screenAbsolute
    @Published var deliveryMode: EventDeliveryMode = .systemWide
    @Published var windows: [WindowInfo] = []
    @Published var selectedWindowID: UInt32?
    @Published var selectedElementInfo: AccessibilityElementInfo?
    @Published var ocrResult = ""
    @Published var scriptLanguage: ScriptLanguage = .pythonLike
    @Published var scriptSource = ""
    @Published private(set) var currentScriptURL: URL?
    @Published private(set) var currentScriptDraftName: String?
    @Published private(set) var currentProjectURL: URL?
    @Published private(set) var currentCaptureSource = "未截图"
    @Published var statusMessage = "先申请权限，再截图取点。"
    @Published var logs: [String] = []
    @Published private(set) var recordedWindowOperations: [RecordedWindowOperation] = []
    @Published private(set) var recordedWindowTarget: WindowTarget?
    @Published var isRecordingWindowOperations = false
    @Published var isRunningScript = false
    @Published var isRunningCode = false
    @Published var hasStartedWorkspaceSession = false

    private var hasPromptedScreenPermissionThisSession = false
    private var hasPromptedAccessibilityPermissionThisSession = false

    private let captureService = ScreenCaptureService()
    private let automationService = AutomationService()
    private let windowService = WindowInspectorService()
    private let accessibilityService = AccessibilityInspectorService()
    private let ocrService = OCRService()
    private let scriptEngine = ScriptEngine()
    private let operationRecorder = WindowOperationRecorderService()
    private let defaultLongPressDurationMs = 700
    private let defaultDragDurationMs = 280

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let exportFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    static let defaultPythonLikeTemplate = """
    # MacClickStudio Python 3 脚本
    def main():
        log('script start')

        login_area = rect(0, 0, 0, 0)

        if wait_color(100, 100, '#FFCC00', 12, 2000):
            click(100, 100)
            long_press(100, 100, 700)

        button = find_image('T1', login_area, 0.92)
        if button:
            log('template found at', button['x'], button['y'], 'score=', button['score'])

        match = find_color('#FFFFFF', rect(0, 0, 300, 120), 8)
        if match:
            log('color found at', match['x'], match['y'])

        drag(240, 420, 640, 420, 260)

        text = ocr_text(0, 0, 320, 120)
        if text:
            log('ocr => ' + text)

    main()
    """

    static let defaultJavaScriptTemplate = """
    function main() {
      log("JS script start");

      const loginArea = rect(0, 0, 0, 0);

      if (waitColor(100, 100, '#FFCC00', 12, 2000)) {
        click(100, 100);
        longPress(100, 100, 700);
      }

      const button = findImage('T1', loginArea, 0.92);
      if (button) {
        log('template found at', button.x, button.y, 'score=', button.score);
      }

      const match = findColor('#FFFFFF', rect(0, 0, 300, 120), 8);
      if (match) {
        log('color found at', match.x, match.y);
      }

      drag(240, 420, 640, 420, 260);

      const text = ocr_text(0, 0, 320, 120);
      if (text) {
        log('ocr => ' + text.split('\n').join(' | '));
      }
    }

    main();
    """

    static func defaultScriptTemplate(for language: ScriptLanguage) -> String {
        switch language {
        case .pythonLike:
            defaultPythonLikeTemplate
        case .javaScript:
            defaultJavaScriptTemplate
        }
    }

    var captureOffset: PixelPoint {
        PixelPoint(x: captureOffsetX, y: captureOffsetY)
    }

    var selectedSamplePoint: PixelPoint? {
        guard let snapshot, let selectedPoint else {
            return nil
        }
        return sampledPoint(from: selectedPoint, in: snapshot)
    }

    var selectedColor: PixelColor? {
        guard let snapshot, let selectedSamplePoint else {
            return nil
        }
        return snapshot.rgba.color(at: selectedSamplePoint)
    }

    var selectedTemplate: ImageTemplate? {
        guard let selectedTemplateID else {
            return nil
        }
        return templates.first(where: { $0.id == selectedTemplateID })
    }

    var selectedWindow: WindowInfo? {
        guard let selectedWindowID else {
            return nil
        }
        return windows.first(where: { $0.windowID == selectedWindowID })
    }

    var selectedRelativePoint: PixelPoint? {
        guard let snapshot, let selectedPoint, let selectedWindow else {
            return nil
        }
        let screenPoint = snapshot.screenPoint(from: selectedPoint)
        return PixelPoint(
            x: Int(screenPoint.x - selectedWindow.screenBounds.minX),
            y: Int(selectedWindow.screenBounds.maxY - screenPoint.y)
        )
    }

    var selectedWindowPixelRect: PixelRect? {
        guard let snapshot, let selectedWindow else {
            return nil
        }
        return snapshot.pixelRect(fromScreenRect: selectedWindow.screenBounds)
    }

    var currentScriptDisplayName: String {
        if let currentScriptURL {
            return currentScriptURL.lastPathComponent
        }
        if let currentScriptDraftName, !currentScriptDraftName.isEmpty {
            return "\(currentScriptDraftName).\(scriptLanguage.defaultFileExtension)"
        }
        return "未新建脚本"
    }

    var currentProjectDisplayName: String {
        currentProjectURL?.lastPathComponent ?? "未命名项目.mcstudio"
    }

    var currentScriptPathDisplay: String {
        if let currentScriptURL {
            return currentScriptURL.path
        }
        if let currentScriptDraftName, !currentScriptDraftName.isEmpty {
            return "未保存 · \(currentScriptDraftName).\(scriptLanguage.defaultFileExtension)"
        }
        return "未新建脚本"
    }

    var currentProjectPathDisplay: String {
        currentProjectURL?.path ?? "未保存项目"
    }

    var recordingSummaryText: String {
        guard let recordedWindowTarget else {
            return recordedWindowOperations.isEmpty ? "还没有录制内容" : "已录制 \(recordedWindowOperations.count) 条操作"
        }
        return "\(recordedWindowTarget.displayTitle) · \(recordedWindowOperations.count) 条"
    }


    var hasScriptDocument: Bool {
        currentScriptURL != nil
            || !(currentScriptDraftName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            || !scriptSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isScriptWorkspaceEmptyStateVisible: Bool {
        currentScriptURL == nil
            && (currentScriptDraftName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && scriptSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasContextPoint: Bool {
        hover != nil || selectedPoint != nil
    }

    func requestPermissions() {
        let screenBefore = captureService.hasScreenCaptureAccess()
        let accessibilityBefore = captureService.hasAccessibilityAccess()

        var screenOK = screenBefore
        var accessibilityOK = accessibilityBefore
        var requestedScreen = false
        var requestedAccessibility = false

        if !screenBefore {
            if !hasPromptedScreenPermissionThisSession {
                screenOK = captureService.requestScreenCaptureAccess(prompt: true)
                hasPromptedScreenPermissionThisSession = true
                requestedScreen = true
            } else {
                screenOK = captureService.hasScreenCaptureAccess()
            }
        }

        if !accessibilityBefore {
            if !hasPromptedAccessibilityPermissionThisSession {
                accessibilityOK = captureService.requestAccessibilityAccess(prompt: true)
                hasPromptedAccessibilityPermissionThisSession = true
                requestedAccessibility = true
            } else {
                accessibilityOK = captureService.hasAccessibilityAccess()
            }
        }

        if screenOK && accessibilityOK {
            statusMessage = "权限已就绪，可以截图、OCR、窗口探测和执行点击。"
            appendLogMessage("权限已就绪：屏幕录制 + 辅助功能")
            return
        }

        let guidance = permissionGuidanceMessage(
            screenGranted: screenOK,
            accessibilityGranted: accessibilityOK,
            requestedScreen: requestedScreen,
            requestedAccessibility: requestedAccessibility
        )
        statusMessage = guidance
        appendLogMessage("权限未完全开启：屏幕录制=\(screenOK) 辅助功能=\(accessibilityOK)")
    }

    func captureScreen() {
        guard ensureScreenCapturePermissionReady() else {
            return
        }

        do {
            snapshot = try captureService.captureMainDisplay()
            currentCaptureSource = "主屏截图"
            statusMessage = "截图完成，当前主屏尺寸：\(snapshot?.rgba.width ?? 0)x\(snapshot?.rgba.height ?? 0)"
            appendLogMessage("主屏截图完成")
            refreshWindows(logResult: false)
            if let selectedPoint {
                updateHover(selectedPoint)
            }
        } catch {
            statusMessage = error.localizedDescription
            appendLogMessage("截图失败：\(error.localizedDescription)")
        }
    }

    func captureSelectedWindow() {
        guard ensureScreenCapturePermissionReady() else {
            return
        }

        if selectedWindow == nil {
            refreshWindows(logResult: false)
        }

        guard let selectedWindow else {
            statusMessage = "请先锁定一个目标窗口，再截窗口图。"
            return
        }

        let targetWindow = selectedWindow
        statusMessage = "正在截取目标窗口：\(targetWindow.displayTitle)"
        appendLogMessage("开始窗口截图 handle=\(targetWindow.windowID) pid=\(targetWindow.pid) \(targetWindow.displayTitle)")

        Task {
            do {
                let capturedSnapshot = try await captureService.captureWindow(targetWindow)
                snapshot = capturedSnapshot
                currentCaptureSource = "窗口截图：\(targetWindow.displayTitle)"
                statusMessage = "窗口截图完成：\(targetWindow.displayTitle)"
                appendLogMessage("窗口截图完成 handle=\(targetWindow.windowID) pid=\(targetWindow.pid) \(targetWindow.displayTitle)")
                clearSelection()
                if let selectedPoint {
                    updateHover(selectedPoint)
                }
            } catch {
                statusMessage = error.localizedDescription
                appendLogMessage("窗口截图失败：\(error.localizedDescription)")
            }
        }
    }

    func refreshWindows(logResult: Bool = true) {
        let previousSelection = selectedWindowID
        windows = windowService.listWindows()
        if let previousSelection, windows.contains(where: { $0.windowID == previousSelection }) {
            selectedWindowID = previousSelection
        } else {
            selectedWindowID = windows.first?.windowID
        }

        if logResult {
            appendLogMessage("刷新窗口列表：\(windows.count) 个可见窗口")
        }
    }

    func updateHover(_ rawPoint: PixelPoint?) {
        guard let snapshot, let rawPoint else {
            hover = nil
            return
        }

        let sampledPoint = sampledPoint(from: rawPoint, in: snapshot)
        guard let color = snapshot.rgba.color(at: sampledPoint) else {
            hover = nil
            return
        }

        hover = HoverSnapshot(rawPoint: rawPoint, sampledPoint: sampledPoint, color: color)
    }

    func selectPoint(_ rawPoint: PixelPoint) {
        selectedPoint = rawPoint
        selectedElementInfo = nil
        updateHover(rawPoint)
        statusMessage = "已选中点位 (\(rawPoint.x), \(rawPoint.y))"
    }

    func promoteHoverToSelection() {
        if let hover {
            selectPoint(hover.rawPoint)
        }
    }

    func updateSelection(_ rect: PixelRect?) {
        selectedRect = rect
        if let rect {
            statusMessage = "已选中区域 x:\(rect.x) y:\(rect.y) w:\(rect.width) h:\(rect.height)"
        }
    }

    func clearSelection() {
        selectedRect = nil
        statusMessage = "已清除区域选框。"
    }

    func clearOCRResult() {
        ocrResult = ""
    }

    func addSampleFromSelectedPoint() {
        guard let point = selectedSamplePoint, let color = selectedColor else {
            statusMessage = "请先截图，并在点位模式下选中一个坐标。"
            return
        }

        let sample = ColorSample(
            name: "S\(samples.count + 1)",
            point: point,
            color: color,
            tolerance: defaultTolerance
        )
        samples.append(sample)
        appendLogMessage("新增比色点 \(sample.name) @ (\(point.x), \(point.y)) \(color.hexString)")
    }

    func removeSample(_ sampleID: UUID) {
        samples.removeAll(where: { $0.id == sampleID })
    }

    func clearSamples() {
        samples.removeAll()
        appendLogMessage("已清空比色点")
    }

    func saveTemplateFromSelection() {
        guard let selectedRect else {
            statusMessage = "请先截图，再切到区域模式拉出模板区域。"
            return
        }

        do {
            let template = try makeTemplate(from: selectedRect)
            templates.append(template)
            selectedTemplateID = template.id
            appendLogMessage("保存模板 \(template.name) mode=\(template.processingMode.title) sim=\(String(format: "%.2f", template.preferredSimilarity))")
        } catch {
            statusMessage = error.localizedDescription
            appendLogMessage("保存模板失败：\(error.localizedDescription)")
        }
    }

    func importScreenshotImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "导入截图"
        panel.message = "选择一张本地图片作为抓抓画布。"
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .bmp, .gif]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        guard let image = NSImage(contentsOf: url), let cgImage = image.cgImageRepresentation, let rgba = RGBAImage(cgImage: cgImage) else {
            statusMessage = "导入截图失败：无法读取图片文件。"
            appendLogMessage("导入截图失败：无法读取 \(url.lastPathComponent)")
            return
        }

        snapshot = DisplaySnapshot(
            rgba: rgba,
            displayBounds: CGRect(x: 0, y: 0, width: rgba.width, height: rgba.height)
        )
        selectedWindowID = nil
        selectedPoint = nil
        selectedRect = nil
        hover = nil
        currentCaptureSource = "导入图片：\(url.lastPathComponent)"
        statusMessage = "已导入本地截图：\(url.lastPathComponent)"
        appendLogMessage("已导入本地截图 \(url.lastPathComponent) \(rgba.width)x\(rgba.height)")
    }

    func exportCurrentScreenshotImage() {
        guard let snapshot else {
            statusMessage = "请先截图或导入一张图片。"
            return
        }
        guard let folderURL = chooseExportFolder(
            title: "选择截图保存文件夹",
            message: "当前截图会保存为 PNG 文件到你选择的文件夹。"
        ) else {
            return
        }

        do {
            let fileURL = try writePNGImage(
                snapshot.rgba,
                to: folderURL,
                preferredBaseName: "screenshot_\(filenameTimestamp())"
            )
            statusMessage = "已保存截图：\(fileURL.lastPathComponent)"
            appendLogMessage("已保存当前截图 \(fileURL.path)")
        } catch {
            statusMessage = "保存截图失败：\(error.localizedDescription)"
            appendLogMessage("保存截图失败：\(error.localizedDescription)")
        }
    }

    func exportSelectionScreenshotImage() {
        guard let snapshot else {
            statusMessage = "请先截图或导入一张图片。"
            return
        }
        guard let selectedRect else {
            statusMessage = "请先在抓抓画布上框选一个区域。"
            return
        }
        guard let cropped = snapshot.rgba.crop(selectedRect) else {
            statusMessage = "选区无效，无法保存截图。"
            return
        }
        guard let folderURL = chooseExportFolder(
            title: "选择选区截图保存文件夹",
            message: "当前选区会裁切成 PNG 文件到你选择的文件夹。"
        ) else {
            return
        }

        do {
            let fileURL = try writePNGImage(
                cropped,
                to: folderURL,
                preferredBaseName: "selection_\(filenameTimestamp())"
            )
            statusMessage = "已保存选区截图：\(fileURL.lastPathComponent)"
            appendLogMessage("已保存选区截图 \(fileURL.path)")
        } catch {
            statusMessage = "保存选区截图失败：\(error.localizedDescription)"
            appendLogMessage("保存选区截图失败：\(error.localizedDescription)")
        }
    }

    func exportSelectionSlices(rows: Int, columns: Int) {
        guard rows > 0, columns > 0 else {
            return
        }
        guard let snapshot else {
            statusMessage = "请先截图或导入一张图片。"
            return
        }
        guard let selectedRect else {
            statusMessage = "请先在抓抓画布上框选一个区域，再使用分割工具。"
            return
        }
        guard let folderURL = chooseExportFolder(
            title: "选择分割图片保存文件夹",
            message: "当前选区会按网格裁切成多张 PNG 文件到你选择的文件夹。"
        ) else {
            return
        }

        let cellWidth = max(1, selectedRect.width / columns)
        let cellHeight = max(1, selectedRect.height / rows)
        let baseName = "split_\(filenameTimestamp())"
        var created = 0

        for row in 0..<rows {
            for column in 0..<columns {
                let originX = selectedRect.x + column * cellWidth
                let originY = selectedRect.y + row * cellHeight
                let width = column == columns - 1 ? selectedRect.x + selectedRect.width - originX : cellWidth
                let height = row == rows - 1 ? selectedRect.y + selectedRect.height - originY : cellHeight
                let rect = PixelRect(x: originX, y: originY, width: max(1, width), height: max(1, height))

                do {
                    guard let cropped = snapshot.rgba.crop(rect) else {
                        continue
                    }
                    _ = try writePNGImage(
                        cropped,
                        to: folderURL,
                        preferredBaseName: "\(baseName)_r\(row + 1)c\(column + 1)"
                    )
                    created += 1
                } catch {
                    appendLogMessage("分割截图失败：\(error.localizedDescription)")
                }
            }
        }

        if created > 0 {
            statusMessage = "已导出 \(created) 张分割截图。"
            appendLogMessage("已导出分割截图 rows=\(rows) cols=\(columns) count=\(created) folder=\(folderURL.path)")
        } else {
            statusMessage = "分割失败：没有导出有效图片。"
        }
    }

    func splitSelectionIntoTemplates(rows: Int, columns: Int) {
        guard rows > 0, columns > 0 else {
            return
        }
        guard let selectedRect else {
            statusMessage = "请先在抓抓画布上框选一个区域，再使用分割工具。"
            return
        }

        let cellWidth = max(1, selectedRect.width / columns)
        let cellHeight = max(1, selectedRect.height / rows)
        var created = 0

        for row in 0..<rows {
            for column in 0..<columns {
                let originX = selectedRect.x + column * cellWidth
                let originY = selectedRect.y + row * cellHeight
                let width = column == columns - 1 ? selectedRect.x + selectedRect.width - originX : cellWidth
                let height = row == rows - 1 ? selectedRect.y + selectedRect.height - originY : cellHeight
                let rect = PixelRect(x: originX, y: originY, width: max(1, width), height: max(1, height))

                do {
                    let template = try makeTemplate(from: rect)
                    templates.append(template)
                    selectedTemplateID = template.id
                    created += 1
                } catch {
                    appendLogMessage("分割模板失败：\(error.localizedDescription)")
                }
            }
        }

        if created > 0 {
            statusMessage = "已从选区分割出 \(created) 个模板。"
            appendLogMessage("分割选区为模板 rows=\(rows) cols=\(columns) count=\(created)")
        } else {
            statusMessage = "分割失败：没有生成有效模板。"
        }
    }

    func removeTemplate(_ templateID: UUID) {
        templates.removeAll(where: { $0.id == templateID })
        if selectedTemplateID == templateID {
            selectedTemplateID = templates.first?.id
        }
    }

    func selectTemplate(_ templateID: UUID) {
        selectedTemplateID = templateID
    }

    func template(named name: String) -> ImageTemplate? {
        templates.first(where: { $0.name == name })
    }

    func selectWindow(_ windowID: UInt32) {
        selectedWindowID = windowID
        selectedElementInfo = nil
    }

    func lockWindowFromSelectedPoint() {
        guard let snapshot, let selectedPoint else {
            statusMessage = "请先在截图上选中一个点位。"
            return
        }

        let screenPoint = snapshot.screenPoint(from: selectedPoint)
        guard let window = windowService.window(at: screenPoint) else {
            statusMessage = "当前点位下没有识别到窗口。"
            return
        }

        if !windows.contains(where: { $0.windowID == window.windowID }) {
            refreshWindows(logResult: false)
        }
        selectedWindowID = window.windowID
        statusMessage = "已锁定窗口：\(window.displayTitle)"
        appendLogMessage("锁定窗口 handle=\(window.windowID) pid=\(window.pid) \(window.displayTitle)")
    }

    func inspectElementAtSelectedPoint() {
        guard let snapshot, let selectedPoint, let selectedWindow else {
            statusMessage = "请先选中点位，并锁定目标窗口。"
            return
        }

        let screenPoint = snapshot.screenPoint(from: selectedPoint)
        selectedElementInfo = accessibilityService.inspectElement(at: screenPoint, pid: selectedWindow.pid)
        if let selectedElementInfo {
            appendLogMessage("控件探测：\(selectedElementInfo.summary)")
        } else {
            appendLogMessage("控件探测失败：当前点位没有取到 AX 元素")
        }
    }

    func runOCR() {
        do {
            let activeSnapshot = try (snapshot ?? captureService.captureMainDisplay())
            snapshot = activeSnapshot
            ocrResult = try ocrService.recognizeText(in: activeSnapshot, rect: selectedRect)
            statusMessage = ocrResult.isEmpty ? "OCR 完成，但没有识别到文字。" : "OCR 完成。"
            appendLogMessage("OCR 完成，字符数 \(ocrResult.count)")
        } catch {
            statusMessage = error.localizedDescription
            appendLogMessage("OCR 失败：\(error.localizedDescription)")
        }
    }

    func addWaitStep() {
        let step = ScriptStep.wait(milliseconds: defaultWaitMs)
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func addClickStep() {
        guard let selectedPoint else {
            statusMessage = "请先在截图上选中一个点位。"
            return
        }

        guard let point = pointForClickStep(from: selectedPoint) else {
            return
        }

        let windowTarget = targetWindowForCurrentMode()
        if coordinateMode == .selectedWindowRelative || deliveryMode == .targetPID {
            guard windowTarget != nil else { return }
        }

        let step = ScriptStep.click(
            point: point,
            coordinateMode: coordinateMode,
            windowTarget: windowTarget,
            deliveryMode: deliveryMode
        )
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func addLongPressStep() {
        guard let selectedPoint else {
            statusMessage = "请先在截图上选中一个点位。"
            return
        }

        guard let point = pointForClickStep(from: selectedPoint) else {
            return
        }

        let windowTarget = targetWindowForCurrentMode()
        if coordinateMode == .selectedWindowRelative || deliveryMode == .targetPID {
            guard windowTarget != nil else { return }
        }

        let step = ScriptStep.longPress(
            point: point,
            coordinateMode: coordinateMode,
            durationMs: defaultLongPressDurationMs,
            windowTarget: windowTarget,
            deliveryMode: deliveryMode
        )
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func addDragStep(to endRawPoint: PixelPoint? = nil) {
        guard let selectedPoint else {
            statusMessage = "请先选一个拖动起点，再在终点处右键添加拖动步骤。"
            return
        }

        let rawEndPoint = endRawPoint ?? hover?.rawPoint
        guard let rawEndPoint else {
            statusMessage = "请把鼠标移动到拖动终点，再添加拖动步骤。"
            return
        }

        guard rawEndPoint != selectedPoint else {
            statusMessage = "拖动起点和终点不能相同。"
            return
        }

        guard let startPoint = pointForClickStep(from: selectedPoint),
              let endPoint = pointForClickStep(from: rawEndPoint) else {
            return
        }

        let windowTarget = targetWindowForCurrentMode()
        if coordinateMode == .selectedWindowRelative || deliveryMode == .targetPID {
            guard windowTarget != nil else { return }
        }

        let step = ScriptStep.drag(
            from: startPoint,
            to: endPoint,
            coordinateMode: coordinateMode,
            durationMs: defaultDragDurationMs,
            windowTarget: windowTarget,
            deliveryMode: deliveryMode
        )
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func addMultiColorStep() {
        guard !samples.isEmpty else {
            statusMessage = "请先添加比色点。"
            return
        }

        let step = ScriptStep.multiColor(sampleIDs: samples.map(\.id), timeoutMs: defaultTimeoutMs)
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func addFindImageStep() {
        guard let template = selectedTemplate else {
            statusMessage = "请先保存并选中一个模板。"
            return
        }

        let windowTarget = deliveryMode == .targetPID ? selectedWindow?.target : nil
        if deliveryMode == .targetPID, windowTarget == nil {
            statusMessage = "定向投递模式下，请先锁定窗口。"
            return
        }

        let step = ScriptStep.findImage(
            templateID: template.id,
            searchRect: useSelectionAsSearchArea ? selectedRect : nil,
            threshold: template.preferredSimilarity,
            timeoutMs: defaultTimeoutMs,
            windowTarget: windowTarget,
            deliveryMode: deliveryMode
        )
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func addFindColorStep() {
        guard let selectedColor else {
            statusMessage = "请先选中一个可取色的点位。"
            return
        }

        let windowTarget = deliveryMode == .targetPID ? selectedWindow?.target : nil
        if deliveryMode == .targetPID, windowTarget == nil {
            statusMessage = "定向投递模式下，请先锁定窗口。"
            return
        }

        let step = ScriptStep.findColor(
            targetColor: selectedColor,
            searchRect: useSelectionAsSearchArea ? selectedRect : nil,
            tolerance: defaultTolerance,
            timeoutMs: defaultTimeoutMs,
            windowTarget: windowTarget,
            deliveryMode: deliveryMode
        )
        scriptSteps.append(step)
        appendLogMessage("新增步骤：\(step.name)")
    }

    func removeStep(_ stepID: UUID) {
        scriptSteps.removeAll(where: { $0.id == stepID })
    }

    func toggleStep(_ stepID: UUID) {
        guard let index = scriptSteps.firstIndex(where: { $0.id == stepID }) else {
            return
        }
        scriptSteps[index].isEnabled.toggle()
    }

    func moveStepUp(_ stepID: UUID) {
        guard let index = scriptSteps.firstIndex(where: { $0.id == stepID }), index > 0 else {
            return
        }
        scriptSteps.swapAt(index, index - 1)
    }

    func moveStepDown(_ stepID: UUID) {
        guard let index = scriptSteps.firstIndex(where: { $0.id == stepID }), index < scriptSteps.count - 1 else {
            return
        }
        scriptSteps.swapAt(index, index + 1)
    }

    func startWindowOperationRecording() {
        refreshWindows(logResult: false)

        guard let target = selectedWindow?.target else {
            statusMessage = "请先锁定一个目标窗口，再开始固定窗口录制。"
            return
        }

        if recordedWindowTarget != target, !recordedWindowOperations.isEmpty {
            recordedWindowOperations.removeAll()
            appendLogMessage("固定窗口录制目标已切换，已清空上一窗口的录制结果")
        }

        recordedWindowTarget = target
        isRecordingWindowOperations = true
        statusMessage = "开始录制固定窗口操作：\(target.displayTitle)"
        appendLogMessage("开始固定窗口录制：\(target.displayTitle)")

        operationRecorder.start(target: target) { [self] operation in
            recordedWindowOperations.append(operation)
            statusMessage = "固定窗口录制中：已记录 \(recordedWindowOperations.count) 条操作"
            appendLogMessage("录制：\(operation.summary) · abs=(\(operation.absolutePoint.x), \(operation.absolutePoint.y))")
        }
    }

    func stopWindowOperationRecording() {
        guard isRecordingWindowOperations || operationRecorder.isRecording else {
            return
        }

        operationRecorder.stop()
        isRecordingWindowOperations = false
        statusMessage = "固定窗口录制已停止，共 \(recordedWindowOperations.count) 条操作。"
        appendLogMessage("固定窗口录制已停止，共 \(recordedWindowOperations.count) 条操作")
    }

    func clearRecordedWindowOperations() {
        if isRecordingWindowOperations {
            stopWindowOperationRecording()
        }

        recordedWindowOperations.removeAll()
        if recordedWindowTarget == nil {
            recordedWindowTarget = selectedWindow?.target
        }
        statusMessage = "已清空固定窗口录制结果。"
        appendLogMessage("已清空固定窗口录制结果")
    }

    func importRecordedOperationsToSteps() {
        guard !recordedWindowOperations.isEmpty else {
            statusMessage = "还没有固定窗口录制结果。"
            return
        }

        guard let target = recordedWindowTarget ?? selectedWindow?.target else {
            statusMessage = "录制结果缺少目标窗口，请重新锁定窗口后再导入。"
            return
        }

        for operation in recordedWindowOperations {
            if operation.delayMs > 0 {
                scriptSteps.append(.wait(milliseconds: operation.delayMs))
            }

            switch operation.kind {
            case .leftClick:
                scriptSteps.append(
                    .click(
                        point: operation.relativePoint,
                        coordinateMode: .selectedWindowRelative,
                        windowTarget: target,
                        deliveryMode: deliveryMode
                    )
                )
            case .longPress:
                scriptSteps.append(
                    .longPress(
                        point: operation.relativePoint,
                        coordinateMode: .selectedWindowRelative,
                        durationMs: operation.durationMs ?? defaultLongPressDurationMs,
                        windowTarget: target,
                        deliveryMode: deliveryMode
                    )
                )
            case .drag:
                guard let endPoint = operation.endRelativePoint else { continue }
                scriptSteps.append(
                    .drag(
                        from: operation.relativePoint,
                        to: endPoint,
                        coordinateMode: .selectedWindowRelative,
                        durationMs: operation.durationMs ?? defaultDragDurationMs,
                        windowTarget: target,
                        deliveryMode: deliveryMode
                    )
                )
            }
        }

        statusMessage = "已把固定窗口录制导入为步骤，共 \(recordedWindowOperations.count) 条操作。"
        appendLogMessage("已把固定窗口录制导入为步骤，共 \(recordedWindowOperations.count) 条操作")
        if deliveryMode != .targetPID {
            appendLogMessage("提示：若希望固定窗口在后台回放，请把事件投递切到目标进程投递")
        }
    }

    func appendRecordedOperationsToScriptSource() {
        guard !recordedWindowOperations.isEmpty else {
            statusMessage = "还没有固定窗口录制结果。"
            return
        }

        guard let target = recordedWindowTarget ?? selectedWindow?.target else {
            statusMessage = "录制结果缺少目标窗口，请重新锁定窗口后再转脚本。"
            return
        }

        appendScriptSnippet(recordedOperationsScriptSnippet(target: target))
        statusMessage = "已把固定窗口录制追加到脚本编辑器。"
        appendLogMessage("已把固定窗口录制追加到脚本编辑器")
    }

    func clearLogs() {
        logs.removeAll()
    }

    func copyScriptJSON() {
        copyToPasteboard(exportScriptJSON())
        appendLogMessage("已复制项目 JSON 到剪贴板")
    }

    func copyScriptSource() {
        copyToPasteboard(scriptSource)
        appendLogMessage("已复制脚本到剪贴板")
    }

    func newProject() {
        operationRecorder.stop()
        isRecordingWindowOperations = false
        hasStartedWorkspaceSession = true
        hasPromptedScreenPermissionThisSession = false
        hasPromptedAccessibilityPermissionThisSession = false

        snapshot = nil
        hover = nil
        selectedPoint = nil
        selectedRect = nil
        samples.removeAll()
        templates.removeAll()
        selectedTemplateID = nil
        scriptSteps.removeAll()
        recordedWindowOperations.removeAll()
        recordedWindowTarget = nil
        ocrResult = ""
        selectedElementInfo = nil
        scriptLanguage = .pythonLike
        scriptSource = ""
        currentScriptURL = nil
        currentScriptDraftName = nil
        currentProjectURL = nil
        currentCaptureSource = "未截图"
        defaultTolerance = 16
        defaultTimeoutMs = 2500
        defaultWaitMs = 500
        defaultSimilarityThreshold = 0.94
        templateProcessingMode = .original
        useSelectionAsSearchArea = false
        captureOffsetX = 0
        captureOffsetY = 0
        coordinateMode = .screenAbsolute
        deliveryMode = .systemWide
        selectedWindowID = nil
        logs.removeAll()
        statusMessage = "已新建项目。"
        appendLogMessage("已新建项目")
    }

    func openProjectDocument() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "打开项目"
        panel.message = "选择一个 MacClickStudio 项目文件（JSON / mcstudio）。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let project = try decoder.decode(StudioProjectExport.self, from: data)
            applyProject(project, sourceURL: url)
            statusMessage = "已打开项目：\(url.lastPathComponent)"
            appendLogMessage("已打开项目 \(url.lastPathComponent)")
        } catch {
            statusMessage = "打开项目失败：\(error.localizedDescription)"
            appendLogMessage("打开项目失败：\(error.localizedDescription)")
        }
    }

    func saveProjectDocument() {
        if let currentProjectURL {
            writeProject(to: currentProjectURL)
        } else {
            saveProjectDocumentAs()
        }
    }

    func saveProjectDocumentAs() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "保存项目"
        panel.message = "把当前步骤、模板、脚本和设置保存为项目文件。"
        panel.nameFieldStringValue = suggestedProjectFilename()

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        writeProject(to: normalizedProjectURL(for: url))
    }


    func newScriptDocument() {
        let alert = NSAlert()
        alert.messageText = "新建脚本"
        alert.informativeText = "请输入脚本名，脚本会先以空白内容创建。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "新建")
        alert.addButton(withTitle: "取消")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "例如：login_flow"
        input.stringValue = currentScriptDraftName ?? ""
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let name = sanitizedScriptName(input.stringValue)
        createNewScriptDocument(named: name.isEmpty ? "Untitled" : name)
    }

    func openScriptDocument() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.title = "打开脚本"
        panel.message = "选择一个 Python 3 脚本、JavaScript 脚本或纯文本脚本。"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let source = try String(contentsOf: url, encoding: .utf8)
            let language = inferredScriptLanguage(for: url, source: source)
            scriptLanguage = language
            scriptSource = source
            currentScriptURL = url
            currentScriptDraftName = nil
            hasStartedWorkspaceSession = true
            statusMessage = "已打开脚本：\(url.lastPathComponent)"
            appendLogMessage("已打开脚本 \(url.lastPathComponent)（\(language.title)）")
        } catch {
            statusMessage = "打开脚本失败：\(error.localizedDescription)"
            appendLogMessage("打开脚本失败：\(error.localizedDescription)")
        }
    }

    func saveScriptDocument() {
        if let currentScriptURL {
            writeScript(to: currentScriptURL)
        } else {
            saveScriptDocumentAs()
        }
    }

    func saveScriptDocumentAs() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.title = "保存脚本"
        panel.message = "把当前脚本保存为纯文本文件。"
        panel.nameFieldStringValue = suggestedScriptFilename()

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        writeScript(to: normalizedScriptURL(for: url))
    }

    func setScriptLanguage(_ language: ScriptLanguage) {
        guard scriptLanguage != language else {
            return
        }

        let previousLanguage = scriptLanguage
        scriptLanguage = language

        if scriptSource == Self.defaultScriptTemplate(for: previousLanguage) {
            scriptSource = Self.defaultScriptTemplate(for: language)
        }

        statusMessage = "脚本语言已切换为 \(language.title)。"
        appendLogMessage("脚本语言切换为 \(language.title)")
    }

    func copySelectedCoordinate() {
        guard let selectedPoint else {
            return
        }
        copyToPasteboard("\(selectedPoint.x),\(selectedPoint.y)")
        appendLogMessage("已复制点击坐标")
    }

    func copySelectedSampleCoordinate() {
        guard let selectedSamplePoint else {
            return
        }
        copyToPasteboard("\(selectedSamplePoint.x),\(selectedSamplePoint.y)")
        appendLogMessage("已复制取色坐标")
    }

    func copySelectedColor() {
        guard let selectedColor else {
            return
        }
        copyToPasteboard(selectedColor.hexString)
        appendLogMessage("已复制颜色值 \(selectedColor.hexString)")
    }

    func copySelectedWindowInfo() {
        guard let selectedWindow else {
            return
        }
        let text = "handle=\(selectedWindow.windowID) pid=\(selectedWindow.pid) owner=\(selectedWindow.ownerName) title=\(selectedWindow.title) bounds=\(selectedWindow.shortBoundsText)"
        copyToPasteboard(text)
        appendLogMessage("已复制窗口信息")
    }

    func copyOCRResult() {
        guard !ocrResult.isEmpty else {
            return
        }
        copyToPasteboard(ocrResult)
        appendLogMessage("已复制 OCR 文本")
    }

    func appendLogMessage(_ message: String) {
        let timestamp = Self.timestampFormatter.string(from: .now)
        logs.append("[\(timestamp)] \(message)")
    }

    func fillDefaultScriptTemplate() {
        if currentScriptURL == nil, currentScriptDraftName == nil {
            currentScriptDraftName = "Untitled"
        }
        scriptSource = Self.defaultScriptTemplate(for: scriptLanguage)
        appendLogMessage("已填充默认脚本模板（\(scriptLanguage.title)）")
    }

    func insertSelectedPointSnippet() {
        guard let selectedPoint else {
            return
        }
        switch scriptLanguage {
        case .pythonLike:
            appendScriptSnippet("point_value = point(\(selectedPoint.x), \(selectedPoint.y))")
        case .javaScript:
            appendScriptSnippet("const pointValue = point(\(selectedPoint.x), \(selectedPoint.y));")
        }
    }

    func insertSelectedColorSnippet() {
        guard let selectedColor else {
            return
        }
        switch scriptLanguage {
        case .pythonLike:
            appendScriptSnippet("color_hex = '\(selectedColor.hexString)'")
        case .javaScript:
            appendScriptSnippet("const colorHex = '\(selectedColor.hexString)';")
        }
    }

    func insertSelectedRectSnippet() {
        guard let selectedRect else {
            return
        }
        switch scriptLanguage {
        case .pythonLike:
            appendScriptSnippet("search_area = rect(\(selectedRect.x), \(selectedRect.y), \(selectedRect.width), \(selectedRect.height))")
        case .javaScript:
            appendScriptSnippet("const searchArea = rect(\(selectedRect.x), \(selectedRect.y), \(selectedRect.width), \(selectedRect.height));")
        }
    }

    func insertSelectedWindowSnippet() {
        guard let selectedWindow else {
            return
        }
        switch scriptLanguage {
        case .pythonLike:
            appendScriptSnippet("window_info = window_bounds('\(escapeJS(selectedWindow.ownerName))', '\(escapeJS(selectedWindow.title))')")
        case .javaScript:
            appendScriptSnippet("const windowInfo = window_bounds('\(escapeJS(selectedWindow.ownerName))', '\(escapeJS(selectedWindow.title))');")
        }
    }

    func insertFunctionSnippet(_ doc: ScriptFunctionDoc) {
        appendScriptSnippet(doc.snippet(for: scriptLanguage))
        appendLogMessage("已插入函数片段：\(doc.name)")
    }

    func applyFunctionExample(_ doc: ScriptFunctionDoc) {
        scriptSource = doc.example(for: scriptLanguage)
        appendLogMessage("已应用函数示例：\(doc.name)")
    }

    func copyFunctionExample(_ doc: ScriptFunctionDoc) {
        copyToPasteboard(doc.example(for: scriptLanguage))
        appendLogMessage("已复制函数示例：\(doc.name)")
    }

    func startRunScript() {
        guard !isRunningScript else {
            return
        }

        Task {
            await runScript()
        }
    }

    func runScriptSource() {
        guard !isRunningCode else {
            return
        }

        let source = scriptSource.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            statusMessage = "脚本编辑器还是空的。"
            return
        }

        isRunningCode = true
        statusMessage = "开始执行脚本（\(scriptLanguage.title)）..."
        appendLogMessage("开始执行脚本（\(scriptLanguage.title)）")

        Task {
            defer {
                isRunningCode = false
            }

            do {
                try await scriptEngine.run(source: scriptSource, language: scriptLanguage, store: self)
                statusMessage = "脚本执行完成。"
                appendLogMessage("脚本执行完成")
            } catch {
                statusMessage = "脚本中断：\(error.localizedDescription)"
                appendLogMessage("脚本中断：\(error.localizedDescription)")
            }
        }
    }

    func exportScriptJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let export = currentProjectExport()

        guard let data = try? encoder.encode(export), let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    func stepSummary(_ step: ScriptStep) -> String {
        switch step.kind {
        case .wait:
            return "等待 \(step.milliseconds)ms"

        case .clickPoint:
            guard let point = step.point else {
                return "点击（缺少坐标）"
            }
            let base = step.coordinateMode == .screenAbsolute
                ? "点击 (\(point.x), \(point.y))"
                : "点击窗口相对点 (\(point.x), \(point.y))"
            return step.eventDeliveryMode == .targetPID ? base + " · 定向投递" : base

        case .longPressPoint:
            guard let point = step.point else {
                return "长按（缺少坐标）"
            }
            let base = step.coordinateMode == .screenAbsolute
                ? "长按 (\(point.x), \(point.y)) \(step.milliseconds)ms"
                : "长按窗口相对点 (\(point.x), \(point.y)) \(step.milliseconds)ms"
            return step.eventDeliveryMode == .targetPID ? base + " · 定向投递" : base

        case .dragPoints:
            guard let startPoint = step.point, let endPoint = step.endPoint else {
                return "拖动（缺少起终点）"
            }
            let base = step.coordinateMode == .screenAbsolute
                ? "拖动 (\(startPoint.x), \(startPoint.y)) → (\(endPoint.x), \(endPoint.y)) \(step.milliseconds)ms"
                : "拖动窗口相对点 (\(startPoint.x), \(startPoint.y)) → (\(endPoint.x), \(endPoint.y)) \(step.milliseconds)ms"
            return step.eventDeliveryMode == .targetPID ? base + " · 定向投递" : base

        case .multiColorCheck:
            return "多点比色，样本 \(step.sampleIDs.count) 个，超时 \(step.timeoutMs)ms"

        case .findImageAndClick:
            let scope = step.searchRect == nil ? "全屏" : "选区"
            let suffix = step.eventDeliveryMode == .targetPID ? " · 定向投递" : ""
            return "\(scope)找图点击，相似度 \(String(format: "%.2f", step.similarityThreshold))\(suffix)"

        case .findColorAndClick:
            let scope = step.searchRect == nil ? "全屏" : "选区"
            let hex = step.targetColor?.hexString ?? "-"
            let suffix = step.eventDeliveryMode == .targetPID ? " · 定向投递" : ""
            return "\(scope)找色点击 \(hex) 容差 \(step.colorTolerance)\(suffix)"
        }
    }

    private func runScript() async {
        guard !scriptSteps.isEmpty else {
            statusMessage = "脚本还是空的，先加几个步骤。"
            return
        }

        isRunningScript = true
        statusMessage = "开始执行步骤脚本..."
        appendLogMessage("开始执行步骤脚本，步骤数 \(scriptSteps.count)")

        defer {
            isRunningScript = false
        }

        do {
            for step in scriptSteps where step.isEnabled {
                do {
                    appendLogMessage("执行：\(stepSummary(step))")
                    switch step.kind {
                    case .wait:
                        try await Task.sleep(for: .milliseconds(step.milliseconds))

                    case .clickPoint:
                        let snapshot = try captureService.captureMainDisplay()
                        let point = try resolvedPixelPoint(for: step, snapshot: snapshot)
                        let targetPID = try resolvedTargetPID(for: step)
                        try automationService.click(
                            pixelPoint: point,
                            snapshot: snapshot,
                            deliveryMode: step.eventDeliveryMode,
                            targetPID: targetPID
                        )

                    case .longPressPoint:
                        let snapshot = try captureService.captureMainDisplay()
                        let point = try resolvedPixelPoint(for: step, snapshot: snapshot)
                        let targetPID = try resolvedTargetPID(for: step)
                        try automationService.longPress(
                            pixelPoint: point,
                            snapshot: snapshot,
                            durationMs: step.milliseconds,
                            deliveryMode: step.eventDeliveryMode,
                            targetPID: targetPID
                        )

                    case .dragPoints:
                        let snapshot = try captureService.captureMainDisplay()
                        let startPoint = try resolvedPixelPoint(for: step, snapshot: snapshot)
                        guard let rawEndPoint = step.endPoint else {
                            throw StudioError.actionUnavailable("拖动步骤缺少终点坐标。")
                        }
                        let endProbeStep = ScriptStep(
                            name: step.name,
                            kind: step.kind,
                            milliseconds: step.milliseconds,
                            point: rawEndPoint,
                            endPoint: nil,
                            coordinateMode: step.coordinateMode,
                            windowTarget: step.windowTarget,
                            eventDeliveryMode: step.eventDeliveryMode
                        )
                        let endPoint = try resolvedPixelPoint(for: endProbeStep, snapshot: snapshot)
                        let targetPID = try resolvedTargetPID(for: step)
                        try automationService.drag(
                            from: startPoint,
                            to: endPoint,
                            snapshot: snapshot,
                            durationMs: step.milliseconds,
                            deliveryMode: step.eventDeliveryMode,
                            targetPID: targetPID
                        )

                    case .multiColorCheck:
                        let samples = samplesForStep(step)
                        guard !samples.isEmpty else {
                            throw StudioError.actionUnavailable("多点比色步骤没有可用样本。")
                        }
                        try await automationService.waitForMultiColor(
                            samples: samples,
                            timeoutMs: step.timeoutMs,
                            captureService: captureService
                        )

                    case .findImageAndClick:
                        guard let template = templateForStep(step) else {
                            throw StudioError.templateMissing
                        }
                        let result = try await automationService.findTemplate(
                            template: template,
                            searchRect: step.searchRect,
                            minimumSimilarity: step.similarityThreshold,
                            timeoutMs: step.timeoutMs,
                            captureService: captureService
                        )
                        let targetPID = try resolvedTargetPID(for: step)
                        try automationService.click(
                            pixelPoint: result.match.rect.center,
                            snapshot: result.snapshot,
                            deliveryMode: step.eventDeliveryMode,
                            targetPID: targetPID
                        )
                        appendLogMessage("找图命中 x:\(result.match.rect.x) y:\(result.match.rect.y) score:\(String(format: "%.3f", result.match.score))")

                    case .findColorAndClick:
                        guard let targetColor = step.targetColor else {
                            throw StudioError.actionUnavailable("找色步骤缺少颜色。")
                        }
                        let result = try await automationService.waitForColor(
                            targetColor: targetColor,
                            searchRect: step.searchRect,
                            tolerance: step.colorTolerance,
                            timeoutMs: step.timeoutMs,
                            captureService: captureService
                        )
                        let targetPID = try resolvedTargetPID(for: step)
                        try automationService.click(
                            pixelPoint: result.point,
                            snapshot: result.snapshot,
                            deliveryMode: step.eventDeliveryMode,
                            targetPID: targetPID
                        )
                        appendLogMessage("找色命中 @ (\(result.point.x), \(result.point.y))")
                    }
                } catch {
                    appendLogMessage("步骤失败：\(error.localizedDescription)")
                    if !step.continueOnFailure {
                        throw error
                    }
                }
            }

            statusMessage = "步骤脚本执行完成。"
            appendLogMessage("步骤脚本执行完成")
        } catch {
            statusMessage = "步骤脚本中断：\(error.localizedDescription)"
            appendLogMessage("步骤脚本中断：\(error.localizedDescription)")
        }
    }

    private func pointForClickStep(from selectedPoint: PixelPoint) -> PixelPoint? {
        switch coordinateMode {
        case .screenAbsolute:
            return selectedPoint

        case .selectedWindowRelative:
            guard let relativePoint = relativePoint(from: selectedPoint) else {
                statusMessage = "窗口相对坐标模式下，请先锁定窗口。"
                return nil
            }
            return relativePoint
        }
    }

    private func relativePoint(from rawPoint: PixelPoint) -> PixelPoint? {
        guard let snapshot, let selectedWindow else {
            return nil
        }
        let screenPoint = snapshot.screenPoint(from: rawPoint)
        return PixelPoint(
            x: Int(screenPoint.x - selectedWindow.screenBounds.minX),
            y: Int(selectedWindow.screenBounds.maxY - screenPoint.y)
        )
    }

    private func targetWindowForCurrentMode() -> WindowTarget? {
        if coordinateMode == .selectedWindowRelative || deliveryMode == .targetPID {
            guard let target = selectedWindow?.target else {
                statusMessage = "当前模式需要先锁定窗口。"
                return nil
            }
            return target
        }
        return nil
    }

    private func resolvedPixelPoint(for step: ScriptStep, snapshot: DisplaySnapshot) throws -> PixelPoint {
        guard let point = step.point else {
            throw StudioError.actionUnavailable("动作步骤缺少坐标。")
        }

        switch step.coordinateMode {
        case .screenAbsolute:
            return point.clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)

        case .selectedWindowRelative:
            guard let target = step.windowTarget,
                  let screenBounds = windowService.bounds(for: target) else {
                throw StudioError.windowMissing("目标窗口已经找不到了，无法计算相对坐标。")
            }
            let screenPoint = CGPoint(
                x: screenBounds.minX + CGFloat(point.x),
                y: screenBounds.maxY - CGFloat(point.y)
            )
            return snapshot.pixelPoint(fromScreenPoint: screenPoint)
        }
    }

    private func resolvedTargetPID(for step: ScriptStep) throws -> pid_t? {
        guard step.eventDeliveryMode == .targetPID else {
            return nil
        }
        guard let pid = step.windowTarget?.pid else {
            throw StudioError.windowMissing("当前步骤要求按 PID 定向投递，但没有目标窗口。")
        }
        return pid_t(pid)
    }

    private func samplesForStep(_ step: ScriptStep) -> [ColorSample] {
        let lookup = Dictionary(uniqueKeysWithValues: samples.map { ($0.id, $0) })
        return step.sampleIDs.compactMap { lookup[$0] }
    }

    private func templateForStep(_ step: ScriptStep) -> ImageTemplate? {
        guard let templateID = step.templateID else {
            return nil
        }
        return templates.first(where: { $0.id == templateID })
    }

    private func sampledPoint(from rawPoint: PixelPoint, in snapshot: DisplaySnapshot) -> PixelPoint {
        rawPoint.adding(captureOffset).clamped(maxWidth: snapshot.rgba.width, maxHeight: snapshot.rgba.height)
    }

    private func makeTemplate(from rect: PixelRect) throws -> ImageTemplate {
        guard let snapshot else {
            throw StudioError.actionUnavailable("请先截图或导入一张图片。")
        }
        guard let crop = snapshot.rgba.crop(rect), let pngData = crop.pngData else {
            throw StudioError.actionUnavailable("模板保存失败，选区无效。")
        }
        return ImageTemplate(
            name: "T\(templates.count + 1)",
            rect: rect,
            pngData: pngData,
            preferredSimilarity: defaultSimilarityThreshold,
            processingMode: templateProcessingMode
        )
    }

    private func chooseExportFolder(title: String, message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = title
        panel.message = message
        panel.prompt = "选择文件夹"

        guard panel.runModal() == .OK else {
            return nil
        }
        return panel.url
    }

    private func filenameTimestamp() -> String {
        Self.exportFilenameFormatter.string(from: .now)
    }

    private func uniquePNGFileURL(in folderURL: URL, preferredBaseName: String) -> URL {
        let trimmed = preferredBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmed.isEmpty ? "capture" : trimmed
        var candidate = folderURL.appendingPathComponent(baseName).appendingPathExtension("png")
        var index = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = folderURL
                .appendingPathComponent("\(baseName)-\(index)")
                .appendingPathExtension("png")
            index += 1
        }

        return candidate
    }

    private func writePNGImage(_ image: RGBAImage, to folderURL: URL, preferredBaseName: String) throws -> URL {
        guard let data = image.pngData else {
            throw StudioError.imageDecodeFailed
        }

        let fileURL = uniquePNGFileURL(in: folderURL, preferredBaseName: preferredBaseName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func createNewScriptDocument(named name: String) {
        currentScriptURL = nil
        currentScriptDraftName = sanitizedScriptName(name)
        scriptSource = ""
        hasStartedWorkspaceSession = true
        statusMessage = "已新建脚本：\(currentScriptDisplayName)"
        appendLogMessage("已新建脚本 \(currentScriptDisplayName)（\(scriptLanguage.title)）")
    }

    private func sanitizedScriptName(_ rawName: String) -> String {
        rawName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: ".\(scriptLanguage.defaultFileExtension)", with: "")
    }

    private func appendScriptSnippet(_ snippet: String) {
        if currentScriptURL == nil, currentScriptDraftName == nil {
            currentScriptDraftName = "Untitled"
        }
        if !scriptSource.isEmpty, !scriptSource.hasSuffix("\n") {
            scriptSource += "\n"
        }
        scriptSource += snippet + "\n"
    }

    private func recordedOperationsScriptSnippet(target: WindowTarget) -> String {
        let title = target.displayTitle.replacingOccurrences(of: "\n", with: " ")

        switch scriptLanguage {
        case .pythonLike:
            var lines = [
                "# 固定窗口录制：\(title)",
                "# 回放前请先锁定同一个窗口；若希望后台回放，建议把事件投递切到目标进程投递。"
            ]

            for operation in recordedWindowOperations {
                if operation.delayMs > 0 {
                    lines.append("sleep_ms(\(operation.delayMs))")
                }

                switch operation.kind {
                case .leftClick:
                    lines.append("click_relative(\(operation.relativePoint.x), \(operation.relativePoint.y))")
                case .longPress:
                    lines.append("long_press_relative(\(operation.relativePoint.x), \(operation.relativePoint.y), \(operation.durationMs ?? defaultLongPressDurationMs))")
                case .drag:
                    if let endPoint = operation.endRelativePoint {
                        lines.append("drag_relative(\(operation.relativePoint.x), \(operation.relativePoint.y), \(endPoint.x), \(endPoint.y), \(operation.durationMs ?? defaultDragDurationMs))")
                    }
                }
            }
            return lines.joined(separator: "\n")

        case .javaScript:
            var lines = [
                "// 固定窗口录制：\(title)",
                "// 回放前请先锁定同一个窗口；若希望后台回放，建议把事件投递切到目标进程投递。"
            ]

            for operation in recordedWindowOperations {
                if operation.delayMs > 0 {
                    lines.append("sleep_ms(\(operation.delayMs));")
                }

                switch operation.kind {
                case .leftClick:
                    lines.append("click_relative(\(operation.relativePoint.x), \(operation.relativePoint.y));")
                case .longPress:
                    lines.append("long_press_relative(\(operation.relativePoint.x), \(operation.relativePoint.y), \(operation.durationMs ?? defaultLongPressDurationMs));")
                case .drag:
                    if let endPoint = operation.endRelativePoint {
                        lines.append("drag_relative(\(operation.relativePoint.x), \(operation.relativePoint.y), \(endPoint.x), \(endPoint.y), \(operation.durationMs ?? defaultDragDurationMs));")
                    }
                }
            }
            return lines.joined(separator: "\n")
        }
    }

    private func ensureScreenCapturePermissionReady() -> Bool {
        guard captureService.hasScreenCaptureAccess() else {
            statusMessage = permissionGuidanceMessage(
                screenGranted: false,
                accessibilityGranted: captureService.hasAccessibilityAccess(),
                requestedScreen: hasPromptedScreenPermissionThisSession,
                requestedAccessibility: false
            )
            return false
        }
        return true
    }

    private func permissionGuidanceMessage(
        screenGranted: Bool,
        accessibilityGranted: Bool,
        requestedScreen: Bool,
        requestedAccessibility: Bool
    ) -> String {
        var missingItems: [String] = []
        if !screenGranted {
            missingItems.append("屏幕录制")
        }
        if !accessibilityGranted {
            missingItems.append("辅助功能")
        }

        let missingText = missingItems.isEmpty ? "无" : missingItems.joined(separator: "、")
        let hostHint = "如果你是在 Xcode 里运行这个 Swift Package，请给 Xcode 授权；如果是 `swift run` 或终端启动，请给 Terminal / iTerm 授权。"
        let restartHint = requestedScreen || requestedAccessibility
            ? "macOS 对这两类权限经常需要完全退出当前宿主程序后才会刷新；勾选后请彻底退出再重新打开。"
            : "请在系统设置 → 隐私与安全性里打开对应权限。"

        return "还缺少：\(missingText)。\(restartHint) \(hostHint)"
    }

    private func currentProjectExport() -> StudioProjectExport {
        StudioProjectExport(
            samples: samples,
            templates: templates,
            selectedTemplateID: selectedTemplateID,
            scriptSteps: scriptSteps,
            scriptLanguage: scriptLanguage,
            scriptSource: scriptSource,
            scriptDraftName: currentScriptDraftName,
            lockedWindowTarget: selectedWindow?.target,
            recordedWindowTarget: recordedWindowTarget,
            recordedWindowOperations: recordedWindowOperations,
            defaultTolerance: defaultTolerance,
            defaultTimeoutMs: defaultTimeoutMs,
            defaultWaitMs: defaultWaitMs,
            defaultSimilarityThreshold: defaultSimilarityThreshold,
            templateProcessingMode: templateProcessingMode,
            useSelectionAsSearchArea: useSelectionAsSearchArea,
            captureOffsetX: captureOffsetX,
            captureOffsetY: captureOffsetY,
            coordinateMode: coordinateMode,
            deliveryMode: deliveryMode
        )
    }

    private func applyProject(_ project: StudioProjectExport, sourceURL: URL?) {
        operationRecorder.stop()
        isRecordingWindowOperations = false

        snapshot = nil
        hover = nil
        selectedPoint = nil
        selectedRect = nil
        currentCaptureSource = "未截图"
        currentProjectURL = sourceURL
        currentScriptURL = nil
        hasStartedWorkspaceSession = true

        samples = project.samples
        templates = project.templates
        selectedTemplateID = project.selectedTemplateID ?? templates.first?.id
        scriptSteps = project.scriptSteps
        scriptLanguage = project.scriptLanguage
        scriptSource = project.scriptSource
        currentScriptDraftName = project.scriptDraftName
        recordedWindowTarget = project.recordedWindowTarget
        recordedWindowOperations = project.recordedWindowOperations
        defaultTolerance = project.defaultTolerance
        defaultTimeoutMs = project.defaultTimeoutMs
        defaultWaitMs = project.defaultWaitMs
        defaultSimilarityThreshold = project.defaultSimilarityThreshold
        templateProcessingMode = project.templateProcessingMode
        useSelectionAsSearchArea = project.useSelectionAsSearchArea
        captureOffsetX = project.captureOffsetX
        captureOffsetY = project.captureOffsetY
        coordinateMode = project.coordinateMode
        deliveryMode = project.deliveryMode
        ocrResult = ""
        selectedElementInfo = nil

        refreshWindows(logResult: false)
        resolveSelectedWindow(using: project.lockedWindowTarget ?? project.recordedWindowTarget)
    }

    private func resolveSelectedWindow(using target: WindowTarget?) {
        guard let target else {
            selectedWindowID = nil
            return
        }

        if let exact = windows.first(where: { $0.windowID == target.windowID }) {
            selectedWindowID = exact.windowID
            return
        }
        if let pidAndTitle = windows.first(where: { $0.pid == target.pid && $0.title == target.title && $0.ownerName == target.ownerName }) {
            selectedWindowID = pidAndTitle.windowID
            return
        }
        if let ownerAndTitle = windows.first(where: { $0.ownerName == target.ownerName && $0.title == target.title }) {
            selectedWindowID = ownerAndTitle.windowID
            return
        }
        selectedWindowID = nil
        appendLogMessage("项目里的目标窗口当前未找到：\(target.ownerName) · \(target.title)")
    }

    private func suggestedScriptFilename() -> String {
        if let currentScriptURL {
            return currentScriptURL.lastPathComponent
        }
        let baseName = sanitizedScriptName(currentScriptDraftName ?? "")
        let safeBaseName = baseName.isEmpty ? "Untitled" : baseName
        return "\(safeBaseName).\(scriptLanguage.defaultFileExtension)"
    }


    private func suggestedProjectFilename() -> String {
        currentProjectURL?.lastPathComponent ?? "Untitled.mcstudio"
    }

    private func normalizedProjectURL(for url: URL) -> URL {
        guard url.pathExtension.isEmpty else {
            return url
        }
        return url.appendingPathExtension("mcstudio")
    }

    private func normalizedScriptURL(for url: URL) -> URL {
        guard url.pathExtension.isEmpty else {
            return url
        }
        return url.appendingPathExtension(scriptLanguage.defaultFileExtension)
    }

    private func inferredScriptLanguage(for url: URL, source: String) -> ScriptLanguage {
        switch url.pathExtension.lowercased() {
        case "js", "mjs", "cjs":
            return .javaScript
        case "py", "pyw", "mcpy":
            return .pythonLike
        default:
            let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("function ") || trimmed.contains("const ") || trimmed.contains("let ") {
                return .javaScript
            }
            return .pythonLike
        }
    }

    private func writeScript(to url: URL) {
        let targetURL = normalizedScriptURL(for: url)

        do {
            try scriptSource.write(to: targetURL, atomically: true, encoding: .utf8)
            currentScriptURL = targetURL
            currentScriptDraftName = targetURL.deletingPathExtension().lastPathComponent
            statusMessage = "已保存脚本：\(targetURL.lastPathComponent)"
            appendLogMessage("已保存脚本 \(targetURL.lastPathComponent)")
        } catch {
            statusMessage = "保存脚本失败：\(error.localizedDescription)"
            appendLogMessage("保存脚本失败：\(error.localizedDescription)")
        }
    }


    private func writeProject(to url: URL) {
        let targetURL = normalizedProjectURL(for: url)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(currentProjectExport())
            try data.write(to: targetURL, options: .atomic)
            currentProjectURL = targetURL
            statusMessage = "已保存项目：\(targetURL.lastPathComponent)"
            appendLogMessage("已保存项目 \(targetURL.lastPathComponent)")
        } catch {
            statusMessage = "保存项目失败：\(error.localizedDescription)"
            appendLogMessage("保存项目失败：\(error.localizedDescription)")
        }
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func escapeJS(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
