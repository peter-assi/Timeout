import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum CyclePhase: Equatable {
        case monitoring
        case breakTime
        case postponedForCall
        case paused
    }

    @Published private(set) var phase: CyclePhase = .monitoring
    @Published private(set) var secondsRemaining = 0

    let settings: SettingsStore
    let launchAtLoginController: LaunchAtLoginController

    private let callActivityDetector = CallActivityDetector()
    private let overlayController = BreakOverlayController()
    private var deadline: Date? {
        didSet {
            scheduleDeadlineTimer()
            updateCountdownRefreshTimer()
        }
    }
    private var deadlineTimer: Timer?
    private var countdownRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isInactive = false
    private var isMenuVisible = false
    private var postponedCallDescription: String?
    private var lastBreakExerciseID: String?

    init(
        settings: SettingsStore = SettingsStore(),
        launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController()
    ) {
        self.settings = settings
        self.launchAtLoginController = launchAtLoginController
        overlayController.onEscape = { [weak self] in
            self?.endBreakEarly()
        }

        bindSettings()
        installWorkspaceObservers()
        launchAtLoginController.apply(desiredEnabled: settings.launchAtLoginEnabled)
        resumeWorkCycle(from: .now)
    }

    var menuBarSymbolName: String {
        switch phase {
        case .monitoring:
            return "timer"
        case .breakTime:
            return "figure.walk.circle.fill"
        case .postponedForCall:
            return "hourglass.circle.fill"
        case .paused:
            return "moon.zzz.fill"
        }
    }

    var phaseTitle: String {
        switch phase {
        case .monitoring:
            return "Next break"
        case .breakTime:
            return "Break in progress"
        case .postponedForCall:
            return "Break delayed"
        case .paused:
            return "Paused"
        }
    }

    var phaseDescription: String {
        switch phase {
        case .monitoring:
            return "Timeout! triggers in \(DurationFormatting.countdown(secondsRemaining))."
        case .breakTime:
            return "Break ends in \(DurationFormatting.countdown(secondsRemaining))."
        case .postponedForCall:
            let callLabel = postponedCallDescription ?? "a call"
            return "Delayed for \(callLabel). Retrying in \(DurationFormatting.countdown(secondsRemaining))."
        case .paused:
            return "The timer resets whenever your session is inactive or the screen sleeps."
        }
    }

    func triggerBreakNow() {
        guard !isInactive else {
            return
        }

        startBreak(from: .now)
    }

    func endBreakEarly() {
        resumeWorkCycle(from: .now)
    }

    func resetCountdown() {
        guard !isInactive else {
            return
        }

        resumeWorkCycle(from: .now)
    }

    func setMenuVisible(_ isVisible: Bool) {
        guard isMenuVisible != isVisible else {
            return
        }

        isMenuVisible = isVisible
        refreshDisplayedCountdown()
        updateCountdownRefreshTimer()
    }

    private func bindSettings() {
        settings.$workIntervalMinutes
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleCycleSettingsChange()
            }
            .store(in: &cancellables)

        settings.$breakDurationSeconds
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleCycleSettingsChange()
            }
            .store(in: &cancellables)

        settings.$launchAtLoginEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.launchAtLoginController.apply(desiredEnabled: isEnabled)
            }
            .store(in: &cancellables)

        settings.$postponeDuringCallsEnabled
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleCallSettingsChange()
            }
            .store(in: &cancellables)

        settings.$callRetryDelaySeconds
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleCallSettingsChange()
            }
            .store(in: &cancellables)

        settings.$exerciseAnimationStyle
            .dropFirst()
            .sink { [weak self] style in
                self?.handleAnimationStyleChange(style)
            }
            .store(in: &cancellables)
    }

    private func handleCycleSettingsChange() {
        guard !isInactive else {
            phase = .paused
            secondsRemaining = Int(settings.workInterval)
            return
        }

        switch phase {
        case .monitoring:
            resumeWorkCycle(from: .now)
        case .breakTime:
            startBreak(from: .now)
        case .postponedForCall:
            attemptAutomaticBreak(from: .now)
        case .paused:
            break
        }
    }

    private func handleCallSettingsChange() {
        guard !isInactive else {
            return
        }

        guard phase == .postponedForCall else {
            return
        }

        attemptAutomaticBreak(from: .now)
    }

    private func handleAnimationStyleChange(_ style: ExerciseAnimationStyle) {
        guard !isInactive, phase == .breakTime else {
            return
        }

        overlayController.updateAnimationStyle(style)
    }

    private func scheduleDeadlineTimer() {
        deadlineTimer?.invalidate()
        deadlineTimer = nil

        guard let deadline else {
            return
        }

        let interval = max(0, deadline.timeIntervalSinceNow)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleDeadlineTimer()
            }
        }
        timer.tolerance = min(max(interval * 0.02, 0.05), 0.5)
        deadlineTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateCountdownRefreshTimer() {
        let shouldRefreshCountdown = deadline != nil && (isMenuVisible || phase == .breakTime)

        guard shouldRefreshCountdown != (countdownRefreshTimer != nil) else {
            return
        }

        countdownRefreshTimer?.invalidate()
        countdownRefreshTimer = nil

        guard shouldRefreshCountdown else {
            return
        }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDisplayedCountdown()
            }
        }
        timer.tolerance = 0.1
        countdownRefreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleDeadlineTimer() {
        guard let deadline else {
            return
        }

        guard deadline <= Date() else {
            scheduleDeadlineTimer()
            return
        }

        let referenceDate = Date()
        refreshDisplayedCountdown()

        switch phase {
        case .monitoring:
            attemptAutomaticBreak(from: referenceDate)
        case .breakTime:
            resumeWorkCycle(from: referenceDate)
        case .postponedForCall:
            attemptAutomaticBreak(from: referenceDate)
        case .paused:
            break
        }
    }

    private func refreshDisplayedCountdown() {
        guard let deadline else {
            return
        }

        let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if isMenuVisible && secondsRemaining != remaining {
            secondsRemaining = remaining
        }

        if phase == .breakTime {
            overlayController.updateSubtitle("Break ends in \(DurationFormatting.countdown(remaining)).")
        }
    }

    private func resumeWorkCycle(from referenceDate: Date) {
        overlayController.hide()
        postponedCallDescription = nil
        phase = .monitoring
        deadline = referenceDate.addingTimeInterval(settings.workInterval)
        secondsRemaining = Int(settings.workInterval)
    }

    private func startBreak(from referenceDate: Date) {
        let exercise = BreakExercise.random(excluding: lastBreakExerciseID)
        lastBreakExerciseID = exercise.id

        phase = .breakTime
        deadline = referenceDate.addingTimeInterval(settings.breakDuration)
        secondsRemaining = Int(settings.breakDuration)
        overlayController.show(
            exercise: exercise,
            animationStyle: settings.exerciseAnimationStyle,
            subtitle: "Break ends in \(DurationFormatting.countdown(secondsRemaining))."
        )
    }

    private func attemptAutomaticBreak(from referenceDate: Date) {
        let detectionConfiguration = CallActivityDetector.Configuration(
            useHardwareActivityDetection: settings.useHardwareActivityDetection,
            useWindowTitleFallback: settings.useWindowTitleFallback
        )

        guard settings.postponeDuringCallsEnabled,
              let detectedCall = callActivityDetector.detectActiveCall(using: detectionConfiguration) else {
            startBreak(from: referenceDate)
            return
        }

        postponeBreak(for: detectedCall, from: referenceDate)
    }

    private func postponeBreak(for detectedCall: DetectedCall, from referenceDate: Date) {
        overlayController.hide()
        postponedCallDescription = detectedCall.displayName
        phase = .postponedForCall
        deadline = referenceDate.addingTimeInterval(settings.callRetryDelay)
        secondsRemaining = Int(settings.callRetryDelay)
    }

    private func pauseForInactivity() {
        guard !isInactive else {
            return
        }

        isInactive = true
        deadline = nil
        overlayController.hide()
        postponedCallDescription = nil
        phase = .paused
        secondsRemaining = Int(settings.workInterval)
    }

    private func resumeAfterInactivity() {
        guard isInactive else {
            return
        }

        isInactive = false
        resumeWorkCycle(from: .now)
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter

        let pauseNotifications: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]

        let resumeNotifications: [Notification.Name] = [
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification
        ]

        workspaceObservers.append(contentsOf: pauseNotifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.pauseForInactivity()
                }
            }
        })

        workspaceObservers.append(contentsOf: resumeNotifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.resumeAfterInactivity()
                }
            }
        })
    }
}
