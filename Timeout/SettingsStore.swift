import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Keys {
        static let workIntervalMinutes = "workIntervalMinutes"
        static let breakDurationSeconds = "breakDurationSeconds"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let postponeDuringCallsEnabled = "postponeDuringCallsEnabled"
        static let callRetryDelaySeconds = "callRetryDelaySeconds"
        static let useHardwareActivityDetection = "useHardwareActivityDetection"
        static let useWindowTitleFallback = "useWindowTitleFallback"
        static let exerciseAnimationStyle = "exerciseAnimationStyle"
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

    @Published var postponeDuringCallsEnabled: Bool {
        didSet {
            persist(postponeDuringCallsEnabled, forKey: Keys.postponeDuringCallsEnabled)
        }
    }

    @Published var callRetryDelaySeconds: Double {
        didSet {
            persist(callRetryDelaySeconds, forKey: Keys.callRetryDelaySeconds)
        }
    }

    @Published var useHardwareActivityDetection: Bool {
        didSet {
            persist(useHardwareActivityDetection, forKey: Keys.useHardwareActivityDetection)
        }
    }

    @Published var useWindowTitleFallback: Bool {
        didSet {
            persist(useWindowTitleFallback, forKey: Keys.useWindowTitleFallback)
        }
    }

    @Published var exerciseAnimationStyle: ExerciseAnimationStyle {
        didSet {
            persist(exerciseAnimationStyle.rawValue, forKey: Keys.exerciseAnimationStyle)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedWorkInterval = defaults.object(forKey: Keys.workIntervalMinutes) as? Double ?? 50
        let storedBreakDuration = defaults.object(forKey: Keys.breakDurationSeconds) as? Double ?? 30
        let storedLaunchAtLogin = defaults.object(forKey: Keys.launchAtLoginEnabled) as? Bool ?? true
        let storedPostponeDuringCalls = defaults.object(forKey: Keys.postponeDuringCallsEnabled) as? Bool ?? true
        let storedCallRetryDelay = defaults.object(forKey: Keys.callRetryDelaySeconds) as? Double ?? 60
        let storedUseHardwareActivityDetection = defaults.object(forKey: Keys.useHardwareActivityDetection) as? Bool ?? true
        let storedUseWindowTitleFallback = defaults.object(forKey: Keys.useWindowTitleFallback) as? Bool ?? true
        let storedExerciseAnimationStyle = defaults.string(forKey: Keys.exerciseAnimationStyle)

        workIntervalMinutes = storedWorkInterval.clamped(to: 5...120)
        breakDurationSeconds = storedBreakDuration.clamped(to: 10...300)
        launchAtLoginEnabled = storedLaunchAtLogin
        postponeDuringCallsEnabled = storedPostponeDuringCalls
        callRetryDelaySeconds = storedCallRetryDelay.clamped(to: 15...600)
        useHardwareActivityDetection = storedUseHardwareActivityDetection
        useWindowTitleFallback = storedUseWindowTitleFallback
        exerciseAnimationStyle = ExerciseAnimationStyle(rawValue: storedExerciseAnimationStyle ?? "") ?? .classic

        isBootstrapping = false

        defaults.set(workIntervalMinutes, forKey: Keys.workIntervalMinutes)
        defaults.set(breakDurationSeconds, forKey: Keys.breakDurationSeconds)
        defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
        defaults.set(postponeDuringCallsEnabled, forKey: Keys.postponeDuringCallsEnabled)
        defaults.set(callRetryDelaySeconds, forKey: Keys.callRetryDelaySeconds)
        defaults.set(useHardwareActivityDetection, forKey: Keys.useHardwareActivityDetection)
        defaults.set(useWindowTitleFallback, forKey: Keys.useWindowTitleFallback)
        defaults.set(exerciseAnimationStyle.rawValue, forKey: Keys.exerciseAnimationStyle)
    }

    var workInterval: TimeInterval {
        workIntervalMinutes * 60
    }

    var breakDuration: TimeInterval {
        breakDurationSeconds
    }

    var callRetryDelay: TimeInterval {
        callRetryDelaySeconds
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
