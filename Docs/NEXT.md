# NEXT.md — Pure Phase Current Priorities
*Always reflects current planned work. A stale NEXT.md is worse than none. Update every session.*

---

## 1.0 — SHIPPED to App Store (May 2026) ✅

## 2.0 — In progress (May 2026)

Four substantive features, all structurally complete and code-verified:
- PRISM (rename of Psychedelic — one syllable, less loaded)
- DRIFT (audio-only psychoacoustic, three layers, real-time AVAudioSourceNode synthesis with sine LUT for render-callback efficiency)
- BLOOM (DRIFT audio + responsive Canvas bloom that breathes / drifts / shimmers with the audio LFOs)
- Apple TV target (six-tile home, focus navigation, full-bleed session, single bundle ID with iOS so the App Store treats it as one listing)

Mark hardware-verified DRIFT and BLOOM on iPhone 16 Plus + AirPods (May 7 evening): "incredibly beautiful and sound amazing." BLOOM's visual movement subsequently amplified per his feedback (radius range ±0.15 → ±0.25, opacity range ±0.075 → ±0.15, plus a new ±5% center drift tied to the phase-drift LFO).

**Done in evening Session 8:**
- tvOS sim screenshots captured at 4K (Docs/AppStoreScreenshots/tv-4k/)
- Real Apple TV pairing tried, failed, deferred to App Store auto-install
- AirPlay verified as a working "free" path (screen mirroring works without code changes)

**Remaining 2.0 work before submission (queued for next session):**

1. **TV graphics** — generate the three layered icon assets (Back / Middle / Front for parallax) plus the Top Shelf hero image (1920×720). CC to adapt the existing iOS app icon code into three layers. Plan agreed; ~1 hr.
2. **AirPlay route picker in session view** — `AVRoutePickerView` embedded in `SessionView` so the user can route audio/screen without leaving the app. Not a blocker (Control Center mirroring works today) but a nice polish. ~1 hr.
3. **Optional: `scripts/capture_screenshots.sh` tvOS extension** — driving the tvOS sim from the existing screenshot pipeline so future submissions are one-command. ~1 hr.
4. **Resolve open question: isochronic AM rate for DRIFT/BLOOM** — provisional 8 Hz. Worth a deliberate Strategic Claude conversation before submitting.
5. **App Store Connect submission**: 2.0 metadata update, upload iOS + tvOS binaries, Add Platform → tvOS on existing listing, attach screenshots, submit. Same flow as 1.0; see `Docs/AppStoreSubmission.md` for gotchas.

## 3.0 — Mark's running idea list (captured May 7 from on-device test)

These are noted, not committed. Strategic Claude and Mark to refine when 2.0 is in the rearview.

- **Adventure further into layer math** — sonically AND visually. The two-layer-on-by-default Drift was the conservative cut. There's a much weirder space to explore: more carriers, more LFO interactions, more cross-modulation between audio LFOs and visual generators.
- **Interference patterns as a visual mode** — Mark's lifelong fascination with moiré-style interference (originally black-and-white, but reskinned to fit the warm trippy aesthetic). Concentric warm rings overlapping at slightly different spatial frequencies, producing slow visible moiré that pulses with the audio. Visually compatible with the existing identity. Conceptually it's the *visual* analog of what Layer 3 already does *acoustically* (interference between detuned carriers producing audible beats). Could be its own state in Advanced — call it RIPPLE, MOIRE, INTERFERE, or something better.
- **Possible biofeedback / ADAPTIVE revisit** — only if a path to real validation appears (pilot user group, academic collaborator). N=1 self-experimentation was deliberately deferred indefinitely. Architecture remains documented in `Docs/PurePhase2.0Spec.md` if it ever returns.

---

## Engine Layer — DONE (Session 2, May 2026)
## Core Views — DONE (Session 3, May 2026)
## HTTP Automation + Polish — DONE (Session 4, May 2026)
## Tap-to-Start, AdvancedView, Ring Fix — DONE (Session 5, May 2026)
## Custom + Custom Breath + Breathwork Mode + Audio Interruption — DONE (Session 6, May 2026)
## iOS 17 + Layout cap + Restore Defaults + Interruption-stops-everything — DONE (Session 6 wrap, May 2026)

Onboarding, Home, SessionConfig, BreathGuide, Session, plus the two component views (IntentTile, GradientProgressRing), AppStorage keys, and a router-style ContentView all shipped. Aesthetic locked: warm-only palette, glyph-driven, sparse industrial type. Built and installed on iPhone 17 Pro simulator and Mark's iPhone 16 Plus. See HISTORY.md.

---

## Current Target — Session 5

**AdvancedView + on-device automation verification + iteration on Mark's hands-on feedback.**

The automation server is the new floor. Every new surface must register an accessibility ID and bus action; every new capability must add a route to `AutomationServer.swift`. **Parity rule, no exceptions.**

