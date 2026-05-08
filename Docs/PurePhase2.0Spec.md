# Pure Phase 2.0 — Design & Engineering Specification
## For Claude Code Implementation

---

## 0. Overview

Pure Phase 2.0 adds four substantive features to the 1.0 foundation. No new entitlements. No new data collection. Privacy story stays "Data Not Collected" — unchanged from 1.0.

**Features:**
1. DRIFT — new Advanced audio-only mode, three psychoacoustic layers, black screen
2. BLOOM — new Advanced mode, same audio engine as DRIFT, slow responsive visuals
3. PRISM — rename of the existing Psychedelic state to a cleaner one-syllable name
4. Apple TV — tvOS target, Siri Remote navigation, full-screen session, defaults only

**Cleanup already completed in pre-2.0 commit (c653dc9):**
- Zero build warnings (Swift 6 actor isolation fixes)
- Vertical centering on Home/Advanced/SessionConfig
- Onboarding copy updated to mention bystanders
- Catalyst flag removed
- App Review Notes pre-filled in App Store Connect
- File hygiene pass

**What 2.0 does not include:**
- Apple Watch companion (deferred)
- Biofeedback / ADAPTIVE / heart rate features (deferred indefinitely)
- Grey noise (deferred indefinitely)
- iCloud sync (explicitly excluded — would change privacy story)
- Any new data collection of any kind
- TestFlight — ship directly to App Store

---

## 1. PRISM (rename of Psychedelic)

### What Changes

The existing "Psychedelic" state is renamed to **PRISM**. One syllable. Fits the rhythm of the tile names. Avoids a word that could attract unnecessary App Store scrutiny. Evokes exactly the right thing — light split into spectrum, color, altered perception.

### What Changes in Code

- `BrainwaveState` name field: "Psychedelic" → "PRISM"
- Display name on tile: "Psychedelic" → "PRISM"
- All string references to "Psychedelic" or "psychedelic" in views, config, @AppStorage keys, and documents
- The descriptor under the tile label: update to match the one-syllable style
- Everything else — Hz (8.0), drift behavior, color mode, session behavior — unchanged

### What Does Not Change

The underlying behavior of PRISM is identical to Psychedelic. No functional changes. Rename only.

---

## 2. DRIFT Mode

### What It Is

DRIFT is an audio-only mode that lives in Advanced alongside Theta, SMR, PRISM, Void, and Custom. It uses three psychoacoustic synthesis layers — inspired by the techniques Kevin Shields uses on My Bloody Valentine recordings — to create auditory depth, movement, and mild perceptual hallucination through pure synthesis.

DRIFT has no visual flicker. The screen is pure black. Eyes closed. The audio layers ARE the experience.

**Safety note:** DRIFT is non-stroboscopic. Users excluded from the primary entrainment states (FOCUS/CALM/SLEEP) by photosensitivity can use DRIFT. This should be noted in the UI where appropriate.

### Placement & Navigation

- New tile in AdvancedView, after PRISM and before BLOOM, before Void and Custom
- SF Symbol: `waveform.path.ecg` or `waveform` — signal/wave, not matching any existing glyph
- Label: **DRIFT**
- Descriptor in Hz position: **psychoacoustics** — single word, same style and placement as Hz readout on other tiles
- Gesture model: tap = start with current saved settings, long press = open shared DRIFT/BLOOM config screen

### Session Screen

- Pure black canvas — no flicker, no color, no visuals of any kind
- Breath guide ring: centered, fully opaque, **on by default** (provides the only visual anchor in an otherwise dark session)
- Breath pattern: user's last saved setting, default Coherence
- Edge progress ring: yes, same as all sessions
- Tap to reveal: exit button and timer only — same as all sessions
- No ambient texture (see Section 2.4)

### The Three Audio Layers

All three layers are toggleable independently in the shared config screen. Default state noted for each.

---

**Layer 1 — Breathing Carrier (default ON)**

