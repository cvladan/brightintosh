#!/usr/bin/env bash
# Build an ad-hoc signed BrightIntosh.app without changing the Xcode project.
# Usage: ./build.sh [debug|release]
set -euo pipefail

CONFIG_INPUT="${1:-debug}"
case "${CONFIG_INPUT}" in
    debug) CONFIGURATION="Debug" ;;
    release) CONFIGURATION="Release" ;;
    *)
        echo "Usage: $0 [debug|release]" >&2
        exit 1
        ;;
esac

APP_NAME="BrightIntosh"
PROJECT="BrightIntosh.xcodeproj"
SCHEME="BrightIntosh"
BUILD_ROOT="${BUILD_ROOT:-.DerivedData/Distribution}"
DERIVED_DATA="${BUILD_ROOT}/Xcode"
APP_BUNDLE="${BUILD_ROOT}/${APP_NAME}.app"
BUILT_APP="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
WIDGET_BUNDLE="${APP_BUNDLE}/Contents/PlugIns/WidgetsExtension.appex"

if ! xcodebuild -version >/dev/null 2>&1; then
    cat >&2 <<'EOF'
xcodebuild requires a full Xcode installation.
Install Xcode, then select it with:
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
EOF
    exit 1
fi

BUILD_SETTINGS=(
    ARCHS=arm64
    ONLY_ACTIVE_ARCH=NO
    CODE_SIGNING_ALLOWED=NO
)

if [[ -n "${VERSION:-}" ]]; then
    BUILD_SETTINGS+=("MARKETING_VERSION=${VERSION}")
fi

if [[ -n "${BUILD_NUMBER:-}" ]]; then
    BUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=${BUILD_NUMBER}")
fi

echo "==> Building ${APP_NAME} (${CONFIGURATION}, arm64)"
xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination "platform=macOS,arch=arm64" \
    "${BUILD_SETTINGS[@]}" \
    build

if [[ ! -d "${BUILT_APP}" ]]; then
    echo "Built app not found at ${BUILT_APP}" >&2
    exit 1
fi

echo "==> Copying ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
ditto "${BUILT_APP}" "${APP_BUNDLE}"

echo "==> Ad-hoc signing"
find "${APP_BUNDLE}" -name embedded.provisionprofile -delete
find "${APP_BUNDLE}" -name _CodeSignature -type d -prune -exec rm -rf {} +

if [[ -d "${WIDGET_BUNDLE}" ]]; then
    codesign \
        --force \
        --sign - \
        --entitlements WidgetsExtension.entitlements \
        "${WIDGET_BUNDLE}"
fi

codesign \
    --force \
    --sign - \
    --entitlements BrightIntosh/BrightIntosh.entitlements \
    "${APP_BUNDLE}"
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

VERSION_BUILT="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_BUNDLE}/Contents/Info.plist")"
BUILD_BUILT="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${APP_BUNDLE}/Contents/Info.plist")"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Version: ${VERSION_BUILT} (${BUILD_BUILT})"
echo "Open with: open ${APP_BUNDLE}"
