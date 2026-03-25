import AppKit
import SwiftUI

private let pictogramFigureColor = Color(red: 0.96, green: 0.92, blue: 0.78)
private let pictogramAccentColor = Color(red: 0.99, green: 0.82, blue: 0.51)

enum ExerciseAnimationStyle: String, CaseIterable, Identifiable {
    case classic
    case human

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:
            return "Classic"
        case .human:
            return "Pictogram"
        }
    }
}

struct BreakExercise: Identifiable {
    enum FocusArea: String {
        case hands = "Hands"
        case arms = "Arms"
        case back = "Back"
    }

    enum MotionStyle {
        case wristCircles
        case fingerFan
        case prayerPress
        case shoulderRolls
        case wallAngels
        case elbowOpeners
        case scapularSqueeze
        case seatedTwist
    }

    let id: String
    let title: String
    let instruction: String
    let focusArea: FocusArea
    let motionStyle: MotionStyle
    let primaryTint: Color
    let secondaryTint: Color

    static let all: [BreakExercise] = [
        BreakExercise(
            id: "wrist-circles",
            title: "Wrist Circles",
            instruction: "Lift your hands off the desk and draw slow circles with both wrists.",
            focusArea: .hands,
            motionStyle: .wristCircles,
            primaryTint: Color(red: 0.45, green: 0.93, blue: 0.89),
            secondaryTint: Color(red: 0.61, green: 0.79, blue: 1.0)
        ),
        BreakExercise(
            id: "finger-fan",
            title: "Finger Fan",
            instruction: "Open the fingers wide, hold for a beat, then relax without clenching.",
            focusArea: .hands,
            motionStyle: .fingerFan,
            primaryTint: Color(red: 0.55, green: 0.83, blue: 1.0),
            secondaryTint: Color(red: 0.76, green: 0.97, blue: 0.95)
        ),
        BreakExercise(
            id: "prayer-press",
            title: "Prayer Press",
            instruction: "Bring the palms together at chest height and press lightly for a few breaths.",
            focusArea: .hands,
            motionStyle: .prayerPress,
            primaryTint: Color(red: 0.97, green: 0.78, blue: 0.43),
            secondaryTint: Color(red: 1.0, green: 0.56, blue: 0.41)
        ),
        BreakExercise(
            id: "shoulder-rolls",
            title: "Shoulder Rolls",
            instruction: "Roll both shoulders up, back, and down in a smooth loop.",
            focusArea: .arms,
            motionStyle: .shoulderRolls,
            primaryTint: Color(red: 0.99, green: 0.60, blue: 0.49),
            secondaryTint: Color(red: 1.0, green: 0.83, blue: 0.55)
        ),
        BreakExercise(
            id: "wall-angels",
            title: "Wall Angels",
            instruction: "Sweep the arms up and down like they are sliding along a wall.",
            focusArea: .arms,
            motionStyle: .wallAngels,
            primaryTint: Color(red: 0.54, green: 0.91, blue: 0.64),
            secondaryTint: Color(red: 0.79, green: 0.97, blue: 0.79)
        ),
        BreakExercise(
            id: "elbow-openers",
            title: "Elbow Openers",
            instruction: "Keep the elbows close to the ribs and rotate the forearms outward.",
            focusArea: .arms,
            motionStyle: .elbowOpeners,
            primaryTint: Color(red: 0.98, green: 0.69, blue: 0.44),
            secondaryTint: Color(red: 1.0, green: 0.84, blue: 0.61)
        ),
        BreakExercise(
            id: "scapular-squeeze",
            title: "Scapular Squeeze",
            instruction: "Lift the chest and gently pull the elbows back to wake up the upper back.",
            focusArea: .back,
            motionStyle: .scapularSqueeze,
            primaryTint: Color(red: 0.88, green: 0.74, blue: 0.45),
            secondaryTint: Color(red: 0.95, green: 0.91, blue: 0.64)
        ),
        BreakExercise(
            id: "seated-twist",
            title: "Seated Twist",
            instruction: "Stay tall and rotate through the upper back from side to side.",
            focusArea: .back,
            motionStyle: .seatedTwist,
            primaryTint: Color(red: 0.47, green: 0.88, blue: 0.95),
            secondaryTint: Color(red: 0.60, green: 0.76, blue: 1.0)
        )
    ]

    static func random(excluding previousExerciseID: String? = nil) -> BreakExercise {
        let candidates = all.filter { $0.id != previousExerciseID }
        return candidates.randomElement() ?? all[0]
    }
}

struct BreakOverlayContent {
    let exercise: BreakExercise
    let animationStyle: ExerciseAnimationStyle
    var subtitle: String

    static let preview = BreakOverlayContent(
        exercise: BreakExercise.all[0],
        animationStyle: .classic,
        subtitle: "Break ends in 00:30."
    )
}

@MainActor
final class BreakOverlayController {
    final class OverlayWindow: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    fileprivate final class OverlayState: ObservableObject {
        @Published var content = BreakOverlayContent.preview
    }

    private let state = OverlayState()
    private var windows: [NSWindow] = []
    private var keyMonitor: Any?
    var onEscape: (() -> Void)?

    func show(exercise: BreakExercise, animationStyle: ExerciseAnimationStyle, subtitle: String) {
        state.content = BreakOverlayContent(
            exercise: exercise,
            animationStyle: animationStyle,
            subtitle: subtitle
        )
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

        state.content.subtitle = subtitle
    }

