import SwiftUI

struct FixedWindowRecordingPanel: View {
    @EnvironmentObject private var store: StudioStore
    var compact: Bool = false
    var includeCaptureButton: Bool = true
    var showTargetPicker: Bool = true

    var body: some View {
        GroupBox("固定窗口录制") {
            VStack(alignment: .leading, spacing: compact ? 8 : 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.isRecordingWindowOperations ? "录制中" : "待机")
                            .font(.headline)
                        Text(statusDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Label(
                        store.isRecordingWindowOperations ? "REC" : "STOP",
                        systemImage: store.isRecordingWindowOperations ? "record.circle.fill" : "pause.circle"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(store.isRecordingWindowOperations ? .red : .secondary)
                }

                if showTargetPicker {
                    WindowTargetPickerBar(
                        title: "录制目标窗口",
                        includeCaptureButton: includeCaptureButton,
                        disableSelection: store.isRecordingWindowOperations,
                        compact: compact
                    )
                }

                infoLine("录制目标", value: recordedTargetText)
                infoLine("当前锁定", value: store.selectedWindow?.displayTitle ?? "-")
                infoLine("操作数量", value: "\(store.recordedWindowOperations.count)")

                if store.deliveryMode != .targetPID {
                    Text("提示：若希望后台回放固定窗口，建议把事件投递切到“目标进程投递”。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                buttonRows

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if store.recordedWindowOperations.isEmpty {
                            Text(emptyText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            ForEach(Array(store.recordedWindowOperations.enumerated()), id: \.element.id) { index, operation in
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("#\(index + 1) \(operation.summary)")
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    Text(operationDetailText(operation))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if index < store.recordedWindowOperations.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: compact ? 92 : 140, maxHeight: compact ? 132 : 220)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var buttonRows: some View {
        if compact {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button("开始录制") { store.startWindowOperationRecording() }
                        .disabled(store.selectedWindow == nil || store.isRecordingWindowOperations)
                    Button("停止") { store.stopWindowOperationRecording() }
                        .disabled(!store.isRecordingWindowOperations)
                    Button("清空") { store.clearRecordedWindowOperations() }
                        .disabled(store.recordedWindowOperations.isEmpty)
                }
                HStack {
                    Button("导入步骤") { store.importRecordedOperationsToSteps() }
                        .disabled(store.recordedWindowOperations.isEmpty)
                    Button("转脚本") { store.appendRecordedOperationsToScriptSource() }
                        .disabled(store.recordedWindowOperations.isEmpty)
                }
            }
        } else {
            ViewThatFits {
                HStack {
                    primaryButtons
                    Spacer(minLength: 0)
                    secondaryButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    primaryButtons
                    secondaryButtons
                }
            }
        }
    }

    private var primaryButtons: some View {
        HStack {
            Button(store.isRecordingWindowOperations ? "录制中..." : "开始录制") {
                store.startWindowOperationRecording()
            }
            .disabled(store.selectedWindow == nil || store.isRecordingWindowOperations)

            Button("停止") {
                store.stopWindowOperationRecording()
            }
            .disabled(!store.isRecordingWindowOperations)

            Button("清空") {
                store.clearRecordedWindowOperations()
            }
            .disabled(store.recordedWindowOperations.isEmpty)
        }
    }

    private var secondaryButtons: some View {
        HStack {
            Button("导入步骤") {
                store.importRecordedOperationsToSteps()
            }
            .disabled(store.recordedWindowOperations.isEmpty)

            Button("转脚本") {
                store.appendRecordedOperationsToScriptSource()
            }
            .disabled(store.recordedWindowOperations.isEmpty)
        }
    }

    private func infoLine(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recordedTargetText: String {
        store.recordedWindowTarget?.displayTitle ?? "-"
    }

    private var statusDescription: String {
        if store.isRecordingWindowOperations {
            return "只记录锁定窗口里的点击、长按和拖动，并自动换算成窗口相对坐标。"
        }
        return "开始后会忽略其他窗口的鼠标动作；停止后可一键导入步骤或转成脚本。"
    }

    private func operationDetailText(_ operation: RecordedWindowOperation) -> String {
        let begin = "abs=(\(operation.absolutePoint.x), \(operation.absolutePoint.y))"
        let durationText = operation.durationMs.map { " · hold=\($0)ms" } ?? ""
        let offsetText = " · t=\(operation.createdAtOffsetMs)ms"

        if let endPoint = operation.endAbsolutePoint, operation.kind == .drag {
            return "\(begin) → (\(endPoint.x), \(endPoint.y))\(durationText)\(offsetText)"
        }
        return "\(begin)\(durationText)\(offsetText)"
    }

    private var emptyText: String {
        compact
            ? "还没有录制内容。先锁定窗口，再点开始录制。"
            : "还没有录制内容。先锁定一个窗口，再点开始录制；只有该窗口里的点击、长按和拖动会被记下来。"
    }
}