The isochronic carrier frequency oscillates slowly via a low-frequency oscillator (LFO). Instead of a fixed carrier (e.g. 220Hz) the tone breathes between carrier−4Hz and carrier+4Hz over a 24-second cycle.

- LFO shape: sine wave
- LFO rate: one full cycle per 24 seconds (0.042Hz)
- LFO depth: ±4Hz from the base carrier frequency
- Effect: the sound never fully settles — it has a sense of aliveness and subtle movement

**Implementation note:** The current AudioEngine pre-generates a fixed buffer and loops it. A breathing carrier cannot be achieved with a static buffer — it requires real-time synthesis. The preferred approach is a real-time `AVAudioSourceNode` that computes samples on the fly, with the LFO phase maintained as persistent state between render callbacks (never reset per callback — must be phase-continuous). This replaces the pre-generated isochronic buffer for DRIFT and BLOOM modes only. The existing buffer-based approach remains for all other modes.

The isochronic pulse envelope (amplitude modulation at the brainwave rate) still applies on top of the breathing carrier — the carrier breathes in frequency while still pulsing at the target Hz. Both modulations coexist.

---

**Layer 2 — Phase Drift (default ON)**

Left and right audio channels receive the same isochronic tone but with a slowly rotating inter-aural phase offset. The offset drifts from 0° to 180° and back over approximately 40 seconds.

- Drift rate: one full 0°→180°→0° cycle per 40 seconds
- Implementation: a slowly modulated delay on one channel, maximum delay ~3.5ms (corresponding to 180° phase offset at 220Hz carrier). Delay value computed from a sine LFO advancing at 1/40Hz.
- Effect: sound appears to move through the head, seeming to originate from different locations without traditional panning. The auditory localization system cannot resolve the source — it feels interior.
- Best experienced with headphones but perceptible on speakers
- UI note: **"Best with headphones"** shown as a subtitle on the config screen

---

**Layer 3 — Harmonic Shimmer (default OFF)**

Two additional carriers at slightly detuned frequencies alongside the main carrier, creating slow acoustic beating patterns through interference.

- Main carrier: e.g. 220Hz
- Additional carriers: carrier−1Hz (219Hz) and carrier+1Hz (221Hz)
- Beating patterns produced: 1Hz and 2Hz — perceived as slow movement and texture in the sound
- All three carriers share the same isochronic pulse envelope
- Effect: the most experiential of the three layers. Creates perceived motion and depth. Opt-in only.
- Implementation: two additional `AVAudioSourceNode` instances running alongside Layer 1, at the detuned frequencies, mixed into the same output bus

---

### Ambient Texture in DRIFT Mode

**Ambient texture is excluded from DRIFT entirely.**

Primary reason: design coherence. DRIFT's philosophy is precise psychoacoustic depth from pure synthesis. The three layers ARE the bed. Adding broadband noise introduces a competing design intent.

Secondary reason: pink and brown noise have energy in the same frequency band as the carriers, dampening the perceptual contrast of Harmonic Shimmer's beating patterns.

**UI implementation:** When the config screen is open for DRIFT (or BLOOM), the ambient texture picker is visibly disabled — greyed out — with a subtitle reading:

> *"DRIFT replaces ambient texture"*

Do not silently override. Surface the trade-off explicitly.

---

## 3. BLOOM Mode

### What It Is

BLOOM is DRIFT with its eyes open. It uses the identical audio engine and psychoacoustic layers as DRIFT, but instead of a black screen it renders slow, generative visuals that respond in real time to the audio synthesis state — the LFO phases, beat timing, and carrier modulation.

BLOOM is not a music visualizer. It does not react to audio amplitude. It is driven by the synthesis parameters themselves — the same slow rates that govern the audio (24-second breathing cycle, 40-second phase drift, 1-2Hz beating) govern the visual field. What you see breathes with what you hear.

**Safety note:** BLOOM is non-stroboscopic. The visual modulation rates are 0.042Hz, 0.025Hz, and 1-2Hz — far below the threshold for photosensitive triggering. Users excluded from FOCUS/CALM/SLEEP can use BLOOM. Note this in the UI.

