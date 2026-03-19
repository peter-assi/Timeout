import CoreGraphics
import Foundation

struct DetectedCall {
    enum Kind {
        case googleMeet
        case slackHuddle
    }

    let kind: Kind
    let appName: String
    let windowTitle: String

    var displayName: String {
        switch kind {
        case .googleMeet:
            return "Google Meet"
        case .slackHuddle:
            return "Slack Huddle"
        }
    }
}

final class CallActivityDetector {
    private let browserOwners: Set<String> = [
        "Arc",
        "Brave Browser",
        "Chromium",
        "Firefox",
        "Google Chrome",
        "Microsoft Edge",
        "Safari"
    ]

    func detectActiveCall() -> DetectedCall? {
        guard let rawWindowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        // This is intentionally heuristic: it avoids requiring Accessibility access.
        for window in rawWindowList where isUsableWindow(window) {
            let ownerName = (window[kCGWindowOwnerName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let windowTitle = (window[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !ownerName.isEmpty else {
                continue
            }

            if isGoogleMeet(ownerName: ownerName, windowTitle: windowTitle) {
                return DetectedCall(kind: .googleMeet, appName: ownerName, windowTitle: windowTitle)
            }

            if isSlackHuddle(ownerName: ownerName, windowTitle: windowTitle) {
                return DetectedCall(kind: .slackHuddle, appName: ownerName, windowTitle: windowTitle)
            }
        }

        return nil
    }

    private func isUsableWindow(_ window: [String: Any]) -> Bool {
        let layer = window[kCGWindowLayer as String] as? Int ?? 0
        let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
        return layer == 0 && alpha > 0
    }

    private func isGoogleMeet(ownerName: String, windowTitle: String) -> Bool {
        guard browserOwners.contains(ownerName) else {
            return false
        }

        let normalizedTitle = windowTitle.lowercased()

        return normalizedTitle.contains("google meet")
            || normalizedTitle.contains("meet.google.com")
            || normalizedTitle == "meet"
            || normalizedTitle.hasPrefix("meet - ")
            || normalizedTitle.hasSuffix(" - meet")
    }

    private func isSlackHuddle(ownerName: String, windowTitle: String) -> Bool {
        guard ownerName == "Slack" else {
            return false
        }

        let normalizedTitle = windowTitle.lowercased()

        return normalizedTitle.contains("huddle")
            || normalizedTitle.contains("slack call")
            || normalizedTitle.contains("calling")
    }
}
