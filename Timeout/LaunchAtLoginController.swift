import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var statusDescription = ""
    @Published private(set) var lastErrorDescription: String?

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
        refreshStatus()
    }

    func apply(desiredEnabled: Bool) {
        do {
            switch (desiredEnabled, service.status) {
            case (true, .enabled), (false, .notRegistered):
                break
            default:
                if desiredEnabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            }

            lastErrorDescription = nil
        } catch {
            lastErrorDescription = error.localizedDescription
        }

        refreshStatus()
    }

    private func refreshStatus() {
        switch service.status {
        case .notRegistered:
            statusDescription = "Launch at login is off."
        case .enabled:
            statusDescription = "Launch at login is enabled."
        case .requiresApproval:
            statusDescription = "Launch at login needs approval in System Settings."
        case .notFound:
            statusDescription = "Launch at login could not find the app bundle."
        @unknown default:
            statusDescription = "Launch at login returned an unknown status."
        }
    }
}

