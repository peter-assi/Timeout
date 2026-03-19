# Timeout!

`Timeout!` is a native macOS menubar app that schedules short movement breaks while you work.

## MVP

- Menubar app with no Dock icon
- Configurable work interval and break duration
- Fullscreen topmost break overlay that says `Timeout!`
- Timer resets when the screen sleeps or the session becomes inactive
- Launch at login is enabled by default and can be turned off from the menu

## Run

Open [Timeout.xcodeproj](/Users/peter.assi/Projects/mentimeter/codex/timeout/Timeout.xcodeproj) in Xcode and run the `Timeout` scheme, or build from the terminal:

```bash
xcodebuild -project Timeout.xcodeproj -scheme Timeout -configuration Debug -derivedDataPath build/DerivedData build
```

The built app bundle lands at `build/DerivedData/Build/Products/Debug/Timeout!.app`.
