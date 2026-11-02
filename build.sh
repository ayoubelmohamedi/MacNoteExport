#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="NoteExport"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=========================================="
echo " Building NoteExport (Universal Binary)"
echo " Compatible with Apple Silicon & Intel Macs"
echo "=========================================="

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 1. Generate AppIcon
echo "Generating AppIcon..."
if which swift >/dev/null 2>&1; then
    swift scripts/generate_icon.swift
    if which iconutil >/dev/null 2>&1 && [ -d "Resources/AppIcon.iconset" ]; then
        iconutil -c icns Resources/AppIcon.iconset -o "$RESOURCES_DIR/AppIcon.icns"
        rm -rf Resources/AppIcon.iconset
    fi
fi

# 2. Compile Sources
SOURCES=(
    "Sources/Models.swift"
    "Sources/HTMLToMarkdown.swift"
    "Sources/NotesBridge.swift"
    "Sources/MainWindowController.swift"
    "Sources/AppDelegate.swift"
    "Sources/CLI.swift"
    "Sources/main.swift"
)

echo "Compiling for Apple Silicon (arm64)..."
swiftc -target arm64-apple-macos11.0 -O "${SOURCES[@]}" -o "$BUILD_DIR/${APP_NAME}_arm64"

echo "Compiling for Intel (x86_64)..."
BUILD_X86_OK=1
swiftc -target x86_64-apple-macos11.0 -O "${SOURCES[@]}" -o "$BUILD_DIR/${APP_NAME}_x86_64" 2>/dev/null || BUILD_X86_OK=0

if [ "$BUILD_X86_OK" -eq 1 ]; then
    echo "Creating Universal 2 Binary (arm64 + x86_64)..."
    lipo -create -output "$MACOS_DIR/$APP_NAME" "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"
else
    echo "Falling back to native architecture binary..."
    cp "$BUILD_DIR/${APP_NAME}_arm64" "$MACOS_DIR/$APP_NAME"
fi

# 3. Copy Plist & PkgInfo
echo "Creating App Bundle..."
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# 4. Ad-hoc codesign for local Gatekeeper acceptance
echo "Signing application bundle..."
codesign -s - --force --deep "$APP_BUNDLE" 2>/dev/null || true

# 5. Create Standalone CLI symlink / helper
cp "$MACOS_DIR/$APP_NAME" "$BUILD_DIR/note-export"
chmod +x "$BUILD_DIR/note-export"

# 6. Package ZIP archive & DMG for distribution
echo "Creating distribution ZIP archive..."
cd "$BUILD_DIR"
zip -r -q "${APP_NAME}-macOS-Universal.zip" "$APP_NAME.app"

echo "Creating distribution DMG image..."
mkdir -p dmg_temp
cp -R "$APP_NAME.app" dmg_temp/
ln -s /Applications dmg_temp/Applications
hdiutil create -volname "$APP_NAME" -srcfolder dmg_temp -ov -format UDZO "${APP_NAME}-macOS-Universal.dmg" >/dev/null 2>&1
rm -rf dmg_temp
cd "$SCRIPT_DIR"

echo "=========================================="
echo " Build Succeeded!"
echo " App Bundle: $APP_BUNDLE"
echo " CLI Binary: $BUILD_DIR/note-export"
echo " Dist ZIP:   $BUILD_DIR/${APP_NAME}-macOS-Universal.zip"
echo " Dist DMG:   $BUILD_DIR/${APP_NAME}-macOS-Universal.dmg"
echo "=========================================="
