#!/bin/bash

# --------------------------------------------
#  DMG Build Script for macOS Applications
# --------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR/.."

APP_PATH="${1:-TwinPixCleaner.app}"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App bundle '$APP_PATH' not found."
    echo "Usage: ./scripts/build_dmg.sh [MyApp.app]"
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
DMG_NAME="$APP_NAME.dmg"
STAGING_DIR="$APP_NAME"_dmg

# --------------------------------------------
# 1. Create staging folder
# --------------------------------------------
echo "📦 Creating staging directory..."
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Ensure cleanup on exit
trap 'rm -rf "$STAGING_DIR"' EXIT

# Copy app bundle
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"

# --------------------------------------------
# 2. Build DMG
# --------------------------------------------
echo "💿 Building DMG..."

hdiutil create "$DMG_NAME" \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov

echo "✅ DMG created successfully: $(pwd)/$DMG_NAME"
