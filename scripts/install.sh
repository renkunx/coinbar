#!/bin/bash
set -euo pipefail

APP_NAME="CoinBar"
RESOURCES_DIR="../Resources"
BUILD_DIR=".build"
INSTALL_DIR="/Applications"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[1/5]${NC} Building ${APP_NAME} (release)..."
swift build -c release

BIN_PATH="$(swift build --show-bin-path -c release)/${APP_NAME}"
if [ ! -f "$BIN_PATH" ]; then
  echo -e "${RED}Error:${NC} Binary not found at ${BIN_PATH}"
  exit 1
fi
echo "  -> ${BIN_PATH}"

echo -e "${GREEN}[2/5]${NC} Creating ${APP_NAME}.app bundle..."
rm -rf "${APP_NAME}.app"
mkdir -p "${APP_NAME}.app/Contents/MacOS" "${APP_NAME}.app/Contents/Resources"
cp "$BIN_PATH" "${APP_NAME}.app/Contents/MacOS/"
cp "${RESOURCES_DIR}/Info.plist" "${APP_NAME}.app/Contents/"
# 拷贝应用图标
if [ -f "${RESOURCES_DIR}/AppIcon.icns" ]; then
  cp "${RESOURCES_DIR}/AppIcon.icns" "${APP_NAME}.app/Contents/Resources/"
fi
echo "  -> ${APP_NAME}.app created"

echo -e "${GREEN}[3/5]${NC} Signing (ad-hoc)..."
codesign --force --deep --sign - "${APP_NAME}.app"
echo "  -> signed"

echo -e "${GREEN}[4/5]${NC} Removing old installation..."
rm -rf "${INSTALL_DIR}/${APP_NAME}.app"

echo -e "${GREEN}[5/5]${NC} Installing to ${INSTALL_DIR}..."
cp -R "${APP_NAME}.app" "${INSTALL_DIR}/"

rm -rf "${APP_NAME}.app"

echo -e "${GREEN}Done!${NC} ${APP_NAME} installed to ${INSTALL_DIR}/${APP_NAME}.app"
echo "Launch from Spotlight or: open \"${INSTALL_DIR}/${APP_NAME}.app\""
