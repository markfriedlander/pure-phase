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

### Decision: Accessibility scope — selective compliance, honest framing
**Date:** May 2026
**Decision:** Pure Phase implements accessibility selectively, not exhaustively, and is explicit about its limits in the onboarding warning.

**Implemented:**
- **VoiceOver on the breath path.** All home and advanced tiles have descriptive `accessibilityLabel` (e.g. "Focus — 40 hertz visual flicker, gamma frequency"), `accessibilityHint` ("Double tap to begin a session"), and a custom `Configure` action via `accessibilityAction(named:)` so VO users can reach the config screen without long-pressing. SF Symbol glyphs are marked `accessibilityHidden(true)` (decorative; the label below carries meaning). Decorative gradient bars are hidden from VO. Sliders and pickers throughout SessionConfigView have meaningful labels and value descriptions ("Tone volume, 60 percent"). The breath ring during a session announces its current stage as `accessibilityValue` so VO users hear "Inhale" → "Hold" → "Exhale". The exit button has an explicit "Exit session" label.
- **Reduce Motion gate.** When iOS Reduce Motion is enabled and the user starts an entrainment session for the first time, an alert appears: "Pure Phase uses rapid rhythmic flicker — that's the entrainment mechanism. You have Reduce Motion enabled. Continue this session?" Cancel dismisses; Continue persists acknowledgment via `@AppStorage("ackReduceMotion")` so subsequent sessions don't re-prompt. **Breathwork mode is exempt** — it has no rapid motion. The acknowledgment key is intentionally NOT reset by Restore Defaults (it's a safety acknowledgment, not a setting).
- **Strengthened onboarding warning.** Now explicit about who the entrainment modes are not for (photosensitivity, seizure history, vestibular disorders, motion sensitivity, significant vision impairment) and explicit that BREATHE has no flicker.
- **Color blindness already handled** by the warm-only palette (no red/green or red/blue ambiguity).

**Intentionally NOT implemented:**
- **Dynamic Type** — every text element uses fixed font sizes via `.font(.system(size: X))`. Scaling them would break the typographic identity (tight letter-spacing on bold compressed wordmarks, sparse layouts). Additionally, the user population that needs Dynamic Type heavily overlaps with the population that should not be using flicker entrainment in the first place — optimizing for them in a flicker-based app is solving the wrong problem. Documented in the warning instead.
- **VoiceOver optimization on entrainment session screens** — a blind user cannot perceive the visual flicker; VO labels there would be performative. The default labels suffice. The breathwork session is the genuinely accessible alternative.
- **Full WCAG audit.** Pure Phase is a free indie app with explicit warnings, not a public service.

**Rationale:** The app's central feature is rapid visual flicker. That feature is fundamentally inaccessible to several user populations, by design. Token Dynamic Type support that doesn't actually help those users is dishonest. Selective compliance plus explicit framing in the warning ("we've designed it for a specific kind of experience; if that's not for you, that's the right call") is more respectful and accurate.

**Apple App Store compliance:** Apple requires apps to not misrepresent accessibility, not to be universally accessible. A free indie app with an accurate prominent warning, a genuinely accessible alternate mode (BREATHE), respect for explicit user signals (Reduce Motion), and a 17+ rating is acceptable.

### Decision: App Store screenshot capture is a tracked tool, not a one-off
**Date:** May 2026
**Decision:** `scripts/capture_screenshots.sh` is committed to the repo and is the canonical way to produce App Store screenshots for any Pure Phase release. Future versions (1.1, 1.2, etc.) re-run the same script when UI changes warrant new screenshots.

**The 5-shot lineup is deliberate:**
1. Home — the four-tile entry point
2. Advanced — the five-tile science menu
3. BREATHE config — most variety-rich settings screen (cues + ambient picker + breath patterns including Custom)
4. BREATHE session in progress — cream ring + halo, no flicker (easy timing)
5. FOCUS at full flash — demonstrates entrainment visually; bright amber on-frame is the most striking color in the app and the highest-contrast vs the black off-frame

