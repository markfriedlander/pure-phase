# MEMORY.md — Pure Phase Strategic Record
*The why behind every major decision. Prevents relitigating settled questions.*

---

## Current Architecture

### Overview
Pure Phase is a SwiftUI iOS app with a clean separation between engine logic and presentation. A single `SessionEngine` owns all timing during a session. Views observe published state from the engine. Audio runs in `AudioEngine`, a separate class that receives timing signals from `SessionEngine`.

### Layer Diagram
```
Views (SwiftUI)
    ↓ observes
SessionEngine (CADisplayLink — master clock)
    ├── publishes: flickerPhase, breathPhase, sessionProgress, brightness
    ├── owns: session state, elapsed time, fade envelope
    └── signals: AudioEngine (isochronic pulse trigger)

AudioEngine (AVAudioEngine)
    ├── isochronic tone player (carrier × pulse envelope)
    └── ambient texture player (pink/brown noise or drone)

TorchController
    └── AVCaptureDevice torch — on/off per flickerPhase
```

### Data Flow
`SessionConfig` → `SessionEngine.start(config:)` → engine runs → views update via `@Published` or `@Observable` → session ends → engine signals completion → `SessionView` dismisses

---

## Major Decisions & Rationale

### Decision: Three primary states only on home screen
**Date:** May 2026
**Decision:** Home screen shows FOCUS, CALM, SLEEP only. All other states behind Advanced panel.
**Rationale:** Original app showed seven states including SMR, Psychedelic, Void — jargon-heavy and undifferentiated. The three primary states have the strongest clinical evidence for photic entrainment specifically. Cleaner entry point, more trustworthy app. Advanced users who want Theta or custom Hz can find it one level deeper.
**Do not revisit** unless user research shows the three-state model is confusing.

### Decision: FOCUS=40Hz, CALM=10Hz, SLEEP=2Hz
**Date:** May 2026
**Decision:** These are the three clinically supported frequencies for the primary states.
**Rationale:**
- 40Hz: MIT Picower Institute research (Li-Huei Tsai), Nature 2024 paper, multiple independent replications, active Phase 3 trials via Cognito Therapeutics. Strongest evidence in the entire brainwave entrainment literature.
- 10Hz: Decades of Alpha EEG suppression in relaxation/anxiety literature. Most replicated entrainment finding after Gamma.
- 2Hz: Delta sleep architecture is well-established. Photic Delta entrainment for sleep onset is supported, though mechanism debate continues.
**Advanced states:** Theta (6Hz), SMR (13.5Hz), Psychedelic (8Hz), Void (0.5Hz), Custom — available but explicitly framed as "less studied."

### Decision: Isochronic tones, not binaural beats
**Date:** May 2026
**Decision:** Audio entrainment uses isochronic tones (audible carrier pulsed at brainwave rate).
**Rationale:** Original code attempted to play a sine wave at the brainwave frequency (e.g., 10Hz) — this is inaudible and wrong. Binaural beats require headphones and have inconsistent entrainment evidence. Isochronic tones work with any speaker, have cleaner entrainment data, and can be precisely synchronized to the visual flicker. Carrier frequency is an audible tone (136–220Hz range) with amplitude envelope pulsing at the target Hz.

### Decision: CADisplayLink replaces nested Timer
**Date:** May 2026
**Decision:** Session timing uses CADisplayLink. Flicker state computed mathematically from elapsed time.
**Rationale:** Original code used nested recursive Timer calls (50ms outer + interval inner). This approach accumulates timing error, is fragile under thread pressure, and at 40Hz Gamma (12.5ms intervals) is unreliable. CADisplayLink fires at display refresh rate (60/120Hz), and computing `sin(2π × targetHz × elapsed) > 0` gives mathematically correct phase at any moment without error accumulation.

### Decision: One SessionEngine owns all timing
**Date:** May 2026
**Decision:** Single timing source for flicker, audio, breath guide, and progress.
**Rationale:** Separate timers drift. Drift between visual flicker and audio pulse defeats the purpose of combined audiovisual entrainment. One clock, one elapsed time reference, all outputs derived from it.

