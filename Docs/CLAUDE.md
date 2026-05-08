# CLAUDE.md — Pure Phase Operational Reference
*Read this at the start of every session. Every session. No exceptions.*

---

## What This Project Is

Pure Phase is a free iOS and tvOS app that uses synchronized light flicker, isochronic audio tones, breath pacing, and (in 2.0) responsive psychoacoustic audio + visuals to guide users toward focus, calm, sleep, breathwork, or psychoacoustic states. It is a science-grounded tool, not a wellness content platform. There is no narration, no subscriptions, no accounts, no content library, no data collection. Think: Lumenate, but free, minimal, and honest about what it is. 1.0 is live in the App Store (May 2026); 2.0 (DRIFT, BLOOM, Apple TV) is built and awaiting submission.

The aesthetic is dark and atmospheric — inspired by the William Gibson "Virtual Light" book cover. Warm amber-to-red spectrum light on near-total black. Sparse. Industrial headers, soft body text, slow deliberate motion.

---

## The Collaboration Structure

**Mark** — product owner, creative director, final decision maker on all UX and scope questions. Has domain knowledge of breathwork and meditation practices. Asks questions before committing to directions.

**Strategic Claude** (claude.ai) — the thinking partner. Design decisions, architecture discussions, spec writing, and reviewing Claude Code's output happen there. When something is ambiguous or consequential, check the spec or ask Mark before proceeding.

**Claude Code (you)** — the builder. You implement what has been specified and discussed. You do not invent scope. You do not make consequential decisions alone. You read before you write, you ask before you assume, and you deliver complete implementations.

---

## Working Rules

**1. Read before touching.**
Read every relevant file before modifying anything. Understanding existing code before changing it is not optional.

**2. Discuss before building anything consequential.**
A sentence describing your plan costs nothing. A misaligned implementation costs hours. On anything non-trivial, state your approach and wait for confirmation before writing code.

**3. Complete implementations only.**
No stubs. No placeholders. No `// TODO` comments left in delivered code. If something can't be completed in a session, say so explicitly and document the stopping point in HANDOFF_BRIEF.

**4. Use the LEGO Block System for all file delivery.**
All files are delivered in clearly marked blocks:
```
// ========== BLOCK N: DESCRIPTION - START ==========
[code]
// ========== BLOCK N: DESCRIPTION - END ==========
```
Maximum ~100 lines per block. Announce block count before starting. Wait for confirmation before proceeding to next block if Mark requests it.

**5. Update documents as part of every session.**
HANDOFF_BRIEF.md gets updated at the end of every meaningful work session. HISTORY.md gets a new entry for every meaningful change. NEXT.md gets updated to reflect current priority order. Code without document updates is an incomplete session.

**6. Flag uncertainty before building.**
If something in the spec is unclear, ask. If two approaches are equally valid and the choice matters, present them and ask. Confident wrong implementations are more expensive than clarifying questions.

**7. Zero warnings policy.**
Compiler warnings are not acceptable in committed code. Fix every warning. Do not suppress warnings with flags, pragmas, or `// swiftlint:disable` comments. If a warning genuinely cannot be fixed — due to a third-party dependency or an Apple framework issue outside our control — document exactly why in a code comment and bring it to Mark for explicit approval before leaving it in place. Suppressing a warning to make the build look clean is not a fix. This rule has no exceptions without Mark's explicit approval.

**8. The documents are ground truth.**
When code and documents disagree, the code gets fixed. When you are uncertain about scope or direction, the spec wins. When the spec is silent, ask Mark.

**9. Ask before inventing.**
If something isn't specified, don't invent it. Ask. This is especially important for: UI layout details, audio parameters, animation specifics, and anything touching the breath guide.

---

## Engineering Principles

**One clock rules everything.**
`SessionEngine` is the single timing source for the entire session. Light flicker, isochronic audio pulses, and breath guide animation all derive from it. Nothing else has its own timer during a session. This is non-negotiable.

**Use CADisplayLink, not Timer.**
The nested recursive Timer approach in the original code is replaced. Use `CADisplayLink` or high-resolution `DispatchSourceTimer`. Compute flicker state mathematically from elapsed time — don't rely on callback timing accuracy.

**Audio is first-class.**
The isochronic tone engine is as important as the visual flicker. Isochronic tones = audible carrier frequency pulsed at the brainwave rate. The original `createTone()` generating a sub-audible sine wave at the brainwave frequency is wrong and must be replaced.

**Synchronization is the product.**
Light and audio pulses must be phase-aligned from the same clock source. If they drift, the app is broken.

**Prefer clarity over cleverness.**
This codebase will be read and extended. Name things for what they are. Structure follows the file architecture in the spec.

**iOS 17 floor + tvOS 17 floor (as of 2.0).**
This is a SwiftUI app with two targets that share a single `com.MarkFriedlander.PurePhase` bundle ID:
- `NeuroLight` (iOS) — primary target, iPhone first, iPad layout via the same target. Apple Silicon Macs run the iOS binary natively via "iPhone & iPad Apps on Mac" (no Catalyst target — that was tried and stripped during 2.0 hygiene).
- `NeuroLightTV` (tvOS) — added in 2.0. Six-tile lean-back UI. Same bundle ID = single App Store listing.

