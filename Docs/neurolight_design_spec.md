# NeuroLight — Design & Engineering Specification
## For Claude Code Implementation

---

## 0. Mission Statement

NeuroLight is a free, no-account, no-subscription photic and auditory brainwave entrainment tool for iPhone. It combines science-backed light flicker, isochronic audio tones, and breath pacing into a single, beautifully minimal experience. It is what Lumenate would be if it respected the user's intelligence and didn't charge them for it.

**What it is not:** a guided meditation app. There is no narration, no journaling, no streaks, no social features, no content library.

---

## 1. Aesthetic Direction

### Primary Reference
**William Gibson's "Virtual Light" book cover (1993)**
- Near-total darkness as the canvas
- Horizontal bands of warm spectrum light — amber bleeding into deep orange bleeding into red
- The light feels technological but also neurological — like something happening *inside* the eye
- Sparse. Almost nothing. What's there hits hard.

### Color Language
- **Background:** True black (`#000000`). Not dark gray. Black.
- **Primary accent:** Amber-to-red gradient (`#F5A623` → `#E8593C` → `#C0392B`)
- **Secondary text:** Warm gray (`#888480`) — not cool gray, not blue-gray
- **Active/glow state:** The accent gradient, used as light emission rather than fill
- **Never use:** Cool blues, purples, greens in the primary UI. Those are reserved for color-mode session screens only.

### Typography
- **App name / headers:** Bold, wide-tracked, all caps. Industrial. Not friendly.
- **Body / descriptors:** Regular weight, lowercase. The contrast between the two creates the tension.
- **No system rounded fonts.** Use SF Pro Display for headers, SF Pro Text for body.
- **Minimal text everywhere.** If something can be communicated visually, do that.

### Motion Language
- Slow. Deliberate. Nothing snaps.
- Transitions feel like something powering up or down, not like navigation.
- The breath guide animation is the emotional heart of the motion language — organic, unhurried, alive.

---

## 2. Information Architecture

### Screen Flow
```
Launch
  └── [if first launch] → Warning/Onboarding → Home
  └── [returning] → Home

Home
  ├── Three primary intent tiles (Focus / Calm / Sleep)
  ├── "Advanced" entry point (subtle, not hidden)
  └── Tap any tile → Session Config → Session

Session Config (per intent)
  ├── Duration picker (5 / 10 / 20 / 40 min / Open)
  ├── Audio toggle + Audio Mode selector
  ├── Breath toggle + Breath Mode selector
  └── [Begin] → Session

Session (full screen)
  ├── Flicker layer (full screen, no UI chrome)
  ├── Breath guide overlay (if enabled)
  ├── Subtle progress ring (outer edge of screen or corner)
  └── Tap to reveal: Exit button only

Advanced Panel
  ├── All states including exploratory ones, tunable Hz
  ├── Custom breath timing controls
  ├── Carrier frequency selector for audio
  └── Same Session Config → Session flow
```

---

## 3. States & Frequency Map

### Primary States (Evidence-Backed — Front of App)

These three appear on the home screen as the primary entry points.

| Intent | Display Name | Hz | Color (session screen) | Scientific Basis |
|--------|-------------|-----|----------------------|-----------------|
| Focus  | **FOCUS** | 40Hz | Deep amber / orange | MIT Picower Institute; Li-Huei Tsai lab; multiple replications; Nature 2024 paper on glymphatic clearance; active Phase 3 clinical trials via Cognito Therapeutics |
| Calm   | **CALM** | 10Hz | Warm green → teal | Decades of EEG literature; Alpha suppression in anxiety consistently documented; most replicated entrainment finding after Gamma |
| Sleep  | **SLEEP** | 2Hz | Deep blue → indigo | Delta sleep architecture well-established; photic Delta entrainment supported in sleep onset studies |

### Advanced States (Exploratory — Behind "Advanced" Entry)

Shown with explicit "less studied" framing. Not hidden — just not the default.

| Name | Hz | Intent | Notes |
|------|----|--------|-------|
| Theta | 6Hz | Deep meditation, dreamy | Strong meditator EEG data; photic entrainment specifically is less studied |
| SMR | 13.5Hz | Calm alertness | Strong neurofeedback literature; photic mechanism less established |
| Psychedelic | 8Hz | Altered visual states | In Theta range; effect is visual drift more than clinical entrainment; clearly labeled as experiential |
| Void | 0.5Hz | Stillness | Below delta; almost no photic research; labeled experimental |
| Custom | User-defined | — | Full Hz slider, 0.5–40Hz, for users who know what they want |

