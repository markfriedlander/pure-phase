# Pure Phase — App Store Submission State

*Authoritative state of the in-progress App Store Connect submission for Pure Phase 1.0. Updated whenever Mark and CC pause or resume the flow. If a CC session loses conversation context (compaction, etc.), this doc is the recovery point.*

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

## Submission progress checklist

### Done
- [x] Apple Developer License Agreement re-accepted (was blocking new app creation)
- [x] App ID `com.MarkFriedlander.PurePhase` registered at developer.apple.com (Description: "Pure Phase", Explicit, no special capabilities)
- [x] App Store Connect "New App" listing created (Pure Phase / iOS / English (U.S.) / SKU purephase / Full Access)
- [x] App Information → Primary Category: **Health & Fitness**
- [x] App Information → Secondary Category: **Lifestyle**
- [x] (Saved to App Store Connect)

### Pending on App Information page
- [ ] **Subtitle** (30 char max). Awaiting Mark's pick from:
  - "Focus. Calm. Sleep. Breathe." (28 chars — mirrors the four home tiles in order)
  - "Light, sound, breath. Free." (27 chars — emphasizes mechanism + that it's free)
  - or his own choice
- [ ] **Content Rights** — click "Set Up Content Rights Information" → answer "Does your app contain, show, or access third-party content?" → **No** (we synthesize all audio, generate all visuals, no licensed content)

### Pending on App Privacy page (sidebar → TRUST & SAFETY → App Privacy)
- [ ] Privacy Practices questionnaire — for **every category Apple asks about**, the answer is "Not Collected." Pure Phase collects nothing. Reference points:
  - No analytics, no tracking, no contact info, no health data, no location, no identifiers, no usage data, no diagnostics
  - The torch uses `AVCaptureDevice` to control hardware only — no image/video data captured
  - Worth confirming the questionnaire is complete and shows "No data collected."

### Pending on Pricing and Availability (sidebar — somewhere below GROWTH & MARKETING)
- [ ] Price tier: **Free**
- [ ] Availability: **All countries and regions** (default)
- [ ] No pre-orders

### Pending on the version 1.0 Distribution page (the page we landed on first)
- [ ] **Description** — Strategic Claude's draft, see below. Paste verbatim.
- [ ] **Keywords** (100 char max, comma-separated) — Strategic Claude's draft (99 chars), see below.
- [ ] **Promotional Text** (170 chars, changeable any time without resubmission) — Strategic Claude's draft, see below.
- [ ] **What's New in This Version** — for 1.0, the welcome blurb. See below.
- [ ] **Support URL** — `https://markfriedlander.github.io/pure-phase/support.html` (already live, HTTP 200 verified)
- [ ] **Marketing URL** (optional) — same Pages site root or skip
- [ ] **Privacy Policy URL** — `https://markfriedlander.github.io/pure-phase/privacy.html` (already live, HTTP 200 verified)
- [ ] **Screenshots** — 6 files in `Docs/AppStoreScreenshots/` (4 iPhone-6.9, 2 iPad-13). Mark's selection from earlier — these are final.
- [ ] **App Icon** — comes automatically from the uploaded build's asset catalog. No separate upload needed.

### Pending: Age Rating questionnaire
- [ ] Set rating to **17+** via Apple's content questionnaire. The reason is stroboscopic effects with documented seizure risk; this matters because it gates unsupervised minor use and aligns with the app's onboarding warning.

### Pending: Build upload (Mark's step, can't be automated)
- [ ] In Xcode: Product → Archive
- [ ] Wait for archive to finish (~1–2 min)
- [ ] Organizer opens automatically with the new archive selected
- [ ] Click **Distribute App** → **App Store Connect** → **Upload**
- [ ] Wait ~10–20 min for Apple processing (status visible in App Store Connect → TestFlight or in the version page)

### Pending: Bind build to version 1.0 + final submit
- [ ] Once build appears as "Ready to Submit" in App Store Connect, attach it to version 1.0 (button in the version's Build section)
- [ ] Click **Add for Review** → **Submit for Review**
- [ ] Wait 24–72 hours for Apple review

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