    func updateAnimationStyle(_ animationStyle: ExerciseAnimationStyle) {
        guard !windows.isEmpty else {
            return
        }

        state.content = BreakOverlayContent(
            exercise: state.content.exercise,
            animationStyle: animationStyle,
            subtitle: state.content.subtitle
        )
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

struct BreakOverlayScreen: View {
    let content: BreakOverlayContent

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                overlayBackground

                switch content.animationStyle {
                case .classic:
                    classicLayout(size: proxy.size)
                case .human:
                    pictogramLayout(size: proxy.size)
                }
            }
        }
    }

    private var overlayBackground: some View {
        LinearGradient(
            colors: [Color(red: 0.12, green: 0.14, blue: 0.19), Color(red: 0.04, green: 0.05, blue: 0.07)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func classicLayout(size: CGSize) -> some View {
        let titleSize = min(max(size.height * 0.14, 112), 156)
        let focusSize = min(max(size.height * 0.018, 16), 20)
        let exerciseTitleSize = min(max(size.height * 0.05, 40), 58)
        let instructionSize = min(max(size.height * 0.03, 24), 32)
        let subtitleSize = min(max(size.height * 0.026, 20), 28)
        let stageWidth = min(size.width * 0.66, 920)
        let stageHeight = min(size.height * 0.34, 360)

        VStack(spacing: 22) {
            Spacer(minLength: 8)

            Text("Timeout!")
                .font(overlayFont("AppleSDGothicNeo-Heavy", size: titleSize, fallbackWeight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)

            Text(content.exercise.focusArea.rawValue.uppercased())
                .font(overlayFont("AppleSDGothicNeo-Bold", size: focusSize, fallbackWeight: .bold))
                .kerning(3)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Capsule().fill(content.exercise.primaryTint.opacity(0.18)))
                .overlay(
                    Capsule()
                        .stroke(content.exercise.primaryTint.opacity(0.42), lineWidth: 1)
                )
                .foregroundStyle(content.exercise.primaryTint)

            VStack(spacing: 10) {
                Text(content.exercise.title)
                    .font(overlayFont("AppleSDGothicNeo-Heavy", size: exerciseTitleSize, fallbackWeight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)

                Text(content.exercise.instruction)
                    .font(overlayFont("AppleSDGothicNeo-Medium", size: instructionSize, fallbackWeight: .medium))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: min(size.width * 0.72, 960))
            }

            ExerciseMotionCard(
                exercise: content.exercise,
                animationStyle: content.animationStyle
            )
            .frame(width: stageWidth, height: stageHeight)

            Text(content.subtitle)
                .font(overlayFont("AppleSDGothicNeo-Bold", size: subtitleSize, fallbackWeight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Spacer(minLength: 10)
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func pictogramLayout(size: CGSize) -> some View {
        let titleSize = min(max(size.height * 0.18, 144), 196)
        let labelSize = min(max(size.height * 0.018, 18), 22)
        let exerciseTitleSize = min(max(size.height * 0.046, 40), 56)
        let instructionSize = min(max(size.height * 0.026, 22), 30)
        let subtitleSize = min(max(size.height * 0.024, 18), 24)
        let stageWidth = min(size.width * 0.44, 520)
        let stageHeight = min(size.height * 0.29, 320)

        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Text("Timeout!")
                .font(overlayFont("AppleSDGothicNeo-Heavy", size: titleSize, fallbackWeight: .black))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)

            Text("PICTOGRAM")
                .font(overlayFont("AppleSDGothicNeo-Bold", size: labelSize, fallbackWeight: .bold))
                .foregroundStyle(pictogramAccentColor)
                .kerning(1)

            VStack(spacing: 8) {
                Text(content.exercise.title)
                    .font(overlayFont("AppleSDGothicNeo-Heavy", size: exerciseTitleSize, fallbackWeight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)

                Text(content.exercise.instruction)
                    .font(overlayFont("AppleSDGothicNeo-Medium", size: instructionSize, fallbackWeight: .medium))
                    .foregroundStyle(Color.white.opacity(0.80))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .frame(maxWidth: min(size.width * 0.60, 760))
            }

            ExerciseMotionCard(
                exercise: content.exercise,
                animationStyle: content.animationStyle
            )
            .frame(width: stageWidth, height: stageHeight)

            Text(content.subtitle)
                .font(overlayFont("AppleSDGothicNeo-Bold", size: subtitleSize, fallbackWeight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 72)
        .padding(.vertical, 42)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct BreakOverlayView: View {
    @ObservedObject var state: BreakOverlayController.OverlayState

    var body: some View {
        BreakOverlayScreen(content: state.content)
    }
}

private struct ExerciseMotionCard: View {
    let exercise: BreakExercise
    let animationStyle: ExerciseAnimationStyle

    var body: some View {
        ZStack {
            switch animationStyle {
            case .classic:
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(Color.white.opacity(0.05))

                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)

                ExerciseMotionView(exercise: exercise, animationStyle: animationStyle)
                    .padding(26)
            case .human:
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(0.98))

                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.black.opacity(0.98), lineWidth: 1)

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [8, 12]))
                    .padding(22)

                ExerciseMotionView(exercise: exercise, animationStyle: animationStyle)
                    .padding(20)
            }
        }
    }
}

private struct ExerciseMotionView: View {
    let exercise: BreakExercise
    let animationStyle: ExerciseAnimationStyle

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let size = proxy.size
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    if animationStyle == .classic {
                        ExerciseBackdrop(primaryTint: exercise.primaryTint)
                    }

                    illustration(size: size, time: time)
                }
                .frame(width: size.width, height: size.height)
            }
        }
    }

    @ViewBuilder
    private func illustration(size: CGSize, time: TimeInterval) -> some View {
        switch animationStyle {
        case .classic:
            classicIllustration(size: size, time: time)
        case .human:
            humanIllustration(size: size, time: time)
        }
    }

    @ViewBuilder
    private func classicIllustration(size: CGSize, time: TimeInterval) -> some View {
        switch exercise.motionStyle {
        case .wristCircles:
            wristCircles(size: size, time: time)
        case .fingerFan:
            fingerFan(size: size, time: time)
        case .prayerPress:
            prayerPress(size: size, time: time)
        case .shoulderRolls:
            shoulderRolls(size: size, time: time)
        case .wallAngels:
            wallAngels(size: size, time: time)
        case .elbowOpeners:
            elbowOpeners(size: size, time: time)
        case .scapularSqueeze:
            scapularSqueeze(size: size, time: time)
        case .seatedTwist:
            seatedTwist(size: size, time: time)
        }
    }

    private func wristCircles(size: CGSize, time: TimeInterval) -> some View {
        let angle = CGFloat(time * 1.7)
        let orbitRadius: CGFloat = min(size.width, size.height) * 0.07
        let leftBase = point(0.31, 0.46, in: size)
        let rightBase = point(0.69, 0.46, in: size)
        let leftElbow = point(0.42, 0.76, in: size)
        let rightElbow = point(0.58, 0.76, in: size)
        let leftHand = CGPoint(x: leftBase.x + cos(angle) * orbitRadius, y: leftBase.y + sin(angle) * orbitRadius)
        let rightHand = CGPoint(x: rightBase.x - cos(angle) * orbitRadius, y: rightBase.y + sin(angle) * orbitRadius)

        return ZStack {
            MotionRing(center: leftBase, diameter: orbitRadius * 2.6, color: exercise.primaryTint)
            MotionRing(center: rightBase, diameter: orbitRadius * 2.6, color: exercise.primaryTint)

            SegmentView(start: leftElbow, end: leftHand, color: Color.white.opacity(0.76), thickness: 24)
            SegmentView(start: rightElbow, end: rightHand, color: Color.white.opacity(0.76), thickness: 24)

            JointView(center: leftElbow, diameter: 18, color: exercise.secondaryTint)
            JointView(center: rightElbow, diameter: 18, color: exercise.secondaryTint)

            HandGlyph(center: leftHand, angle: .radians(Double(angle) + 0.4), color: exercise.primaryTint)
            HandGlyph(center: rightHand, angle: .radians(-Double(angle) - 0.4), color: exercise.primaryTint)

            SymbolMarker(name: "arrow.clockwise", center: point(0.21, 0.28, in: size), size: 28, color: exercise.primaryTint)
            SymbolMarker(name: "arrow.counterclockwise", center: point(0.79, 0.28, in: size), size: 28, color: exercise.primaryTint)
        }
    }

    private func fingerFan(size: CGSize, time: TimeInterval) -> some View {
        let spread = mix(0.18, 0.34, pulse(time, speed: 1.8))
        let leftPalm = point(0.33, 0.66, in: size)
        let rightPalm = point(0.67, 0.66, in: size)

        return ZStack {
            PalmGlyph(center: leftPalm, angle: .degrees(-12), color: exercise.primaryTint)
            PalmGlyph(center: rightPalm, angle: .degrees(12), color: exercise.primaryTint)

            ForEach(-2...2, id: \.self) { index in
                let factor = CGFloat(index)
                let leftStart = CGPoint(x: leftPalm.x + factor * 7, y: leftPalm.y - 48)
                let leftEnd = translated(
                    leftStart,
                    by: vector(length: 58 - CGFloat(abs(index)) * 4, angle: -.pi / 2 + factor * spread - 0.08)
                )
                let rightStart = CGPoint(x: rightPalm.x - factor * 7, y: rightPalm.y - 48)
                let rightEnd = translated(
                    rightStart,
                    by: vector(length: 58 - CGFloat(abs(index)) * 4, angle: -.pi / 2 - factor * spread + 0.08)
                )

                SegmentView(start: leftStart, end: leftEnd, color: Color.white.opacity(0.82), thickness: 11)
                SegmentView(start: rightStart, end: rightEnd, color: Color.white.opacity(0.82), thickness: 11)
            }

            SegmentView(
                start: CGPoint(x: leftPalm.x - 24, y: leftPalm.y - 8),
                end: CGPoint(x: leftPalm.x - 58, y: leftPalm.y - 22),
                color: Color.white.opacity(0.82),
                thickness: 11
            )
            SegmentView(
                start: CGPoint(x: rightPalm.x + 24, y: rightPalm.y - 8),
                end: CGPoint(x: rightPalm.x + 58, y: rightPalm.y - 22),
                color: Color.white.opacity(0.82),
                thickness: 11
            )

        }
    }

    private func prayerPress(size: CGSize, time: TimeInterval) -> some View {
        let press = pulse(time, speed: 1.4)
        let palmOffset = mix(64, 24, press)
        let center = point(0.50, 0.54, in: size)
        let leftPalm = CGPoint(x: center.x - palmOffset, y: center.y)
        let rightPalm = CGPoint(x: center.x + palmOffset, y: center.y)
        let leftElbow = point(0.33, 0.78, in: size)
        let rightElbow = point(0.67, 0.78, in: size)

        return ZStack {
            CapsuleMarker(center: leftPalm, width: 42, height: 126, angle: .degrees(-5), color: Color.white.opacity(0.86))
            CapsuleMarker(center: rightPalm, width: 42, height: 126, angle: .degrees(5), color: Color.white.opacity(0.86))

            SegmentView(
                start: leftElbow,
                end: CGPoint(x: leftPalm.x - 8, y: leftPalm.y + 54),
                color: exercise.secondaryTint.opacity(0.82),
                thickness: 20
            )
            SegmentView(
                start: rightElbow,
                end: CGPoint(x: rightPalm.x + 8, y: rightPalm.y + 54),
                color: exercise.secondaryTint.opacity(0.82),
                thickness: 20
            )

            SymbolMarker(name: "arrow.left.and.right.circle.fill", center: point(0.50, 0.24, in: size), size: 34, color: exercise.primaryTint)
        }
    }

    private func shoulderRolls(size: CGSize, time: TimeInterval) -> some View {
        let roll = CGFloat(time * 1.5)
        let leftBase = point(0.43, 0.34, in: size)
        let rightBase = point(0.57, 0.34, in: size)
        let shoulderOffset = CGPoint(x: cos(roll) * 10, y: sin(roll) * 16)
        let leftShoulder = CGPoint(x: leftBase.x + shoulderOffset.x, y: leftBase.y + shoulderOffset.y)
        let rightShoulder = CGPoint(x: rightBase.x - shoulderOffset.x, y: rightBase.y + shoulderOffset.y)
        let neck = point(0.50, 0.28, in: size)
        let waist = point(0.50, 0.74, in: size)

        return ZStack {
            MotionRing(center: leftBase, diameter: 64, color: exercise.primaryTint)
            MotionRing(center: rightBase, diameter: 64, color: exercise.primaryTint)

            SegmentView(start: neck, end: waist, color: Color.white.opacity(0.78), thickness: 28)
            SegmentView(start: leftShoulder, end: CGPoint(x: leftShoulder.x - 34, y: leftShoulder.y + 88), color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: rightShoulder, end: CGPoint(x: rightShoulder.x + 34, y: rightShoulder.y + 88), color: exercise.secondaryTint.opacity(0.84), thickness: 20)

            JointView(center: leftShoulder, diameter: 28, color: exercise.primaryTint)
            JointView(center: rightShoulder, diameter: 28, color: exercise.primaryTint)
            JointView(center: neck, diameter: 44, color: Color.white.opacity(0.94))

            SymbolMarker(name: "arrow.clockwise.circle.fill", center: point(0.30, 0.22, in: size), size: 30, color: exercise.primaryTint)
            SymbolMarker(name: "arrow.clockwise.circle.fill", center: point(0.70, 0.22, in: size), size: 30, color: exercise.primaryTint)
        }
    }

    private func wallAngels(size: CGSize, time: TimeInterval) -> some View {
        let sweep = pulse(time, speed: 1.15)
        let neck = point(0.50, 0.28, in: size)
        let waist = point(0.50, 0.74, in: size)
        let leftShoulder = point(0.43, 0.38, in: size)
        let rightShoulder = point(0.57, 0.38, in: size)
        let leftElbow = point(mix(0.37, 0.28, sweep), mix(0.58, 0.40, sweep), in: size)
        let rightElbow = point(1 - mix(0.37, 0.28, sweep), mix(0.58, 0.40, sweep), in: size)
        let leftWrist = point(mix(0.31, 0.20, sweep), mix(0.74, 0.20, sweep), in: size)
        let rightWrist = point(1 - mix(0.31, 0.20, sweep), mix(0.74, 0.20, sweep), in: size)

        return ZStack {
            Capsule()
                .fill(Color.white.opacity(0.08))
                .frame(width: 14, height: size.height * 0.72)
                .position(x: size.width * 0.50, y: size.height * 0.52)

            SegmentView(start: neck, end: waist, color: Color.white.opacity(0.78), thickness: 28)
            SegmentView(start: leftShoulder, end: leftElbow, color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: rightShoulder, end: rightElbow, color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: leftElbow, end: leftWrist, color: exercise.primaryTint.opacity(0.92), thickness: 18)
            SegmentView(start: rightElbow, end: rightWrist, color: exercise.primaryTint.opacity(0.92), thickness: 18)

            JointView(center: neck, diameter: 44, color: Color.white.opacity(0.94))
            JointView(center: leftShoulder, diameter: 22, color: exercise.secondaryTint)
            JointView(center: rightShoulder, diameter: 22, color: exercise.secondaryTint)

            SymbolMarker(name: "arrow.up.and.down.circle.fill", center: point(0.14, 0.28, in: size), size: 30, color: exercise.primaryTint)
        }
    }

    private func elbowOpeners(size: CGSize, time: TimeInterval) -> some View {
        let open = pulse(time, speed: 1.35)
        let neck = point(0.50, 0.30, in: size)
        let waist = point(0.50, 0.74, in: size)
        let leftShoulder = point(0.44, 0.40, in: size)
        let rightShoulder = point(0.56, 0.40, in: size)
        let leftElbow = point(0.42, 0.61, in: size)
        let rightElbow = point(0.58, 0.61, in: size)
        let leftWrist = point(mix(0.50, 0.32, open), mix(0.48, 0.43, open), in: size)
        let rightWrist = point(1 - mix(0.50, 0.32, open), mix(0.48, 0.43, open), in: size)

        return ZStack {
            SegmentView(start: neck, end: waist, color: Color.white.opacity(0.78), thickness: 28)
            SegmentView(start: leftShoulder, end: leftElbow, color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: rightShoulder, end: rightElbow, color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: leftElbow, end: leftWrist, color: exercise.primaryTint.opacity(0.92), thickness: 18)
            SegmentView(start: rightElbow, end: rightWrist, color: exercise.primaryTint.opacity(0.92), thickness: 18)

            JointView(center: neck, diameter: 44, color: Color.white.opacity(0.94))
            JointView(center: leftElbow, diameter: 18, color: exercise.primaryTint)
            JointView(center: rightElbow, diameter: 18, color: exercise.primaryTint)

            SymbolMarker(name: "arrow.turn.up.left", center: point(0.25, 0.30, in: size), size: 30, color: exercise.primaryTint)
            SymbolMarker(name: "arrow.turn.up.right", center: point(0.75, 0.30, in: size), size: 30, color: exercise.primaryTint)
        }
    }

    private func scapularSqueeze(size: CGSize, time: TimeInterval) -> some View {
        let squeeze = pulse(time, speed: 1.3)
        let neck = point(0.50, 0.28, in: size)
        let waist = point(0.50, 0.72, in: size)
        let chestCenter = point(0.50, 0.50, in: size)
        let leftShoulder = point(mix(0.43, 0.40, squeeze), mix(0.38, 0.36, squeeze), in: size)
        let rightShoulder = point(1 - mix(0.43, 0.40, squeeze), mix(0.38, 0.36, squeeze), in: size)
        let leftElbow = point(mix(0.39, 0.30, squeeze), mix(0.58, 0.52, squeeze), in: size)
        let rightElbow = point(1 - mix(0.39, 0.30, squeeze), mix(0.58, 0.52, squeeze), in: size)
        let leftWrist = point(mix(0.45, 0.35, squeeze), mix(0.49, 0.44, squeeze), in: size)
        let rightWrist = point(1 - mix(0.45, 0.35, squeeze), mix(0.49, 0.44, squeeze), in: size)

        return ZStack {
            Capsule()
                .fill(Color.white.opacity(0.14))
                .frame(width: mix(94, 122, squeeze), height: 136)
                .position(chestCenter)

            SegmentView(start: neck, end: waist, color: Color.white.opacity(0.78), thickness: 28)
            SegmentView(start: leftShoulder, end: leftElbow, color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: rightShoulder, end: rightElbow, color: exercise.secondaryTint.opacity(0.84), thickness: 20)
            SegmentView(start: leftElbow, end: leftWrist, color: exercise.primaryTint.opacity(0.92), thickness: 18)
            SegmentView(start: rightElbow, end: rightWrist, color: exercise.primaryTint.opacity(0.92), thickness: 18)

            JointView(center: neck, diameter: 44, color: Color.white.opacity(0.94))
            SymbolMarker(name: "arrow.left.and.right", center: point(0.50, 0.24, in: size), size: 34, color: exercise.primaryTint)
        }
    }

    private func seatedTwist(size: CGSize, time: TimeInterval) -> some View {
        let twist = Angle(radians: sin(time * 1.1) * 0.28)

        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 150, height: 20)
                .position(x: size.width * 0.50, y: size.height * 0.84)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 22, height: 96)
                .position(x: size.width * 0.50, y: size.height * 0.71)

            TwistFigure(primaryTint: exercise.primaryTint, secondaryTint: exercise.secondaryTint)
                .frame(width: min(size.width * 0.34, 230), height: min(size.height * 0.72, 250))
                .rotationEffect(twist, anchor: .bottom)
                .position(x: size.width * 0.50, y: size.height * 0.67)

            SymbolMarker(name: "arrow.uturn.left.circle.fill", center: point(0.24, 0.26, in: size), size: 32, color: exercise.primaryTint)
            SymbolMarker(name: "arrow.uturn.right.circle.fill", center: point(0.76, 0.26, in: size), size: 32, color: exercise.primaryTint)
        }
    }

    @ViewBuilder
    private func humanIllustration(size: CGSize, time: TimeInterval) -> some View {
        switch exercise.motionStyle {
        case .wristCircles:
            humanWristCircles(size: size, time: time)
        case .fingerFan:
            humanFingerFan(size: size, time: time)
        case .prayerPress:
            humanPrayerPress(size: size, time: time)
        case .shoulderRolls:
            humanShoulderRolls(size: size, time: time)
        case .wallAngels:
            humanWallAngels(size: size, time: time)
        case .elbowOpeners:
            humanElbowOpeners(size: size, time: time)
        case .scapularSqueeze:
            humanScapularSqueeze(size: size, time: time)
        case .seatedTwist:
            humanSeatedTwist(size: size, time: time)
        }
    }

    private func humanWristCircles(size: CGSize, time: TimeInterval) -> some View {
        let orbit = CGFloat(time * 1.6)
        let orbitRadius: CGFloat = min(size.width, size.height) * 0.048
        let neck = point(0.50, 0.17, in: size)
        let waist = point(0.50, 0.57, in: size)
        let leftShoulder = point(0.44, 0.30, in: size)
        let rightShoulder = point(0.56, 0.30, in: size)
        let leftElbow = point(0.42, 0.46, in: size)
        let rightElbow = point(0.58, 0.46, in: size)
        let leftWristBase = point(0.40, 0.35, in: size)
        let rightWristBase = point(0.60, 0.35, in: size)
        let leftWrist = CGPoint(x: leftWristBase.x + cos(orbit) * orbitRadius, y: leftWristBase.y + sin(orbit) * orbitRadius)
        let rightWrist = CGPoint(x: rightWristBase.x - cos(orbit) * orbitRadius, y: rightWristBase.y + sin(orbit) * orbitRadius)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: leftWrist,
                rightWrist: rightWrist,
                footSpreadScale: 0.90
            )

            CurvedArrowMarker(center: leftWristBase, radius: orbitRadius * 1.55, startDegrees: 220, endDegrees: 20, lineWidth: 4)
            CurvedArrowMarker(center: rightWristBase, radius: orbitRadius * 1.55, startDegrees: 160, endDegrees: -40, lineWidth: 4)
        }
    }

    private func humanFingerFan(size: CGSize, time: TimeInterval) -> some View {
        let spread = mix(0.10, 0.24, pulse(time, speed: 1.9))
        let neck = point(0.50, 0.17, in: size)
        let waist = point(0.50, 0.57, in: size)
        let leftShoulder = point(0.44, 0.30, in: size)
        let rightShoulder = point(0.56, 0.30, in: size)
        let leftElbow = point(0.43, 0.46, in: size)
        let rightElbow = point(0.57, 0.46, in: size)
        let leftPalm = point(0.44, 0.34, in: size)
        let rightPalm = point(0.56, 0.34, in: size)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: CGPoint(x: leftPalm.x, y: leftPalm.y + 8),
                rightWrist: CGPoint(x: rightPalm.x, y: rightPalm.y + 8),
                torsoWidthScale: 0.94,
                footSpreadScale: 0.90,
                showsHands: false
            )

            fanPalm(center: leftPalm, mirrored: false, spread: spread)
            fanPalm(center: rightPalm, mirrored: true, spread: spread)
        }
    }

    private func humanPrayerPress(size: CGSize, time: TimeInterval) -> some View {
        let press = pulse(time, speed: 1.4)
        let palmOffset = mix(18, 8, press)
        let neck = point(0.50, 0.17, in: size)
        let waist = point(0.50, 0.57, in: size)
        let leftShoulder = point(0.44, 0.30, in: size)
        let rightShoulder = point(0.56, 0.30, in: size)
        let leftElbow = point(0.45, 0.48, in: size)
        let rightElbow = point(0.55, 0.48, in: size)
        let center = point(0.50, 0.38, in: size)
        let leftPalm = CGPoint(x: center.x - palmOffset, y: center.y)
        let rightPalm = CGPoint(x: center.x + palmOffset, y: center.y)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: CGPoint(x: leftPalm.x - 6, y: leftPalm.y + 26),
                rightWrist: CGPoint(x: rightPalm.x + 6, y: rightPalm.y + 26),
                footSpreadScale: 0.90,
                showsHands: false
            )

            CapsuleMarker(center: leftPalm, width: 20, height: 70, angle: .degrees(-2), color: pictogramFigureColor)
            CapsuleMarker(center: rightPalm, width: 20, height: 70, angle: .degrees(2), color: pictogramFigureColor)

            ArrowLineMarker(
                start: CGPoint(x: center.x - 62, y: center.y),
                end: CGPoint(x: center.x - 26, y: center.y),
                lineWidth: 4
            )
            ArrowLineMarker(
                start: CGPoint(x: center.x + 62, y: center.y),
                end: CGPoint(x: center.x + 26, y: center.y),
                lineWidth: 4
            )
        }
    }

    private func humanShoulderRolls(size: CGSize, time: TimeInterval) -> some View {
        let roll = CGFloat(time * 1.5)
        let neck = point(0.50, 0.16, in: size)
        let waist = point(0.50, 0.56, in: size)
        let leftBase = point(0.44, 0.28, in: size)
        let rightBase = point(0.56, 0.28, in: size)
        let offset = CGPoint(x: cos(roll) * 8, y: sin(roll) * 14)
        let leftShoulder = CGPoint(x: leftBase.x + offset.x, y: leftBase.y + offset.y)
        let rightShoulder = CGPoint(x: rightBase.x - offset.x, y: rightBase.y + offset.y)
        let leftElbow = point(0.35, 0.42, in: size)
        let rightElbow = point(0.65, 0.42, in: size)
        let leftWrist = point(0.37, 0.56, in: size)
        let rightWrist = point(0.63, 0.56, in: size)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: leftWrist,
                rightWrist: rightWrist,
                torsoWidthScale: 1.06,
                footSpreadScale: 1.08
            )

            CurvedArrowMarker(center: CGPoint(x: leftBase.x - 18, y: leftBase.y + 10), radius: 34, startDegrees: 220, endDegrees: 30, lineWidth: 4)
            CurvedArrowMarker(center: CGPoint(x: rightBase.x + 18, y: rightBase.y + 10), radius: 34, startDegrees: 150, endDegrees: -40, lineWidth: 4)
        }
    }

    private func humanWallAngels(size: CGSize, time: TimeInterval) -> some View {
        let sweep = pulse(time, speed: 1.15)
        let neck = point(0.50, 0.17, in: size)
        let waist = point(0.50, 0.57, in: size)
        let leftShoulder = point(0.44, 0.30, in: size)
        let rightShoulder = point(0.56, 0.30, in: size)
        let leftElbow = point(mix(0.40, 0.30, sweep), mix(0.44, 0.27, sweep), in: size)
        let rightElbow = point(1 - mix(0.40, 0.30, sweep), mix(0.44, 0.27, sweep), in: size)
        let leftWrist = point(mix(0.35, 0.22, sweep), mix(0.56, 0.15, sweep), in: size)
        let rightWrist = point(1 - mix(0.35, 0.22, sweep), mix(0.56, 0.15, sweep), in: size)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: leftWrist,
                rightWrist: rightWrist,
                torsoWidthScale: 0.96,
                footSpreadScale: 0.92
            )

            ArrowLineMarker(start: point(0.14, 0.58, in: size), end: point(0.14, 0.16, in: size), lineWidth: 4)
            ArrowLineMarker(start: point(0.86, 0.16, in: size), end: point(0.86, 0.58, in: size), lineWidth: 4)
        }
    }

    private func humanElbowOpeners(size: CGSize, time: TimeInterval) -> some View {
        let open = pulse(time, speed: 1.35)
        let neck = point(0.50, 0.17, in: size)
        let waist = point(0.50, 0.57, in: size)
        let leftShoulder = point(0.44, 0.30, in: size)
        let rightShoulder = point(0.56, 0.30, in: size)
        let leftElbow = point(0.44, 0.44, in: size)
        let rightElbow = point(0.56, 0.44, in: size)
        let leftWrist = point(mix(0.49, 0.32, open), mix(0.33, 0.30, open), in: size)
        let rightWrist = point(1 - mix(0.49, 0.32, open), mix(0.33, 0.30, open), in: size)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: leftWrist,
                rightWrist: rightWrist,
                torsoWidthScale: 0.98,
                footSpreadScale: 0.92
            )

            CurvedArrowMarker(center: CGPoint(x: leftElbow.x - 18, y: leftElbow.y - 8), radius: 24, startDegrees: 245, endDegrees: 55, lineWidth: 4)
            CurvedArrowMarker(center: CGPoint(x: rightElbow.x + 18, y: rightElbow.y - 8), radius: 24, startDegrees: 125, endDegrees: -65, lineWidth: 4)
        }
    }

    private func humanScapularSqueeze(size: CGSize, time: TimeInterval) -> some View {
        let squeeze = pulse(time, speed: 1.3)
        let neck = point(0.50, 0.17, in: size)
        let waist = point(0.50, 0.57, in: size)
        let leftShoulder = point(mix(0.44, 0.41, squeeze), mix(0.30, 0.28, squeeze), in: size)
        let rightShoulder = point(1 - mix(0.44, 0.41, squeeze), mix(0.30, 0.28, squeeze), in: size)
        let leftElbow = point(mix(0.42, 0.34, squeeze), mix(0.43, 0.38, squeeze), in: size)
        let rightElbow = point(1 - mix(0.42, 0.34, squeeze), mix(0.43, 0.38, squeeze), in: size)
        let leftWrist = point(mix(0.46, 0.37, squeeze), mix(0.35, 0.30, squeeze), in: size)
        let rightWrist = point(1 - mix(0.46, 0.37, squeeze), mix(0.35, 0.30, squeeze), in: size)

        return ZStack {
            StandingPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: leftWrist,
                rightWrist: rightWrist,
                torsoWidthScale: 1.03,
                footSpreadScale: 1.02
            )

            ArrowLineMarker(start: point(0.38, 0.24, in: size), end: point(0.46, 0.24, in: size), lineWidth: 4)
            ArrowLineMarker(start: point(0.62, 0.24, in: size), end: point(0.54, 0.24, in: size), lineWidth: 4)
        }
    }

    private func humanSeatedTwist(size: CGSize, time: TimeInterval) -> some View {
        let twist = CGFloat(sin(time * 1.1) * 0.28)
        let waist = point(0.50, 0.50, in: size)
        let neck = rotate(point(0.50, 0.17, in: size), around: waist, by: twist)
        let leftShoulder = rotate(point(0.44, 0.29, in: size), around: waist, by: twist)
        let rightShoulder = rotate(point(0.56, 0.29, in: size), around: waist, by: twist)
        let leftElbow = rotate(point(0.42, 0.41, in: size), around: waist, by: twist)
        let rightElbow = rotate(point(0.60, 0.45, in: size), around: waist, by: twist)
        let leftWrist = rotate(point(0.56, 0.42, in: size), around: waist, by: twist)
        let rightWrist = rotate(point(0.44, 0.50, in: size), around: waist, by: twist)

        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(pictogramFigureColor.opacity(0.14))
                .frame(width: 138, height: 18)
                .position(x: size.width * 0.50, y: size.height * 0.76)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(pictogramFigureColor.opacity(0.14))
                .frame(width: 18, height: 78)
                .position(x: size.width * 0.50, y: size.height * 0.65)

            SeatedPictogramFigure(
                neck: neck,
                waist: waist,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftElbow: leftElbow,
                rightElbow: rightElbow,
                leftWrist: leftWrist,
                rightWrist: rightWrist
            )

            CurvedArrowMarker(center: point(0.30, 0.23, in: size), radius: 26, startDegrees: 260, endDegrees: 60, lineWidth: 4)
            CurvedArrowMarker(center: point(0.70, 0.23, in: size), radius: 26, startDegrees: 120, endDegrees: -80, lineWidth: 4)
        }
    }

    private func fanPalm(center: CGPoint, mirrored: Bool, spread: CGFloat) -> some View {
        let direction: CGFloat = mirrored ? -1 : 1

        return ZStack {
            PalmGlyph(
                center: center,
                angle: .degrees(mirrored ? 10 : -10),
                color: pictogramFigureColor,
                scale: 0.62
            )

            ForEach(-2...2, id: \.self) { index in
                let factor = CGFloat(index)
                let start = CGPoint(
                    x: center.x + (mirrored ? -factor : factor) * 5,
                    y: center.y - 34
                )
                let end = translated(
                    start,
                    by: vector(
                        length: 34 - CGFloat(abs(index)) * 3,
                        angle: -.pi / 2 + direction * factor * spread + (mirrored ? 0.05 : -0.05)
                    )
                )

                SegmentView(start: start, end: end, color: pictogramAccentColor.opacity(0.92), thickness: 6)
            }

            SegmentView(
                start: CGPoint(x: center.x + (mirrored ? 16 : -16), y: center.y - 4),
                end: CGPoint(x: center.x + (mirrored ? 34 : -34), y: center.y - 16),
                color: pictogramAccentColor.opacity(0.92),
                thickness: 6
            )
        }
    }
}