### Placement & Navigation

- New tile in AdvancedView, immediately after DRIFT
- SF Symbol: `sparkles` or `rays` — something that suggests emanation, color, bloom
- Label: **BLOOM**
- Descriptor in Hz position: **psychoacoustics** — same as DRIFT
- Gesture model: tap = start, long press = open shared DRIFT/BLOOM config screen (identical config, different session behavior)

### Session Screen — Visual Vocabulary

The visual layer is a full-screen radial bloom — the app icon made alive and full-screen. Same warm amber-to-red color language as the rest of the app. Three visual elements, each driven by one audio LFO:

**Breathing Carrier (Layer 1) drives overall brightness and scale:**
As the carrier LFO rises toward its peak (carrier+4Hz), the visual field brightens slightly and the bloom expands outward. As it falls toward its trough (carrier-4Hz), the bloom contracts and dims. One full visual breath every 24 seconds. The visual field is literally inhaling and exhaling with the carrier.

**Phase Drift (Layer 2) drives color temperature:**
As the inter-aural phase offset rotates through its 40-second cycle, the bloom's color slowly shifts along the warm spectrum — from deep amber at 0° toward deep red at 180° and back. The color moves through the same space the sound is moving through. Visual and audio drift are synchronized.

**Harmonic Shimmer (Layer 3, when ON) drives texture:**
When Layer 3 is active, very subtle interference rings appear in the visual field at the 1-2Hz beat frequency — soft, barely-there moiré-like patterns in the radial gradient. More felt than seen. Reinforces the acoustic beating with a corresponding visual analog.

**Base visual:** A full-screen radial gradient bloom, centered, with the same concentric ring language as the app icon. Warm core bleeding outward through orange into deep red into black at the edges. The bloom is always present; the three layers modulate it.

**Implementation approach:** SwiftUI `TimelineView` driving `Canvas` or `MeshGradient` (iOS 18+). The `AutomationBus` (or equivalent) publishes the three LFO phase values every frame; the visual layer reads them and computes gradient parameters. No Metal required for this vocabulary — SwiftUI gradient rendering is sufficient. If performance is inadequate on the iOS 17 floor device, escalate to a Metal pass and flag for discussion.

**No visual intensity knob in 2.0.** The visual vocabulary is designed to work at one intensity level. A knob can be added in 2.1 if user feedback indicates it's needed.

### Shared Session Config — DRIFT and BLOOM

DRIFT and BLOOM share a single session config screen. The config is identical — same options, same defaults. The state distinction is what happens during the session, not how it's configured beforehand.

Long pressing either the DRIFT or BLOOM tile opens this shared config screen:

- **Duration** — 5 / 10 / 20 / 40 / Open. Default: 20 minutes.
- **Breath guide** — toggle, default ON. Shows breath pattern selector when on.
- **Breath pattern** — Coherence, 4-7-8, Box, Slow Wave, Custom. Default: Coherence.
- **Audio layers** — three independent toggles:
  - Breathing Carrier — default ON
  - Phase Drift — default ON
  - Harmonic Shimmer — default OFF
- **Ambient texture** — visibly disabled, subtitle: "DRIFT replaces ambient texture"
- **Carrier frequency** — same Advanced carrier selector. Default: 220Hz.
- Subtitle on config screen: **"Best with headphones"**

### BLOOM/DRIFT Shared @AppStorage Keys

- `driftBloomBreathEnabled: Bool = true`
- `driftBloomBreathPattern: String = "coherence"`
- `driftBloomLayerBreathingCarrier: Bool = true`
- `driftBloomLayerPhaseDrift: Bool = true`
- `driftBloomLayerHarmonicShimmer: Bool = false`
- `driftBloomDuration: Int = 20`
- `driftBloomCarrierHz: Double = 220.0`

