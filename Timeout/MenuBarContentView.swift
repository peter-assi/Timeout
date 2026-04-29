import SwiftUI

struct MenuBarContentView: View {
    let model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MenuStatusView(model: model)

            Divider()

            SettingsControlsView(settings: settings)

            Toggle("Launch at login", isOn: $settings.launchAtLoginEnabled)

            if settings.postponeDuringCallsEnabled {
                Text("Hardware activity is checked first using camera and microphone usage. Visible window titles for Google Meet and Slack Huddles can stay enabled as a fallback.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            LaunchAtLoginStatusView(launchAtLoginController: launchAtLoginController)

            Divider()

            MenuActionButtons(model: model)

            Button("Quit Timeout!") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 360)
        .onAppear {
            model.setMenuVisible(true)
        }
        .onDisappear {
            model.setMenuVisible(false)
        }
    }
}

private struct MenuStatusView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Timeout!")
                .font(.title2.weight(.bold))

            Text(model.phaseTitle)
                .font(.headline)

            Text(model.phaseDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsControlsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Work interval")
                .font(.headline)

            HStack(spacing: 12) {
                Slider(value: $settings.workIntervalMinutes, in: 5...120, step: 5)

                Text(DurationFormatting.minutesLabel(settings.workIntervalMinutes))
                    .font(.body.monospacedDigit())
                    .frame(width: 64, alignment: .trailing)
            }

            Text("Break duration")
                .font(.headline)
                .padding(.top, 2)

            HStack(spacing: 12) {
                Slider(value: $settings.breakDurationSeconds, in: 10...300, step: 5)

                Text(DurationFormatting.secondsLabel(settings.breakDurationSeconds))
                    .font(.body.monospacedDigit())
                    .frame(width: 64, alignment: .trailing)
            }

            Text("Animation style")
                .font(.headline)
                .padding(.top, 2)

            Picker("Animation style", selection: $settings.exerciseAnimationStyle) {
                ForEach(ExerciseAnimationStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Delay automatic breaks during calls", isOn: $settings.postponeDuringCallsEnabled)
                .padding(.top, 2)

            Toggle("Use camera and microphone activity", isOn: $settings.useHardwareActivityDetection)
                .disabled(!settings.postponeDuringCallsEnabled)

            Toggle("Use window title fallback", isOn: $settings.useWindowTitleFallback)
                .disabled(!settings.postponeDuringCallsEnabled)

            Text("Retry delay")
                .font(.headline)
                .foregroundStyle(settings.postponeDuringCallsEnabled ? .primary : .secondary)

            HStack(spacing: 12) {
                Slider(value: $settings.callRetryDelaySeconds, in: 15...600, step: 15)
                    .disabled(!settings.postponeDuringCallsEnabled)

                Text(DurationFormatting.secondsLabel(settings.callRetryDelaySeconds))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(settings.postponeDuringCallsEnabled ? .primary : .secondary)
                    .frame(width: 64, alignment: .trailing)
            }
        }
    }
}

private struct LaunchAtLoginStatusView: View {
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(launchAtLoginController.statusDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let errorDescription = launchAtLoginController.lastErrorDescription {
                Text(errorDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct MenuActionButtons: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack {
            if model.phase == .breakTime {
                Button("End break", action: model.endBreakEarly)
            } else {
                Button("Start break now", action: model.triggerBreakNow)
            }

            Spacer()

            Button("Reset timer", action: model.resetCountdown)
                .disabled(model.phase == .paused)
        }
    }
}
