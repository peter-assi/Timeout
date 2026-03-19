import AVFoundation
import CoreAudio
import CoreGraphics
import Foundation

struct DetectedCall {
    enum Kind {
        case activeCamera
        case activeCameraAndMicrophone
        case activeMicrophone
        case googleMeet
        case slackHuddle
    }

    let kind: Kind

    var displayName: String {
        switch kind {
        case .activeCamera:
            return "active camera"
        case .activeCameraAndMicrophone:
            return "active camera and microphone"
        case .activeMicrophone:
            return "active microphone"
        case .googleMeet:
            return "Google Meet"
        case .slackHuddle:
            return "Slack Huddle"
        }
    }
}

final class CallActivityDetector {
    struct Configuration {
        let useHardwareActivityDetection: Bool
        let useWindowTitleFallback: Bool
    }

    private let browserOwners: Set<String> = [
        "Arc",
        "Brave Browser",
        "Chromium",
        "Firefox",
        "Google Chrome",
        "Microsoft Edge",
        "Safari"
    ]

    func detectActiveCall(using configuration: Configuration) -> DetectedCall? {
        if configuration.useHardwareActivityDetection, let detectedHardwareActivity = detectHardwareActivity() {
            return detectedHardwareActivity
        }

        if configuration.useWindowTitleFallback, let detectedWindowTitle = detectWindowTitleActivity() {
            return detectedWindowTitle
        }

        return nil
    }

    private func detectHardwareActivity() -> DetectedCall? {
        let cameraActive = isCameraActive()
        let microphoneActive = isMicrophoneActive()

        switch (cameraActive, microphoneActive) {
        case (true, true):
            return DetectedCall(kind: .activeCameraAndMicrophone)
        case (true, false):
            return DetectedCall(kind: .activeCamera)
        case (false, true):
            return DetectedCall(kind: .activeMicrophone)
        case (false, false):
            return nil
        }
    }

    private func detectWindowTitleActivity() -> DetectedCall? {
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
                return DetectedCall(kind: .googleMeet)
            }

            if isSlackHuddle(ownerName: ownerName, windowTitle: windowTitle) {
                return DetectedCall(kind: .slackHuddle)
            }
        }

        return nil
    }

    private func isCameraActive() -> Bool {
        let deviceTypes: [AVCaptureDevice.DeviceType]

        if #available(macOS 14.0, *) {
            deviceTypes = [.builtInWideAngleCamera, .continuityCamera, .external]
        } else {
            deviceTypes = [.builtInWideAngleCamera]
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )

        return discoverySession.devices.contains(where: \.isInUseByAnotherApplication)
    }

    private func isMicrophoneActive() -> Bool {
        inputDeviceIDs().contains(where: isInputRunningSomewhere)
    }

    private func inputDeviceIDs() -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        let systemObject = AudioObjectID(kAudioObjectSystemObject)

        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(), count: deviceCount)

        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &deviceIDs) == noErr else {
            return []
        }

        return deviceIDs.filter(hasInputStreams)
    }

    private func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &address) else {
            return false
        }

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &dataSize) == noErr else {
            return false
        }

        return dataSize >= UInt32(MemoryLayout<AudioStreamID>.size)
    }

    private func isInputRunningSomewhere(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        if let isRunning = propertyValue(of: deviceID, address: &address) {
            return isRunning
        }

        address.mScope = kAudioObjectPropertyScopeGlobal
        return propertyValue(of: deviceID, address: &address) ?? false
    }

    private func propertyValue(of objectID: AudioObjectID, address: inout AudioObjectPropertyAddress) -> Bool? {
        guard AudioObjectHasProperty(objectID, &address) else {
            return nil
        }

        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, &isRunning) == noErr else {
            return nil
        }

        return isRunning == 1
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
