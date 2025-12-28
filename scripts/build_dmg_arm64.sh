#!/bin/bash

# VioletPatch - macOS DMG Build Script
# Usage: ./scripts/build_violetpatch_dmg.sh

set -e

# Configuration
APP_NAME="violetpatch"
PRETTY_APP_NAME="VioletPatch" # Name for the DMG volume and file
BUNDLE_ID="br.com.flutterando.violetpatch"
FLUTTER_APP_DIR="violetpatch"
VERSION=$(grep 'version:' "$FLUTTER_APP_DIR/pubspec.yaml" | sed 's/version: //' | cut -d'+' -f1)
BUILD_DIR="$FLUTTER_APP_DIR/build/macos"
OUTPUT_DIR="dist/arm64"
SIGNING_IDENTITY="Developer ID Application"  # Auto-detected if available

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  VioletPatch DMG Builder${NC}"
echo -e "${GREEN}  Version: $VERSION${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 1. Check Requirements
echo -e "${YELLOW}Checking requirements...${NC}"
if ! command -v create-dmg &> /dev/null; then
    echo -e "${RED}Error: create-dmg not found. Install with: brew install create-dmg${NC}"
    exit 1
fi

if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}')
    echo -e "${GREEN}✓ Found signing identity: $SIGNING_IDENTITY${NC}"
else
    echo -e "${RED}Error: No Developer ID Application certificate found.${NC}"
    # Allow continuing without signing for testing if needed, but fail for now as requested "notarizar" implies signing
    exit 1
fi
echo ""

# 2. Clean & Build Flutter App
echo -e "${YELLOW}Building Flutter App...${NC}"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

pushd "$FLUTTER_APP_DIR" > /dev/null
flutter clean
flutter build macos --release
popd > /dev/null

echo -e "${GREEN}✓ Flutter build complete${NC}"
echo ""

# 3. Prepare Paths
APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
MACOS_DIR="$APP_PATH/Contents/MacOS"

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App bundle not found at $APP_PATH${NC}"
    exit 1
fi

# 4. Code Signing
echo -e "${YELLOW}Signing App Bundle...${NC}"
ENTITLEMENTS_APP="$FLUTTER_APP_DIR/macos/Runner/Release.entitlements"

# Sign Flutter Frameworks & Dylibs
echo "  Signing Frameworks & Libraries..."
find "$APP_PATH/Contents/Frameworks" -type f -name "*.dylib" -exec \
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" {} \;

find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" -exec \
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" {} \;

# Sign Main Executable
echo "  Signing Main Executable..."
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS_APP" \
    "$MACOS_DIR/$APP_NAME"

# Sign Bundle
echo "  Signing App Bundle..."
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS_APP" \
    "$APP_PATH"

echo -e "${GREEN}✓ Signing complete${NC}"
echo ""

# 5. Create DMG
echo -e "${YELLOW}Creating DMG...${NC}"
DMG_NAME="${PRETTY_APP_NAME}-${VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Note: Icon path needs to be correct. create-dmg expects a source file if using --volicon? 
# Usually .appiconset is a folder of images. create-dmg --volicon expects a .icns file.
# The original script used 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png' which is a png. create-dmg might handle png.
# We will use the 512.png from the assets.

VOL_ICON="$FLUTTER_APP_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset/512.png"

create-dmg \
  --volname "$PRETTY_APP_NAME" \
  --volicon "$VOL_ICON" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "$APP_NAME.app" 150 190 \
  --hide-extension "$APP_NAME.app" \
  --app-drop-link 450 185 \
  --no-internet-enable \
  "$DMG_PATH" \
  "$APP_PATH"

if [ ! -f "$DMG_PATH" ]; then
    echo -e "${RED}Error: DMG creation failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ DMG created: $DMG_PATH${NC}"
echo ""

# 6. Notarization
echo -e "${YELLOW}Notarizing DMG...${NC}"
if [ -z "$APPLE_ID" ] || [ -z "$APPLE_APP_PASSWORD" ] || [ -z "$TEAM_ID" ]; then
    echo -e "${YELLOW}⚠ Skipping notarization: Missing credentials (APPLE_ID, APPLE_APP_PASSWORD, TEAM_ID)${NC}"
    echo -e "${YELLOW}  Export these variables to enable notarization.${NC}"
else
    echo "  Submitting to Apple Notary Service..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_APP_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait

    echo -e "${YELLOW}Stapling ticket...${NC}"
    xcrun stapler staple "$DMG_PATH"
    echo -e "${GREEN}✓ Notarization & Stapling complete${NC}"
fi

echo ""
echo -e "${GREEN}Build Success! File located at: $DMG_PATH${NC}"
