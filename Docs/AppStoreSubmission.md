# Pure Phase — App Store Submission State

*Pure Phase 1.0 was submitted to Apple's review queue on May 7, 2026. This doc now records the final state of every section + lessons learned. Keep it for the 1.0.1 (or any future) submission — it captures the gotchas that aren't obvious from Apple's UI.*

## Final status: SUBMITTED ✅

- Submitted at: May 7, 2026
- Build: 1.0 (1) — uploaded via Xcode Archive → Distribute App → App Store Connect → Upload
- Expected review window: 24–72 hours
- Auto-release on approval (default)

## 1.0.1 cleanup punch list (from this submission)

These are small things that surfaced during submission. None blocked 1.0; all worth doing before 1.0.1.

- **Add `ITSAppUsesNonExemptEncryption = false` to Info.plist.** Apple's modal even told us: setting this in Info.plist skips the encryption questionnaire on every future submission. The app uses zero encryption (no network calls in production) so this is factually safe.
- **Resolve the 3 build warnings.** Mark saw 3 warnings during Archive. Identify and fix before 1.0.1 — clean baseline for the next submission. (Capture warning text from Xcode's Issue Navigator.)
- **Consider whether to re-capture iPhone screenshots at 1284×2778 native** rather than capturing 1320×2868 and downsampling (we resized via `sips -z 2778 1284` for this submission — see `scripts/capture_screenshots.sh` header). Apple's iPhone slot still labels itself "6.5\" Display" and rejects 1320×2868. If this is still true at 1.0.1, change the Simulator target in `capture_screenshots.sh` to a device whose native screenshot size is 1284×2778.

---



---

## Account / app identifiers

| Item | Value |
|---|---|
| Apple Developer Team ID | `FBUNBDS7R7` |
| Bundle ID (Apple Developer) | `com.MarkFriedlander.PurePhase` (registered May 2026) |
| App Store Connect Apple ID | `6767311034` |
| App display name | `Pure Phase` |
| SKU | `purephase` |
| Primary Language | English (U.S.) |

## Heads-up: developer membership

Apple Developer membership expires in **22 days** from May 2026 (per the developer.apple.com banner Mark saw during this session). Mark plans to renew but Apple's renewal flow was misbehaving when he tried. App review usually takes 1–3 days, so submitting now is fine — just don't let the renewal slip beyond expiration day, or the listing gets unlisted.

---

## Submission checklist — all done

| Section | Final value |
|---|---|
| Developer License Agreement | re-accepted |
| App ID registration | `com.MarkFriedlander.PurePhase` (developer.apple.com) |
| App Store Connect listing | created (Pure Phase / iOS / SKU `purephase` / Full Access) |
| Primary Category | Health & Fitness |
| Secondary Category | Lifestyle |
| Subtitle | "Breathe. Focus. Calm. Sleep." (28 chars) |
| Content Rights | No (third-party content) |
| App Privacy | Data Not Collected (published) |
| Pricing | Free, 175 countries/regions |
| Apple Silicon Mac availability | enabled (Automatic, macOS 11.0) |
| Description | Strategic Claude's verbatim text — see drafted copy below |
| Keywords | `brainwave,entrainment,focus,sleep,calm,meditation,breathwork,isochronic,gamma,alpha,delta,binaural` (99 chars) |
| Promotional Text | "Free. No subscription. Synchronized light, sound, and breath for focus, calm, and sleep. Tap to begin." |
| Version | 1.0 |
| Copyright | 2026 Mark Friedlander |
| Support URL | https://markfriedlander.github.io/pure-phase/support.html |
| Privacy Policy URL | https://markfriedlander.github.io/pure-phase/privacy.html |
| Marketing URL | (skipped — optional) |
| iPhone screenshots | 4 (resized to 1284×2778 — see gotchas) |
| iPad screenshots | 2 (2064×2752 native, no resize) |
| Age Rating | 18+ override (stroboscopic effects / documented seizure risk). On legacy iOS <26 displays as 17+ globally with regional exceptions (A18 Brazil, 19+ Korea). |
| Regulated Medical Device | No |
| Build | 1.0 (1) — uploaded via Xcode Archive → Distribute App → App Store Connect → Upload |
| Encryption (Export Compliance) | None of the algorithms (Pure Phase has no network calls, no custom crypto). 1.0.1 cleanup: add `ITSAppUsesNonExemptEncryption = false` to Info.plist. |
| Sign-in required (review) | Off (no accounts) |
| Contact Information | Mark Friedlander / 818-416-5229 / markfriedlander@yahoo.com |
| Final action | **Add for Review** → submitted May 7, 2026 |

## Lessons / gotchas to remember next time

1. **iPhone screenshot dimensions** — App Store Connect's iPhone slot is labeled "6.5\" Display" and rejects 1320×2868 (iPhone 17 Pro Max native). Accepted sizes are 1242×2688 or 1284×2778. iPad 2064×2752 is accepted natively. Resize iPhone shots before upload (`sips -z 2778 1284 SRC --out resized/SRC`).
2. **Apple's age rating tiers** — 17+ no longer exists in the dropdown. The new tiers are 13+ / 16+ / 18+. For seizure-risk gating, **18+** is the right factual override. Apple maps 18+ back to 17+ for legacy iOS versions.
3. **The "Items required to start review" check is silent** — if you click Add for Review and the page just spins, scroll up: there's a list saying what's missing. Apple won't pop a toast or scroll to the missing field.
4. **"Sign-in required" defaults to ON** for new submissions. Pure Phase has no accounts; turn it off explicitly or you'll be asked for demo credentials.
5. **Programmatic input setters don't always commit to React state.** If a section refuses to save after JS-set values, click into a field, type a character, delete it, click Save — that triggers React's onChange and the values stick.
6. **The Add for Review button requires trusted pointer events.** Programmatic `.click()` and synthesized PointerEvents both fail silently. You have to physically click it.
7. **Encryption questionnaire pops every submission** unless `ITSAppUsesNonExemptEncryption = false` is in Info.plist. Adding that key skips it forever for an app like ours that uses zero encryption.
8. **App Privacy "Publish" is a one-way commit** for the version — once published, edits are versioned. Pure Phase's "Data Not Collected" answer is dead simple, but that publish step is required, not optional.
9. **Apple's renewal flow misbehaves in Safari** — Mark hit this. Chrome worked. If renewal fails in Safari, switch browsers before assuming the issue is your account.
10. **Don't look at "what's new"** — for 1.0, there's no "What's New in This Version" field on the inflight page. That field only appears on subsequent version submissions.

---

## Drafted copy (from Strategic Claude — paste verbatim into App Store Connect)

### Description (~1,800 chars, 4,000 max)

```
Pure Phase uses synchronized light, sound, and breath to guide you into focused, calm, or sleep states — without subscriptions, accounts, narration, or bloat.

Tap to begin. Hold to tune. That's the whole interface.

THREE SCIENCE-GROUNDED STATES

FOCUS — 40Hz gamma frequency, synchronized light and isochronic audio. Associated with peak mental clarity. The subject of ongoing clinical research at MIT and elsewhere.

CALM — 10Hz alpha frequency. One of the most consistently documented frequencies in relaxation and stress research. Ideal for unwinding, creative work, or transition between tasks.

SLEEP — 2Hz delta frequency. Use with eyes closed and torch enabled. The flashlight pulses at the session frequency through your eyelids — no screen required.

BREATHE — GUIDED BREATHWORK
A fourth mode with no flicker — just a breathing ring that expands and contracts to pace your breath. Choose from Coherence (6 breaths per minute, the HRV resonance frequency), 4-7-8, Box breathing, or Slow Wave. Or build your own pattern in Advanced settings.

ISOCHRONIC AUDIO
A warm audible carrier tone pulses at the brainwave frequency, synchronized frame-by-frame with the visual flicker. Underneath, a procedurally generated ambient texture — pink noise, brown noise, or sustained drone — provides continuity and masks environmental sound. Everything is generated on-device. No audio files.

ADVANCED
For users who know what they want: Theta, SMR, Psychedelic, and Void states, a custom Hz slider from 0.5 to 40Hz, custom breath timing with independent inhale, hold, and exhale controls, and carrier frequency selection. Clearly labeled as exploratory.

PURE PHASE IS FREE
No subscription. No account. No guided narration. No content library. No streak tracking. No ads. No data collection of any kind. Everything runs on your device.

⚠️ Pure Phase uses rapid rhythmic light pulses. Do not use if you are photosensitive or have a history of epilepsy or seizure disorders. Always use in a safe, seated, stationary environment. Not a medical device.
```

### Promotional Text (170 char max — can be changed without resubmission)

```
Free. No subscription. Synchronized light, sound, and breath for focus, calm, and sleep. Tap to begin.
```

### Keywords (100 char max, comma-separated, NO spaces between)

```
brainwave,entrainment,focus,sleep,calm,meditation,breathwork,isochronic,gamma,alpha,delta,binaural
```

(99 chars exactly — one to spare)

### What's New in This Version (for 1.0)

```
Welcome to Pure Phase. Four modes: BREATHE, FOCUS, CALM, SLEEP. Synchronized light, isochronic audio, and guided breath. Free, forever.
```

---

## Approved/prohibited language guardrails (re-cite from MEMORY.md)

When pasting / editing copy, reviewers and future-CC must respect these rules:

**Approved:** "useful for guided breathwork and meditation," "explore relaxation and focus through light and sound," "guides you toward."

**Prohibited:** any disease name, "treats," "improves [outcome]," "clinically proven," any reference to Alzheimer's, amyloid, or the 40Hz clinical-trial research by name. The science is real but disease-name association triggers FDA medical device classification and Apple review complications.

The current draft above stays inside the lines — note "associated with" rather than "treats," "subject of ongoing clinical research" rather than naming the trials, and a clear "Not a medical device" disclaimer at the end.

---

## Open questions for Mark

- Subtitle? (See the two proposals above; or pick your own at ≤30 chars)
- After uploading the build via Xcode Organizer, does the binary need a TestFlight pass first or are we going straight to App Store review? (Current plan: skip TestFlight per Mark's earlier "I'm OK doing that in public" — confirming this is still the call when the time comes)

---

## Where this doc fits

When picking up a new CC session for this project, the read-order is:
1. `Docs/CLAUDE.md` (operational rules)
2. `Docs/HANDOFF_BRIEF.md` (current session bridge)
3. **This file** if the prior session was working on App Store submission
4. `Docs/MEMORY.md` and `Docs/HISTORY.md` for deeper context

This doc deletes itself, in essence, the day the app ships and version 1.0 is approved.

*Last updated: May 2026 — mid-session, with categories saved, awaiting subtitle pick + remaining metadata + build upload.*
