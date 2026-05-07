# NEXT.md — NeuroLight Current Priorities
*Always reflects current planned work. A stale NEXT.md is worse than none. Update every session.*

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
