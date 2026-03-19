import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    enum CyclePhase: Equatable {
        case monitoring
        case breakTime
        case paused
    }

    @Published private(set) var phase: CyclePhase = .monitoring
    @Published private(set) var secondsRemaining = 0

    let settings: SettingsStore
    let launchAtLoginController: LaunchAtLoginController

    private let overlayController = BreakOverlayController()
    private var deadline: Date?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isInactive = false

    init(
        settings: SettingsStore = SettingsStore(),
        launchAtLoginController: LaunchAtLoginController = LaunchAtLoginController()
    ) {
        self.settings = settings
        self.launchAtLoginController = launchAtLoginController

        bindSettings()
        installWorkspaceObservers()
        startTimer()
        launchAtLoginController.apply(desiredEnabled: settings.launchAtLoginEnabled)
        resumeWorkCycle(from: .now)
    }

    var menuBarSymbolName: String {
        switch phase {
        case .monitoring:
            return "timer"
        case .breakTime:
            return "figure.walk.circle.fill"
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

    private func bindSettings() {
        settings.$workIntervalMinutes
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)

        settings.$breakDurationSeconds
            .dropFirst()
            .sink { [weak self] _ in
                self?.handleSettingsChange()
            }
            .store(in: &cancellables)

        settings.$launchAtLoginEnabled
            .dropFirst()
            .sink { [weak self] isEnabled in
                self?.launchAtLoginController.apply(desiredEnabled: isEnabled)
            }
            .store(in: &cancellables)
    }

    private func handleSettingsChange() {
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
        case .paused:
            break
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard let deadline else {
            return
        }

        let remaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        secondsRemaining = remaining

        if phase == .breakTime {
            overlayController.updateSubtitle("Break ends in \(DurationFormatting.countdown(remaining)).")
        }

        guard remaining == 0 else {
            return
        }

        switch phase {
        case .monitoring:
            startBreak(from: .now)
        case .breakTime:
            resumeWorkCycle(from: .now)
        case .paused:
            break
        }
    }

    private func resumeWorkCycle(from referenceDate: Date) {
        overlayController.hide()
        phase = .monitoring
        deadline = referenceDate.addingTimeInterval(settings.workInterval)
        secondsRemaining = Int(settings.workInterval)
    }

    private func startBreak(from referenceDate: Date) {
        phase = .breakTime
        deadline = referenceDate.addingTimeInterval(settings.breakDuration)
        secondsRemaining = Int(settings.breakDuration)
        overlayController.show(subtitle: "Break ends in \(DurationFormatting.countdown(secondsRemaining)).")
    }

    private func pauseForInactivity() {
        guard !isInactive else {
            return
        }

        isInactive = true
        deadline = nil
        overlayController.hide()
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
