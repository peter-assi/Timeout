import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let workIntervalMinutes = "workIntervalMinutes"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    private let defaults: UserDefaults
    private var isBootstrapping = true

    @Published var workIntervalMinutes: Double {
        didSet {
            persist(workIntervalMinutes, forKey: Keys.workIntervalMinutes)
        }
    }

    @Published var breakDurationSeconds: Double {
        didSet {
            persist(breakDurationSeconds, forKey: Keys.breakDurationSeconds)
        }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            persist(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedWorkInterval = defaults.object(forKey: Keys.workIntervalMinutes) as? Double ?? 50
        let storedBreakDuration = defaults.object(forKey: Keys.breakDurationSeconds) as? Double ?? 30
        let storedLaunchAtLogin = defaults.object(forKey: Keys.launchAtLoginEnabled) as? Bool ?? true

        workIntervalMinutes = storedWorkInterval.clamped(to: 5...120)
        breakDurationSeconds = storedBreakDuration.clamped(to: 10...300)
        launchAtLoginEnabled = storedLaunchAtLogin

        isBootstrapping = false

        defaults.set(workIntervalMinutes, forKey: Keys.workIntervalMinutes)
        defaults.set(breakDurationSeconds, forKey: Keys.breakDurationSeconds)
        defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
    }

    var workInterval: TimeInterval {
        workIntervalMinutes * 60
    }

    var breakDuration: TimeInterval {
        breakDurationSeconds
    }

    private func persist<Value>(_ value: Value, forKey key: String) {
        guard !isBootstrapping else {
            return
        }

        defaults.set(value, forKey: key)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

