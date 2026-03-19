import Foundation

enum DurationFormatting {
    static func countdown(_ totalSeconds: Int) -> String {
        let seconds = max(totalSeconds, 0)
        let minutes = seconds / 60
        let remainder = seconds % 60
        return String(format: "%02d:%02d", minutes, remainder)
    }

    static func minutesLabel(_ minutes: Double) -> String {
        "\(Int(minutes.rounded())) min"
    }

    static func secondsLabel(_ seconds: Double) -> String {
        "\(Int(seconds.rounded())) sec"
    }
}

