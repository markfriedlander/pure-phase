# HISTORY.md — Pure Phase Project Chronicle
*A running log of what was built, when, and why it matters. Updated every meaningful session.*

---

## May 2026 — Project Inception & Design Phase

### Design Session — Strategic Claude (claude.ai)
**Completed:**
- Full analysis of existing `ContentView.swift` and `NeuroLightApp.swift`
- Competitive research: Lumenate app (Rosamund Pike / Creative Director), competitor landscape
- Scientific literature review: photic entrainment, binaural beats vs. isochronic tones, 40Hz Gamma research (MIT/Tsai lab, Nature 2024), Alpha relaxation evidence, Delta sleep architecture
- Product design decisions: three primary states (FOCUS/CALM/SLEEP), intent-based entry vs. jargon-based, isochronic audio architecture, breath guide design, session timer model
- Breathwork options: Coherence (6 BPM), 4-7-8, Box, Slow Wave; custom tuning in Advanced
- Aesthetic direction established: William Gibson "Virtual Light" book cover as reference — black canvas, amber→red warm spectrum, sparse, industrial

**Key decisions made (see MEMORY.md for full rationale):**
- FOCUS=40Hz, CALM=10Hz, SLEEP=2Hz — evidence-backed front states only
- Advanced panel for Theta, SMR, Psychedelic, Void, Custom
- Isochronic tones replace original broken sine-wave audio
- CADisplayLink replaces nested Timer
- One SessionEngine owns all timing
- iOS only for v1
- Standard UserDefaults, no iCloud suite name

**Documents created:**
- `neurolight_design_spec.md` — full product specification
- `CLAUDE.md` — operational constitution
- `HANDOFF_BRIEF.md` — session bridge
- `MEMORY.md` — strategic record
- `HISTORY.md` — this file
- `NEXT.md` — current priorities

**What was NOT done:**
- No code written yet
- No Xcode project modified
- No files created in the Pure Phase project directory

**State handed to Claude Code:**
Clean start. Full spec. Five documents. Two original Swift files for reference.

---

*Future entries go below this line, newest at top.*

---

## May 2026 — Session 7: Rename to Pure Phase + GitHub repo + Pages live

**The product is now Pure Phase.** A different company is using "NeuroLight" for entrainment hardware. Switched names cleanly.

**Code-side rename** (mostly already in place from incremental work this session):
- `INFOPLIST_KEY_CFBundleDisplayName` = "Pure Phase" (Debug + Release)
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.MarkFriedlander.PurePhase` (Debug + Release)
- `HomeView` and `OnboardingView` wordmark text "PURE PHASE"
- AutomationServer reports `name: "Pure Phase Automation"` from `/help`
- App icon: warm radial pulse (no NL letterform — text removed when name changed; icon is now pure mark)

**Docs scrub:** ran a targeted perl substitution across all five docs replacing `NeuroLight` → `Pure Phase` and `NEUROLIGHT` → `PURE PHASE`, EXCLUDING file paths (`NeuroLight/Models/...`), file names (`NeuroLightApp.swift`), and historical bundle ID references (`com.MarkFriedlander.NeuroLight`). The source folder, Xcode project file, and legacy `NeuroLightApp` struct keep their original names — changing those would be churn for no user benefit.

**GitHub:**
- Repo created at `https://github.com/markfriedlander/pure-phase` (public, default branch `main`)
- `.gitignore` excludes DerivedData, xcuserdata, screenshots, secrets/credentials patterns
- Initial push includes the full Models/Engine/Views/Utilities tree, asset catalog with new icon, automation server, doc set
- GitHub Pages enabled on `main` / root
- `index.html`, `privacy.html`, `support.html` deployed and verified live (HTTP 200) at `https://markfriedlander.github.io/pure-phase/`
- Privacy/support copy uses Strategic Claude's draft, styled in Pure Phase's warm-amber-on-black aesthetic

**Verified on simulator:**
- App launches as `com.MarkFriedlander.PurePhase`
- `/help` returns `name: "Pure Phase Automation", port: 8770`
- Home screen renders with PURE PHASE wordmark
- All previous functionality (tile gestures, breath cues, audio, etc.) intact

**Installed on Mark's iPhone 16 Plus.**

**Standing tasks remaining for 1.0 ship:**
- Launch screen (gradient bar + PURE PHASE fade-in)
- Reduce Motion warning (one-time gentle nudge)
- VoiceOver labels on tile glyphs
- Screenshot automation script for App Store screenshots at all required device sizes
- `INFOPLIST_KEY_NSLocalNetworkUsageDescription` for friendly first-run permission prompt copy
- App Store Connect: 17+ rating, screenshots upload, description (Strategic Claude already drafted), TestFlight invite
- Real-device verification: torch in dark room (Sleep), 40-min Open mode end-to-end, Mac Catalyst window behavior

---

## May 2026 — Session 6 wrap: iOS 17, Layout cap, Restore Defaults, Real interruption handling

**Closed Session 6 with the remaining items from Strategic Claude's mid-session letter, minus the deferred-to-1.1 set.**