private struct StandingPictogramFigure: View {
    let neck: CGPoint
    let waist: CGPoint
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let leftElbow: CGPoint
    let rightElbow: CGPoint
    let leftWrist: CGPoint
    let rightWrist: CGPoint
    var torsoWidthScale: CGFloat = 1
    var footSpreadScale: CGFloat = 1
    var showsHands: Bool = true

    var body: some View {
        let shoulderDistance = max(distance(leftShoulder, rightShoulder), 48)
        let chest = midpoint(leftShoulder, rightShoulder)
        let neckBase = CGPoint(x: neck.x, y: neck.y + shoulderDistance * 0.16)
        let hipOffset = shoulderDistance * 0.24
        let leftHip = CGPoint(x: waist.x - hipOffset, y: waist.y)
        let rightHip = CGPoint(x: waist.x + hipOffset, y: waist.y)
        let upperLegLength = shoulderDistance * 0.70
        let lowerLegLength = shoulderDistance * 0.68
        let kneeLift = shoulderDistance * 0.06
        let leftKnee = CGPoint(x: waist.x - hipOffset * 0.78, y: waist.y + upperLegLength - kneeLift)
        let rightKnee = CGPoint(x: waist.x + hipOffset * 0.78, y: waist.y + upperLegLength - kneeLift)
        let footSpread = hipOffset * 1.18 * footSpreadScale
        let leftFoot = CGPoint(x: waist.x - footSpread, y: leftKnee.y + lowerLegLength)
        let rightFoot = CGPoint(x: waist.x + footSpread, y: rightKnee.y + lowerLegLength)

        return ZStack {
            Ellipse()
                .fill(pictogramFigureColor)
                .frame(width: shoulderDistance * 0.48, height: shoulderDistance * 0.66)
                .position(neck)

            SegmentView(start: neckBase, end: chest, color: pictogramFigureColor, thickness: shoulderDistance * 0.15)

            PictogramTorsoShape(
                chest: chest,
                pelvis: waist,
                chestWidth: shoulderDistance * 0.92 * torsoWidthScale,
                waistWidth: shoulderDistance * 0.56
            )
            .fill(pictogramFigureColor)

            SegmentView(start: leftShoulder, end: leftElbow, color: pictogramFigureColor, thickness: shoulderDistance * 0.17)
            SegmentView(start: rightShoulder, end: rightElbow, color: pictogramFigureColor, thickness: shoulderDistance * 0.17)
            SegmentView(start: leftElbow, end: leftWrist, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)
            SegmentView(start: rightElbow, end: rightWrist, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)

            SegmentView(start: leftHip, end: leftKnee, color: pictogramFigureColor, thickness: shoulderDistance * 0.16)
            SegmentView(start: rightHip, end: rightKnee, color: pictogramFigureColor, thickness: shoulderDistance * 0.16)
            SegmentView(start: leftKnee, end: leftFoot, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)
            SegmentView(start: rightKnee, end: rightFoot, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)

            if showsHands {
                JointView(center: leftWrist, diameter: shoulderDistance * 0.12, color: pictogramFigureColor)
                JointView(center: rightWrist, diameter: shoulderDistance * 0.12, color: pictogramFigureColor)
            }

            FootMarker(center: leftFoot, width: shoulderDistance * 0.22, height: shoulderDistance * 0.10)
            FootMarker(center: rightFoot, width: shoulderDistance * 0.22, height: shoulderDistance * 0.10)
        }
    }
}

