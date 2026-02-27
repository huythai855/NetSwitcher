#!/usr/bin/env bash
set -euo pipefail

APP_NAME="NetSwitcher"
APP_BUNDLE="dist/${APP_NAME}.app"
DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="dist/${DMG_NAME}"
STAGE_DIR="dist/dmg-root"
VOL_NAME="${APP_NAME}"

if [ ! -d "$APP_BUNDLE" ]; then
  echo "❌ Không thấy $APP_BUNDLE"
  echo "Hãy build app trước: swift build -c release && ./bundle_app.sh"
  exit 1
fi

echo "🧹 Dọn thư mục tạm..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

echo "📦 Copy app vào staging..."
cp -R "$APP_BUNDLE" "$STAGE_DIR/"

echo "🔗 Tạo shortcut Applications..."
ln -s /Applications "$STAGE_DIR/Applications"

echo "🗑️ Xóa DMG cũ (nếu có)..."
rm -f "$DMG_PATH"

echo "💿 Tạo DMG..."
hdiutil create \
  -volname "$VOL_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "✅ Xong: $DMG_PATH"
echo "Mở thử:"
echo "open \"$DMG_PATH\""