Settings persist independently from other states. DRIFT and BLOOM share the same stored settings since their config is identical.

### What BLOOM and DRIFT Are Not

Neither mode claims clinical evidence. Both are clearly labeled as experiential and exploratory. Copy must use language like: "exploratory," "experimental," "psychoacoustic," "experiential." Not: "entrainment," "clinically studied," "treats," "improves," "proven," or any disease name.

---

## 4. Apple TV Support

### Philosophy

The Pure Phase session experience — full-screen color pulse filling the entire visual field — is more powerful on a large TV screen than on a phone. BLOOM especially becomes a genuinely compelling TV experience: room-filling spatial audio, large-field slow responsive visuals, immersive and beautiful. TV is the best version of BLOOM.

### Interaction Model — Defaults Only, No Configuration

The TV app has no configuration. No settings screen. No long press. No tuning of any kind.

The complete interaction model:
- **Scroll** — navigate between tiles using the Siri Remote touch surface
- **Click** — start the selected session immediately with app defaults
- **Click** — stop the session and return to the tile screen

That is the entire gesture vocabulary. No more, no less.

All session parameters use the app's saved defaults. If no defaults have been set from an iPhone, hardcoded defaults apply: 20 minutes, audio on (Breathing Carrier + Phase Drift), breath on (Coherence), color mode on, no torch.

### TV Home Screen

Five tiles: BREATHE, FOCUS, CALM, SLEEP, DRIFT, BLOOM. Same black background, same warm glyph aesthetic, same gradient bar and PURE PHASE wordmark. No settings item. No Advanced panel. Tiles only. PRISM, Theta, SMR, Void, Custom are not shown on TV in 2.0 — primary states plus DRIFT and BLOOM only.

### Platform-Specific Changes

- **Torch:** Hidden entirely on tvOS. `TorchController.isAvailable` already returns false on non-iPhone; verify every torch UI surface is gated and confirmed absent on tvOS.
- **Layout:** 560pt max-width cap applies to any navigational screens. Session screen is full-bleed — fills the entire display. This is correct and intentional.
- **No iCloud sync:** TV uses defaults. Privacy story stays clean.
- **Full-screen:** tvOS apps launch full-screen by default. Confirm in scheme configuration.
- **BLOOM on TV:** The visual layer renders full-screen. This is the flagship TV experience — the slow breathing bloom filling a large display in a dark room is exactly what BLOOM was designed for.

### Xcode Project Changes

- Add tvOS target to project
- New tvOS scheme
- Shared source with `#if os(tvOS)` guards where needed
- tvOS deployment target: tvOS 17.0
- Verify all views compile and render correctly under tvOS simulator

---

## 5. Build Sequence

Build in this order. Each step is independently verifiable.

1. **PRISM rename** — find/replace, confirm build clean, confirm all tiles display correctly
2. **DRIFT audio engine** — real-time `AVAudioSourceNode`, Layer 1 first (breathing carrier + LFO), then Layer 2 (phase drift delay), then Layer 3 (harmonic shimmer). Verify each layer independently via automation server audio tap before adding next.
3. **Shared DRIFT/BLOOM config UI** — config screen, layer toggles, ambient disabled state with tooltip
4. **DRIFT session screen** — pure black canvas, breath guide overlay, verify audio plays correctly end-to-end
5. **BLOOM visual layer** — `TimelineView` + `Canvas`/`MeshGradient`, AutomationBus LFO phase publication, three visual mappings (brightness/scale, color temperature, texture rings)
6. **BLOOM session screen** — visual layer on top of DRIFT audio foundation, verify all three visual elements respond to their respective LFO sources
7. **DRIFT + BLOOM verification** — automation server: start both modes, observe audio and visual output, confirm all three layers independently toggleable, confirm shared config persists correctly
8. **tvOS target** — add target, Siri Remote navigation, six-tile home screen (BREATHE/FOCUS/CALM/SLEEP/DRIFT/BLOOM), full-screen session
9. **BLOOM on TV** — verify visual layer renders beautifully full-screen on tvOS simulator
10. **tvOS verification** — all six states run correctly on simulator
11. **Integration pass** — full run-through on iPhone, iPad, Mac, TV
12. **Device verification** — iPhone physical device: audio confirmed audible (isochronic pulse + all three layers), visual confirmed for BLOOM, PRISM behavior unchanged
13. **Document updates** — HISTORY, HANDOFF, NEXT, MEMORY, CLAUDE.md all updated
14. **Submission** — direct to App Store, no TestFlight