private struct SeatedPictogramFigure: View {
    let neck: CGPoint
    let waist: CGPoint
    let leftShoulder: CGPoint
    let rightShoulder: CGPoint
    let leftElbow: CGPoint
    let rightElbow: CGPoint
    let leftWrist: CGPoint
    let rightWrist: CGPoint

    var body: some View {
        let shoulderDistance = max(distance(leftShoulder, rightShoulder), 48)
        let chest = midpoint(leftShoulder, rightShoulder)
        let neckBase = CGPoint(x: neck.x, y: neck.y + shoulderDistance * 0.16)
        let hipOffset = shoulderDistance * 0.24
        let leftHip = CGPoint(x: waist.x - hipOffset, y: waist.y)
        let rightHip = CGPoint(x: waist.x + hipOffset, y: waist.y)
        let leftKnee = CGPoint(x: waist.x - shoulderDistance * 0.08, y: waist.y + shoulderDistance * 0.28)
        let rightKnee = CGPoint(x: waist.x + shoulderDistance * 0.16, y: waist.y + shoulderDistance * 0.28)
        let leftFoot = CGPoint(x: leftKnee.x - shoulderDistance * 0.08, y: leftKnee.y + shoulderDistance * 0.28)
        let rightFoot = CGPoint(x: rightKnee.x + shoulderDistance * 0.04, y: rightKnee.y + shoulderDistance * 0.28)

        return ZStack {
            Ellipse()
                .fill(pictogramFigureColor)
                .frame(width: shoulderDistance * 0.48, height: shoulderDistance * 0.66)
                .position(neck)

            SegmentView(start: neckBase, end: chest, color: pictogramFigureColor, thickness: shoulderDistance * 0.15)

            PictogramTorsoShape(
                chest: chest,
                pelvis: waist,
                chestWidth: shoulderDistance * 0.92,
                waistWidth: shoulderDistance * 0.58
            )
            .fill(pictogramFigureColor)

            SegmentView(start: leftShoulder, end: leftElbow, color: pictogramFigureColor, thickness: shoulderDistance * 0.17)
            SegmentView(start: rightShoulder, end: rightElbow, color: pictogramFigureColor, thickness: shoulderDistance * 0.17)
            SegmentView(start: leftElbow, end: leftWrist, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)
            SegmentView(start: rightElbow, end: rightWrist, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)

            SegmentView(start: leftHip, end: leftKnee, color: pictogramFigureColor, thickness: shoulderDistance * 0.16)
            SegmentView(start: rightHip, end: rightKnee, color: pictogramFigureColor, thickness: shoulderDistance * 0.16)
            SegmentView(start: leftKnee, end: leftFoot, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)
            SegmentView(start: rightKnee, end: rightFoot, color: pictogramFigureColor, thickness: shoulderDistance * 0.14)

            JointView(center: leftWrist, diameter: shoulderDistance * 0.11, color: pictogramFigureColor)
            JointView(center: rightWrist, diameter: shoulderDistance * 0.11, color: pictogramFigureColor)

            FootMarker(center: leftFoot, width: shoulderDistance * 0.22, height: shoulderDistance * 0.10)
            FootMarker(center: rightFoot, width: shoulderDistance * 0.22, height: shoulderDistance * 0.10)
        }
    }
}

