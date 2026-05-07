# HANDOFF_BRIEF.md — Pure Phase Session Bridge
*Update this at the end of every meaningful work session. It is the first document a new instance reads.*

---

## Current State — May 2026 (post Session 4)

**Status: Tap bug fixed. Onboarding fonts bumped. Landscape reflow handled. HTTP automation server live and working. Full flow drivable from curl: tap any tile, change any setting, start a session with a full config, observe live engine telemetry, exit. Both iOS Simulator and Mark's iPhone 16 Plus running the new build.**

### Session 4 — HTTP Automation + Tap Fix + Polish (built this session)

**Bug fixes:**
- `IntentTileView` — was wrapping content in a Button with a competing simultaneousGesture, which silently swallowed taps under NavigationLink. Rewritten as pure presentation. Hit testing now lives only on the parent NavigationLink. **Home tile taps work.**
- `OnboardingView` — fonts bumped (body 19pt, warning 17pt, checkbox label 15pt, ENTER 15pt) for legibility. Added accessibilityIdentifiers for automation.
- `HomeView` — wrapped in ScrollView; content frame caps at maxWidth 600, centered. Reflows cleanly in landscape and on Catalyst.
- `SessionConfigView` — content frame caps at maxWidth 700. Added accessibility IDs.
- `ContentView` — replaced bug where setting `bus.requestedConfigState = nil` after handling caused the same onChange to fire and pop the navigation. Now uses `DispatchQueue.main.async` to defer the clear and `guard let` to ignore nil transitions. Same fix applied to `bus.requestedSession`.
- `SessionView` — added bus wiring (registers `session.exit`, sets `currentEngine`/`currentScreen`/`currentConfig`, clears on disappear).

**New foundational infrastructure (always-on bus, DEBUG-only server):**
- `Engine/AutomationBus.swift` — singleton `@Observable` actor that views read/write. Holds `currentScreen`, `currentEngine` (live SessionEngine while a session is running), `currentConfig`, `lastEvent`, plus inbound `requestedConfigState` / `requestedSession` / `dismissTicket` and an action registry keyed by accessibility identifier. Compiled in **all** configurations because it is also the path the Begin button uses to ask the router to present a SessionView. Cheap when the server is gone.
- `Engine/AutomationHTTP.swift` — minimal HTTP/1.1 request parser and response builder. **DEBUG only.** No third-party dependency.
- `Engine/AutomationServer.swift` — **DEBUG only.** `NWListener`-based local HTTP server on port 8765, all interfaces, accepts plain HTTP. Routes verbs in parity with user-facing surfaces:
  - `GET  /state` — full snapshot (current screen, engine telemetry, every AppStorage value, registered actions)
  - `GET  /actions` — list registered accessibility IDs
  - `GET  /screenshot` — PNG of the current key window
  - `POST /tap {id}` — fire any registered action
  - `POST /set {key, value}` — write any AppStorage key
  - `POST /navigate {to}` — push a SessionConfig screen
  - `POST /reset-onboarding` and `/onboarding/accept`
  - `POST /session/start {state, duration?, audioEnabled?, isoVolume?, ambientType?, ambientVolume?, breathEnabled?, breathPattern?, colorModeEnabled?, torchEnabled?}`
  - `POST /session/stop`
- `NeuroLightApp` — starts the server in `init()` under `#if DEBUG`.
- Every interactive surface now registers itself with the bus using a stable accessibility identifier:
  - Onboarding: `onboarding.toggle`, `onboarding.accept`, `onboarding.enter`
  - Home: `home.tile.focus|calm|sleep`, `home.advanced`
  - Config: `config.begin`
  - Session: `session.exit`

### Verified end-to-end on simulator (curl from Mac → iPhone 17 Pro sim)
1. `POST /tap home.tile.focus` → screen becomes `config.focus`, `config.begin` registered
2. `POST /session/start {state:"sleep", duration:"five"}` → SessionView presents, engine starts running
3. `GET /state` returns live `flickerPhase`, `breathPhase`, `breathStageName`, `brightness`, `elapsed`, `remaining`, `sessionProgress`
4. `POST /tap session.exit` → engine stops, view dismisses, screen returns to `home`

Screenshots in `Docs/Screenshots/` show the warm Calm and ember Sleep aesthetic running cleanly.

