import SwiftUI

@main
struct CodexProfilesApp: App {
    @State private var model: AppModel

    init() {
        let model = AppModel(demo: CommandLine.arguments.contains("--demo"))
        model.updater = UpdateController(enabled: !model.isDemo) { [weak model] in
            guard let model else { return false }
            return !model.isBusy && !model.pendingNewLogin
        }
        _model = State(initialValue: model)
        if model.isDemo {
            Task { @MainActor in model.showDemoWindow() }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environment(model)
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: BrandImage.menuBar)
                    .renderingMode(.template)
                if let remaining = model.menuBarUsage {
                    Text(remaining).monospacedDigit()
                }
            }
            .help("Codex Profiles — \(model.currentTitle)")
        }
        .menuBarExtraStyle(.window)
    }
}
