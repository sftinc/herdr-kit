#!/bin/bash
# Builds build.noindex/Herdr.app (.noindex keeps it out of Spotlight). Pass --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

app=build.noindex/Herdr.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp .build/release/Herdr "$app/Contents/MacOS/Herdr"

# App icon from Resources/AppIcon.png (1024x1024).
iconset=build.noindex/AppIcon.iconset
rm -rf "$iconset" && mkdir -p "$iconset"
for size in 16 32 128 256 512; do
    sips -z $size $size Resources/AppIcon.png --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Herdr</string>
    <key>CFBundleDisplayName</key><string>Herdr</string>
    <key>CFBundleIdentifier</key><string>local.herdr.app</string>
    <key>CFBundleExecutable</key><string>Herdr</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

xattr -cr "$app"
codesign --force -s - "$app"
echo "Built $app"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/Herdr.app
    cp -R "$app" /Applications/
    echo "Installed /Applications/Herdr.app"
fi
