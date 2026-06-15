# Agent guide

Notes for AI agents and maintainers working in this fork.

## Upstream policy

Keep distribution work isolated from upstream-owned project files so upstream changes can be merged cleanly. Do not add release or Homebrew instructions to `README.md`.

Fork-specific additions:

- `build.sh` builds the existing `BrightIntosh` Xcode scheme into `.DerivedData/Distribution/BrightIntosh.app`.
- `install.sh` installs that build into `/Applications`.
- `release.sh` publishes a ZIP to GitHub Releases and creates or updates the cask in the separate Homebrew tap.
- `AGENTS.md` is the home for fork build and distribution notes.

## Requirements

- Full Xcode, not only Command Line Tools. Select it with `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`.
- An arm64 Mac. The supported MacBook models are Apple silicon, and release artifacts are arm64-only.
- `gh`, authenticated for `cvladan/brightintosh`.
- Homebrew for cask style validation.
- A clean checkout of `cvladan/homebrew-tap`. The default path is `/Volumes/SSD/dev/homebrew-tap`; override it with `TAP_DIR`.

## Build and install

```sh
./build.sh
./build.sh release
./install.sh release
```

The scripts pass build settings on the `xcodebuild` command line and do not rewrite `project.pbxproj`. The resulting app is ad-hoc signed for direct distribution and is not notarized.

The non-Store `BrightIntosh` scheme is intentional. Do not release the `BrightIntosh (Store Editon)` scheme outside the App Store.

## Distribution

The GitHub release asset is `.DerivedData/Distribution/BrightIntosh.zip`. The Homebrew cask lives in `cvladan/homebrew-tap` as `Casks/brightintosh.rb`.

Cut a release with:

```sh
./release.sh
TAP_DIR=/another/homebrew-tap ./release.sh 6.0.4
```

The default version and build number come from the existing Xcode project. An explicit version is injected into the build and does not alter project files. `BUILD_NUMBER=114 ./release.sh 6.0.4` similarly overrides the bundle build number.

Release order:

1. Require clean app and tap working trees.
2. Build and ad-hoc sign the release app.
3. ZIP the app with `ditto` and compute its SHA-256.
4. Write and validate `Casks/brightintosh.rb`.
5. Push tag `vX.Y.Z` and create the GitHub release.
6. Commit and push the cask.

Install or upgrade through the tap:

```sh
brew install --cask cvladan/tap/brightintosh
brew upgrade --cask brightintosh
```

## Verified environment

Release build verified on June 15, 2026 with macOS 26.5.1, Xcode 26.5, and Swift 6.3.2. The arm64 app and widget pass deep code-signature validation with their sandbox and app-group entitlements preserved, and the app launches successfully.
