#!/usr/bin/env bash
# Build, install to /Applications, and launch BrightIntosh.
set -euo pipefail

CONFIG="${1:-debug}"
APP_NAME="BrightIntosh"
BUILD_ROOT="${BUILD_ROOT:-.DerivedData/Distribution}"
SOURCE_APP="${BUILD_ROOT}/${APP_NAME}.app"
INSTALLED_APP="/Applications/${APP_NAME}.app"

BUILD_ROOT="${BUILD_ROOT}" ./build.sh "${CONFIG}"

echo "==> Stopping any running instance"
killall "${APP_NAME}" 2>/dev/null || true

echo "==> Installing ${INSTALLED_APP}"
rm -rf "${INSTALLED_APP}"
ditto "${SOURCE_APP}" "${INSTALLED_APP}"

echo "==> Launching"
open "${INSTALLED_APP}"

echo ""
echo "Done. ${APP_NAME} is installed and running."