### Notes for next session
- The HTTP server binds to all interfaces on port 8765. On the simulator, Mac → simulator localhost works directly. On a physical phone, Mac and phone must be on the same Wi-Fi; use the phone's IP. iOS may prompt for Local Network permission on first hit on a real device — accept once and it sticks.
- The bus pattern is set: every new user-facing surface MUST register at least one accessibility identifier and corresponding action. Add a verb to AutomationServer's route table whenever a new capability lands. **This is the parity rule — do not let the API drift from the UI.**
- AdvancedView is still pending. So is the iso-tone carrier-frequency selector.
- No automated screenshot capture script yet — that's a small Bash wrapper around `/screenshot`. Defer until needed.

---

## Current State — May 2026 (post Session 3)

**Status: Core Views shipped and running on Mark's iPhone 16 Plus and the iOS 17 Pro simulator. Build green for iOS, simulator, and Mac Catalyst. Aesthetic locked in: warm-only palette, glyph-driven home, sparse industrial type. Next session: HTTP automation tool (Mark requested it move forward — sooner is better) plus AdvancedView and on-device verification.**

### Session 3 — Core Views (built this session)
- `Models/BrainwaveState.swift` — tints rewritten to be **warm-only**. Sleep is now ember-red (8B2E1F → 1A0503), Calm is peach-to-brick (D9824A → 8B3A2A), Theta is amber-to-maroon, Void is deep ember black, Psychedelic stays warm with controlled magenta. No blues anywhere — both because Mark requested it and because it aligns with sleep-onset light research.
- `Utilities/AppStorage+Keys.swift` — single source of truth for every UserDefaults key.
- `Views/Components/IntentTileView.swift` — sparse home tile, ultra-light SF Symbol painted in the gradient with a soft outer glow. Press feedback is a quiet brightness lift.
- `Views/Components/GradientProgressRing.swift` — 1-pt rounded-rectangle stroke traced from top-center, peripheral by design.
- `Views/OnboardingView.swift` — first-launch warning gated by an actual checkbox (not tap-through), persisted via `@AppStorage`, no medical claims (verified against the approved-language list).
- `Views/HomeView.swift` — three glyphs on black: `viewfinder` for FOCUS, `water.waves` for CALM, `moon.fill` for SLEEP. Industrial PURE PHASE title, ADVANCED affordance at the bottom (Session 4). NavigationStack with hidden toolbar and explicit Color.black background.
- `Views/SessionConfigView.swift` — pre-session controls: duration row (5/10/20/40/Open), audio block (sound toggle, tone slider, ambient type segmented, texture slider), breath block (toggle + preset list), visual block (color flash, torch — torch row hidden when `TorchController.isAvailable == false`, i.e. always under Catalyst). All settings persist via `@AppStorage`. Begin button uses the state's gradient.
- `Views/BreathGuideView.swift` — single ring, ease-in-out scale 0.4↔1.0 mapped from `engine.breathPhase`, soft inner glow gradient, 0.5 Hz shimmer during hold stages, opacity rides on `engine.brightness`.
- `Views/SessionView.swift` — full-screen flicker layer (color or gradient depending on Color Flash toggle), opacity multiplied by `engine.brightness` so 3 s fade-in and 30 s fade-out are automatic; breath guide overlay; edge progress ring; tap-reveal exit + remaining timer with 3 s auto-hide; idle timer disabled during session; psychedelic warm hue drift via `.hueRotation` clamped to ±22°.
- `ContentView.swift` — replaced with a clean root router: shows `OnboardingView` until acknowledged, then `HomeView`. `.preferredColorScheme(.dark)` enforced.

### Decisions made this session (per Mark)
- **Warm-only palette across all states** — no blues, even for Sleep. Aligns with sleep-onset light research.
- **Glyph-driven home** with SF Symbols (sparse > literal). Three glyphs picked: viewfinder, water.waves, moon.fill. Same pattern will extend into the eventual Advanced panel.
- **Slow fade-up on session entry** — handled implicitly by the engine's brightness ramp; views simply multiply by it.
- **Edge progress ring** — non-invasive, peripheral, never grabs focus. Hidden in Open mode.
- **HTTP automation tool moves forward to next session** (per Mark, "sooner is better") and grows in parity with user-facing features going forward. Treated as foundational infrastructure.

