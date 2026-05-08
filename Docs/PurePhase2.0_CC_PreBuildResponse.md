# Pure Phase 2.0 — CC Pre-Build Response

*Answers to the six architecture questions in §6 of the spec, locked before writing DRIFT/BLOOM code.*

---

## Q1. AVAudioSourceNode architecture

**Three separate `AVAudioSourceNode` instances mixed by `AVAudioMixerNode`.** Confirmed approach.

- Layer 1 (Breathing Carrier): one source node, base carrier frequency
- Layer 3 (Harmonic Shimmer): two additional source nodes at `carrier−1Hz` and `carrier+1Hz`, instantiated only when shimmer is enabled
- Mixer combines all active source nodes; per-layer volume / mute is just attaching/detaching nodes from the mixer

Layer 2 (Phase Drift) is **not** a separate node — it's per-channel delay implemented inside each source node's render block (see Q3). One node = one stereo output with the right channel delayed.

This gives:
- Independent enable/disable per layer (just attach/detach the source node)
- Solo-able for verification via the automation server
- No allocations on the render thread (all source nodes pre-instantiated at session start; layer toggle = `engine.attach`/`detach`)
- Consistent left-channel reference across layers (right channel delay computed from shared phase drift LFO state)

---

## Q2. LFO phase continuity

**Yes — phase is persistent state, never reset per render callback.** Confirmed approach.

Each LFO maintains a `Double` phase value in `[0, 1)`. Per render block:

```swift
phase = (phase + frameCount * lfoFrequency / sampleRate)
            .truncatingRemainder(dividingBy: 1.0)
```

The `truncatingRemainder` keeps the phase from drifting toward floating-point precision loss over long sessions. At 0.042 Hz (Layer 1 breathing carrier) and 48 kHz sample rate, a 1-hour session accumulates ~150 cycles — well within `Double` precision, but the modulo is cheap and prevents long-run drift on Open-mode sessions.

LFO phases live in a shared `DriftSynthesisState` object (see Q5) so all three source nodes can read them without each maintaining its own copy. This also eliminates a class of bugs where the three carriers would slowly desync.

---

## Q3. Phase Drift delay implementation

**Variable-delay ring buffer inside each source node's render callback.** Not `AVAudioUnitDelay`.

Reasons:
- Tighter control over phase continuity — `AVAudioUnitDelay` reschedules audio in a way that can introduce small artifacts when its delay parameter is modulated frequently
- Modulation rate is very slow (1/40 Hz) — interpolation doesn't need to be heroic; linear is fine
- ~50 lines of code, no new audio framework surface
- Each source node is self-contained — Layer 3's two additional nodes get the same delay treatment without extra plumbing

Implementation per source node:

```
Per frame n:
  1. mono = sin(2π × (carrier + breathingLFO(t) + detune) × t / sr)
           × isochronicEnvelope(t)
  2. ringBuffer.write(mono)
  3. delaySamples = maxDelaySamples × (1 - cos(2π × phaseDriftLFO(t))) / 2
  4. L_out = mono
  5. R_out = ringBuffer.read(at: writeIdx - delaySamples)   // linear interp
```

Ring buffer size: 512 samples (~10.7 ms at 48 kHz, safely above the 3.5 ms max delay we need).

`writeIdx - delaySamples` is non-integer; linear interpolation between adjacent buffer entries gives a smooth result without phasing artifacts.

---

## Q4. BLOOM visual implementation

**SwiftUI `Canvas` driven by `TimelineView(.animation)`.** iOS 17 compatible.

`MeshGradient` is iOS 18+. Our deployment floor is iOS 17, so it's out for 2.0.

`Canvas` supports `RadialGradient` shading via `GraphicsContext.fill(_:with:)`. The base bloom is a centered radial gradient with 4–5 color stops (warm core → orange → deep red → black). The three LFO-driven mappings are:

| LFO | Visual parameter |
|---|---|
| Breathing Carrier (24 s, sin) | Bloom radius scale (0.85 → 1.15× base) and overall opacity (0.85 → 1.0) |
| Phase Drift (40 s, sin) | Color stop interpolation between two warm palettes (amber-leaning ↔ red-leaning) |
| Harmonic Shimmer (1–2 Hz, when ON) | Subtle additive ring overlay at low alpha — drawn as a second `Canvas` pass with a soft inner-ring stroke modulated at the beat frequency |

`TimelineView(.animation)` updates at the display's preferred refresh rate (60 Hz on most devices, 120 Hz on ProMotion). The `Canvas` reads the current LFO phases from `DriftSynthesisState` (see Q5) and draws.

