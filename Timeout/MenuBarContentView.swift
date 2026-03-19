import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    @ObservedObject var launchAtLoginController: LaunchAtLoginController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            Divider()

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
            }

            Toggle("Launch at login", isOn: $settings.launchAtLoginEnabled)

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

            Divider()

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

            Button("Quit Timeout!") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 340)
    }
}

