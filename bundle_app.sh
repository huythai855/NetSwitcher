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
