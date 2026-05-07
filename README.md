# Pure Phase

A free iOS app that uses synchronized light flicker, isochronic audio tones, and breath pacing to guide the user toward focus, calm, or sleep states. Also includes a flicker-free breathwork mode.

No subscriptions. No accounts. No analytics. No content library. Everything runs on-device. Source code is here.

## What it does

Four modes on the home screen:

- **BREATHE** — Animated breath ring, optional audio cues at each phase. No flicker.
- **FOCUS** — 40 Hz visual flicker + isochronic audio. Gamma range. Associated with sustained attention in research literature.
- **CALM** — 10 Hz visual flicker + isochronic audio. Alpha range. Associated with relaxed alert states.
- **SLEEP** — 2 Hz visual flicker + isochronic audio. Delta range. Best with the iPhone torch enabled and eyes closed; the flashlight pulses through the eyelids.

An **Advanced** screen exposes Theta, SMR, Psychedelic, Void, and a fully Custom state with user-set Hz (0.5–40) and carrier frequency (80–440 Hz). Custom breath patterns are supported with independent inhale, hold-in, exhale, and hold-out durations.

A safety warning gates the first launch — the app uses rapid rhythmic light pulses and is not appropriate for users with photosensitivity or seizure disorders.

## How to use

On the home screen:

- **Tap** any tile to start a session immediately using the last-saved settings.
- **Hold** any tile (about half a second) to open the configuration screen for that mode — duration, audio levels, breath pattern, color flash, torch.

During a session:

- Tap anywhere to reveal the timer and an exit button. They auto-hide after 3 seconds.
- The session fades in over 3 seconds and out over 30 seconds at the end (except in Open mode, which has no fixed end).

Open the **Restore Defaults** button at the bottom of any session config screen to reset all settings to recommended starting values.

## How the code is organized

Standard SwiftUI app, iOS 17+, also runs on Mac via Catalyst. Source tree:

```
NeuroLight/                    (folder kept under original codename)
├── App/
│   └── NeuroLightApp.swift    Entry point; starts the debug HTTP server in DEBUG builds
├── Models/
│   ├── BrainwaveState.swift   Eight states (Focus, Calm, Sleep, Theta, SMR, Psychedelic, Void, Custom, plus Breathwork)
│   ├── BreathPattern.swift    Four presets (Coherence, 4-7-8, Box, Slow Wave) + runtime Custom pattern
│   └── SessionConfig.swift    Full session configuration (state, duration, audio, breath, torch, color)
├── Engine/
│   ├── SessionEngine.swift    Master clock — single CADisplayLink drives all timing
│   ├── AudioEngine.swift      AVAudioEngine; isochronic tone, ambient texture, breath cues, all procedurally synthesized
│   ├── TorchController.swift  AVCaptureDevice torch; safe no-op on Catalyst
│   ├── AutomationBus.swift    Coordination between views and the debug HTTP server
│   ├── AutomationServer.swift Debug-only HTTP server (port 8770) for testing and screenshot capture
│   └── AutomationHTTP.swift   Minimal HTTP/1.1 parser — no third-party dependencies
├── Views/
│   ├── OnboardingView.swift   First-launch warning, gated by an actual checkbox
│   ├── HomeView.swift         Four tiles, single-tap-start / long-press-config gestures
│   ├── AdvancedView.swift     Advanced states + Custom Hz / carrier sliders
│   ├── SessionConfigView.swift  Pre-session settings, persisted via @AppStorage
│   ├── SessionView.swift      Full-bleed flicker, breath ring overlay, edge progress
│   ├── BreathGuideView.swift  Centered cream ring with warm halo
│   └── Components/            IntentTileView, GradientProgressRing, TileGesture
└── Utilities/
    ├── AppStorage+Keys.swift  Centralized persistence key constants
    └── Layout.swift           Single content max-width constant for iPad/Mac layout
```

### Key engineering decisions

**One clock.** A single CADisplayLink in `SessionEngine` drives flicker phase, breath phase, fade envelope, and audio pulse timing. No view or sub-engine has its own timer. This is what keeps light, sound, and breath from drifting apart over a session.

**Math, not callbacks.** Flicker phase is computed as `sin(2π × Hz × elapsed) > 0` per frame, not toggled on a recurring timer. This is accurate at 40 Hz where timer-based approaches accumulate drift.

**Procedural audio.** All audio is synthesized at session start — no audio files, no licensing, small binary. Isochronic tone is an audible carrier (carrier Hz, e.g. 220 Hz) amplitude-modulated at the brainwave Hz with soft-edged pulses. Pink noise uses Voss-McCartney; brown noise is leaky integration; drone is a sustained low sine. Buffer lengths are chosen so loop boundaries fall on zero crossings.

**Audio interruption.** When a phone call or other audio app interrupts, `SessionEngine` pauses the display link, forces the torch off, sets brightness to 0, and pauses audio together. On resume, it adjusts the start time so elapsed continues seamlessly — no jump in breath cycle or audio buffer position.

**Persistence.** All user settings are stored via `@AppStorage` (UserDefaults under the hood). The app collects nothing else. No network calls in production builds.