private struct CurvedArrowMarker: View {
    let center: CGPoint
    let radius: CGFloat
    let startDegrees: CGFloat
    let endDegrees: CGFloat
    var lineWidth: CGFloat = 4

    var body: some View {
        let tip = point(onCircleAt: endDegrees)
        let leftWing = wingPoint(from: tip, angleDegrees: endDegrees - 28)
        let rightWing = wingPoint(from: tip, angleDegrees: endDegrees + 28)

        return ZStack {
            Path { path in
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(Double(startDegrees)),
                    endAngle: .degrees(Double(endDegrees)),
                    clockwise: false
                )
            }
            .stroke(pictogramAccentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: tip)
                path.addLine(to: leftWing)
                path.move(to: tip)
                path.addLine(to: rightWing)
            }
            .stroke(pictogramAccentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    private func point(onCircleAt degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )
    }

    private func wingPoint(from tip: CGPoint, angleDegrees: CGFloat) -> CGPoint {
        let radians = angleDegrees * .pi / 180
        return CGPoint(
            x: tip.x - cos(radians) * lineWidth * 3.2,
            y: tip.y - sin(radians) * lineWidth * 3.2
        )
    }
}

private struct ArrowLineMarker: View {
    let start: CGPoint
    let end: CGPoint
    var lineWidth: CGFloat = 4

