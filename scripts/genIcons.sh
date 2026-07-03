#!/bin/bash
cd ../Resources
ICONSET="AppIcon.iconset" && rm -rf "$ICONSET" && mkdir -p "$ICONSET"
SRC="AppIcon-1024.png"
for s in 16 32 64 128 256 512; do
  sips -z $s $s "$SRC" --out "$ICONSET/icon_${s}x${s}.png"
  sips -z $((s*2)) $((s*2)) "$SRC" --out "$ICONSET/icon_${s}x${s}@2x.png"
done
cp "$SRC" "$ICONSET/icon_512x512@2x.png"
iconutil -c icns "$ICONSET" -o AppIcon.icns && rm -rf "$ICONSET"