**Built/changed:**
- `IPHONEOS_DEPLOYMENT_TARGET` lowered from 26 → **17** in pbxproj. Audited every Swift file for `@available` / `if #available` — none. Every API in use is iOS 17+.
- New `Utilities/Layout.swift` with `Layout.contentMaxWidth = 560`. Applied to HomeView, AdvancedView, SessionConfigView, OnboardingView. Replaced the previous 600 / 700 hard-coded values. iPhone is unaffected (cap is invisible at ≤ 430 pt screen widths). iPad / Mac get a quiet centered column with black margins.
- Mac Catalyst fullscreen verified working out of the box (green button → fills display, app already supports resize).
- Torch UI audit: confirmed every torch-related surface in views is gated by `TorchController.isAvailable` (which returns false on Catalyst). Single guarded surface lives in `SessionConfigView.visualSection`.
- `Utilities/AppStorage+Keys.swift` extended with explicit `StorageDefault` values for every persisted key plus `StorageDefault.restoreAll()` that writes them all in one call.
- `SessionConfigView` gains a "RESTORE DEFAULTS" button below BEGIN. Tracked accessibility identifier `config.restoreDefaults`. Medium haptic on press. Calls `StorageDefault.restoreAll()`.
- AppStorage audit: walked every Toggle, Slider, and Picker in SessionConfigView. Every settable control persists. Single-tap-start correctness now bulletproof.
- **Audio interruption handling moved from `AudioEngine` to `SessionEngine`.** Strategic Claude correctly flagged that the previous handler only paused audio while flicker and torch kept running. New design: SessionEngine observes `AVAudioSession.interruptionNotification`, calls its own `pauseForInterruption()` (invalidates CADisplayLink, forces torch off, sets brightness to 0, calls `audio.pauseForInterruption()`) on `.began`, and `resumeFromInterruption()` (re-creates display link with corrected start time so elapsed continues seamlessly, calls `audio.resumeFromInterruption()`) on `.ended` with `.shouldResume`. AudioEngine no longer owns the observer; just exposes pause/resume methods the engine calls.
- New `SessionEngine.isPaused` published state (observable for future "session paused — resume?" UI).

**Decisions made (with Mark in-session):**
- iOS 17, not 26. Reach > simplicity for early dev.
- Single 560 pt cap, not two-cap. Simpler to reason about; behaves the same on every iPhone regardless.
- 10 min default duration kept (not 20 min). Less committed for everyday use.
- Color mode default off kept (not on). Quieter starting point for first-time users.
- Grey noise deferred to 1.1.
- Halo stutter and 40 Hz Focus pattern change deferred to 1.1 (Mark prefers current halo look; Focus pattern is hardware-bound to non-ProMotion displays).
- `state.isBreathwork` kept; SessionType enum rejected (one source of truth).
- AudioEngine never owns interruption observer again — SessionEngine is the conductor.

**Verified live on simulator:**
- Home → tap FOCUS → `screen=session.focus`, `engine.active=True`, `audio.maxPeak ≈ 0.42`, `audio.engineRunning=True`. End-to-end with real audio output measured.
- Mac Catalyst build → BUILD SUCCEEDED.
- Both iOS Simulator and Catalyst targets build clean.

**Installed on Mark's iPhone 16 Plus.**

**Three explicit deferrals to 1.1** (logged in MEMORY.md "Known Polish Issues"):
1. Halo stutter at breath cycle peaks — blur+scaleEffect interaction. Pre-render to Metal texture in 1.1.
2. 40 Hz Focus pattern change on 60 Hz displays — hardware-bound (non-ProMotion). Fix path: refresh-rate detection + UI hint, or quantized frame-rate flicker.
3. Grey noise ambient option — ISO 226 filtered. Wait for 1.1 to research the published 29-frequency coefficient table and implement an FFT-based filter.

**Engineering notes for the next session (Session 7 — App Store prep):**
- App icon. Currently default. Needs warm glyph on black, gradient language.
- Launch screen. Currently default. Could be the gradient bar + PURE PHASE title fading in.
- Reduce Motion warning on first launch (one-time gentle "this app uses rapid flicker by design").
- VoiceOver labels on all tile glyphs.
- Screenshot automation script — bash wrapper around `/screenshot`, walks all screens, captures at every Apple-required iPhone/iPad/Mac resolution.
- `INFOPLIST_KEY_NSLocalNetworkUsageDescription` so first-time Local Network permission prompt has friendly copy on physical devices.

---

## May 2026 — Session 6 (continued): Live Verification + API Extensions + Port Move + popToRoot

**Drove every Session-6 deliverable through the automation server on the simulator. All passed.**

**API extensions added during testing (per "build what you need" rule):**
- `/state` now includes a `config` block with the active session's `stateID`, `stateHz`, `stateCarrierHz`, `isBreathwork`, all timing/audio/breath/visual settings, plus full breath-pattern timing breakdown and live `breathBPM`. Previously you could see the engine's instantaneous output but not the Hz it was deriving from — that hid Custom-state verification.
- `/state` now includes a `breathCues` block: `fireCount`, `lastStage`, `lastFiredSecondsAgo`. Required for verifying breath cues actually fire.
- `AutomationBus.recordBreathCue(stage:)` — bumped from `SessionView.onChange(of: engine.breathStageName)` whenever a cue tone is scheduled.
- `/help` now reports the bound port.
- `popToRootTicket: Int` on the bus, observed by ContentView. `/navigate to=home` now bumps the ticket to actually clear the navigation stack — previously it only cleared request flags, leaving you stranded on Advanced.