**Framing copy for Advanced panel:**
> "These states have less clinical research behind them than Focus, Calm, and Sleep. They're included for experienced users who want to explore. Use them with the same care as the primary states."

---

## 4. Session Engine Architecture

### The Core Principle
**One clock drives everything.** Light flicker, isochronic audio pulses, and breath guide animation all derive from a single `SessionEngine` timing source. They may run at different rates (a breath cycle is much slower than a flicker cycle) but they share a single start time and tick source to prevent drift.

### `SessionEngine` — What It Owns
- Master `CADisplayLink` or high-resolution `DispatchSourceTimer`
- Current `SessionState` (frequency, duration, elapsed, phase)
- Publishes: `flickerPhase: Bool`, `breathPhase: Double` (0.0–1.0), `sessionProgress: Double` (0.0–1.0)
- Handles soft fade-in (first 3 seconds, flicker brightness ramps up) and soft fade-out (final 30 seconds, flicker brightness ramps down)
- On session complete: fires completion event, stops all outputs gracefully

### Timer Approach
Replace the current nested recursive `Timer` calls with a `CADisplayLink` running at display refresh rate (60 or 120Hz depending on device). Compute flicker state from elapsed time and target frequency mathematically rather than relying on timer callback timing:

```swift
// Conceptual — not literal code
let flickerPhase = sin(2π × targetHz × elapsedTime) > 0
```

This is more accurate at high frequencies (40Hz Gamma especially) and doesn't accumulate timing error.

### Session Duration & Fade
- Options: 5 / 10 / 20 / 40 minutes / Open (no limit)
- Fade-in: 3 second linear brightness ramp from 0 → full
- Fade-out: 30 second linear brightness ramp from full → 0, then session complete screen
- "Open" mode: no fade-out, user exits manually

---

## 5. Visual Session Screen

### Flicker Layer
- Full screen, ignores safe area
- Default (no color mode): pure `#FFFFFF` / `#000000` with brightness modulated by fade envelope
- Color mode: each state has an assigned session color (see table above). The "on" flash is that color at full brightness, "off" is black.
- **Gamma/Focus special case:** At 40Hz the flicker is at the edge of perception. Consider a subtle radial bloom from center — a soft radial gradient that pulses outward from center at each flash. Research suggests full-field stimulation is important; a radial element helps ensure peripheral vision is engaged.
- **Psychedelic mode:** Hue rotates continuously but sync the hue position to the flicker phase, not to wall-clock time (fix the current `Date()` bug)

### Torch / Eyes-Closed Mode
- Available for all states
- When enabled: screen dims to near-black during session (to save battery and signal "eyes closed"), torch fires at flicker frequency
- Eyes-closed is the recommended mode for Sleep/Delta — note this in the UI

### Session Overlay (Revealed on Tap)
- Single tap anywhere reveals: exit button (top right), session timer remaining (top left)
- Auto-hides after 3 seconds of no interaction
- No other chrome during session

### Progress Indicator
- A very thin ring or arc at the very edge of the screen, so subtle it reads almost subliminally
- Fills over the session duration
- Inherits the amber→red gradient color language
- Does not interrupt the flicker experience

---

## 6. Audio Engine

### Architecture Philosophy
The audio is a first-class feature, not an afterthought. It runs through `AVAudioEngine` with proper session category setup (`playback` with `mixWithOthers` false — the session takes over audio).

### Isochronic Tone Generation
The current `createTone()` generates a simple sine at the brainwave frequency (e.g., 10Hz for Alpha). **This is wrong** — 10Hz is inaudible. The correct approach:

**Isochronic tone = audible carrier frequency × pulsed at the brainwave rate**

```
Carrier: 220Hz sine wave (warm, non-harsh)
Pulse rate: target brainwave Hz (e.g., 10 pulses/sec for Alpha)
Pulse shape: fast attack (2ms), sustain, fast decay (2ms) — square-ish envelope
Synchronized: pulse timing locked to the same clock as the visual flicker
```

The carrier frequency should be selectable in Advanced settings. Defaults:
- Focus (40Hz pulse): 220Hz carrier (A3 — grounded, focused)
- Calm (10Hz pulse): 174Hz carrier (slightly lower, rounder)
- Sleep (2Hz pulse): 136Hz carrier (very low, earth tone — Schumann resonance adjacent)

### Ambient Texture Layer
Under the isochronic tone, a continuous ambient texture:
- Generated procedurally via `AVAudioEngine` — no audio files needed, no licensing
- Type selectable: Pink noise / Brown noise / Pure drone (sustained carrier only, no pulse, for reference)
- Default: Pink noise at -18dB relative to isochronic tone
- Pink noise is perceptually flatter than white noise — more comfortable for extended sessions
- The texture provides environmental masking and continuity between pulses

