import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController {
    final class OverlayWindow: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    fileprivate final class OverlayState: ObservableObject {
        @Published var subtitle = ""
    }

    private let state = OverlayState()
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    var onEscape: (() -> Void)?

    func show(subtitle: String) {
        state.subtitle = subtitle
        ensureWindows()
        installEscapeMonitor()

        NSApp.activate(ignoringOtherApps: true)

        for window in windows where window !== preferredKeyWindow {
            window.orderFrontRegardless()
        }

        preferredKeyWindow?.makeKeyAndOrderFront(nil)
    }

    func updateSubtitle(_ subtitle: String) {
        guard !windows.isEmpty else {
            return
        }

        state.subtitle = subtitle
    }

    func hide() {
        removeEscapeMonitor()
        windows.forEach { $0.orderOut(nil) }
    }

    private var preferredKeyWindow: NSWindow? {
        windows.first(where: { $0.screen == NSScreen.main }) ?? windows.first
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
        removeEscapeMonitor()
        windows.forEach { $0.close() }
        windows = screens.map(makeWindow(for:))
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = OverlayWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
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

    private func installEscapeMonitor() {
        guard keyMonitor == nil else {
            return
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else {
                return event
            }

            self?.onEscape?()
            return nil
        }
    }

    private func removeEscapeMonitor() {
        guard let keyMonitor else {
            return
        }

        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }
}

private struct BreakOverlayView: View {
    @ObservedObject var state: BreakOverlayController.OverlayState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.09, green: 0.17, blue: 0.17), Color(red: 0.02, green: 0.06, blue: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.41, green: 0.94, blue: 0.88).opacity(0.12))
                .frame(width: 620, height: 620)
                .offset(x: 420, y: -250)

            Circle()
                .fill(Color(red: 0.41, green: 0.94, blue: 0.88).opacity(0.07))
                .frame(width: 440, height: 440)
                .offset(x: -520, y: 320)

            VStack(spacing: 22) {
                Text("Timeout!")
                    .font(font("AppleSDGothicNeo-Heavy", size: 190, fallbackWeight: .black))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.76, green: 0.98, blue: 0.96))

                Text("Step away from the keyboard and move around a bit.")
                    .font(font("AppleSDGothicNeo-Medium", size: 35, fallbackWeight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(state.subtitle)
                    .font(font("AppleSDGothicNeo-Bold", size: 28, fallbackWeight: .bold))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(48)
        }
    }

    private func font(_ name: String, size: CGFloat, fallbackWeight: NSFont.Weight) -> Font {
        let resolvedFont = NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
        return Font(resolvedFont)
    }
}
