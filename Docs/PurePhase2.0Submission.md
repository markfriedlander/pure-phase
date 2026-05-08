# Pure Phase 2.0 — App Store Submission State

*Working doc for the 2.0 submission flow. Mirrors the 1.0 doc (`Docs/AppStoreSubmission.md`) and references its hard-won gotchas.*

---

## Submission readiness checklist

| Item | Status |
|---|---|
| iOS binary | ready — built clean, awaits Xcode Archive + Upload |
| tvOS binary | ready — built clean, awaits Xcode Archive + Upload |
| TV App Icon (layered Back/Middle/Front, both home + App Store sizes) | ✅ committed in `NeuroLightTV/Assets.xcassets/...brandassets/` |
| TV Top Shelf hero (1920×720 + 2320×720 wide) | ✅ committed |
| iPhone screenshots | ✅ reusing 1.0 set |
| iPad screenshots | ✅ reusing 1.0 set |
| Apple TV screenshots (3840×2160) | ✅ four stills in `Docs/AppStoreScreenshots/tv-4k/` |
| Description (paste-ready, see below) | ✅ approved by Strategic Claude |
| Promotional Text (paste-ready) | ✅ approved |
| What's New in This Version (paste-ready) | ✅ approved |
| Keywords (paste-ready) | ✅ approved |
| App Privacy disclosure | unchanged — still "Data Not Collected" |
| Age Rating | unchanged — still 18+ |
| Subtitle | unchanged — "Breathe. Focus. Calm. Sleep." |

---

## App Store Connect submission steps

In rough order:

1. **Mark archives in Xcode**:
   - Scheme: `NeuroLight` (iOS)
   - Destination: `Any iOS Device (arm64)`
   - Product → Archive
   - Distribute App → App Store Connect → Upload
   - Wait ~10–20 min for Apple processing
2. **Mark archives the tvOS target**:
   - Scheme: `NeuroLightTV`
   - Destination: `Any tvOS Device (arm64)`
   - Product → Archive
   - Distribute App → App Store Connect → Upload
   - Wait ~10–20 min for Apple processing
3. **In App Store Connect (CC drives via Chrome MCP)**:
   - Open Pure Phase listing → "+" or version tab → create new version 2.0
   - **Add Platform → tvOS** on the existing app (CRITICAL — this keeps it one App Store listing rather than spawning a second app)
   - Update version 2.0 metadata: Description, Promotional Text, What's New, Keywords (paste-ready text below)
   - Upload Apple TV screenshots
   - Attach iOS build (1.0 (1)+1 = 2.0 (1) once it appears)
   - Attach tvOS build
   - Submit for Review

The 1.0 submission gotchas (`Docs/AppStoreSubmission.md`) almost all still apply. The big ones to remember:
- "Items required to start the review process" check is silent — if the page just spins on Submit, scroll up and look for the requirements list.
- React-state forms need the "type a character + delete" trick if a JS-set value isn't committing.
- Apple's first response to a 1.0 was a Guideline 2.1 "Information Needed." That's MUCH less likely on a 2.0 update (they already approved the app), but if it happens we already know the dance.
- App Review Notes were pre-filled during 1.0 — should still be in place. Worth verifying the 2.0 update doesn't clear them.

---

## Approved copy — paste verbatim into App Store Connect

### Description (paragraph to add)

This goes between the existing "ISOCHRONIC AUDIO" block and "ADVANCED" block in the current 1.0 description. Strategic Claude tightened the original CC draft from the more clinical "±4Hz over a 24-second cycle" framing to experiential language.

```
DRIFT & BLOOM
New psychoacoustic modes for headphones. Three synthesis layers create auditory depth and slow movement through pure tones — a breathing carrier, a drifting stereo field, and optional harmonic shimmer. DRIFT pairs them with a pure black canvas. BLOOM pairs them with a slow generative visual field that breathes and shifts color in sync with the audio. Non-stroboscopic — accessible to anyone who can't tolerate the entrainment modes.
```

### Promotional Text (170 char max)

```
Free. No subscription. Synchronized light, sound, and breath for focus, calm, sleep — and now DRIFT.
```

(102 chars — clean, points to the headline 2.0 addition.)

### What's New in This Version (4000 char max)

```
DRIFT — a new audio-only mode for headphones. Three psychoacoustic layers synthesize slow movement and depth from pure tones.

BLOOM — DRIFT plus slow generative visuals. The screen breathes with the audio.

Apple TV support. The full experience on a large screen.

Plus the existing safety acknowledgement now mentions bystanders. The flicker fills the room when projected.
```

### Keywords (100 char max, comma-separated, NO spaces)

```
brainwave,entrainment,focus,sleep,calm,meditation,breathwork,isochronic,psychoacoustic,gamma,alpha
```

(99 chars. Replaces 1.0 keywords. Net change: added `psychoacoustic` (real differentiating search term — nobody in this category is using it). Removed `drift` (also our state name, vanity), `binaural` (technically a different thing), `delta` (covered by sleep semantically).)

### Subtitle

Keep as-is. "Breathe. Focus. Calm. Sleep." 28 chars.

---

## Approved language guardrails (from MEMORY.md)

Same rules as 1.0. The new copy was screened against:

**Approved:** "useful for guided breathwork and meditation," "explore relaxation and focus through light and sound," "guides you toward," "non-stroboscopic," "psychoacoustic," "slow generative visuals," "auditory depth and movement," "accessible to anyone."

**Prohibited:** any disease name, "treats," "improves [outcome]," "clinically proven," "entrainment" applied to DRIFT/BLOOM specifically (those are NOT entrainment), Alzheimer's / amyloid / 40Hz clinical-trial references by name.

The new paragraph for DRIFT/BLOOM stays clean: "psychoacoustic," "auditory depth," "non-stroboscopic — accessible." No clinical claims attached to the new modes. The "Not a medical device" disclaimer at the end of the existing 1.0 description remains.

---

*Pure Phase 2.0 — submission ready May 8, 2026.*
*Approved by Strategic Claude; CC drives the App Store Connect flow.*