Performance budget: a single `Canvas` with 1–2 radial gradients per frame on iOS 17 floor (A12 or later) is well under budget. If a future device target falls below this, we escalate to a Metal pass — but that's a 3.0 concern at the earliest.

---

## Q5. Audio → Visual state bridge

**A `final class DriftSynthesisState: @unchecked Sendable` holding atomic-by-alignment `Double` values, written from the audio render thread, read from the main thread without locks.**

The audio render thread runs at real-time priority and cannot block, lock, or allocate. The SwiftUI view layer reads observable state on the main actor. We need a thread-safe bridge that costs nothing on the audio side.

The hardware fact we lean on: **64-bit aligned `Double` stores are atomic on all Apple silicon and modern Intel.** A naked write of a `Double` cannot tear at the architecture level. The Swift language model is more conservative — it requires explicit synchronization for cross-actor mutation — but at the hardware level the writes are clean.

Approach:

```swift
final class DriftSynthesisState: @unchecked Sendable {
    // Read by view layer on main thread, written by audio render thread.
    // Word-aligned Double writes are atomic on A-series and Apple silicon.
    // Tearing is invisible for sub-Hz visual modulation; even a one-frame
    // stale value cannot be perceived.
    var breathingCarrierPhase: Double = 0   // [0, 1)
    var phaseDriftPhase: Double = 0          // [0, 1)
    var harmonicShimmerPhase: Double = 0     // [0, 1)

    // Parameters set by main thread, read by audio render thread.
    // Same atomicity argument applies.
    var carrierHz: Double = 220.0
    var layerBreathingCarrier: Bool = true
    var layerPhaseDrift: Bool = true
    var layerHarmonicShimmer: Bool = false
}
```

The `@unchecked Sendable` annotation tells Swift's concurrency checker we know what we're doing. The class lives at session scope — created at session start, destroyed at session end. The audio thread holds a strong reference for the duration of the session; the view layer reads through `AutomationBus.driftState` which is set on session start and cleared on session end.

For the SwiftUI side, `TimelineView(.animation)` re-renders at display rate; each render reads the current phase values. No `@Published`, no `@Observable` — explicit polling at frame rate is simpler and the values change continuously anyway, so observation churn would just match the redraw rate.

**Rationale comment goes in the source code above the class declaration**, citing the architectural choice and why the unchecked-Sendable is safe in this specific use case.

If concurrency-strict mode complains in a way `@unchecked` doesn't suppress, the fallback is a `os_unfair_lock`-protected struct read — but I expect we won't need that.

---

## Q6. tvOS focus navigation audit

Quick scan of current navigation patterns and what 2.0 tvOS needs:

**On TV (the only views shipped to tvOS in 2.0):**

- **HomeView** — six tiles (BREATHE/FOCUS/CALM/SLEEP/DRIFT/BLOOM). Each tile is currently a `Button` with `simultaneousGesture(LongPressGesture)`. On tvOS, `Button` is focusable by default, the long press doesn't apply (no config on TV), so the tile reduces to a plain `Button(action: start)`. **`#if os(tvOS)`** branch in `IntentTileView` / `TileGesture.swift` to drop the long press on TV.
- **SessionView** — full-bleed flicker / breath ring / edge progress. On tvOS, the tap-to-reveal-exit gesture needs translation. Siri Remote sends `.cancel` on Menu button press and `.select` on click. Map both to "reveal exit overlay" or just direct-exit. Recommendation: Menu button = exit immediately (matches tvOS HIG — Menu always backs out); click on touch surface = reveal overlay (consistent with iOS tap behavior).

**Not on TV in 2.0** (no focus work needed):
- AdvancedView (not shown)
- SessionConfigView (not shown — TV uses defaults, no config)
- OnboardingView (still applies on TV — same checkbox-acknowledgement gate). Need to verify it focuses cleanly. The single checkbox + ENTER button pattern should work without modification.

**Specific code touchpoints I expect to add/modify:**

1. `TileGesture.swift` — `#if os(tvOS)` branch with no long-press
2. `SessionView.swift` — `#if os(tvOS)` branch for Menu button handling via `onExitCommand` and `onPlayPauseCommand`
3. `HomeView.swift` — drop the `ADVANCED` nav link on tvOS (no AdvancedView on TV)
4. New tvOS scheme + target in the Xcode project (the only project-file change)
5. `TorchController.swift` — verify torch UI is gated with `!targetEnvironment(macCatalyst) && !os(tvOS)` everywhere it appears
6. `OnboardingView.swift` — quick smoke test on tvOS simulator. May need minor focus tweaks but I don't expect new work

**Apple TV deployment target: tvOS 17.0** to match iOS floor.

---

*CC pre-build response — locked before DRIFT/BLOOM code.*