**Multi-platform.** iPhone is primary. iPad and Mac (via Catalyst) are supported with a shared content layout — tiles and config views are capped at 560 pt wide and centered on larger displays. The session experience itself is full-bleed on every screen size. The torch UI is hidden entirely on Mac and on iPhones without torch hardware.

### Debug HTTP automation server

In `Debug` builds only, the app runs a small HTTP server on port 8770 that exposes the full UI as an API:

- `GET /state` — current screen, engine state, audio diagnostics, session config, breath cue history, registered actions, all persisted settings
- `GET /screenshot` — PNG of the current key window
- `POST /tap {id}` — fire any registered accessibility identifier (any home tile, any config control, exit, etc.)
- `POST /set {key, value}` — write any AppStorage key
- `POST /navigate {to}` — push to home, advanced, or any state's config screen
- `POST /session/start {state, duration?, audioEnabled?, ...}` — launch a fully specified session
- `POST /session/stop` — end the current session
- `POST /reset-onboarding` and `POST /onboarding/accept` — onboarding state control
- `GET /help` — endpoint listing

This layer is stripped entirely from Release builds. It is used during development for verification, regression checks, and capturing App Store screenshots at every required device resolution.

## How to build and run

Open `NeuroLight.xcodeproj` in Xcode (16 or later). Select the `NeuroLight` scheme. Build and run.

```bash
# iOS Simulator
xcodebuild -project NeuroLight.xcodeproj -scheme NeuroLight \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build

# Mac Catalyst
xcodebuild -project NeuroLight.xcodeproj -scheme NeuroLight \
  -destination 'platform=macOS,variant=Mac Catalyst' -configuration Debug build
```

To install on a physical device, you'll need to set your own development team in the project's Signing & Capabilities tab. The bundle identifier is `com.MarkFriedlander.PurePhase`.

The Xcode project folder is named `NeuroLight/` and contains a `NeuroLightApp` struct. These predate the rename and are kept under their original names because changing them would create churn for no user-visible benefit. The product, the bundle identifier, and the display name are all "Pure Phase".

## Releasing — App Store screenshots

Whenever a release needs fresh App Store screenshots (UI changed, new mode added, etc.), run:

```bash
xcodebuild -project NeuroLight.xcodeproj -scheme NeuroLight \
  -destination 'generic/platform=iOS Simulator' -configuration Debug build
scripts/capture_screenshots.sh
```

The script drives the simulator via the debug HTTP automation server and captures five screens at Apple's required device resolutions (iPhone 6.9", iPad 13"):

| # | Screen | Why |
|---|---|---|
| 1 | Home | The four-tile entry point |
| 2 | Advanced | The five-tile science menu |
| 3 | BREATHE config | Most variety-rich settings screen (cues toggle, ambient picker, breath patterns) |
| 4 | BREATHE session in progress | Cream ring + warm halo on black; no flicker, easy timing |
| 5 | FOCUS at full flash | Demonstrates entrainment visually; FOCUS's bright amber on-frame is the most striking color in the app. Caught via 8-shot burst capture + a Swift helper that picks by average pixel luminance (`scripts/pick_brightest.swift`) — file size alone isn't a reliable on-frame signal for low-saturation colors. |

For each PNG, a companion `*-thumb.png` is produced via `sips -Z 400` for safe inspection without bloating context. The full-size files are what get uploaded to App Store Connect; thumbnails are for quick previewing or for any agent that needs to verify content programmatically.

**Heads up on iPhone size:** at the May 2026 submission, App Store Connect's iPhone slot rejected the native 1320 × 2868 capture and only accepted 1242 × 2688 or 1284 × 2778. Workaround: `sips -z 2778 1284 SRC.png --out resized/SRC.png` for each iPhone PNG before upload. iPad shots were accepted as-is. Apple's UI labels likely lag the latest device generation; revisit when a new iPhone size becomes natively accepted.

Output goes to `Docs/AppStoreScreenshots/` (gitignored).

If you ever extend the script to add a 6th shot or change the lineup, keep the output count low — App Store reviewers prefer 3–5 distinctive shots over 10 redundant ones.

## Privacy

Pure Phase collects nothing, transmits nothing, stores nothing on a server. All settings are local. The full privacy policy is at https://markfriedlander.github.io/pure-phase/privacy.html.

## Support

User-facing support documentation is at https://markfriedlander.github.io/pure-phase/support.html.

For questions or feedback: markfriedlander@yahoo.com

## Status

Pre-1.0 development. Working on iPhone (tested on iPhone 16 Plus running iOS 26.x) and iOS Simulator. Mac Catalyst builds and runs but has not been exhaustively tested. App Store submission pending.

## License

The source code in this repository is released under the **MIT License**. See [LICENSE](LICENSE) for the full text. In short: do anything you want with the code, just keep the copyright notice intact, and don't expect a warranty.

The name **Pure Phase**, the app icon (warm radial pulse), and the visual identity (warm-amber-on-black aesthetic, "PURE PHASE" wordmark) are not covered by the MIT license — those are project branding. If you fork this code to ship your own app, please use a different name and a different icon. The MIT terms cover the code, not the brand.