### Decision: Breath and flicker are independent channels
**Date:** May 2026
**Decision:** Breath pacing and light flicker run at their own rates; they do not need to align.
**Rationale:** They are entraining different systems — respiratory/vagal tone (breath) vs. cortical oscillation (flicker). A 6 BPM breath cycle and 10Hz Alpha flicker have no natural common frequency. Forcing alignment would require compromising one or both. They share a start time and clock source but run at their own periods.

### Decision: Project renamed NeuroLight → Pure Phase
**Date:** May 2026
**Decision:** Public name of the app is **Pure Phase**. Bundle identifier `com.MarkFriedlander.PurePhase`. Display name (CFBundleDisplayName) "Pure Phase". Wordmark text in Onboarding/Home/Advanced reads "PURE PHASE". GitHub repo at `markfriedlander/pure-phase`. Pages live at `https://markfriedlander.github.io/pure-phase/{privacy,support}.html`.
**Rationale:** Discovered another company is using "NeuroLight" for entrainment hardware. Conflict avoided by changing names. "Pure Phase" was confirmed clean on the App Store (only adjacent results were unrelated UPS battery apps). Bundle ID was confirmed available.
**Note on history:** Older HISTORY entries and inline source-file path references intentionally retain the original "NeuroLight" name where it accurately describes what was true at the time (the source folder, the Xcode project file name, and the legacy struct `NeuroLightApp` are still on disk under the original names — changing those would create churn for no user-visible benefit). The product is Pure Phase; the source tree happens to have an old internal codename.

### Decision: Minimum deployment target is iOS 17
**Date:** May 2026
**Decision:** iOS 17.0 minimum.
**Rationale:** Originally set to iOS 26 for early-development simplicity, but iOS 26 as a minimum would have made the app invisible to almost everyone at launch. iOS 17 has been shipping for years and covers essentially all active iPhones. Every API in use (NavigationStack, @Observable, AVAudioEngine, CADisplayLink, AVCaptureDevice, @AppStorage) is available on iOS 17.
**Supersedes:** the earlier "iOS 26 + Mac Catalyst" decision below — iOS 26 part replaced; Mac Catalyst part still stands.

### Decision: Multi-platform support — Mac Catalyst + iPad
**Date:** May 2026
**Decision:** App ships on iPhone (primary), iPad, and Mac via Catalyst. Three specific accommodations only:
1. **Mac fullscreen** — works out of the box via Catalyst's green button. Verified.
2. **Torch hidden on non-iPhone** — `TorchController.isAvailable` returns false on Catalyst (and on any iPhone without torch hardware), so SessionConfigView never renders the flashlight toggle there. UI surface gated cleanly.
3. **Max-width 560 pt content cap** — `Layout.contentMaxWidth` constant applied to Home, Advanced, SessionConfig, Onboarding. Cap is invisible on every iPhone (≤ 430 pt naturally). Centers content with black margins on iPad / Mac.
**Out of scope:** any further platform-specific behavior. Session screens (flicker, breath ring, edge progress) stay full-bleed on every platform — the experience scales naturally.

### Decision: Single 560 pt content cap
**Date:** May 2026
**Decision:** One layout constant, `Layout.contentMaxWidth = 560`, used by every navigational/configuration view. Session experience (flicker, breath ring, progress) ignores the cap.
**Rationale:** Two-cap proposals (e.g., 500 for tiles, 600 for forms) would require maintaining two constants and judgment about which view uses which. 560 splits the difference, fits comfortably on iPad and Mac, and is invisible on every iPhone.

