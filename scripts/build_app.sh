#!/bin/bash

# Ensure we're in the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR/.."

APP_NAME="TwinPixCleaner"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🚀 Building $APP_NAME..."

# 1. Build release version
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📦 Creating App Bundle..."

# 2. Create directory structure
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Copy executable
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# 4. Copy Info.plist
if [ -f "Info.plist" ]; then
    cp "Info.plist" "$CONTENTS_DIR/"
else
    echo "⚠️ Warning: Info.plist not found, using default"
fi

# 5. Generate AppIcon.icns from AppIcon.png, then copy it into the bundle
# (AppIcon.png is source-format JPEG despite its extension, so every sips call below
# forces PNG output — iconutil rejects iconset members that aren't real PNGs.)
if [ -f "AppIcon.png" ]; then
    ICONSET="AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    sips -s format png -z 16 16   AppIcon.png --out "$ICONSET/icon_16x16.png"      > /dev/null
    sips -s format png -z 32 32   AppIcon.png --out "$ICONSET/icon_16x16@2x.png"   > /dev/null
    sips -s format png -z 32 32   AppIcon.png --out "$ICONSET/icon_32x32.png"      > /dev/null
    sips -s format png -z 64 64   AppIcon.png --out "$ICONSET/icon_32x32@2x.png"   > /dev/null
    sips -s format png -z 128 128 AppIcon.png --out "$ICONSET/icon_128x128.png"    > /dev/null
    sips -s format png -z 256 256 AppIcon.png --out "$ICONSET/icon_128x128@2x.png" > /dev/null
    sips -s format png -z 256 256 AppIcon.png --out "$ICONSET/icon_256x256.png"    > /dev/null
    sips -s format png -z 512 512 AppIcon.png --out "$ICONSET/icon_256x256@2x.png" > /dev/null
    sips -s format png -z 512 512 AppIcon.png --out "$ICONSET/icon_512x512.png"    > /dev/null
    sips -s format png -z 1024 1024 AppIcon.png --out "$ICONSET/icon_512x512@2x.png" > /dev/null
    iconutil -c icns "$ICONSET" -o AppIcon.icns
    rm -rf "$ICONSET"
fi

if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/"
else
    echo "⚠️ Warning: AppIcon.icns not found/generated — the app will show a generic icon in the Dock"
fi

# 6. Copy SwiftPM Resources (if exists)
# SwiftPM creates a bundle named TwinPixCleaner_TwinPixCleaner.bundle
if [ -d "$BUILD_DIR/TwinPixCleaner_TwinPixCleaner.bundle" ]; then
    cp -r "$BUILD_DIR/TwinPixCleaner_TwinPixCleaner.bundle" "$RESOURCES_DIR/"
fi

# 6. Sign the app (ad-hoc signing to run locally)
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ $APP_NAME.app created successfully!"
echo "📂 Location: $(pwd)/$APP_BUNDLE"
echo ""
echo "To distribute:"
echo "1. Right-click $APP_NAME.app"
echo "2. Compress \"$APP_NAME\""
echo "3. Distribution file is ready at $(pwd)/$APP_NAME.zip"