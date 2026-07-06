#!/bin/bash
set -euo pipefail

VERSION="${1:?用法: ./scripts/bump_version.sh <version>, 例如: 1.0.1}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST="$PROJECT_DIR/Resources/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
echo "✅ Info.plist → CFBundleShortVersionString = $VERSION"

git -C "$PROJECT_DIR" add "$PLIST"
git -C "$PROJECT_DIR" commit -m "chore: bump version to $VERSION"

git -C "$PROJECT_DIR" tag "v$VERSION"
echo "✅ git tag v$VERSION"

git -C "$PROJECT_DIR" push && git -C "$PROJECT_DIR" push --tags
echo "✅ 已推送，CI 将自动构建 v$VERSION"