### Decision: iOS 26 + Mac Catalyst
**Date:** May 2026 (revised mid-Session 1)
**Decision:** Minimum iOS raised to 26. Mac Catalyst enabled — the app runs on Mac as if it were an iPad. Native AppKit/macOS code is still removed; the legacy `#if os(macOS)` branches are gone for good.
**Rationale:** Targeting iOS 26 lets us use the newest SwiftUI/AVFoundation features without backporting. Limiting the audience to recent iPhones is acceptable because this is not a commercial release. Catalyst gives Mark a native Mac development and use experience without forcing us to maintain a parallel AppKit codebase. Torch is simply unavailable under Catalyst — guard the call sites at the engine level rather than branching the UI.
**Implementation:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `SUPPORTS_MACCATALYST = YES`, `TARGETED_DEVICE_FAMILY = "1,2"`. Catalyst-specific gating uses `#if targetEnvironment(macCatalyst)`, never `#if os(macOS)`.
**Torch behavior under Catalyst:** Hide every torch-related control from the UI entirely (no toggle, no mention) — the user must not see a dead setting. All session output runs through the screen on Catalyst. The engine layer additionally no-ops torch calls as a defense-in-depth measure.
**Supersedes:** the prior "iOS only, iPhone only" decision below.

### Decision: iOS only for v1 (SUPERSEDED)
**Date:** May 2026
**Decision:** macOS support removed. All `#if os(macOS)` / `#else` branches stubbed or deleted.
**Rationale:** The original code had macOS fallback UI that was incomplete and untested. The torch (flashlight) feature — central to eyes-closed entrainment — is iOS only. Splitting attention between platforms at this stage of the rebuild would compromise quality of both. macOS can return when iOS is solid.
**Note:** Superseded by the iOS 26 + Mac Catalyst decision above.

### Decision: No UserDefaults iCloud suite name
**Date:** May 2026
**Decision:** Standard `UserDefaults.standard` via `@AppStorage`. No custom suite name.
**Rationale:** Original code used `UserDefaults(suiteName: "iCloud.com.markfriedlander.NeuroLight")` — an iCloud-prefixed suite ID that requires a CloudKit/App Group entitlement. Without that entitlement configured, behavior is undefined. We are not building CloudKit sync. Use plain `@AppStorage` keys defined in `AppStorage+Keys.swift`.

### Decision: Age rating set to 17+
**Date:** May 2026
**Decision:** App Store age rating is 17+.
**Rationale:** The app involves stroboscopic effects with documented seizure risk. 17+ is the appropriate App Store age rating. Set intentionally to reduce risk of unsupervised use by minors. Configured in App Store Connect via the content questionnaire.

### Decision: No medical claims anywhere in the app or App Store listing
**Date:** May 2026
**Decision:** The app makes no therapeutic claims.
**Approved language:** "useful for guided breathwork and meditation," "explore relaxation and focus through light and sound," "guides you toward."
**Prohibited language:** any disease name, "treats," "improves," "clinically proven," or any reference to the 40Hz Alzheimer's/amyloid research.
**Rationale:** Not because the research is unsound — it is substantial (MIT/Tsai lab, Nature 2024, active Phase 3 trials via Cognito Therapeutics) — but because disease-name association in an app triggers FDA medical device classification and Apple review complications. The science is real. The regulatory category change is the problem. This applies to in-app copy, App Store description, screenshots, marketing site, and any companion materials.

### Decision: Privacy policy hosted on GitHub Pages
**Date:** May 2026
**Decision:** App collects no data whatsoever. A simple privacy policy stating this will be drafted and hosted on Mark's existing GitHub Pages setup. Required by App Store even for zero-data-collection apps. To be created before App Store submission.

