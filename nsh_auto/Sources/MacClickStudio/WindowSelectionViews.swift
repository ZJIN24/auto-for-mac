import SwiftUI

struct WindowTargetPickerBar: View {
    @EnvironmentObject private var store: StudioStore

    var title: String = "目标窗口"
    var includeCaptureButton: Bool = true
    var disableSelection: Bool = false
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: $store.selectedWindowID) {
                Text("未选择").tag(Optional<UInt32>.none)
                ForEach(store.windows) { window in
                    Text(window.displayTitle).tag(Optional(window.windowID))
                }
            }
            .pickerStyle(.menu)
            .disabled(disableSelection)

            if compact {
                HStack {
                    Button("刷新") { store.refreshWindows() }
                    if includeCaptureButton {
                        Button("截目标窗口") { store.captureSelectedWindow() }
                            .disabled(store.selectedWindow == nil)
                    }
                }
            } else {
                ViewThatFits {
                    HStack {
                        Button("刷新窗口") { store.refreshWindows() }
                        if includeCaptureButton {
                            Button("截取目标窗口") { store.captureSelectedWindow() }
                                .disabled(store.selectedWindow == nil)
                        }
                        Spacer(minLength: 0)
                        Text(store.selectedWindow?.displayTitle ?? "还没有锁定窗口")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Button("刷新窗口") { store.refreshWindows() }
                            if includeCaptureButton {
                                Button("截取目标窗口") { store.captureSelectedWindow() }
                                    .disabled(store.selectedWindow == nil)
                            }
                        }
                        Text(store.selectedWindow?.displayTitle ?? "还没有锁定窗口")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .onAppear {
            if store.windows.isEmpty {
                store.refreshWindows(logResult: false)
            }
        }
    }
}
