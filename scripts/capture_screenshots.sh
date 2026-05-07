#!/usr/bin/env bash
#
# Capture App Store screenshots for Pure Phase by driving the app
# through its key states via the debug HTTP automation server.
#
# Usage:
#   scripts/capture_screenshots.sh
#
# Apple's required screenshot sizes for 1.0 submission (as of 2026):
#   iPhone 6.9"   1320 × 2868   (iPhone 17 Pro Max — auto-scales smaller iPhones)
#   iPad 13"      2064 × 2752   (iPad Pro 13" M5  — auto-scales smaller iPads)
#
# We capture 4 screens (the only visually distinctive ones — entrainment
# session screens are repetitive across Focus/Calm/Sleep so we don't
# duplicate them):
#   1. home          — the four-tile entry point
#   2. advanced      — the five-tile science menu
#   3. config        — BREATHE config (unique cues toggle + ambient picker)
#   4. breathe       — BREATHE session in progress (cream ring + halo)
#   5. focus_flash   — FOCUS session caught at the flicker on-frame
#                      (40 Hz; bright amber #F5A623 is the most striking
#                      on-frame in the app, caught via 8-shot burst +
#                      brightness-based picker — see scripts/pick_brightest.swift)
#
# For each PNG, we also produce a `-thumb.png` at max dimension 400px
# via the built-in `sips` tool. The thumbnails are small enough (~150 KB)
# to be safely read by tools that pipe image data through a conversation.
# The full-size PNGs are what get uploaded to App Store Connect.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_ROOT="$REPO_ROOT/Docs/AppStoreScreenshots"
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/NeuroLight-hejliqafwjwjgnaagjvjsvpovtyq/Build/Products/Debug-iphonesimulator/NeuroLight.app"
BUNDLE_ID="com.MarkFriedlander.PurePhase"
PORT=8770
HOST="http://127.0.0.1:${PORT}"

# (display-name, output-subfolder)
TARGETS=(
  "iPhone 17 Pro Max|iphone-6.9"
  "iPad Pro 13-inch (M5)|ipad-13"
)

mkdir -p "$OUT_ROOT"

# --- helpers --------------------------------------------------------

