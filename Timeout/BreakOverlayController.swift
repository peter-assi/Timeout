import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController {
    fileprivate final class OverlayState: ObservableObject {
        @Published var subtitle = ""
    }

    private let state = OverlayState()
    private var windows: [NSWindow] = []

    func show(subtitle: String) {
        state.subtitle = subtitle
        ensureWindows()

        for window in windows {
            window.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func updateSubtitle(_ subtitle: String) {
        guard !windows.isEmpty else {
            return
        }

        state.subtitle = subtitle
    }

    func hide() {
        windows.forEach { $0.orderOut(nil) }
    }

    private func ensureWindows() {
        let screens = NSScreen.screens

        guard windows.count == screens.count else {
            rebuildWindows(for: screens)
            return
        }

        for (window, screen) in zip(windows, screens) where window.frame != screen.frame {
            rebuildWindows(for: screens)
            return
        }
    }

    private func rebuildWindows(for screens: [NSScreen]) {
        windows.forEach { $0.close() }
        windows = screens.map(makeWindow(for:))
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.isMovable = false
        window.isOpaque = false
        window.level = .screenSaver
        window.titleVisibility = .hidden
        window.contentView = NSHostingView(rootView: BreakOverlayView(state: state))

        return window
    }
}

private struct BreakOverlayView: View {
    @ObservedObject var state: BreakOverlayController.OverlayState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.14, blue: 0.19), Color(red: 0.04, green: 0.05, blue: 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Timeout!")
                    .font(.system(size: 108, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text("Step away from the keyboard and move around a bit.")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(state.subtitle)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(48)
        }
    }
}
