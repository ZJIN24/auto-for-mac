import SwiftUI

struct ScriptEditorWorkspaceView: View {
    @EnvironmentObject private var store: StudioStore
    @Binding private var showLibrary: Bool
    private let allowLibraryToggle: Bool
    private let allowProjectActions: Bool

    init(
        showLibrary: Binding<Bool> = .constant(true),
        allowLibraryToggle: Bool = true,
        allowProjectActions: Bool = true
    ) {
        self._showLibrary = showLibrary
        self.allowLibraryToggle = allowLibraryToggle
        self.allowProjectActions = allowProjectActions
    }

    var body: some View {
        if showLibrary {
            HSplitView {
                editorPanel
                    .frame(minWidth: 760, idealWidth: 920)

                ScriptFunctionLibraryPanel()
                    .frame(minWidth: 320, idealWidth: 380, maxWidth: 460)
            }
        } else {
            editorPanel
        }
    }

    private var editorPanel: some View {
        GroupBox("脚本工作台") {
            VStack(alignment: .leading, spacing: 12) {
                headerRow
                fileStatusPanel
                fileActionRow
                insertRow

                Text(store.scriptLanguage.editorHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if store.isScriptWorkspaceEmptyStateVisible {
                    emptyEditorState
                } else {
                    TextEditor(text: $store.scriptSource)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(8)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            Picker("语言", selection: languageBinding) {
                ForEach(ScriptLanguage.allCases) { language in
                    Text(language.title).tag(language)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentScriptDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(store.currentProjectDisplayName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Text("录制：\(store.recordingSummaryText)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if allowLibraryToggle {
                VisibilityToggleChip(title: showLibrary ? "隐藏函数库" : "显示函数库", systemImage: "books.vertical", isOn: $showLibrary)
            }
        }
    }

    private var fileStatusPanel: some View {
        GroupBox("当前文件") {
            VStack(alignment: .leading, spacing: 8) {
                statusLine(title: "脚本", value: store.currentScriptPathDisplay)
                statusLine(title: "项目", value: store.currentProjectPathDisplay)
                statusLine(title: "录制", value: store.recordingSummaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyEditorState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("还没有新建脚本")
                .font(.title3.weight(.semibold))
            Text("这里保持空白。你可以先新建一个命名脚本，或者直接打开现有脚本。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("点“新建脚本”后会先输入脚本名，再进入空白编辑区。")
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack(spacing: 10) {
                Button("新建脚本…") { store.newScriptDocument() }
                Button("打开脚本") { store.openScriptDocument() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.12), lineWidth: 1)
        )
    }

    private var fileActionRow: some View {
        ViewThatFits(in: .horizontal) {
            fileActionRowInline
            fileActionRowStacked
        }
        .buttonStyle(.bordered)
    }

    private var fileActionRowInline: some View {
        HStack(spacing: 8) {
            Button("新建脚本") { store.newScriptDocument() }
            Button("打开脚本") { store.openScriptDocument() }
            Button("保存脚本") { store.saveScriptDocument() }
            Button("脚本另存为") { store.saveScriptDocumentAs() }

            if allowProjectActions {
                Divider()
                    .frame(height: 16)

                Button("打开项目") { store.openProjectDocument() }
                Button("保存项目") { store.saveProjectDocument() }
            }

            Divider()
                .frame(height: 16)

            Button("导入录制代码") { store.appendRecordedOperationsToScriptSource() }
                .disabled(store.recordedWindowOperations.isEmpty)
            Button("填充模板") { store.fillDefaultScriptTemplate() }
            Button(store.isRunningCode ? "执行中..." : "运行脚本") { store.runScriptSource() }
                .disabled(store.isRunningCode)
            Button("复制脚本") { store.copyScriptSource() }
        }
    }

    private var fileActionRowStacked: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button("新建脚本") { store.newScriptDocument() }
                Button("打开脚本") { store.openScriptDocument() }
                Button("保存脚本") { store.saveScriptDocument() }
                Button("脚本另存为") { store.saveScriptDocumentAs() }
            }
            if allowProjectActions {
                HStack(spacing: 8) {
                    Button("打开项目") { store.openProjectDocument() }
                    Button("保存项目") { store.saveProjectDocument() }
                    Button("导入录制代码") { store.appendRecordedOperationsToScriptSource() }
                        .disabled(store.recordedWindowOperations.isEmpty)
                    Button("填充模板") { store.fillDefaultScriptTemplate() }
                    Button(store.isRunningCode ? "执行中..." : "运行脚本") { store.runScriptSource() }
                        .disabled(store.isRunningCode)
                    Button("复制脚本") { store.copyScriptSource() }
                }
            } else {
                HStack(spacing: 8) {
                    Button("导入录制代码") { store.appendRecordedOperationsToScriptSource() }
                        .disabled(store.recordedWindowOperations.isEmpty)
                    Button("填充模板") { store.fillDefaultScriptTemplate() }
                    Button(store.isRunningCode ? "执行中..." : "运行脚本") { store.runScriptSource() }
                        .disabled(store.isRunningCode)
                    Button("复制脚本") { store.copyScriptSource() }
                }
            }
        }
    }

    private var insertRow: some View {
        HStack(spacing: 8) {
            Button("插入点") { store.insertSelectedPointSnippet() }
            Button("插入颜色") { store.insertSelectedColorSnippet() }
            Button("插入选区") { store.insertSelectedRectSnippet() }
            Button("插入窗口") { store.insertSelectedWindowSnippet() }
            Spacer()
        }
        .buttonStyle(.borderless)
    }

    private var languageBinding: Binding<ScriptLanguage> {
        Binding(
            get: { store.scriptLanguage },
            set: { store.setScriptLanguage($0) }
        )
    }

    private func statusLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }
}

struct ScriptFunctionLibraryPanel: View {
    @EnvironmentObject private var store: StudioStore
    @State private var query = ""

    private var filteredDocs: [ScriptFunctionDoc] {
        ScriptFunctionLibrary.docs.filter { $0.matches(query) }
    }

    var body: some View {
        GroupBox("函数库") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索函数、关键字、示例", text: $query)
                        .textFieldStyle(.roundedBorder)
                    if !query.isEmpty {
                        Button("清空") { query = "" }
                            .buttonStyle(.borderless)
                    }
                }

                HStack {
                    Text("当前语言：\(store.scriptLanguage.title)")
                    Spacer()
                    Text("\(filteredDocs.count) 条结果")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if filteredDocs.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "questionmark.text.page")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.secondary)
                                Text("没有匹配的函数")
                                    .font(.headline)
                                Text("试试搜索：找图、找色、窗口、OCR、click_relative")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }

                        ForEach(filteredDocs) { doc in
                            ScriptFunctionCard(doc: doc)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct ScriptFunctionCard: View {
    @EnvironmentObject private var store: StudioStore
    let doc: ScriptFunctionDoc

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(doc.name)
                    .font(.headline)
                Spacer()
                Text(doc.category)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }

            Text(doc.signature(for: store.scriptLanguage))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Text(doc.summary)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(doc.example(for: store.scriptLanguage))
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 8) {
                Button("插入") { store.insertFunctionSnippet(doc) }
                Button("使用示例") { store.applyFunctionExample(doc) }
                Button("复制示例") { store.copyFunctionExample(doc) }
                Spacer()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioCardSurface()
    }
}