**Port moved 8765 → 8770.** Another simulator app ("Posey") owns 8765. Conflict was silent — server failed to bind, requests were going to whoever responded first. Moved to 8770 (Pure Phase-specific). Documented in source and HANDOFF.

**Small bug fixed during verification:**
- `SessionView` was gating breath cue firing on `engine.brightness > 0.05`, which meant the very first Inhale cue at session start was missed (brightness needed ~0.15s to clear the threshold). The master fade envelope already mutes cues during fade-in via `mixer.outputVolume = brightness`, so the explicit gate was redundant *and* missed the opening cue. Removed.

**Verified end-to-end on iPhone 17 Pro simulator:**

| Test | Result |
|---|---|
| Home shows BREATHE as fourth tile (wind glyph) | ✓ screenshot 15 |
| Tap BREATHE → breath-only session starts | ✓ |
| Breath-only session: `flickerPhase=false`, `isBreathwork=true`, `audioEnabled=false`, `torchEnabled=false`, `colorMode=false` | ✓ |
| Visual: black canvas, enlarged centered cream ring, soft warm halo behind it, INHALE label | ✓ screenshot 16 |
| Breath cues: toggle on, run 16 s, count = 3 transitions (Coherence 5/0/5/0) — exact match | ✓ |
| Breath cue last fired ~1 s before query (correct timing) | ✓ |
| Custom Hz: set `customHz=7.5`, `customCarrierHz=200` via `/set` | ✓ |
| Start Custom session → `config.stateHz=7.5`, `config.stateCarrierHz=200` reported back | ✓ |
| Custom config screen renders FREQUENCY section with sliders at 7.5 / 200 | ✓ screenshot 19 |
| Custom breath: set 4/4/4/4, select pattern "Custom", start session | ✓ |
| Active config reports `breathPattern="Custom"`, all four phases = 4, BPM = 3.75, cycle = 16 s | ✓ |
| Breathwork config screen: AMBIENT header, Breath cues toggle, no VISUAL section | ✓ screenshot 18 |
| Screen-name fix: Advanced → Theta → exit → screen reports `advanced` (was `home`) | ✓ |
| `/navigate to=home` from Advanced → actually pops to Home | ✓ (after popToRootTicket fix) |

**Not yet verified (deferred — needs phone hardware or hands-on):**
- Audio interruption: Siri / phone call mid-session pause/resume. Hard to reproduce in sim. Verify on physical phone with a real call.
- "Use Pure Phase audio or keep my music?" prompt — `isOtherAudioPlaying` is exposed but no UI gate yet.
- Cream ring + halo *audibility* of cue tones. Code looks right; ear test pending.

**Installed on Mark's iPhone 16 Plus.** Try it — BREATHE tile, tap to start, hold to tune.

---

## May 2026 — Session 6: Custom + Custom Breath + Breathwork Mode + Audio Interruption (Claude Code)

