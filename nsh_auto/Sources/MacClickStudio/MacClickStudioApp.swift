import SwiftUI

@main
struct MacClickStudioApp: App {
    @StateObject private var store = StudioStore()

    var body: some Scene {
        Window("MacClickStudio", id: AppSceneID.main) {
            ContentView()
                .environmentObject(store)
                .studioWorkspaceChrome()
                .bringAppToFrontOnAppear()
                .frame(minWidth: 1380, minHeight: 900)
        }
        .defaultPosition(.center)
        .windowResizability(.contentMinSize)
        .commands {
            MainAppCommands(store: store)
        }

        Window("抓抓", id: AppSceneID.grabber) {
            GrabberUtilityWindowView()
                .environmentObject(store)
                .studioWorkspaceChrome()
                .bringAppToFrontOnAppear()
                .grabberUtilityWindowStyle(initialSize: CGSize(width: 860, height: 620))
        }
        .windowResizability(.automatic)

        MenuBarExtra("MacClickStudio", systemImage: "cursorarrow.click.2") {
            AppMenuBarPanelView()
                .environmentObject(store)
                .studioWorkspaceChrome()
        }

        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("MacClickStudio 设置")
                    .font(.title2)
                Text("主页面负责项目、脚本、录制与函数库；抓抓窗口负责截图、找点、锁窗与录制辅助。")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 420)
        }
    }
}
