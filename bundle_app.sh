#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NetSwitcher"
BUNDLE_ID="local.thai.netswitcher"
BIN_PATH=".build/release/${APP_NAME}"
APP_DIR="dist/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RES_DIR="${CONTENTS_DIR}/Resources"
PLIST_PATH="${CONTENTS_DIR}/Info.plist"
ICON_ICNS="assets/AppIcon.icns"

if [ ! -f "$BIN_PATH" ]; then
  echo "❌ Không thấy binary ở $BIN_PATH"
  echo "Hãy chạy: swift build -c release"
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

# Copy executable
cp "$BIN_PATH" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

if [ -f "$ICON_ICNS" ]; then
  cp "$ICON_ICNS" "${RES_DIR}/AppIcon.icns"
  echo "🎨 Added app icon: $ICON_ICNS"
else
  echo "ℹ️ No icon found at $ICON_ICNS (skip)"
fi


# Info.plist
cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>

  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>

  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>

  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>

  <key>CFBundleName</key>
  <string>${APP_NAME}</string>

  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>

  <key>CFBundlePackageType</key>
  <string>APPL</string>

  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>

  <key>CFBundleVersion</key>
  <string>1</string>

  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>

  <key>CFBundleIconFile</key>
  <string>AppIcon</string>

  <!-- Menu bar app, không hiện Dock icon -->
  <key>LSUIElement</key>
  <true/>

  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

# Ad-hoc sign để macOS đỡ khó chịu (local-only)
codesign --force --deep --sign - "$APP_DIR"

echo "✅ Built app: $APP_DIR"
echo "Mở thử bằng:"
echo "open \"$APP_DIR\""
