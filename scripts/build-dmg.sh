#!/bin/zsh
set -e

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$PROJECT/build"

echo "==> Generating Xcode project..."
cd "$PROJECT"
xcodegen generate

echo "==> Building release..."
xcodebuild \
  -project "$PROJECT/gTile.xcodeproj" \
  -scheme gTile \
  -configuration Release \
  -derivedDataPath "$BUILD" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  build | tail -5

echo "==> Packaging DMG..."
rm -rf "$BUILD/dmg-staging"
mkdir -p "$BUILD/dmg-staging"
cp -r "$BUILD/Build/Products/Release/gTile.app" "$BUILD/dmg-staging/"
ln -s /Applications "$BUILD/dmg-staging/Applications"

hdiutil create \
  -volname "gTile" \
  -srcfolder "$BUILD/dmg-staging" \
  -ov -format UDZO \
  "$BUILD/gTile.dmg"

rm -rf "$BUILD/dmg-staging"

echo ""
echo "Done: $BUILD/gTile.dmg"