    var body: some View {
        let theta = angle(start, end)
        let leftWing = CGPoint(
            x: end.x - cos(theta - .pi / 6) * lineWidth * 3.2,
            y: end.y - sin(theta - .pi / 6) * lineWidth * 3.2
        )
        let rightWing = CGPoint(
            x: end.x - cos(theta + .pi / 6) * lineWidth * 3.2,
            y: end.y - sin(theta + .pi / 6) * lineWidth * 3.2
        )

        return ZStack {
            Path { path in
                path.move(to: start)
                path.addLine(to: end)
            }
            .stroke(pictogramAccentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            Path { path in
                path.move(to: end)
                path.addLine(to: leftWing)
                path.move(to: end)
                path.addLine(to: rightWing)
            }
            .stroke(pictogramAccentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct FootMarker: View {
    let center: CGPoint
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: height * 0.5, style: .continuous)
            .fill(pictogramFigureColor)
            .frame(width: width, height: height)
            .position(center)
    }
}

private struct PictogramTorsoShape: Shape {
    let chest: CGPoint
    let pelvis: CGPoint
    let chestWidth: CGFloat
    let waistWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let dx = pelvis.x - chest.x
        let dy = pelvis.y - chest.y
        let length = max(sqrt(dx * dx + dy * dy), 0.001)
        let unit = CGPoint(x: dx / length, y: dy / length)
        let normal = CGPoint(x: -unit.y, y: unit.x)

        let topLeft = CGPoint(x: chest.x + normal.x * chestWidth * 0.5, y: chest.y + normal.y * chestWidth * 0.5)
        let topRight = CGPoint(x: chest.x - normal.x * chestWidth * 0.5, y: chest.y - normal.y * chestWidth * 0.5)
        let bottomRight = CGPoint(x: pelvis.x - normal.x * waistWidth * 0.5, y: pelvis.y - normal.y * waistWidth * 0.5)
        let bottomLeft = CGPoint(x: pelvis.x + normal.x * waistWidth * 0.5, y: pelvis.y + normal.y * waistWidth * 0.5)

        var path = Path()
        path.move(to: topLeft)
        path.addQuadCurve(
            to: topRight,
            control: CGPoint(x: chest.x, y: chest.y + length * 0.08)
        )
        path.addLine(to: bottomRight)
        path.addQuadCurve(
            to: bottomLeft,
            control: CGPoint(x: pelvis.x, y: pelvis.y - length * 0.14)
        )
        path.closeSubpath()
        return path
    }
}

private struct ExerciseBackdrop: View {
    let primaryTint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .stroke(primaryTint.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [8, 12]))
            .padding(12)
    }
}

