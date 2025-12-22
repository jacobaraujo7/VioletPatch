#!/bin/bash

set -e

APP_NAME="VioletPatch"
PROJECT_DIR="violetpatch"
OUTPUT_DIR="build"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "🔨 Building ARM64 (Apple Silicon)..."
cd "$PROJECT_DIR"
flutter build macos --release
cd ..

# Create ARM64 DMG
echo "📦 Creating ARM64 DMG..."
create-dmg \
  --volname "$APP_NAME" \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 200 \
  --icon "violetpatch.app" 150 200 \
  "$OUTPUT_DIR/$APP_NAME-arm64.dmg" \
  "$PROJECT_DIR/build/macos/Build/Products/Release/violetpatch.app"

# Clean build for x86
rm -rf "$PROJECT_DIR/build/macos"

echo "🔨 Building x86_64 (Intel)..."
cd "$PROJECT_DIR"
arch -x86_64 flutter build macos --release
cd ..

# Create x86_64 DMG
echo "📦 Creating x86_64 DMG..."
create-dmg \
  --volname "$APP_NAME" \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 200 \
  --icon "violetpatch.app" 150 200 \
  "$OUTPUT_DIR/$APP_NAME-x86_64.dmg" \
  "$PROJECT_DIR/build/macos/Build/Products/Release/violetpatch.app"

echo "✅ Done! DMGs created in $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR"
