#!/bin/bash

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

# 5. Copy Icon (if exists)
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$RESOURCES_DIR/"
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