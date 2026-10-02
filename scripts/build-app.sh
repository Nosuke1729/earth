#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ "$configuration" != "release" && "$configuration" != "debug" ]]; then
    echo 'Usage: scripts/build-app.sh [release|debug]' >&2
    exit 1
fi
bash scripts/swift.sh build -c "$configuration" --product SecondEarth
binary_directory="$(bash scripts/swift.sh build -c "$configuration" --show-bin-path)"
app_directory="$PWD/build/SECOND EARTH.app"
mkdir -p "$app_directory/Contents/MacOS" "$app_directory/Contents/Resources"
cp "$binary_directory/SecondEarth" "$app_directory/Contents/MacOS/SecondEarth"
cat > "$app_directory/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleIdentifier</key><string>com.nosuke1729.secondearth</string>
    <key>CFBundleName</key><string>SECOND EARTH</string>
    <key>CFBundleDisplayName</key><string>SECOND EARTH</string>
    <key>CFBundleExecutable</key><string>SecondEarth</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.3.0</string>
    <key>CFBundleVersion</key><string>3</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSMultipleInstancesProhibited</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_directory"
echo "Built $app_directory"
echo 'Open it with: open "build/SECOND EARTH.app"'