Source-shared via Xcode synchronized folder groups. iOS-only views (HomeView, AdvancedView, SessionConfigView, SessionView, OnboardingView, TileGesture, ContentView, NeuroLightApp) wrapped at file scope with `#if os(iOS)`. tvOS-specific views live in `NeuroLightTV/`. Engine, models, audio, and shared display components compile to both targets unchanged. See `Docs/MEMORY.md` "tvOS source-sharing" decision for details.

Do not introduce new Catalyst code. Do not introduce new `#if os(macOS)` branches. The few remaining `#if !targetEnvironment(macCatalyst)` guards in source are inert (Catalyst flag is off in the project) but kept rather than ripped out — minor cleanup deferred.

---

## What This Project Does Not Build

Do not add any of the following, ever, without explicit discussion and approval from Mark:

- Guided narration or voice content
- Session history, journaling, or streaks
- User accounts or sign-in of any kind
- Push notifications or reminders
- HealthKit integration (future scope, not now)
- Subscription or paywall logic
- Analytics, telemetry, or tracking
- iPad-specific layout (future scope)
- Social or sharing features
- CloudKit sync (the UserDefaults iCloud suite name bug in original code is a bug, not a feature)

---

## The File Architecture

```
NeuroLight/
├── App/
│   └── NeuroLightApp.swift
├── Models/
│   ├── BrainwaveState.swift
│   ├── BreathPattern.swift
│   └── SessionConfig.swift
├── Engine/
│   ├── SessionEngine.swift
│   ├── AudioEngine.swift
│   └── TorchController.swift
├── Views/
│   ├── HomeView.swift
│   ├── SessionConfigView.swift
│   ├── SessionView.swift
│   ├── BreathGuideView.swift
│   ├── AdvancedView.swift
│   ├── OnboardingView.swift
│   └── Components/
│       ├── IntentTileView.swift
│       └── GradientProgressRing.swift
└── Utilities/
    └── AppStorage+Keys.swift
```

Build in this order: Models → Engine → Views (Home → Config → Session → Advanced → Onboarding).

---

## The Three Primary States

| Intent | Hz | Evidence |
|--------|-----|---------|
| FOCUS | 40Hz | MIT/Nature 2024; active clinical trials |
| CALM | 10Hz | Decades of Alpha EEG literature |
| SLEEP | 2Hz | Delta sleep architecture research |

Advanced states (Theta, SMR, PRISM, Void, Custom) are behind the Advanced panel with appropriate "less studied" framing. PRISM was renamed from Psychedelic in 2.0; behavior is unchanged. DRIFT and BLOOM (psychoacoustic audio-only and audio-plus-visual modes) join Advanced in 2.0 — see PurePhase2.0Spec.md.

---

## Image Handling Rule (HARD)

**Never use the `Read` tool on a file ending `.png`, `.jpg`, `.jpeg`, `.gif`, `.heic`, `.heif`, `.bmp`, or `.webp`** — with one explicit exception: a file whose name ends `-thumb.png`.

### Why this rule exists

Reading an image file pipes the decoded image bytes through the conversation. iPhone simulator screenshots are roughly 3 MB each at full device resolution (1206×2622 ≈ 3,164,532 pixels). Several times during Pure Phase development, reading a full-size PNG into the conversation broke the session — context bloat, recovery required, lost work.

### How to verify visual output safely

Three options, in order of preference:

1. **Ask the user to look at the file in Finder.** They have eyes; I don't need to look at the rendered output to know if my code is right. ("Open `Docs/AppStoreScreenshots/iphone-6.9/01_home.png` and tell me if the four tiles are correctly ordered.")

2. **Read a thumbnail.** Any rendering or screenshot pipeline I build must produce a `-thumb.png` companion file at max dimension 400 px (~100–200 KB) via `sips -Z 400 input.png --out input-thumb.png`. The macOS built-in `sips` tool is reliable, no dependencies. The thumbnail is small enough to read without bloating context.

3. **Trust the code.** If I rendered something with explicit parameters (font size 192, stroke width 9, radial gradient stops at 0/30/65/100%), I do not need to look at the result to know what it is. If the code compiles and the parameters are right, the output is right. Visual confirmation is the user's job.

### Pattern for any pipeline that produces images

When writing code that captures or renders images, always include a thumbnail step:

```bash
xcrun simctl io "$udid" screenshot "$full"
sips -Z 400 "$full" --out "${full%.png}-thumb.png" >/dev/null
```

Or in any script: full-size next to thumbnail, never one without the other. The user reviews the full-size; I read the thumbnail only when the user explicitly asks me to verify a specific shot.

### What this looks like in practice

- **Don't:** "Let me check what that rendered as" → `Read /Users/.../screenshot.png` → CRASH
- **Do:** "Saved to `Docs/AppStoreScreenshots/iphone-6.9/01_home.png` (3 MB) and `01_home-thumb.png` (150 KB). The full-size is ready for App Store Connect; want me to spot-check the thumb, or will you review in Finder?"

This rule applies to every Claude Code session on every project. **Not just Pure Phase.** The crashes are a constraint of how images flow through the conversation, not a project-specific quirk.

---

## Reference Documents

- **HANDOFF_BRIEF.md** — read first. Current state and immediate next step.
- **MEMORY.md** — architectural decisions and their rationale.
- **HISTORY.md** — chronological log of what was built and why.
- **NEXT.md** — current priorities and guardrails for the next pass.
- **neurolight_design_spec.md** — the full product specification. The authoritative source.

---

*Pure Phase — Version 1.0 spec, May 2026.*
*Written in collaboration between Mark and Strategic Claude.*
