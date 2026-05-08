#!/usr/bin/env bash
#
# Build, codesign, and install Pure Phase on a paired physical iPhone.
#
# Usage:
#   scripts/install_on_device.sh [device-udid]
#
# If no UDID is passed, the script prompts you to pick from paired
# available devices.
#
# Why this script exists:
# When `xcodebuild` runs from the command line on macOS Sequoia+, it
# attaches `com.apple.provenance` extended attributes to files in the
# build product. The codesign step then rejects with "resource fork,
# Finder information, or similar detritus not allowed". Xcode's GUI
# build doesn't hit this — only command-line builds do.
#
# This script: (1) strips xattrs from the source tree, (2) runs the
# build, (3) strips xattrs from the build product, (4) codesigns
# manually with the correct entitlements, (5) installs via devicectl.
#
# We do NOT add this as an Xcode Run Script build phase because that
# would touch the project file (.pbxproj) and create churn for a
# command-line-only problem. Mark's day-to-day archive flow uses Xcode
# directly and never hits this.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

BUNDLE_ID="com.MarkFriedlander.PurePhase"
SCHEME="NeuroLight"
PROJECT="NeuroLight.xcodeproj"
BUILD_DIR="$REPO_ROOT/build/DeviceBuild"
APP_PATH="$BUILD_DIR/Build/Products/Debug-iphoneos/NeuroLight.app"
SIGN_ID="Apple Development: Mark Friedlander (B95S762SU6)"

# --- Pick device UDID -----------------------------------------------

DEVICE_UDID="${1:-}"
if [ -z "$DEVICE_UDID" ]; then
  echo "Available paired devices:"
  xcrun devicectl list devices 2>/dev/null \
    | awk '/available \(paired\)/ && /iPhone/ {print NR": "$0}'
  echo ""
  read -r -p "Paste the UDID of the device to install on: " DEVICE_UDID
fi

if [ -z "$DEVICE_UDID" ]; then
  echo "No device UDID provided. Aborting." >&2
  exit 1
fi

# --- Strip xattrs from source ---------------------------------------

echo "==> Stripping com.apple.provenance from source tree"
xattr -cr NeuroLight 2>/dev/null || true
xattr -cr "$BUILD_DIR" 2>/dev/null || true

# --- Build (will fail at codesign — that's expected) ---------------

echo "==> Building for device (codesign will fail; we re-sign manually)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$DEVICE_UDID" \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR" \
  build 2>&1 | tail -5 || true

if [ ! -d "$APP_PATH" ]; then
  echo "Build product missing at $APP_PATH — aborting" >&2
  exit 1
fi

# --- Strip xattrs from build product, then codesign ----------------

echo "==> Stripping xattrs from .app and codesigning"
xattr -cr "$APP_PATH"

ENTITLEMENTS="$BUILD_DIR/Build/Intermediates.noindex/NeuroLight.build/Debug-iphoneos/NeuroLight.build/NeuroLight.app.xcent"
if [ ! -f "$ENTITLEMENTS" ]; then
  echo "Entitlements file missing at $ENTITLEMENTS — aborting" >&2
  exit 1
fi

codesign \
  --force \
  --sign "$SIGN_ID" \
  --entitlements "$ENTITLEMENTS" \
  --timestamp=none \
  --generate-entitlement-der \
  "$APP_PATH"

codesign --verify --verbose "$APP_PATH"

# --- Install ---------------------------------------------------------

echo "==> Installing on device $DEVICE_UDID"
xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"

echo ""
echo "Done. Pure Phase installed on the device. Launch it from the home screen."
