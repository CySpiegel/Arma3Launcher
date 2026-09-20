import SwiftUI

@main
struct Arma3LauncherApp: App {
    @State private var model = LauncherModel()

    var body: some Scene {
        WindowGroup {
            MainWindow(model: model)
                .frame(minWidth: 960, minHeight: 620)
                .task { model.start() }
                .onChange(of: model.appearance, initial: true) { _, appearance in
                    switch appearance {
                    case .system: NSApplication.shared.appearance = nil
                    case .light: NSApplication.shared.appearance = NSAppearance(named: .aqua)
                    case .dark: NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
                    }
                }
                .onReceive(
                    NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
                ) {
                    _ in model.refreshIfIdle()
                }
        }
        .defaultSize(width: 1160, height: 720)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .sidebar) {
                Button("Refresh Content") { model.refresh() }
                    .keyboardShortcut("r")
            }
        }
    }
}