### Audio Implementation Notes
- `AVAudioSession` category: `.playback`, activated on session start, deactivated on session end
- `AVAudioPlayerNode` for the isochronic buffer (loop a 1-second buffer containing exactly N cycles at the carrier, pulsed at target rate)
- Second `AVAudioPlayerNode` for ambient texture
- `AVAudioMixerNode` to combine, with independent volume controls
- Generate buffers on a background thread before session start; pre-fill before `play()` to avoid startup glitch
- Honor iOS silent switch: if device is silenced, audio is suppressed gracefully without crashing
- Respect user's own music: if user has audio playing when they launch, prompt: "Use NeuroLight audio or continue with your own?"

### Audio Options in Session Config
- **On / Off toggle**
- **Isochronic tone volume** (slider, default 60%)
- **Ambient texture type** (Pink noise / Brown noise / Drone / Off)
- **Ambient texture volume** (slider, default 30%)
- **Carrier frequency** (in Advanced: 80–440Hz range, with named presets)

---

## 7. Breath Guide

### Design Reference
Apple Watch Breathe app — an organic shape (petal cluster or ring) that expands on inhale, contracts on exhale. The expansion feels alive, not mechanical. The animation curve is ease-in-out, not linear — it accelerates into the expansion and decelerates at the top, just like a real breath.

### NeuroLight Breath Guide Aesthetic
- A single ring or soft radial shape, centered on screen
- Expands outward on inhale (scaling from ~0.4 to ~1.0 of its max size)
- Contracts on exhale
- Color: inherits the amber→red gradient language — glows warmer and brighter at full expansion, dims and cools at contraction
- Opacity: semi-transparent so the flicker layer shows through — the breath guide and the flicker coexist
- During hold phases: ring pulses very gently (a slow 0.5Hz inner shimmer) to signal "hold" without stopping motion entirely

### Breath Presets (Quick-Start)

| Name | Pattern | BPM | Good For |
|------|---------|-----|----------|
| **Coherence** | 5s in / 5s out | 6 BPM | HRV, calm focus, default |
| **4-7-8** | 4s in / 7s hold / 8s out | ~3.2 BPM | Anxiety, sleep onset |
| **Box** | 4s in / 4s hold / 4s out / 4s hold | ~3.75 BPM | Stress reset, focus |
| **Slow Wave** | 6s in / 6s out | 5 BPM | Deep meditation |

Default preset: **Coherence** (6 BPM). This has the strongest HRV/vagal tone research behind it and suits the widest range of users.

### Advanced Breath Config
- Independent sliders for: Inhale / Inhale Hold / Exhale / Exhale Hold (each 1–12 seconds)
- Calculated BPM shown live as user adjusts
- Warning shown if pattern goes below 2 BPM (very slow, disorienting)
- Preset slots: user can save their own pattern as a named preset

### Breath + Flicker Independence
Breath pacing and light flicker are **independent channels**. They share the same session start time but run at their own rates. A 6 BPM breath cycle and a 10Hz Alpha flicker do not need to align. This is correct — they are entraining different systems (respiratory/vagal vs. cortical) simultaneously.

The breath guide overlay appears on top of the flicker layer at ~50% opacity, so both are perceptible.

---

## 8. Onboarding & Safety

### First Launch Only
- Full-screen modal, cannot be skipped on first launch
- Dark background, amber accent, serious tone
- Content:
  - What NeuroLight does (one sentence)
  - **Seizure / photosensitivity warning** — prominent, red text
  - Who should not use it (photosensitive, epilepsy history, currently driving, operating machinery)
  - "Always use in a safe, still environment"
  - "This is not a medical device"
  - Toggle: "I understand and accept these terms"
  - Button: "Enter NeuroLight" (disabled until toggle is on)
- "Don't show again" persists via `@AppStorage` with a plain `UserDefaults` key (no iCloud suite name — fix the current bug)

---

## 9. File Architecture

Break the current single `ContentView.swift` into proper separation. Claude Code should create this structure:

