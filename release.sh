#!/usr/bin/env bash
# Build, publish a GitHub release, and create/update the Homebrew cask.
#
# Usage:
#   ./release.sh          # use MARKETING_VERSION from the Xcode project
#   ./release.sh 6.0.4    # release an explicit version without editing the project
#
# Override the tap checkout with TAP_DIR=/path/to/homebrew-tap.
set -euo pipefail

APP_NAME="BrightIntosh"
REPO="cvladan/brightintosh"
BUILD_ROOT="${BUILD_ROOT:-.DerivedData/Distribution}"
APP_BUNDLE="${BUILD_ROOT}/${APP_NAME}.app"
ZIP_PATH="${BUILD_ROOT}/${APP_NAME}.zip"
PROJECT_FILE="BrightIntosh.xcodeproj/project.pbxproj"
TAP_DIR="${TAP_DIR:-/Volumes/SSD/dev/homebrew-tap}"
CASK_FILE="${TAP_DIR}/Casks/brightintosh.rb"

project_value() {
    local key="$1"
    sed -nE "s/^[[:space:]]*${key} = ([0-9]+(\\.[0-9]+)*);/\\1/p" "${PROJECT_FILE}" |
        sort -u |
        tail -1
}

command -v gh >/dev/null || {
    echo "gh CLI not found. Install it and run gh auth login." >&2
    exit 1
}

VERSION="${1:-$(project_value MARKETING_VERSION)}"
BUILD_NUMBER="${BUILD_NUMBER:-$(project_value CURRENT_PROJECT_VERSION)}"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Version must have the form X.Y.Z; got '${VERSION}'." >&2
    exit 1
fi

if [[ ! "${BUILD_NUMBER}" =~ ^[0-9]+$ ]]; then
    echo "Build number must be an integer; got '${BUILD_NUMBER}'." >&2
    exit 1
fi

TAG="v${VERSION}"

if [[ ! -d "${TAP_DIR}/.git" ]]; then
    echo "Homebrew tap checkout not found at ${TAP_DIR}." >&2
    echo "Set TAP_DIR=/path/to/homebrew-tap and try again." >&2
    exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
    echo "brightintosh has uncommitted changes. Commit or stash them first." >&2
    git status --short >&2
    exit 1
fi

if [[ -n "$(git -C "${TAP_DIR}" status --porcelain)" ]]; then
    echo "${TAP_DIR} has uncommitted changes. Commit or stash them first." >&2
    git -C "${TAP_DIR}" status --short >&2
    exit 1
fi

if git rev-parse "${TAG}" >/dev/null 2>&1; then
    echo "Tag ${TAG} already exists locally." >&2
    exit 1
fi

echo "==> Pulling tap (${TAP_DIR})"
git -C "${TAP_DIR}" pull --ff-only

echo "==> Building ${TAG} (${BUILD_NUMBER})"
BUILD_ROOT="${BUILD_ROOT}" VERSION="${VERSION}" BUILD_NUMBER="${BUILD_NUMBER}" ./build.sh release

echo "==> Creating ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

SHA256="$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')"
SIZE="$(du -h "${ZIP_PATH}" | awk '{print $1}')"
echo "==> ${ZIP_PATH} (${SIZE}, sha256: ${SHA256})"

echo "==> Writing ${CASK_FILE}"
mkdir -p "$(dirname "${CASK_FILE}")"
cat > "${CASK_FILE}" <<EOF
cask "brightintosh" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${REPO}/releases/download/v#{version}/BrightIntosh.zip"
  name "BrightIntosh"
  desc "Extend the brightness range of supported XDR displays"
  homepage "https://github.com/${REPO}"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "BrightIntosh.app"

  zap trash: [
    "~/Library/Containers/de.brightintosh.app",
    "~/Library/Group Containers/group.de.brightintosh.app",
    "~/Library/Preferences/de.brightintosh.app.plist",
  ]
end
EOF

echo "==> Checking cask"
mkdir -p "${BUILD_ROOT}/HomebrewCache"
ruby -c "${CASK_FILE}"
HOMEBREW_CACHE="${BUILD_ROOT}/HomebrewCache" brew style "${CASK_FILE}"

echo "==> Tagging and pushing ${TAG}"
git tag "${TAG}"
git push origin HEAD
git push origin "${TAG}"

echo "==> Publishing GitHub release ${TAG}"
gh release create "${TAG}" "${ZIP_PATH}" \
    --repo "${REPO}" \
    --title "${TAG}" \
    --notes "Release ${TAG}"

echo "==> Committing and pushing tap"
git -C "${TAP_DIR}" add Casks/brightintosh.rb
git -C "${TAP_DIR}" commit -m "brightintosh ${VERSION}"
git -C "${TAP_DIR}" push origin HEAD

echo ""
echo "Done. Install with:"
echo "  brew install --cask cvladan/tap/brightintosh"