**Built without device access** (Mark's iPhone and sim were in use by another instance). All changes verified by iOS Simulator and Mac Catalyst builds — both BUILD SUCCEEDED. Live verification on hardware queued for when Mark frees up.

**Custom-state Hz / carrier — closed.**
- `Models/BrainwaveState.swift` — added `isCustom`, `isBreathwork`, and `resolvingCustomValues()` MainActor method that reads `customHz` / `customCarrierHz` from AppStorage and returns a state copy with those values. Static catalog stays immutable; the custom resolution happens at SessionConfig build time.
- `Utilities/AppStorage+Keys.swift` — added `customHz` (default 10.0), `customCarrierHz` (default 174.0). `StorageDefault` enum centralizes defaults.
- `Views/SessionConfigView.swift` — for `state.isCustom`, a `FREQUENCY` section appears at the top: brainwave-Hz slider (0.5–40, 0.5 steps) and carrier slider (80–440 Hz, 2 Hz steps), each with live monospaced numeric readout.

**Custom breath pattern — closed.**
- `Models/BreathPattern.swift` — added `BreathPattern.custom()` factory (MainActor) that builds a "Custom" pattern from the four custom-breath AppStorage keys, and `allChoices()` that returns presets + custom. `preset(named:)` now resolves "Custom" through `custom()`.
- `Utilities/AppStorage+Keys.swift` — added `customBreathInhale`, `customBreathInhaleHold`, `customBreathExhale`, `customBreathExhaleHold` (default 5/0/5/0 = Coherence).
- `SessionConfigView.swift` — pattern picker now lists Custom as a fifth row (BPM displayed live, "—" if cycle = 0). When Custom is selected, four sliders (1–12 s, 0.5 s steps; holds 0–12) appear with monospaced second-readouts. A live "X.X BPM · Ys cycle" line shows the result. Sub-2-BPM warning appears in red below.

**Breath-only mode — built.** Per Mark's preference: option (a) — fourth tile on Home, alongside FOCUS/CALM/SLEEP. Halo (ii) — soft warm radial behind a centered enlarged ring. Tones toggleable.
- `Models/BrainwaveState.swift` — added `BrainwaveState.breathwork`. `id = "breathwork"`, `hz = 0`, `carrierHz = 0`, `allowTorch = false`, warm amber tint. Added to `BrainwaveState.all` (so `state(forID:)` finds it) but **not** to `.primary` or `.advanced` collections (so existing iterators don't pick it up incidentally).
- `Models/SessionConfig.swift` — added `breathAudioCues: Bool` and `breathCueVolume: Double` fields. `default(for:)` adapts when state is breathwork: audio off, ambient off, breath enabled, no cues by default.
- `Views/HomeView.swift` — fourth tile with `wind` SF Symbol pointing at `BrainwaveState.breathwork`. Same `tileGesture` (tap = start with current settings, long-press = config). `home.tile.breathwork` and `home.tile.breathwork.config` actions registered.
- `Views/SessionConfigView.swift` — branches on `state.isBreathwork`:
  - Section header changes from `AUDIO` to `AMBIENT`.
  - Replaces "Sound" toggle with "Breath cues" toggle + cue-volume slider.
  - Hides the entire `VISUAL` section (no flicker, no torch).
  - Breath guide is mandatory — no toggle.
- `Views/SessionView.swift` — major branching:
  - Skips the flicker layer when `state.isBreathwork`.
  - Renders a soft warm radial halo behind the ring, gently breathing with `breathPhase` (per Mark's halo (ii)).
  - Passes `enlarged: true` to BreathGuideView.
  - On `breathStageName` change, fires `engine.audio.playBreathCue(stage:volume:)` if `breathAudioCues` is on. Tracks `lastBreathStage` so cues fire on transitions, not every tick.
- `Views/BreathGuideView.swift` — new `enlarged: Bool` param. Larger size (320 vs 240), thicker stroke (2.8 vs 2.2), thicker halo, larger label offset.
- `Engine/AudioEngine.swift` — added `cueNode` (third AVAudioPlayerNode), `playBreathCue(stage:volume:)`, and `makeCueBuffer(stage:format:)` which synthesizes:
  - **Inhale:** rising sine sweep 260→440 Hz over 220 ms (perfect-fourth rise)
  - **Exhale:** falling sine sweep 440→260 Hz over 220 ms
  - **Hold:** sustained 220 Hz for 180 ms
  - All with soft attack/release envelopes to prevent clicks.

**Audio interruption — handled.**
- `Engine/AudioEngine.swift` — `init()` registers an observer on `AVAudioSession.interruptionNotification`. On `.began`: pauses all three nodes and the engine. On `.ended` with `.shouldResume` option set: reactivates the audio session and restarts. Phase realignment is best-effort (we don't try to resync flicker math; the user won't notice).
- `AudioEngine.isOtherAudioPlaying` static property exposed so future onboarding can offer "use Pure Phase audio or keep my music" choice (the prompt itself isn't wired into the UI yet — deferred until next session, since it's a small UX decision: ask once, ask every session, etc.).

**Screen-name bookkeeping — fixed.**
- `Views/SessionView.swift` — saves the previous `bus.currentScreen` value on appear, restores it on disappear. No more clobber to `"home"` after exiting a session that came from Advanced.

**Builds verified:**
- iOS Simulator: BUILD SUCCEEDED
- Mac Catalyst: BUILD SUCCEEDED

**Pending verification on hardware (when Mark's phone/sim free up):**
- Tap BREATHE on Home → centered ring on black with warm halo
- Toggle "Breath cues" on → hear three distinct tones at each phase transition
- Custom state long-press → see Hz / carrier sliders, change them, start session, verify Hz stuck
- Custom breath: pick Custom row, drag sliders to e.g. 4/4/4/4, see "3.8 BPM · 16s cycle"
- Trigger an interruption (Siri or a phone call) mid-session, verify audio pauses and resumes
- After exiting a Theta session from Advanced, `GET /state` should report `screen: advanced` (not `home`)

**Known deferred:**
- "Use Pure Phase audio or keep my music?" prompt — wired in `isOtherAudioPlaying` but no UI gate yet.
- Reduce Motion warning, App icon, launch screen, VoiceOver pass — Session 7.
- Privacy policy text + App Store description draft — Session 8.

---

## May 2026 — Session 5: Tap-to-Start, AdvancedView, Ring Fix (Claude Code)

**Built/changed:**
- `BreathGuideView.swift` — ring stroke now warm cream (`#FFF2DC`) at 0.92 opacity, line width 2.2, with shadow halo. Warm tint moved to a soft radial halo behind the ring. Ring stays visible regardless of where the flicker is in its cycle. Per Mark's feedback: previously the ring used the state tint and disappeared when the flash matched.
- `SessionView.swift` — breath overlay opacity bumped from 0.55 to 0.85 to match.
- `Models/SessionConfig.swift` — added `fromAppStorage(state:)` factory that reads every persisted setting and falls back to the universal default. This is the config used by single-tap-start.
- `Views/Components/TileGesture.swift` — new `tileGesture(onTap:onLongPress:)` view modifier. LongPressGesture (0.45 s) `exclusively(before:)` TapGesture so the long-press wins when held. Medium haptic on long-press fire. Subtle scale + opacity press feedback.
- `Views/HomeView.swift` — three primary tiles now use `tileGesture`. **Single tap = start a session immediately with the user's last-saved settings; long press (~½ s) = open Session Config.** "tap to begin · hold to tune" hint text under the title. ADVANCED affordance pushes AdvancedView via the new `NavigationRoute.advanced` value.
- `Views/AdvancedView.swift` — **new.** Five tiles (theta / SMR / psychedelic / void / custom) using the same gesture pattern, plus per-tile Hz label. Disclaimer: "less studied — explore with care".
- `Engine/NavigationRoute.swift` — new tiny enum used for non-state-id navigation pushes (currently just `.advanced`).
- `ContentView.swift` — switched to typed `NavigationPath` so we can push both String state-ids and NavigationRoute values onto the same stack with separate `navigationDestination` resolvers. Observes `bus.requestedRoute` to push Advanced from the API.
- `Engine/AutomationBus.swift` — added `requestedRoute: NavigationRoute?`.
- `Engine/AutomationServer.swift` — `/navigate to=advanced` now pushes Advanced. `/navigate to=home` clears both the config request and the route.

**Action registry now exposes:**
- `home.tile.{focus,calm,sleep}` — tap-equivalent (start session with current settings)
- `home.tile.{focus,calm,sleep}.config` — long-press-equivalent (open config)
- `home.advanced` — push AdvancedView
- `advanced.tile.{theta,smr,psychedelic,void,custom}` — tap-equivalent
- `advanced.tile.{theta,smr,psychedelic,void,custom}.config` — long-press-equivalent
- `config.begin` — Begin button on SessionConfig
- `session.exit` — close button during session
- `onboarding.{toggle,accept,enter}`

**Verified end-to-end on simulator (curl from Mac):**
- `POST /tap home.tile.focus` → goes straight from Home into a live Focus session (engine running, brightness 1, breath cycling). Single-tap-start works.
- `POST /tap session.exit` → fade-out and back.
- `POST /navigate to=advanced` → AdvancedView appears, advanced.tile.* actions registered.
- `POST /tap advanced.tile.theta` → Theta session running.
- Screenshots `12_focus_with_cream_ring.png` (new ring is **clearly** visible against black with warm halo), `13_advanced.png` (5 advanced tiles), `14_theta_session.png` (cream ring on amber-Theta backdrop).

**Installed on Mark's iPhone 16 Plus.**

**Known small issue (deferred):** when SessionView dismisses, `bus.currentScreen` is set to `"home"` unconditionally, even if the underlying view is Advanced. The actions list correctly reflects the actual screen (the only consumer that matters); the screen string is the only thing wrong. Will fix by removing the clobber and letting the underlying view's last-set value stick, or by saving/restoring around presentation.

**Engineering notes for Session 6:**
- Custom state still uses model defaults (10 Hz / 174 Hz carrier). A dedicated `CustomConfigView` with Hz + carrier + custom breath sliders is the next obvious add — wire it into long-press on `advanced.tile.custom`.
- Add `INFOPLIST_KEY_NSLocalNetworkUsageDescription` to pbxproj so first-time Local Network permission prompt on physical device has friendly copy.

---

## May 2026 — Session 4: HTTP Automation + Tap Fix + Polish (Claude Code)

**Bug fixes (in flight from Session 3 feedback):**
- `IntentTileView` was a Button with simultaneousGesture; under NavigationLink that swallowed taps. Rewritten as pure presentation. Home navigation now actually navigates.
- Onboarding font sizes bumped (body 19pt, warning 17pt, checkbox 15pt, ENTER 15pt). Mark called the previous sizes hard to read.
- HomeView, OnboardingView, SessionConfigView wrapped in ScrollView with `maxWidth` caps so they reflow cleanly in landscape and on Catalyst.
- ContentView had a logic bug where setting `bus.requestedConfigState = nil` after consuming a navigation request caused the same `.onChange` to fire and pop the stack. Fixed by using `guard let` to ignore nils and `DispatchQueue.main.async` to defer the clear. Same fix applied to `bus.requestedSession`.

**Built (foundational infra — debug-only HTTP automation):**
- `Engine/AutomationBus.swift` — always-compiled `@Observable` singleton coordinating views and the server. Holds current screen, current engine, last event, inbound navigation/session requests, and an accessibility-id-keyed action registry. Also serves as the Begin button's signal path so the router can present SessionView from one place.
- `Engine/AutomationHTTP.swift` — DEBUG-only HTTP/1.1 parser and response builder. No third-party dependencies.
- `Engine/AutomationServer.swift` — DEBUG-only `NWListener` server on port 8765. Verbs: `/state`, `/actions`, `/screenshot`, `/tap`, `/set`, `/navigate`, `/reset-onboarding`, `/onboarding/accept`, `/session/start`, `/session/stop`. Each verb has parity with one or more user-facing surfaces.
- `NeuroLightApp.swift` — starts the server in `init()` under `#if DEBUG`. Stripped from Release.
- Every interactive surface registers an accessibility identifier and bus action: `onboarding.toggle/accept/enter`, `home.tile.focus|calm|sleep`, `home.advanced`, `config.begin`, `session.exit`.

**Decisions made (with Mark in-session):**
- HTTP automation tool is foundational, not optional. Built now rather than deferred — Mark explicitly pushed for it after seeing taps fail to land in the third-party simulator MCP.
- "Parity rule": every new user-facing surface gets a corresponding API verb in the same change. Documented in `HANDOFF_BRIEF.md`.
- Bus is always compiled (Release too) because Begin button routes through it. Server is DEBUG-only.
- Server binds to all interfaces (not just loopback) so the Mac can reach a physical iPhone over Wi-Fi.

**Verified end-to-end (curl from Mac → simulator):**
- `POST /tap home.tile.focus` → screen becomes `config.focus`, `config.begin` registered.
- `POST /session/start {state:"sleep", duration:"five"}` → SessionView presents; engine starts.
- `GET /state` returns live engine telemetry: `flickerPhase`, `brightness`, `breathPhase`, `breathStageName`, `elapsed`, `remaining`, `sessionProgress`.
- `POST /tap session.exit` → engine stops, view dismisses, screen returns to home.
- Screenshots `09_after_calm.png` and `10_sleep_session.png` confirm the warm aesthetic running cleanly.

**Installed on Mark's iPhone 16 Plus** (`devicectl install app`).

**Engineering notes for Session 5:**
- AdvancedView still pending (theta, smr, psychedelic, void, custom Hz, custom breath, carrier-freq selector). Add `home.advanced` action to navigate, `advanced.tile.<id>` for each, and `/navigate to=advanced` server verb.
- iOS may prompt for Local Network permission on physical device first hit. Add `INFOPLIST_KEY_NSLocalNetworkUsageDescription` to pbxproj if the prompt becomes friction.
- The third-party `mcp__ios-simulator__ui_tap` is no longer needed for our flows — the embedded server bypasses it entirely.

---

## May 2026 — Session 3: Core Views + Aesthetic Lock-In (Claude Code)

**Built (10 LEGO blocks):**
- `Utilities/AppStorage+Keys.swift` — centralized UserDefaults key constants.
- `Views/Components/IntentTileView.swift` — sparse home tile (ultra-light SF Symbol + tracked-caps label, soft glow, quiet press feedback).
- `Views/Components/GradientProgressRing.swift` — 1-pt rounded-rectangle stroke traced from top-center, peripheral by design.
- `Views/OnboardingView.swift` — checkbox-gated first-launch warning, no medical claims.
- `Views/HomeView.swift` — three glyphs on black: viewfinder (FOCUS), water.waves (CALM), moon.fill (SLEEP). NavigationStack with hidden toolbar; ADVANCED affordance at bottom.
- `Views/SessionConfigView.swift` — duration / audio / breath / visual sections, all `@AppStorage`-backed; torch row hidden via `TorchController.isAvailable` (Catalyst rule).
- `Views/BreathGuideView.swift` — single warm ring, ease-in-out scale, hold-stage shimmer at 0.5 Hz.
- `Views/SessionView.swift` — full-screen flicker × `engine.brightness`, breath overlay, edge progress ring, tap-reveal exit + remaining time with 3 s auto-hide, idle-timer disabled while running, psychedelic warm hue drift.
- `ContentView.swift` — replaced placeholder with a real router: `OnboardingView` until acknowledged, then `HomeView`. `preferredColorScheme(.dark)`.

**Updated:**
- `Models/BrainwaveState.swift` — tints rewritten to **warm-only** palette per Mark. Sleep ember-red (0x8B2E1F → 0x1A0503), Calm peach-to-brick (0xD9824A → 0x8B3A2A), Theta amber-to-maroon, Void deep ember-black, Psychedelic warm magenta-red. No blues anywhere — aligns with sleep-onset light research.

**Decisions made (with Mark in-session):**
- Warm-only palette across all states — explicit from Mark, scientifically appropriate for relaxation/sleep contexts.
- Glyph-driven home (SF Symbols, sparse).
- Slow fade-up handled implicitly by engine brightness; views multiply by it. No extra view animation needed.
- Edge progress ring is non-invasive; hidden in Open mode (sessionProgress is nil).
- HTTP automation tool moved up to **Session 4** (per Mark, "sooner is better — baked in from go, grows in parity with the feature set"). Treated as foundational debug infrastructure.

**Verified:**
- iOS Simulator build → BUILD SUCCEEDED.
- iOS Device build → BUILD SUCCEEDED, installed on Mark's iPhone 16 Plus via `devicectl`.
- Onboarding screen confirmed visually correct (warm gradient, dim red warning, gated checkbox, ENTER button enables on accept).
- Home screen confirmed visually correct (black canvas, three warm glyphs in proper tints, PURE PHASE title, ADVANCED affordance).

**Engineering notes for Session 4:**
- Third-party `mcp__ios-simulator__ui_tap` reports success but coordinate mapping is unreliable. The new HTTP automation tool should bypass it entirely — hook the app directly via a debug-only embedded HTTP server with verbs for navigation, settings, taps by `accessibilityIdentifier`, session control, and live state observation.
- Continue the `accessibilityIdentifier` convention started on home tiles (`home.tile.focus|calm|sleep`) on every interactive element going forward.
- A NavigationStack with default toolbar will paint a white background under SwiftUI's iOS 26 default — fix by `.toolbar(.hidden, for: .navigationBar)` plus `.background(Color.black)` on the NavigationStack.
- Onboarding reset for testing: `xcrun simctl spawn <udid> defaults delete com.MarkFriedlander.NeuroLight hasSeenOnboarding`.

---

## May 2026 — Session 2: Engine Layer (Claude Code)

**Built (3 LEGO blocks, in order):**
- `NeuroLight/Engine/TorchController.swift` — `@Observable` class wrapping `AVCaptureDevice` torch. `isAvailable` returns false under Catalyst; `setOn(_:)` is guarded with `#if !targetEnvironment(macCatalyst)`. Adds `forceOff()` for clean session shutdown. Views read `isAvailable` to hide torch UI entirely under Catalyst per project rule.
- `NeuroLight/Engine/SessionEngine.swift` — the master clock. `@Observable`. CADisplayLink-driven. Mathematical phase computation: `flickerPhase = sin(2π × effectiveHz × t) > 0`. Owns `audio` and `torch` sub-engines and drives them from each tick (audio mixer volume = brightness; torch fires only on edges to avoid hammering hardware). 3 s linear fade-in, 30 s linear fade-out (skipped in Open mode). Psychedelic state applies ±20% drift on a 15 s cycle. Walks the breath pattern's four stages and publishes `breathPhase` (0–1 within stage) and `breathStageName`. `sessionProgress` is `Double?` — nil in Open mode so views can hide the ring.
- `NeuroLight/Engine/AudioEngine.swift` — `AVAudioEngine` with two `AVAudioPlayerNode`s and an `AVAudioMixerNode`. Isochronic buffer = carrier sine × square-with-soft-edges envelope; cycles-per-loop = round(pulseHz) for clean wraparound on integer Hz, longer loops for non-integer. Pink noise via Voss-McCartney (16 octaves). Brown noise via leaky integration. Drone via 110 Hz sustained sine. Loop edges crossfaded (2048-frame ramp) to suppress click. Audio session category `.playback`, activated on start, deactivated on stop. All synthesis on the main thread at `start()` — fast enough for v1; can move to background later if startup latency surfaces.

**Decisions made (with Mark in-session):**
- Start/Stop only, **no pause** in v1. Pausing breaks entrainment.
- Audio fades in alongside the visual over the same 3 seconds.
- Completion behavior owned by Views. Engine performs the 30 s fade-out, fires `completionHandler`, returns to idle. Final visual choreography (gradient shimmer / return to home) is `SessionView`'s job — keeps the engine pure and lets us tune feel without touching timing.
- Psychedelic drift kept at original ±20% / 15 s.
- 40 Hz unevenness on 60 Hz devices is accepted. 120 Hz iPhones render perfectly clean 3-on / 3-off.

**Verified:**
- iOS Simulator build → BUILD SUCCEEDED.
- Mac Catalyst build → BUILD SUCCEEDED.

**What was NOT done (per session boundary):**
- No Views code.
- No `ContentView.swift` changes — still the minimal "models layer ready" placeholder. The real Home / Session / Advanced views land in Session 3, gated on Mark's answers to the four open UX questions in NEXT.md.

**Engineering notes for Session 3:**
- Views observe `SessionEngine` directly. They do not animate from their own clocks — every visible change should derive from a published value (`brightness`, `flickerPhase`, `breathPhase`/`breathStageName`, `sessionProgress`).
- `SessionView` should multiply the flash color's opacity by `engine.brightness` so fade-in/fade-out is automatic.
- `BreathGuideView` should map `breathPhase` (0–1) to scale within the current stage. An ease-in-out curve is appropriate; the engine itself uses linear phase, leaving the curve to the view.
- Torch UI in `SessionConfigView` and `AdvancedView` must be wrapped in a check on `TorchController.isAvailable` — hide entirely when false (Catalyst).

---

## May 2026 — Session 1 Addendum 2: Documentation-Only Pass

**No Swift code touched this session.** Captured decisions from a parallel discussion between Mark and Strategic Claude, plus a clarification on Catalyst torch behavior.

**Clarified:** Under Mac Catalyst, all torch-related UI must be **hidden entirely** (not just disabled). All session output runs through the screen on Catalyst. Engine still no-ops torch calls as defense-in-depth. Updated `MEMORY.md` (iOS 26 + Catalyst decision) and the platform-scope auto-memory file to match.

**Added to `MEMORY.md`:**
- New section "Phase 4 Concepts — Do Not Build Yet" with the closed-loop biofeedback / Apple Watch HR streaming entry.
- Decision: Age rating 17+.
- Decision: No medical claims anywhere in app or App Store listing — with explicit approved/prohibited language list and the regulatory rationale (disease-name association triggers FDA medical device classification, not because the science is unsound).
- Decision: Privacy policy hosted on GitHub Pages (zero data collection, but App Store still requires a policy).

**Added to `NEXT.md`:**
- New "Pre-Submission Checklist — Before App Store" section: privacy policy, 17+ rating, language review, warning-on-first-launch checkbox, `@AppStorage` persistence of consent, screenshots, TestFlight.
- Deferred screenshot-automation note: a debug-only local HTTP control layer for programmatic UI driving and exhaustive screenshot capture, stripped from release builds. Scheduled for Session 4 or 5.

**Added to `HANDOFF_BRIEF.md`:**
- Standing rule: this documentation pass must be confirmed complete before any Swift code is written next session.
- Standing rule: the four open UX questions (breath guide visual, home tile layout, session entry transition, progress indicator) must be answered by Mark before Views are built — no inventing.
- Standing rule: Catalyst torch UI hidden entirely.

**Saved to auto-memory:**
- Updated `feedback_platform_scope.md` to capture the "hide torch UI on Catalyst" clarification.
- Added `feedback_no_medical_claims.md` for durable copy-writing guardrails.

---

## May 2026 — Session 1 Addendum: Platform Scope Change

**Decided with Mark:** iOS 26 is the locked minimum (no backporting to 16). Mac Catalyst is enabled — the app now also runs on Mac as if it were an iPad.

**Implemented:**
- `SUPPORTS_MACCATALYST = YES` added to both Debug and Release target configurations in `project.pbxproj`.
- `IPHONEOS_DEPLOYMENT_TARGET = 26.0` confirmed (already in place).
- `TARGETED_DEVICE_FAMILY = "1,2"` confirmed.

**Doc updates:**
- `CLAUDE.md` — "iOS only" engineering rule replaced with "iOS 26 + Mac Catalyst", with explicit guidance to use `#if targetEnvironment(macCatalyst)` not `#if os(macOS)`.
- `MEMORY.md` — original "iOS only for v1" decision marked SUPERSEDED, new "iOS 26 + Mac Catalyst" decision logged with rationale.
- `neurolight_design_spec.md` — Section 12 rewritten to reflect new platform scope.
- `HANDOFF_BRIEF.md` — environment block updated; both build verifications recorded.

**Verified:**
- iOS Simulator build → BUILD SUCCEEDED.
- Mac Catalyst build → BUILD SUCCEEDED.

**Engineering note for future sessions:** Torch (`AVCaptureDevice`) is iOS-only. Under Catalyst the device has no torch. Guard at the `TorchController` level (silent no-op when running under Catalyst) rather than branching any view code.

---

## May 2026 — Session 1: Models Layer (Claude Code)

**Built:**
- `NeuroLight/Models/BrainwaveState.swift` — `EvidenceTier`, `SessionTint` (gradient pair), `Color(hex:)`, full eight-state catalog (focus, calm, sleep, theta, smr, psychedelic, voidState, custom) with stable string IDs, primary/advanced/all collections, `state(forID:)` lookup.
- `NeuroLight/Models/BreathPattern.swift` — four presets (Coherence, 4-7-8, Box, Slow Wave), `cycleDuration` and `bpm`, `default = .coherence`, `preset(named:)` lookup.
- `NeuroLight/Models/SessionConfig.swift` — `SessionDuration` (5/10/20/40/Open with `minutes: Double?` and `hasFadeOut`), `AmbientSoundType` (pink/brown/drone/off), `SessionConfig` struct, universal `default(for:)` factory.

**Replaced:**
- `NeuroLight/ContentView.swift` — legacy single-file UI (broken nested-Timer flicker, commented-out audio, iCloud UserDefaults suite bug, seven undifferentiated states, macOS branches, shake-to-exit, embedded `SettingsView`/`IntroView`/`flickerColor`) replaced with a minimal black "models layer ready" placeholder. Necessary because the legacy file defined a duplicate `BrainwaveState` that collided with the new model. The real Home / Session / Advanced views are scheduled for Session 3.

**Decisions made this session:**
- Stable string IDs on `BrainwaveState` (not UUIDs) — required for any future `@AppStorage` persistence to round-trip.
- `nonisolated` on all model types — pure value types that should be usable from any actor context, despite project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
- `SessionTint` carries both ends of a gradient (start + end hex) so Views can choose between gradient and a dominant solid color per surface.
- `void` named `voidState` in code (Swift keyword collision); displayName remains "VOID".
- Universal `SessionConfig.default(for:)` rather than per-state defaults — simpler, less surprising.

**Verified:**
- `xcodebuild -scheme Pure Phase -destination 'generic/platform=iOS Simulator' -configuration Debug build` → BUILD SUCCEEDED.

**Confirmed with Mark:**
- "Open" duration = no time limit, runs until tap-to-exit; all other durations end with a 30-second fade.
- Stable string IDs are fine; user-facing labels are FOCUS/CALM/SLEEP etc.
- Aesthetic for forthcoming Views: Virtual Light colors, sparser than legacy UI, glyph-driven over text-driven.

**What was NOT done:**
- No Engine code, no Views code (per session boundary).
- No `project.pbxproj` edits needed — synchronized folder groups handle it.

---
