import SwiftUI

@main
struct TimeoutApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Timeout!", systemImage: model.menuBarSymbolName) {
            MenuBarContentView(
                model: model,
                settings: model.settings,
                launchAtLoginController: model.launchAtLoginController
            )
        }
        .menuBarExtraStyle(.window)
    }
}
