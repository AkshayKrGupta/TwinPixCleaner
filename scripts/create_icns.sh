#!/bin/bash

SOURCE_ICON="$1"
ICONSET_DIR="AppIcon.iconset"

if [ -z "$SOURCE_ICON" ]; then
    echo "Usage: ./create_icns.sh <path_to_1024x1024_png>"
    exit 1
fi

echo "🎨 Creating iconset from $SOURCE_ICON..."

mkdir -p "$ICONSET_DIR"

# Resize to all required sizes
sips -z 16 16     --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_16x16.png"
sips -z 32 32     --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_16x16@2x.png"
sips -z 32 32     --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_32x32.png"
sips -z 64 64     --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_32x32@2x.png"
sips -z 128 128   --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_128x128.png"
sips -z 256 256   --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_128x128@2x.png"
sips -z 256 256   --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_256x256.png"
sips -z 512 512   --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_256x256@2x.png"
sips -z 512 512   --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_512x512.png"
sips -z 1024 1024 --setProperty format png "$SOURCE_ICON" --out "$ICONSET_DIR/icon_512x512@2x.png"

echo "🔨 Converting to .icns..."
iconutil -c icns "$ICONSET_DIR"

# Cleanup
rm -rf "$ICONSET_DIR"

echo "✅ AppIcon.icns created!"