# Resolve a simulator UDID by display name. Errors out if not found.
udid_for() {
  local name="$1"
  xcrun simctl list devices available --json \
    | python3 -c "
import json, sys
d = json.load(sys.stdin)
for runtime, devs in d['devices'].items():
    if 'iOS' not in runtime and 'iPadOS' not in runtime: continue
    for dev in devs:
        if dev.get('name') == '$name' and dev.get('isAvailable'):
            print(dev['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null || true
}

# Wait for the automation server to respond.
wait_for_server() {
  local tries=0
  until curl -sf -o /dev/null "$HOST/help" 2>/dev/null; do
    tries=$((tries + 1))
    if [ $tries -gt 30 ]; then
      echo "  ! server didn't come up after 30s" >&2
      return 1
    fi
    sleep 1
  done
}

# Save a screenshot via simctl AND generate a -thumb.png alongside.
shot() {
  local udid="$1"
  local outdir="$2"
  local name="$3"
  local full="$outdir/${name}.png"
  local thumb="$outdir/${name}-thumb.png"
  xcrun simctl io "$udid" screenshot "$full" >/dev/null 2>&1
  sips -Z 400 "$full" --out "$thumb" >/dev/null
  printf "    saved %-22s  full=%s thumb=%s\n" "$name" \
    "$(du -h "$full" | cut -f1)" \
    "$(du -h "$thumb" | cut -f1)"
}

# POST to the automation server. Short timeout so a missing server
# doesn't hang the script — failed bind on a busy port is silent and
# we'd rather fail loud and fast than wait 75 s of TCP timeout.
api_post() {
  local path="$1"
  local body="${2:-}"
  if [ -n "$body" ]; then
    curl -s --max-time 2 -X POST "${HOST}${path}" -H "Content-Type: application/json" -d "$body" > /dev/null || true
  else
    curl -s --max-time 2 -X POST "${HOST}${path}" > /dev/null || true
  fi
}

# Kill Pure Phase on every other booted sim BEFORE starting a new capture,
# so we never have two sims fighting for port 8770 on the Mac's localhost.
# (Discovered the hard way: identical screenshots from a sim where the
# server failed to bind because a previous sim's app was still running.)
release_port_from_other_sims() {
  local me="$1"
  local booted
  booted=$(xcrun simctl list devices booted 2>/dev/null \
    | grep -oE '\([0-9A-F-]{36}\)' | tr -d '()')
  for other in $booted; do
    if [ "$other" != "$me" ]; then
      xcrun simctl terminate "$other" "$BUNDLE_ID" 2>/dev/null || true
    fi
  done
}

# --- capture flow per device ----------------------------------------

capture_one() {
  local name="$1"
  local subfolder="$2"
  local outdir="$OUT_ROOT/$subfolder"
  mkdir -p "$outdir"

  echo ""
  echo "=== $name ==="

  local udid
  udid=$(udid_for "$name")
  if [ -z "$udid" ]; then
    echo "  ! no available simulator named '$name' — skipping" >&2
    return 0
  fi
  echo "  udid: $udid"

  echo "  booting..."
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true

  echo "  setting clean status bar (9:41, full battery, full wifi)..."
  xcrun simctl status_bar "$udid" override \
    --time "9:41" \
    --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3 \
    --dataNetwork wifi >/dev/null 2>&1 || true

  echo "  installing..."
  xcrun simctl install "$udid" "$APP_PATH"

  echo "  resetting onboarding..."
  xcrun simctl spawn "$udid" defaults delete "$BUNDLE_ID" hasSeenOnboarding >/dev/null 2>&1 || true
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true

  echo "  releasing port 8770 from any other booted sims..."
  release_port_from_other_sims "$udid"

  echo "  launching..."
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
  sleep 3

  if ! wait_for_server; then
    echo "  ! automation server never came up on $name — skipping" >&2
    return 1
  fi

  # Skip the onboarding warning visually — we capture the post-onboarding
  # experience. Reviewers see the safety story via the App Store listing.
  api_post "/onboarding/accept"
  sleep 2

  shot "$udid" "$outdir" "01_home"

  api_post "/navigate" '{"to":"advanced"}'
  sleep 1.5
  shot "$udid" "$outdir" "02_advanced"

  api_post "/navigate" '{"to":"breathwork"}'
  sleep 1.5
  shot "$udid" "$outdir" "03_config_breathe"

  # Start a BREATHE session via the API. Breathwork has no flicker so
  # capture timing is trivial — just wait through fade-in and let the
  # ring be mid-inhale.
  api_post "/session/start" '{"state":"breathwork","duration":"five"}'
  sleep 6
  shot "$udid" "$outdir" "04_breathe_session"

  api_post "/tap" '{"id":"session.exit"}'
  sleep 2

  # FOCUS at flicker on-frame. 40 Hz on-phase is too short to time
  # via /state polling (12.5 ms vs ~150 ms screenshot dispatch), so we
  # use burst capture: 8 screenshots back-to-back, then pick by
  # measured pixel luminance. FOCUS's bright amber (#F5A623, luminance
  # ~167) gives a sharp signal vs the black off-frames (~0).
  api_post "/session/start" '{"state":"focus","duration":"five"}'
  sleep 4   # wait through 3 s fade-in
  capture_at_on_phase "$udid" "$outdir" "05_focus_flash"
  api_post "/tap" '{"id":"session.exit"}'
  sleep 1

  echo "  done. files in $outdir"
}

# Capture an on-frame of the visual flicker via burst-capture.
#
# Why this approach: polling /state for flickerPhase=true and snapping
# afterwards has a 200–400 ms overhead between the "on" signal and the
# actual capture (curl + python parse + simctl dispatch). At 2 Hz the
# on-phase is only 250 ms, so polling consistently misses.
#
# Burst-capture sidesteps the timing problem: take 8 screenshots
# back-to-back (~150 ms each, ~1.2 s total), covering 2.4 cycles at
# 2 Hz so several on-frames are guaranteed to be in the burst. Then
# pick the largest file by byte size. PNG compresses dark uniform
# frames much smaller than frames with vivid color, so the on-frame
# is reliably the largest file in the burst.
capture_at_on_phase() {
  local udid="$1"
  local outdir="$2"
  local name="$3"
  local full="$outdir/${name}.png"
  local thumb="$outdir/${name}-thumb.png"

  local burst_dir="${outdir}/.burst"
  mkdir -p "$burst_dir"
  rm -f "$burst_dir"/*.png

  for i in $(seq 1 8); do
    xcrun simctl io "$udid" screenshot "$burst_dir/burst_${i}.png" >/dev/null 2>&1
  done

  # Pick the brightest of the burst by ACTUAL average pixel luminance
  # (not file size — PNG compresses uniform low-saturation colors like
  # SLEEP's ember red almost identically to uniform black, which would
  # break a size-based picker). The Swift helper measures perceived
  # luminance and prints the brightest path.
  local best
  best=$(swift "$REPO_ROOT/scripts/pick_brightest.swift" "$burst_dir"/burst_*.png 2>/dev/null)
  if [ -z "$best" ] || [ ! -f "$best" ]; then
    echo "    ! $name: brightness picker failed; falling back to largest file" >&2
    best=$(ls -S "$burst_dir"/burst_*.png 2>/dev/null | head -1)
  fi
  if [ -z "$best" ]; then
    echo "    ! $name: burst capture produced no files" >&2
    rm -rf "$burst_dir"
    return
  fi

  cp "$best" "$full"
  sips -Z 400 "$full" --out "$thumb" >/dev/null
  # Keep the burst dir on disk for inspection — if the auto-pick is
  # ever wrong, the user can browse the bursts and rename the right
  # one. Folder is gitignored along with everything under
  # Docs/AppStoreScreenshots/.
  printf "    saved %-12s  full=%s thumb=%s (brightest of 8 burst, kept in .burst)\n" "$name" \
    "$(du -h "$full" | cut -f1)" \
    "$(du -h "$thumb" | cut -f1)"
}

# --- main -----------------------------------------------------------

echo "Pure Phase — App Store screenshot capture"
echo "Output root: $OUT_ROOT"

if [ ! -d "$APP_PATH" ]; then
  echo "Build the app first:" >&2
  echo "  xcodebuild -project NeuroLight.xcodeproj -scheme NeuroLight \\" >&2
  echo "    -destination 'generic/platform=iOS Simulator' -configuration Debug build" >&2
  exit 1
fi

for entry in "${TARGETS[@]}"; do
  IFS='|' read -r name subfolder <<< "$entry"
  capture_one "$name" "$subfolder"
done

echo ""
echo "All done."
echo "  Full-size PNGs: ready for App Store Connect upload"
echo "  *-thumb.png:    safe-to-read previews (max 400 px, ~150 KB)"