**4. `Engine/TorchController.swift`**
- Extract `toggleTorch()` from original ContentView
- Wrap in a clean class with `isOn: Bool` published property
- Handle `AVCaptureDevice` safely with proper error handling

**5. `Engine/SessionEngine.swift`**
- `CADisplayLink` as timing source
- Published: `flickerPhase: Bool`, `breathPhase: Double` (0.0–1.0 within current breath phase), `breathStageName: String` ("Inhale"/"Hold"/"Exhale"), `sessionProgress: Double`, `brightness: Double` (fade envelope)
- Fade-in: 3 seconds ramp
- Fade-out: 30 seconds ramp (not in Open mode)
- Completion callback
- Start/stop/pause interface

**6. `Engine/AudioEngine.swift`**
- `AVAudioEngine` with two player nodes: isochronic + ambient
- Isochronic: generate 1-second buffer of audible carrier (default 220Hz) with amplitude envelope pulsing at target Hz — phase-locked to SessionEngine clock
- Ambient: pink noise or brown noise or drone, generated procedurally
- Volume controls for each layer
- Graceful handling of silent switch and audio interruptions

---

## After Engine — Session 3

**Build Core Views.**

**7. `Views/HomeView.swift`** — three intent tiles, Advanced entry, aesthetic
**8. `Views/SessionConfigView.swift`** — duration, audio, breath toggles and options
**9. `Views/BreathGuideView.swift`** — organic ring animation, the emotional heart
**10. `Views/SessionView.swift`** — full-screen session, flicker + breath overlay + progress

---

## After Core Views — Session 4

**Complete the app.**

**11. `Views/AdvancedView.swift`** — all states, custom Hz, custom breath, carrier freq
**12. `Views/OnboardingView.swift`** — first-launch warning, matches aesthetic
**13. `Views/Components/`** — IntentTileView, GradientProgressRing
**14. `Utilities/AppStorage+Keys.swift`** — centralized key constants
**15. Final integration** — wire everything together, test all three primary states end-to-end

---

## Models Layer — DONE (Session 1, May 2026)

All three model files shipped, app builds cleanly. See HISTORY.md for the entry. Legacy `ContentView.swift` retired in favor of a minimal placeholder; real views land in Session 3.

---

## Guardrails — What Not to Do in Session 3

- Do not touch `NeuroLightApp.swift` — it's fine as-is
- Do not modify any file in `Models/` or `Engine/` without explicit reason and a note in HISTORY
- Do not invent answers to the four open UX questions below — wait for Mark
- Do not introduce a second timer or animation driver in views — derive everything from `SessionEngine`'s published values
- Do not show torch UI when `TorchController.isAvailable` is false (Catalyst rule)
- Do not add CloudKit, iCloud, or App Group anything
- Do not add any features from the "What Not to Build" list in CLAUDE.md
- Do not use any prohibited copy from the "No medical claims" decision in MEMORY.md

---

## Standing Questions to Resolve Before Session 3 (Views)

These need answers from Mark before the views are built:

- **Breath guide visual detail:** Petal cluster (like Apple Watch) or single expanding ring? Or something else entirely in the Virtual Light color language?
- **Home screen tile layout:** Full-width stacked tiles (current app style) or something more spatial/atmospheric — e.g., large centered cards with more breathing room between them?
- **Session transition:** Cut directly to full-screen flicker, or a brief "powering up" transition (2-3 second fade from black)?
- **Progress indicator:** Thin outer-edge ring, or a subtle timer display (MM:SS remaining), or nothing at all?

---

*Last updated: May 2026 — Session 1 complete (Models). Engine layer is next.*

---

## Pre-Submission Checklist — Before App Store

These do not block engineering work but must all be true before submitting to the App Store.

- [ ] Privacy policy drafted and live on GitHub Pages
- [ ] Age rating set to 17+ in App Store Connect
- [ ] App Store description reviewed against approved language list (see MEMORY.md — "No medical claims" decision)
- [ ] No disease names, no therapeutic outcome claims anywhere in metadata or app copy
- [ ] Seizure / photosensitivity warning on first launch confirmed to require active user engagement (checkbox, not a tap-through)
- [ ] Warning does not need to appear on every launch — once confirmed and stored via `@AppStorage` is sufficient and is the correct UX
- [ ] Screenshots captured at all Apple-required device resolutions (see screenshot automation note below)
- [ ] TestFlight build distributed and tested

### Note: Screenshot automation (deferred — Session 4 or 5)

CC should build a debug-only local HTTP control layer that allows programmatic driving of the app UI — navigating screens, triggering session states, capturing screenshots at exact Apple-required resolutions for each device size. This layer is stripped from release builds. This is the same pattern used in Mark's other projects for LLM parameter control and exhaustive UI testing. Spec this as a Session 4 or 5 task after the core app is functional. Do not build it during Engine or Core Views work.
