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

# POST to the automation server.
api_post() {
  local path="$1"
  local body="${2:-}"
  if [ -n "$body" ]; then
    curl -s -X POST "${HOST}${path}" -H "Content-Type: application/json" -d "$body" > /dev/null
  else
    curl -s -X POST "${HOST}${path}" > /dev/null
  fi
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

  echo "  launching..."
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
  sleep 3

  wait_for_server

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
  sleep 1

  echo "  done. files in $outdir"
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
