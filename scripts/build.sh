#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$PWD/dist/ConfDDL.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ConfDDL" "$APP/Contents/MacOS/ConfDDL"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleName</key><string>ConfDDL</string>
    <key>CFBundleDisplayName</key><string>ConfDDL</string>
    <key>CFBundleIdentifier</key><string>cn.valkqs.ConfDDL</string>
    <key>CFBundleExecutable</key><string>ConfDDL</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.1.1</string>
    <key>CFBundleVersion</key><string>3</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleDevelopmentRegion</key><string>zh_CN</string>
    <key>CFBundleLocalizations</key><array><string>zh_CN</string><string>en</string></array>
</dict></plist>
PLIST

xcrun swift scripts/make-icon.swift "$PWD/dist"
iconutil -c icns "$PWD/dist/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp Vendor/Yams/LICENSE "$APP/Contents/Resources/Yams-LICENSE.txt"
cp docs/licenses/LibYAML.txt "$APP/Contents/Resources/LibYAML-LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
codesign --force --sign - --identifier cn.valkqs.ConfDDL "$APP"
codesign --verify --deep --strict "$APP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/dist/ConfDDL-macOS.zip"
echo "构建完成：$APP"

if [[ "${1:-}" == "--install" ]]; then
    TARGET="$HOME/Applications/ConfDDL.app"
    if [[ -e "$TARGET" ]]; then
        echo "安装位置已有 ConfDDL；请退出应用，并手动将 dist/ConfDDL.app 替换到 ~/Applications。"
        exit 1
    fi
    mkdir -p "$HOME/Applications"
    ditto "$APP" "$TARGET"
    open "$TARGET" --args --show
    echo "已安装：$TARGET"
fi