---

## 6. Questions for CC Before Building

Answer these before writing DRIFT/BLOOM code:

1. **AVAudioSourceNode architecture:** Three separate nodes (one per layer) mixed by AVAudioMixerNode, or a single node computing all layers? Three separate nodes is the recommendation — gives independent per-layer volume control and clean enable/disable. Confirm your approach.

2. **LFO phase continuity:** The breathing carrier LFO phase must be maintained as persistent state between render callbacks — never reset per callback. Confirm this is your implementation approach.

3. **Phase Drift delay implementation:** Variable-delay line within the source node render callback, or AVAudioUnitDelay? Either is acceptable. State your choice before building.

4. **BLOOM visual implementation:** `MeshGradient` (iOS 18+) or `Canvas` with manual gradient drawing (iOS 16+ compatible)? Given our iOS 17 deployment floor, `Canvas` is the safer choice unless `MeshGradient` is available in iOS 17. Verify and confirm before building the visual layer.

5. **AutomationBus / LFO state publication:** How will the audio synthesis LFO phase values be made available to the SwiftUI visual layer in real time? The audio render thread cannot directly update `@Published` properties — needs a thread-safe bridge. What's your approach?

6. **tvOS focus navigation:** Quick audit of current navigation patterns before building TV — which views will need explicit `focusable()` modifiers or other tvOS-specific handling?

---

## 7. Copy & Language Rules

Same approved/prohibited language as 1.0 (see MEMORY.md). Additional for 2.0:

**DRIFT and BLOOM approved:**
- "psychoacoustic audio layers"
- "experimental audio mode"
- "exploratory"
- "best with headphones"
- "audio-only — no flicker" (DRIFT only)
- "slow responsive visuals" (BLOOM only)
- "non-stroboscopic — safe for photosensitive users"

**DRIFT and BLOOM prohibited:**
- Any clinical claims
- "entrainment" — these modes are not clinically studied entrainment
- "treats," "improves," "proven"
- Any disease names

**PRISM approved:** Same language as Psychedelic had, minus the word "psychedelic." Use: "immersive visual rhythm," "color and drift," "exploratory."

**TV approved:** "full-screen experience," "designed for large displays," "immersive."

---

## 8. What Not to Build

Do not add any of the following without explicit discussion with Mark:

- Biofeedback / ADAPTIVE / heart rate features
- Apple Watch companion
- iCloud settings sync
- Grey noise
- Layer 4 / sub-threshold pulse — dropped, do not add
- Visual intensity knob for BLOOM — deferred to 2.1
- Any new HealthKit access
- Any new data collection
- Guided narration or voice content
- Subscriptions, accounts, or paywalls
- PRISM, Theta, SMR, Void, Custom on tvOS in this version

---

## 9. Document Updates Required

At session end, CC updates:

- **MEMORY.md** — DRIFT/BLOOM decisions and rationale, PRISM rename, tvOS scope, ambient exclusion rationale, Layer 4 dropped, visual intensity deferred
- **HISTORY.md** — 2.0 build entry
- **HANDOFF_BRIEF.md** — current state
- **NEXT.md** — 2.0 completion, 2.1 candidates (visual intensity knob, remaining Advanced states on TV, grey noise if ever revisited)
- **CLAUDE.md** — platform scope updated to include tvOS

---

*Pure Phase 2.0 Specification — May 2026*
*Written by Strategic Claude in collaboration with Mark Friedlander and Claude Code*