private struct SegmentView: View {
    let start: CGPoint
    let end: CGPoint
    let color: Color
    let thickness: CGFloat

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: distance(start, end), height: thickness)
            .rotationEffect(.radians(angle(start, end)))
            .position(midpoint(start, end))
    }
}

private struct JointView: View {
    let center: CGPoint
    let diameter: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .position(center)
    }
}

private struct CapsuleMarker: View {
    let center: CGPoint
    let width: CGFloat
    let height: CGFloat
    let angle: Angle
    let color: Color

    var body: some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: height)
            .rotationEffect(angle)
            .position(center)
    }
}

private struct MotionRing: View {
    let center: CGPoint
    let diameter: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .stroke(color.opacity(0.32), style: StrokeStyle(lineWidth: 3, dash: [8, 12]))
            .frame(width: diameter, height: diameter)
            .position(center)
    }
}

private struct SymbolMarker: View {
    let name: String
    let center: CGPoint
    let size: CGFloat
    let color: Color

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(color.opacity(0.92))
            .position(center)
    }
}

private struct PalmGlyph: View {
    let center: CGPoint
    let angle: Angle
    let color: Color
    var scale: CGFloat = 1

    var body: some View {
        Capsule()
            .fill(color.opacity(0.88))
            .frame(width: 68 * scale, height: 116 * scale)
            .rotationEffect(angle)
            .position(center)
    }
}