**Why these specifically, why nothing else:** entrainment session screens (FOCUS, CALM, SLEEP) differ only in tint — adding multiple is duplicative. App Store reviewers prefer 3–5 distinctive shots over 10 redundant ones. BREATHE config is chosen because it has unique controls (cues toggle, cue volume slider, ambient picker) that the entrainment configs don't. **FOCUS for the on-frame shot** rather than SLEEP because FOCUS's bright amber (#F5A623, luminance ~167) is dramatically more visible than SLEEP's deep ember red (#8B2E1F, luminance ~64) — the SLEEP on-frame is correct but reads as "atmospheric and quiet" rather than "this app does visual entrainment." Initially considered SLEEP because of easier on-frame timing (2 Hz vs 40 Hz), but solved that with the burst-capture approach below.

**Engineering hard-won lessons baked into the script:**
- **Port collision between sims.** Both iPhone and iPad sims share the Mac's localhost. If the iPhone app binds port 8770 and we then try to capture the iPad without terminating the iPhone app first, the iPad's automation server fails to bind silently. Every API call goes to the iPhone (which is the wrong device); every iPad screenshot captures the same pre-action state. Fixed via `release_port_from_other_sims` which terminates Pure Phase on all other booted sims before launching the target.
- **Curl timeouts.** Default curl behavior on a non-responsive server is ~75 seconds of TCP timeout. With the polling loop in `capture_at_on_phase` running 30 attempts, that's a 37-minute hang on a dead server. Fixed via `--max-time 2`.
- **`wait_for_server` must be honored.** Original version logged a warning and continued; now it returns 1 and the capture function bails with a loud error.
- **Status bar override** so screenshots show 9:41 / full battery / full Wi-Fi instead of whatever the sim happens to be in. Apple's convention.
- **Each PNG gets a `-thumb.png` companion** via `sips -Z 400`, in line with the image-handling rule.
- **Burst capture for the on-frame shot.** Polling `/state` for `flickerPhase=true` and capturing afterwards has 200–400 ms of overhead between the "on" report and the actual screenshot — at 40 Hz the on-phase is 12.5 ms, polling consistently misses. Solution: take 8 screenshots back-to-back (each ~150 ms, total ~1.2 s ≈ 48 cycles), then pick the brightest. File size alone is unreliable for low-saturation colors (PNG compresses uniform deep red almost identically to uniform black) — `scripts/pick_brightest.swift` computes actual average pixel luminance via Core Graphics and prints the brightest path. The `.burst/` folder is kept on disk so the auto-pick can be manually overridden if needed.

**For the next release** (1.1+): re-run the script after building, eyeball the output in Finder, upload to App Store Connect. If the home screen or session UI changes substantively, the output of the script will reflect that automatically — no script changes needed. If a new mode is added (e.g., Resonance / Drone — see Phase 4 Concepts), add a 6th step to the script's per-device flow. Keep the total count under 7.

### Decision: CC must never read full-size image files
**Date:** May 2026
**Decision:** A hard rule, documented in `CLAUDE.md` under "Image Handling Rule": Claude Code must never use the `Read` tool on files ending `.png`, `.jpg`, `.jpeg`, `.gif`, `.heic`, `.heif`, `.bmp`, or `.webp`, with one exception — files whose name ends `-thumb.png`.
**Rationale:** Reading an image pipes the decoded bytes through the conversation. iPhone simulator screenshots are ~3 MB each at full device resolution. Several Pure Phase sessions crashed and required recovery when CC tried to "verify" rendered output by reading full-size PNGs. Multiple incidents, same root cause.
**Pattern:** Any image-producing pipeline (screenshot capture, render scripts) must produce a `-thumb.png` companion at max dimension 400 px via `sips -Z 400`. The user reviews the full-size in Finder; CC reads the thumbnail only when explicitly asked to verify a specific image.
**Methodology:** Three safe approaches to visual verification — (1) ask the user to look in Finder, (2) read a thumbnail, (3) trust the code. Spelled out in CLAUDE.md.
**Cross-project applicability:** This is a constraint of how images flow through Claude Code conversations, not project-specific. Future projects on any topic should adopt the same rule. Worth surfacing to other Claude Code sessions and to Anthropic as a real ergonomic finding.

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

### Resonance / Drone — sonic-only "wall" mode (Kevin Shields lineage)
Mark surfaced this late-night, May 2026. Inspired by the famous extended-noise section in My Bloody Valentine's "You Made Me Realise" live performances — sometimes called the "holocaust section" — and the perceptual phenomena it produces (auditory pareidolia / phantom melodies, Tartini difference tones, time-distortion, mild dissociation).

A future Pure Phase mode in the same family as BREATHE — purely auditory, no flicker — that sits next to the existing isochronic-tone work but pursues a different mechanism. Where isochronic tones drive cortical entrainment via amplitude modulation at brainwave frequencies, this mode would pursue **perceptual immersion via sustained spectral mass**:

- Multiple sustained drones, slightly detuned (sub-Hz beating between sources creates slow movement without explicit modulation)
- Carefully chosen harmonic relationships that produce audible **difference tones** (frequencies your auditory system generates from the interaction of physical inputs that aren't actually present)
- Slow spectral evolution over minutes — closer in lineage to Eliane Radigue, Phill Niblock, La Monte Young, Ellen Arkbro than to MBV literally (we cannot reproduce 130 dB warehouse volume in a free app — but the perceptual phenomena are partially reachable at safe volumes with headphones)
- No flicker. Black canvas. Maybe a single very slow visual element.
- Long sessions (20–60 minutes) — the perceptual effects compound with time.

Out of scope for v1. Worth designing carefully — wrong execution is just unpleasant noise; right execution is genuinely transporting. Lineage is well-documented in drone music; we'd want to study Radigue's three-oscillator approach, Niblock's overtone-cluster technique, and the Tartini tone literature before implementing. Defer to 1.x discussion with Mark.

### Apple TV (tvOS) support
Mark surfaced this during App Store Connect submission for 1.0. The big-screen-in-a-dark-room version of Pure Phase is arguably the *intended* eyes-closed experience scaled up — far more immersive than a phone, especially for SLEEP. Audio is also significantly better through TV speakers / home theater than through a phone speaker.

**Engineering scope (roughly 2–3 sessions):**
- Add tvOS to `TARGETED_DEVICE_FAMILY` (currently "1,2"), add tvOS scheme/target
- Redesign home for landscape — four glyphs laid out horizontally rather than vertically; the 560 pt content cap is wrong for this surface
- Replace tap/long-press with focus-engine + Siri Remote button mapping. Click on the focus = start session; Play/Pause or long-hold = config; Menu = back
- Scale the breath ring up significantly on TV's larger canvas (320 pt is intimate on iPhone but lost in a 1080p / 4K rectangle)
- Strengthen the onboarding photosensitivity warning further — a 65" OLED at 40 Hz Gamma hits harder than an iPhone screen
- Skip torch entirely (no hardware on TV — same gating pattern as Catalyst)
- HTTP automation server: needs to be tested on tvOS, may need adjustments. Bonjour discovery might be useful since Apple TV doesn't have a friendly localhost story
- Separate tvOS listing on App Store (parallel to Mark's existing Reflect TV pattern)
- Separate tvOS screenshots — landscape, larger device sizes

**Out of scope for 1.0.** Defer to 1.1 or 1.2 depending on what other polish accumulates after launch.

### Closed-loop biofeedback entrainment (Apple Watch)
Apple exposes real-time heart rate streaming to third-party apps via HealthKit during active workout sessions, typically at 1-second resolution. A future version of Pure Phase could use incoming HR and HRV data to modulate flicker frequency and audio in real time — nudging toward Alpha if HR is elevated, holding at target state as HRV improves. The breath guide could adjust its pacing dynamically to meet the user rather than imposing a fixed rhythm. This is closed-loop neurofeedback. It is the right direction for a 2.0 but explicitly out of scope for v1.