```
NeuroLight/
├── App/
│   └── NeuroLightApp.swift          (unchanged — entry point only)
│
├── Models/
│   ├── BrainwaveState.swift         (state definitions, frequency map, evidence tier)
│   ├── BreathPattern.swift          (preset definitions, custom config)
│   └── SessionConfig.swift          (duration, audio settings, breath settings, chosen state)
│
├── Engine/
│   ├── SessionEngine.swift          (master clock, publishes flicker/breath/progress)
│   ├── AudioEngine.swift            (AVAudioEngine wrapper, isochronic + ambient generation)
│   └── TorchController.swift        (AVCaptureDevice torch, extracted from ContentView)
│
├── Views/
│   ├── HomeView.swift               (intent tiles: Focus / Calm / Sleep)
│   ├── SessionConfigView.swift      (duration, audio, breath options)
│   ├── SessionView.swift            (full-screen session: flicker + breath guide + progress)
│   ├── BreathGuideView.swift        (the organic ring animation, standalone component)
│   ├── AdvancedView.swift           (all states, custom Hz, custom breath, carrier freq)
│   ├── OnboardingView.swift         (first-launch warning modal)
│   └── Components/
│       ├── IntentTileView.swift     (reusable home screen tile)
│       └── GradientProgressRing.swift (subtle session progress indicator)
│
└── Utilities/
    └── AppStorage+Keys.swift        (centralized UserDefaults key constants)
```

---

## 10. Settings Persistence

Use `@AppStorage` throughout. Fix the current `UserDefaults` suite name issue — use standard `UserDefaults.standard`, no iCloud suite name unless CloudKit sync is an explicit future feature.

Keys to persist:
- `hasSeenOnboarding: Bool`
- `lastUsedIntentIndex: Int`
- `preferredDuration: Int` (minutes)
- `audioEnabled: Bool`
- `audioIsoVolume: Double`
- `audioAmbientType: String`
- `audioAmbientVolume: Double`
- `breathEnabled: Bool`
- `breathPresetName: String`
- `breathCustomInhale: Double` (etc. for each phase)
- `colorModeEnabled: Bool`
- `torchEnabled: Bool`

---

## 11. What to Preserve from Existing Code

Claude Code should **keep** the following logic, refactored into the new architecture:

- The `BrainwaveState` struct concept (rename/extend, don't discard)
- `toggleTorch()` function logic → move to `TorchController.swift`
- `flickerColor()` logic → move into `SessionView.swift` or `SessionEngine`
- `ShakeViewController` / `ShakeViewControllerRepresentable` → keep, move to Utilities
- The intro warning content → rewrite copy into `OnboardingView.swift`
- The drift logic for Psychedelic mode → keep in `SessionEngine`

Claude Code should **replace**:
- The entire UI (HomeView, TabView, SettingsView, all of ContentView's body)
- The nested recursive Timer approach → replace with CADisplayLink
- `createTone()` → replace with proper isochronic tone generation
- The `UserDefaults` suite name

---

## 12. Platform Scope

- **Primary target: iPhone on iOS 26+, plus Mac via Mac Catalyst.** The Mac build presents as an iPad-class app — no native AppKit, no separate UI. The legacy `#if os(macOS)` branches are removed for good. Catalyst-specific gating uses `#if targetEnvironment(macCatalyst)`.
- **Minimum iOS:** 26.0 (deliberate; uses the newest SwiftUI/AVFoundation features without backports). Audience reach intentionally narrow — this is not a commercial release.
- **Devices:** iPhone (primary) and Mac via Catalyst. iPad-native layout is future scope. Torch features are unavailable under Catalyst — guard the engine call sites, do not branch the UI.

---

## 13. What Not to Build

Do not build any of the following, even if they seem like natural additions:

- Guided narration or voice content
- Session history or journaling
- User accounts or sign-in
- Push notifications or reminders
- Health app integration (future scope)
- Subscription or paywall logic
- Analytics or tracking of any kind
- iPad-specific layout
- Social or sharing features

---

## 14. Handoff Notes for Claude Code

1. **Read all existing Swift files first** before writing any new code. Understand what exists.
2. **The Visual Light book cover** is the aesthetic north star. Dark, warm spectrum light, sparse, a little dangerous-feeling.
3. **Audio is first-class.** The isochronic tone engine is as important as the visual flicker. They must be synchronized.
4. **One clock.** `SessionEngine` owns timing. Nothing else should have its own timer.
5. **Use LEGO block approach** for file delivery — each file as a separate complete block, sequentially.
6. **Ask before inventing.** If something isn't specified here, ask rather than guess. Especially for the breath guide animation specifics and the audio buffer generation math.
7. **The three primary states (Focus/Calm/Sleep) must work perfectly** before any advanced states are touched.
8. **Test the 40Hz Gamma case specifically** — this is the highest frequency and the most demanding on the timer precision.

---

*End of specification. Version 1.0 — May 2026.*