### Decision: Restore Defaults button + curated default values
**Date:** May 2026
**Decision:** SessionConfigView has a small "RESTORE DEFAULTS" button below BEGIN. One tap resets every persisted setting via `StorageDefault.restoreAll()`. Medium haptic on press.
**The defaults** (codified in `StorageDefault`):
- Duration: **10 min** (Mark's preference; MIT studies used 20–40 min, but 10 felt less committed for everyday use)
- Audio: on, isochronic 60%, ambient pink at 30%
- Breath: on, Coherence (5/0/5/0)
- Color mode: **off** (Mark's call — quieter default)
- Torch: off (deliberate opt-in)
- Custom Hz: 10, custom carrier: 174 (matches static .custom)
- Custom breath: 5/0/5/0 (matches Coherence)
- Breath audio cues: **on by default in breathwork mode**
- Breath cue volume: 0.7
**Do not change without explicit discussion with Mark.**

### Decision: Breath-only as a fourth Home tile
**Date:** May 2026
**Decision:** Breath-only mode lives as the FIRST tile on Home — order is BREATHE → FOCUS → CALM → SLEEP, the warmth-to-deep visual gradient. Same gesture model as the three entrainment tiles (tap = start, long press = config). It is not in Advanced and is not a toggle inside an existing state.
**Rationale:** Breathwork is a different mode of using the app, not a variant of entrainment. Promoting it to Home gives it appropriate weight; users approaching Pure Phase for breathwork don't think of themselves as advanced users.

### Decision: Breath-only visual — cream ring + warm halo on black
**Date:** May 2026
**Decision:** During a breath-only session: black canvas, enlarged centered cream ring (320 pt vs the 240 pt overlay in entrainment sessions), warm amber radial halo behind the ring (option (ii) per Mark — same family resemblance as entrainment session screens but no flicker). Torch disabled. Isochronic tone disabled. Idle timer disabled (same as entrainment — screen must not auto-dim mid-session).

### Decision: Breath audio cues — lightweight, toggleable, on by default
**Date:** May 2026
**Decision:** Breath-only mode supports optional audio cues at phase transitions. **Inhale = rising sine sweep 260→440 Hz** over 220 ms; **Exhale = falling sweep 440→260 Hz** over 220 ms; **Hold = sustained 220 Hz** for 180 ms. Soft attack/release envelopes prevent click. Procedurally synthesized buffers, pre-built once per session, no audio files. Cues toggle in SessionConfigView with a separate volume slider. Default ON for breathwork mode (silence is jarring); user can disable.
**Explicitly not narration** — no voice content, no guided meditation language. Stays within the CLAUDE.md prohibition on voice content.

### Decision: SessionEngine owns audio interruption handling
**Date:** May 2026
**Decision:** `AVAudioSession.interruptionNotification` observer lives on `SessionEngine`, not on `AudioEngine`. Engine exposes `pauseForInterruption()` / `resumeFromInterruption()` that suspend the CADisplayLink, force the torch off, set brightness to 0, and pause audio together. Resume restarts the display link with a corrected `startTime` so elapsed picks up exactly where it paused — no jump in audio buffer position or breath cycle.
**Rationale:** Strategic Claude correctly flagged that audio-only interruption handling left flicker and torch running during phone calls — battery drain plus a confusing experience. Centralizing pause/resume on the engine ensures all three modalities stop and start together.

### Decision: Breathwork-mode coherence — `state.isBreathwork`, not a separate enum
**Date:** May 2026
**Decision:** Breathwork mode is identified by `state.isBreathwork` (computed from `id == "breathwork"`), not a separate `SessionType { entrainment, breathwork }` enum on SessionConfig.
**Rationale:** Strategic Claude proposed the enum. Considered and rejected because adding it on top of the state would create two places where the truth lives — a session with `state.breathwork` and `type: .entrainment` would be incoherent and the code would have to defend against the mismatch in every branch. One source of truth is simpler and equivalent in behavior.

### Decision: Default breath preset is Coherence (6 BPM)
**Date:** May 2026
**Decision:** Default breath pattern is 5s inhale / 5s exhale, 6 breaths per minute.
**Rationale:** 6 BPM is the respiratory resonance frequency that maximizes HRV and vagal tone — the most strongly evidence-backed slow breathing pattern. Mark's personal preference aligns with the research. Suits the widest range of use cases. 4-7-8 is the alternative quick-start for sleep/anxiety specifically.

---

## Abandoned Approaches

### Approach: Simple sine wave at brainwave frequency for audio
**Tried in:** Original code (`createTone()`)
**Why abandoned:** Brainwave frequencies (0.5–40Hz) are below the threshold of audible hearing. A 10Hz sine wave produces no perceptible sound. The function generated silence or near-silence. Replaced with isochronic tone approach: audible carrier (136–220Hz) with amplitude envelope pulsed at the target frequency.

### Approach: Nested recursive Timer for flicker
**In original code:** `Timer.scheduledTimer(withTimeInterval: 0.05)` outer loop firing inner timer at computed interval.
**Why abandoned:** Timing error accumulates. At 40Hz the required interval is 12.5ms — within Timer's minimum resolution but unreliable under main thread load. Error compounds with each recursion. Replaced with CADisplayLink + mathematical phase computation.

### Approach: Single-file architecture
**In original code:** All ~510 lines in ContentView.swift including SettingsView defined before the file header.
**Why abandoned:** Unmaintainable at the scale this app needs to reach. Struct defined before its imports. Free function after class closing. No separation of concerns. Replaced with the seven-directory architecture defined in CLAUDE.md.

---

## Development Roadmap

### Phase 1 — Current
Models + Engine + Core Views (Home, Config, Session, Breath Guide)
Goal: Working app with three primary states, functional audio, functional breath guide.

### Phase 2 — Next
Advanced panel. Custom Hz. Custom breath timing. Carrier frequency selector.

### Phase 3 — Future
Polish pass. Animation refinement. Accessibility. TestFlight.

### Phase 4 — Possible Future
HealthKit integration (HRV tracking during sessions). iPad layout. macOS return.

---

## Known Polish Issues — Deferred to 1.1

Three real visual issues that are not show-stoppers and that Mark elected to defer past 1.0:

### Halo stutter at breath cycle peaks
The breath ring's warm halo uses `.stroke(RadialGradient).blur(radius: 14)`. The Gaussian blur is recomputed every CADisplayLink tick (60–120 / sec) while the parent `.scaleEffect` is also changing. The cream ring itself is smooth (no blur), but the halo visibly stutters at the top and bottom of each breath cycle. Mark prefers the current look; we tried a no-blur fill alternative (`Circle().fill(RadialGradient(...))`) and Mark didn't like the aesthetic. **Fix path for 1.1:** pre-render the halo to a Metal texture and blit it cheaply each frame, or use a multi-stop gradient with no blur but a denser falloff curve to keep the soft glow without per-frame blur cost.

### 40 Hz Focus pattern change on 60 Hz displays
At 40 Hz, on a 60 Hz refresh display, frames alternate 1-on / 1-off / 2-on / 1-off / 1-on / 2-off — an unavoidable beating pattern that some viewers perceive as "the rhythm shifting." On 120 Hz ProMotion displays (iPhone Pro, recent iPad Pro) the math is exact — 3-on / 3-off — and the issue disappears. Mark confirmed his iPhone 16 Plus has no ProMotion (it's a non-Pro Plus, 60 Hz), which matches the report. **Fix path for 1.1:** detect refresh rate via `UIScreen.main.maximumFramesPerSecond` and either (a) display a small "best on ProMotion" hint on first run on 60 Hz devices, or (b) experiment with frame-rate-quantized flicker that lands on integer frame counts at 60 Hz (would alter the perceptual frequency by a few percent — needs research).

### Grey noise as fourth ambient option
ISO 226-2003 inverse equal-loudness-contour-filtered white noise. Strategic Claude proposed it as a differentiator. Mark elected to defer — pink noise already serves the comfortable-extended-listening case, and few users will notice. **Fix path for 1.1:** fetch the published 29-frequency ISO 226 coefficient table, implement an FFT-based filter (not naive convolution), verify output spectrum measures perceptually flat.

---

## Phase 4 Concepts — Do Not Build Yet

These are intentionally captured here so we don't lose the thinking, but they are explicitly out of scope for v1. Do not implement, scaffold, or design UI around any of these without an explicit green light from Mark.

### Closed-loop biofeedback entrainment (Apple Watch)
Apple exposes real-time heart rate streaming to third-party apps via HealthKit during active workout sessions, typically at 1-second resolution. A future version of Pure Phase could use incoming HR and HRV data to modulate flicker frequency and audio in real time — nudging toward Alpha if HR is elevated, holding at target state as HRV improves. The breath guide could adjust its pacing dynamically to meet the user rather than imposing a fixed rhythm. This is closed-loop neurofeedback. It is the right direction for a 2.0 but explicitly out of scope for v1.