### Build State (post Session 3)
- iOS Simulator (iPhone 17 Pro, iOS 26.3) → **BUILD SUCCEEDED**, installed, launched, screenshots in `Docs/Screenshots/`
- iOS Device (Mark's iPhone 16 Plus) → **BUILD SUCCEEDED**, installed via `devicectl` at `D24FB384-9C55-5D33-9B0D-DAEBFA6528D6`
- Mac Catalyst → **BUILD SUCCEEDED** (last verified Session 2 — re-verify next session after Catalyst-specific torch UI changes)

### Notes for next session
- The third-party `mcp__ios-simulator__ui_tap` produced "tap successful" results that didn't actually hit targets — coordinate mapping is unreliable. The HTTP automation tool we're about to build should bypass this entirely by hooking the app directly: a debug-only HTTP server inside the app that exposes every navigable surface and every settable state. Build it as a real first-class feature, not a wrapper around external tooling.
- All home tiles have `accessibilityIdentifier` (`home.tile.focus|calm|sleep`). Continue this convention everywhere.
- Onboarding can be reset for testing via: `xcrun simctl spawn <udid> defaults delete com.MarkFriedlander.NeuroLight hasSeenOnboarding`.

---

## Current State — May 2026 (post Session 2)

**Status: Engine layer complete and compiling cleanly on both iOS and Mac Catalyst. Core Views (Session 3) is the next target — but the four open UX questions in NEXT.md must be answered by Mark before Views begin.**

### Session 2 — Engine Layer (built this session)
- `Engine/TorchController.swift` — `@Observable` class. `isAvailable` returns false on Catalyst; `setOn(_:)` is a guarded no-op there. `forceOff()` for clean shutdown. Views read `isAvailable` to hide torch UI entirely on Catalyst.
- `Engine/SessionEngine.swift` — the master clock. `@Observable`. CADisplayLink-driven. Publishes `isRunning`, `flickerPhase`, `breathPhase`, `breathStageName`, `sessionProgress` (Optional — nil in Open mode), `brightness`, `elapsed`, `remaining`. Mathematical phase computation (`sin(2π × Hz × t) > 0`). 3-second fade-in, 30-second fade-out (skipped in Open mode). Psychedelic state has ±20% drift on a 15-second cycle. Owns `audio` and `torch` sub-engines and drives them from each tick. Start/stop only — **no pause** in v1 (per Mark).
- `Engine/AudioEngine.swift` — `@Observable`. Two `AVAudioPlayerNode`s (isochronic + ambient) into an `AVAudioMixerNode`. Isochronic = audible carrier × square-with-soft-edges envelope at the pulse rate, generated as a seamlessly-loopable buffer (cycles-per-loop chosen for clean wraparound). Pink noise via Voss-McCartney; brown noise via leaky integration; drone is a 110 Hz sine. All buffers procedurally synthesized at `start()`, no audio files. Master fade applied via mixer `outputVolume` in `setEnvelope(_:)` called from SessionEngine each tick. Audio session category `.playback`, deactivated on stop. Catalyst-safe (audio session calls gated).

### Decisions made this session (per Mark)
- **Start/Stop only** — no pause in v1. Pausing breaks entrainment; cleaner to just restart.
- **Audio fades in alongside visual** over the same 3 seconds.
- **Completion behavior** is a View concern. Engine performs the slow 30-second fade-out, then fires `completionHandler` and goes idle. Visual choreography of the post-session moment is owned by `SessionView` (Session 3) — keeps the engine pure and gives us flexibility to tune the feel later.
- **Psychedelic drift** kept at ±20% over 15 s (matches original).
- **40 Hz on a 60 Hz device** — accept the slight unevenness. 120 Hz iPhones get clean 3-on / 3-off rendering.

### Earlier sessions (still valid)
- `Models/BrainwaveState.swift`, `Models/BreathPattern.swift`, `Models/SessionConfig.swift` — see Session 1 entry in HISTORY.md.
- `ContentView.swift` is still the minimal "models layer ready" placeholder. Replaced wholesale in Session 3.

### What Exists Right Now
- `NeuroLight/Models/BrainwaveState.swift` — full state catalog: three primary (focus / calm / sleep) and five advanced (theta, smr, psychedelic, voidState, custom). Stable string IDs (not UUIDs) so persistence round-trips. Includes `EvidenceTier`, `SessionTint` (gradient pair via hex), and `Color(hex:)` helper.
- `NeuroLight/Models/BreathPattern.swift` — four presets (Coherence default, 4-7-8, Box, Slow Wave) with `cycleDuration` and `bpm` computed.
- `NeuroLight/Models/SessionConfig.swift` — `SessionDuration` (5/10/20/40/Open with `minutes: Double?` and `hasFadeOut`), `AmbientSoundType` (pink/brown/drone/off), full `SessionConfig` struct, universal `SessionConfig.default(for:)`.
- `NeuroLight/ContentView.swift` — **replaced** with a minimal black "models layer ready" placeholder so the app target still compiles. The legacy ~510-line file (broken Timer flicker, commented-out audio, iCloud UserDefaults suite bug, all 7 states equally surfaced) is gone. The real Home / Session / Advanced views land in Session 3.
- `NeuroLight/NeuroLightApp.swift` — unchanged.

### What Has Been Decided (this session)
- Stable string IDs for `BrainwaveState` (`"focus"`, `"calm"`, `"sleep"`, etc.) — safe for `@AppStorage` persistence later.
- `SessionTint` exposes both a gradient and a dominant color so Views can choose; both ends defined per state.
- `void` is named `voidState` in code (since `void` is a reserved-ish word in Swift); user-facing displayName remains "VOID".
- Universal default `SessionConfig` regardless of intent (audio on at 60% iso / 30% pink, breath on with Coherence, color mode off, torch off, 10 min).
- All Model types marked `nonisolated` — pure value types, free to use from any actor context.
- Xcode project uses synchronized folder groups (objectVersion 77) — dropping files into `NeuroLight/<subfolder>/` auto-includes them in the target. No `project.pbxproj` editing needed for future Engine/Views files.

### Build State (post Session 2)
- iOS Simulator build → **BUILD SUCCEEDED**
- Mac Catalyst build → **BUILD SUCCEEDED**

---

## Immediate Next Step

**Session 4: HTTP Automation Layer + AdvancedView.** Mark explicitly asked for the automation tool to move forward this session ("sooner is better — should be baked in from go, growing as the feature set grows"). Treat it as foundational infrastructure: a debug-only embedded HTTP server (`#if DEBUG`-gated, stripped from Release builds) that lets Claude Code drive every user-facing surface of the app. It must keep parity with the UI as new features ship — every new surface the user can reach gets a corresponding verb in the API.

Outline:
- `Engine/AutomationServer.swift` — debug-only HTTP server, port 8765 by default, restricted to localhost. Routes for: get state, navigate to screen, set any `@AppStorage` value, simulate tap on any view by `accessibilityIdentifier`, screenshot trigger, start/stop a session with a fully specified config, observe live engine state.
- A small `AutomationBus` actor that views read from / write to so the server can drive them without coupling.
- `AdvancedView.swift` for the exploratory states (theta, smr, psychedelic, void, custom Hz, custom breath, carrier frequency).
- Re-verify on device after.

---

## Open Standing Questions for Mark (still unanswered, needed before Views)
- Breath guide visual: petal cluster vs. single ring vs. something else in the Virtual Light language
- Home tile layout: stacked vs. spatial/centered cards
- Session entry transition: cut vs. 2-3s fade-up
- Progress indicator: edge ring vs. timer text vs. nothing

These don't block Engine work — flagging only so they're remembered when Views begin.

---

## Environment

- Language: Swift, SwiftUI
- Minimum iOS: **26.0** (locked in by Mark — intentional, not a default)
- Targets: iPhone (primary) + **Mac Catalyst** (Mac runs the app as if it were an iPad)
- Frameworks in use: SwiftUI; AVFoundation/AVFAudio coming in Engine layer
- No third-party dependencies
- Project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — pure value types use `nonisolated` to stay free of actor constraints
- Catalyst-specific code uses `#if targetEnvironment(macCatalyst)` — never `#if os(macOS)`
- Torch (flashlight) is unavailable under Catalyst — guard at the engine level, do not branch the UI

---

## Standing Rules for Next Session
- Read CLAUDE.md, this file, and NEXT.md before writing a single line
- State plan for `SessionEngine` before implementing — it's the riskiest piece in the app
- Use LEGO block system for all file delivery
- Do not touch `AudioEngine` until `SessionEngine` is reviewed and approved
- Ask before inventing anything not specified in `neurolight_design_spec.md`
- The May 2026 documentation update session (privacy policy, age rating, no-medical-claims, Phase 4 closed-loop concept, screenshot automation, pre-submission checklist) must be confirmed complete before any Swift code is written in the next session
- The four open UX questions listed at the bottom of NEXT.md (breath guide visual, home tile layout, session entry transition, progress indicator) **must be answered by Mark** before Views are built — do not invent answers to those questions
- Under Mac Catalyst, all torch-related UI must be hidden entirely (no dead toggles); engine no-ops torch as defense-in-depth

---

## In-progress: App Store submission (May 2026, mid-session)

CC and Mark are mid-way through the App Store Connect submission flow for Pure Phase 1.0. **Authoritative state, drafted copy, and the full pending checklist are in `Docs/AppStoreSubmission.md`.** Read that first if continuing the submission work; do NOT re-derive from scratch.

Quick summary of where we are:
- App Store Connect listing created (Apple ID 6767311034)
- Bundle ID `com.MarkFriedlander.PurePhase` registered with Apple Developer
- App Information page: Primary category = Health & Fitness, Secondary = Lifestyle, **saved**
- Subtitle, Content Rights, App Privacy questionnaire, Pricing & Availability, version 1.0 metadata, age rating, build upload — all still pending
- Strategic Claude's drafted description / keywords / promotional text / What's New copy lives in the AppStoreSubmission doc

If a context compaction happened mid-flow, the recovery doc has everything needed to resume.

---

## Pick up tomorrow morning here

**Mark stopped at end of evening on May 6, 2026 — got tired suddenly. Resuming in the AM.**

State at sign-off:
- Launch fade-in committed and pushed (1.2 s ease-out from black on cold start of ContentView).
- `scripts/capture_screenshots.sh` committed and pushed. Captures 4 screens (Home, Advanced, BREATHE config, BREATHE session) at iPhone 6.9" and iPad 13" sizes, with a `*-thumb.png` alongside each via `sips -Z 400`.
- `Docs/AppStoreScreenshots/` is in `.gitignore` (build artifact, not source of truth).
- Image-handling rule documented in `CLAUDE.md` and a corresponding decision in `MEMORY.md`. **CC must never read full-size image files; only `*-thumb.png` are safe.**
- Screenshot script was running in the background when Mark signed off — **stopped cleanly with `TaskStop`** before sign-off so nothing keeps the simulator running overnight. Output may or may not be complete in `Docs/AppStoreScreenshots/iphone-6.9/` depending on how far it got.
- All commits pushed to `https://github.com/markfriedlander/pure-phase` through `cb9abd4`.

### First thing tomorrow

1. Re-run `scripts/capture_screenshots.sh` from a clean state to get a complete set of screenshots, OR check what's already in `Docs/AppStoreScreenshots/` and only re-capture missing pieces.
2. Mark reviews the full-size PNGs in Finder — confirms they look right.
3. Move to App Store Connect submission (Chrome MCP browser automation for the form, Xcode Organizer for the build upload).

Three deferred-to-1.1 items (logged in MEMORY "Known Polish Issues") are still on hold:
- Halo stutter at breath cycle peaks
- 40 Hz Focus pattern change on 60 Hz displays
- Grey noise ambient option

Three deferred-to-1.0-finish items still owed by Mark on real hardware:
- Sleep mode in a dark room with torch on
- 40-minute Open mode end-to-end
- Mac Catalyst window behavior

---

## Last Updated
May 2026 — **Session 7: Renamed to Pure Phase. GitHub repo and Pages live.**

The product is now **Pure Phase**. Bundle ID `com.MarkFriedlander.PurePhase`. Display name "Pure Phase". Public repo at `https://github.com/markfriedlander/pure-phase`. Privacy + support pages at `https://markfriedlander.github.io/pure-phase/{privacy,support}.html` (HTTP 200, verified). App icon is the warm radial pulse — no letterform.

Source tree, Xcode project file, and legacy `NeuroLightApp` struct keep their original names on disk. The product is Pure Phase; the codename internally is unchanged.

Installed on Mark's iPhone 16 Plus.

**Carried forward from Session 6** (still true):
- iOS 17 deployment target, Mac Catalyst, max-width 560 pt cap on Home/Advanced/Config/Onboarding
- Restore Defaults button in SessionConfigView
- Audio interruption suspends flicker + torch + audio together via SessionEngine
- Audio output verified at `maxPeak ≈ 0.42` via debug-only tap on `/state.audio`
- Automation server on **port 8770** (DEBUG only)

**Three issues deferred to 1.1** (see MEMORY.md "Known Polish Issues"):
- Halo stutter at breath cycle peaks (blur+scaleEffect interaction)
- 40 Hz Focus pattern change on 60 Hz (non-ProMotion) displays
- Grey noise ambient option (ISO 226 filtered)
