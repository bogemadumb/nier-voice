#!/bin/bash
# Собирает Nier Voice.app без Xcode: swift build + ручной бандл + подпись.
# По умолчанию ставит в /Applications: постоянный путь нужен, чтобы выданные macOS
# разрешения (микрофон, Универсальный доступ) не терялись при каждом обновлении.
#   APP=/tmp/Nier\ Voice.app ./build.sh        — собрать в другое место
#   SIGN_IDENTITY="Nier Voice Self" ./build.sh  — подписать сертификатом из make-cert.sh вместо ad-hoc
set -euo pipefail
BASE="$(cd "$(dirname "$0")" && pwd)"
APP="${APP:-/Applications/Nier Voice.app}"
BIN_NAME="NierVoice"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

# Command Line Tools на SDK macOS 27 не содержат плагина SwiftUIMacros (@State там — макрос), поэтому
# без Xcode собираем на SDK 26.x, если он есть
SDK26=$(ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -1 || true)
if [ -z "${SDKROOT:-}" ] && [ -n "$SDK26" ] && ! xcode-select -p | grep -q Xcode.app; then export SDKROOT="$SDK26"; fi

cd "$BASE"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/$BIN_NAME"

pkill -f "Nier Voice.app/Contents/MacOS/$BIN_NAME" 2>/dev/null || true
sleep 0.5

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$BIN_NAME"
cp "$BASE/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Nier Voice</string>
  <key>CFBundleDisplayName</key><string>Nier Voice</string>
  <key>CFBundleExecutable</key><string>$BIN_NAME</string>
  <key>CFBundleIdentifier</key><string>ru.bogema.niervoice</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>10</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSUIElement</key><true/>
  <key>NSMicrophoneUsageDescription</key>
  <string>Слушает микрофон, пока удерживается клавиша диктовки.</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP" >/dev/null 2>&1
touch "$APP"
echo "готово: $APP"
