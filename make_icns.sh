#!/usr/bin/env bash
set -euo pipefail

SRC_PNG="${1:-assets/icon.png}"
OUT_ICNS="${2:-assets/AppIcon.icns}"

if [ ! -f "$SRC_PNG" ]; then
  echo "❌ Không thấy file PNG: $SRC_PNG"
  exit 1
fi

ICONSET_DIR="$(dirname "$OUT_ICNS")/AppIcon.iconset"
mkdir -p "$(dirname "$OUT_ICNS")"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Tạo các size chuẩn cho iconutil
sips -z 16 16     "$SRC_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32     "$SRC_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "$SRC_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64     "$SRC_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "$SRC_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256   "$SRC_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$SRC_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512   "$SRC_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$SRC_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$SRC_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

echo "✅ Created: $OUT_ICNS"