#!/bin/bash
set -e

APP_NAME="Codex Copilot Bridge"
BUNDLE_ID="com.xjin6.codex-copilot-bridge"
VERSION="1.1.0"
BINARY="codex-copilot-bridge"

echo "==> Building Node.js binaries..."
mkdir -p dist
pkg . --targets node20-macos-arm64 --output "dist/${BINARY}-node-arm64"
pkg . --targets node20-macos-x64   --output "dist/${BINARY}-node-x64"

echo "==> Compiling Swift wrapper..."
swiftc -framework Cocoa -framework WebKit \
  -target arm64-apple-macos11 \
  Sources/main.swift -o "dist/${BINARY}-swift-arm64"
swiftc -framework Cocoa -framework WebKit \
  -target x86_64-apple-macos10.15 \
  Sources/main.swift -o "dist/${BINARY}-swift-x64"

echo "==> Creating universal Swift wrapper with lipo..."
lipo -create "dist/${BINARY}-swift-arm64" "dist/${BINARY}-swift-x64" \
     -output "dist/${BINARY}-swift"
rm "dist/${BINARY}-swift-arm64" "dist/${BINARY}-swift-x64"

echo "==> Generating ICNS icon..."
ICONSET="dist/AppIcon.iconset"
rm -rf "${ICONSET}"
mkdir -p "${ICONSET}"
for size in 16 32 128 256 512; do
  sips -z $size $size codex-color.png \
    --out "${ICONSET}/icon_${size}x${size}.png"       > /dev/null
  sips -z $((size*2)) $((size*2)) codex-color.png \
    --out "${ICONSET}/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "${ICONSET}" -o "dist/AppIcon.icns"
rm -rf "${ICONSET}"

echo "==> Assembling .app bundle..."
APP="dist/${APP_NAME}.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources/bin"

# Swift wrapper is the main executable (shows native window + Dock icon)
cp "dist/${BINARY}-swift" "${APP}/Contents/MacOS/${BINARY}"
chmod +x "${APP}/Contents/MacOS/${BINARY}"
rm "dist/${BINARY}-swift"

# Node binaries live in Resources/bin, launched by the Swift wrapper
cp "dist/${BINARY}-node-arm64" "${APP}/Contents/Resources/bin/${BINARY}-arm64"
cp "dist/${BINARY}-node-x64"   "${APP}/Contents/Resources/bin/${BINARY}-x64"
chmod +x "${APP}/Contents/Resources/bin/${BINARY}-arm64"
chmod +x "${APP}/Contents/Resources/bin/${BINARY}-x64"
rm "dist/${BINARY}-node-arm64" "dist/${BINARY}-node-x64"

cp "dist/AppIcon.icns" "${APP}/Contents/Resources/AppIcon.icns"

cat > "${APP}/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleVersion</key>
  <string>${VERSION}</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleExecutable</key>
  <string>${BINARY}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

echo "==> Packaging as zip..."
cd dist
zip -r "${APP_NAME}.zip" "${APP_NAME}.app"
cd ..

echo ""
echo "Done! dist/${APP_NAME}.zip"
echo "      $(du -sh "dist/${APP_NAME}.zip" | cut -f1)"