private struct HandGlyph: View {
    let center: CGPoint
    let angle: Angle
    let color: Color
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Capsule()
                .fill(color.opacity(0.88))
                .frame(width: 40 * scale, height: 74 * scale)
                .rotationEffect(angle)
                .position(center)

            Capsule()
                .fill(Color.white.opacity(0.82))
                .frame(width: 12 * scale, height: 28 * scale)
                .rotationEffect(angle + .degrees(38))
                .position(x: center.x + (18 * scale), y: center.y + (12 * scale))
        }
    }
}

private struct TwistFigure: View {
    let primaryTint: Color
    let secondaryTint: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let neck = point(0.50, 0.16, in: size)
            let waist = point(0.50, 0.78, in: size)
            let leftShoulder = point(0.34, 0.28, in: size)
            let rightShoulder = point(0.66, 0.28, in: size)
            let leftElbow = point(0.28, 0.44, in: size)
            let rightElbow = point(0.72, 0.54, in: size)
            let leftWrist = point(0.62, 0.52, in: size)
            let rightWrist = point(0.36, 0.62, in: size)

            ZStack {
                SegmentView(start: neck, end: waist, color: Color.white.opacity(0.80), thickness: 26)
                SegmentView(start: leftShoulder, end: rightShoulder, color: secondaryTint.opacity(0.84), thickness: 18)
                SegmentView(start: leftShoulder, end: leftElbow, color: primaryTint.opacity(0.92), thickness: 16)
                SegmentView(start: rightShoulder, end: rightElbow, color: primaryTint.opacity(0.92), thickness: 16)
                SegmentView(start: leftElbow, end: leftWrist, color: Color.white.opacity(0.78), thickness: 14)
                SegmentView(start: rightElbow, end: rightWrist, color: Color.white.opacity(0.78), thickness: 14)

                JointView(center: neck, diameter: 40, color: Color.white.opacity(0.94))
            }
        }
    }
}

private func overlayFont(_ name: String, size: CGFloat, fallbackWeight: NSFont.Weight) -> Font {
    let resolvedFont = NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
    return Font(resolvedFont)
}

private func point(_ x: CGFloat, _ y: CGFloat, in size: CGSize) -> CGPoint {
    CGPoint(x: size.width * x, y: size.height * y)
}

private func translated(_ point: CGPoint, by vector: CGPoint) -> CGPoint {
    CGPoint(x: point.x + vector.x, y: point.y + vector.y)
}

private func vector(length: CGFloat, angle: CGFloat) -> CGPoint {
    CGPoint(x: cos(angle) * length, y: sin(angle) * length)
}

private func mix(_ start: CGFloat, _ end: CGFloat, _ progress: CGFloat) -> CGFloat {
    start + (end - start) * progress
}

private func pulse(_ time: TimeInterval, speed: Double) -> CGFloat {
    CGFloat((sin(time * speed) + 1) * 0.5)
}

private func distance(_ start: CGPoint, _ end: CGPoint) -> CGFloat {
    sqrt(pow(end.x - start.x, 2) + pow(end.y - start.y, 2))
}

private func midpoint(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
    CGPoint(x: (start.x + end.x) * 0.5, y: (start.y + end.y) * 0.5)
}

private func angle(_ start: CGPoint, _ end: CGPoint) -> CGFloat {
    atan2(end.y - start.y, end.x - start.x)
}

private func rotate(_ point: CGPoint, around origin: CGPoint, by angle: CGFloat) -> CGPoint {
    let translatedX = point.x - origin.x
    let translatedY = point.y - origin.y

    return CGPoint(
        x: origin.x + (translatedX * cos(angle) - translatedY * sin(angle)),
        y: origin.y + (translatedX * sin(angle) + translatedY * cos(angle))
    )
}
