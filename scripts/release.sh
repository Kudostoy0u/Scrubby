#!/usr/bin/env bash
# Builds, signs, notarizes and publishes a Scrubby release on GitHub.
#
#   scripts/release.sh 0.1.0
#
# One-time setup:
#   1. A "Developer ID Application" certificate in your keychain
#      (Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application).
#   2. Notarization credentials saved under the profile name "scrubby":
#      xcrun notarytool store-credentials scrubby --apple-id <email> --team-id <TEAMID>
#   3. gh logged in (gh auth login).
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION="${1:?usage: scripts/release.sh <version>}"
NOTARY_PROFILE="${NOTARY_PROFILE:-scrubby}"
TAG="v$VERSION"

SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' | head -1)}"
if [ -z "$SIGN_IDENTITY" ]; then
  echo "No 'Developer ID Application' certificate found in your keychain." >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "Commit your changes before releasing." >&2
  exit 1
fi

echo "==> Building $TAG, signed with: $SIGN_IDENTITY"
BUILD_NUMBER="$(git rev-list --count HEAD)" VERSION="$VERSION" SIGN_IDENTITY="$SIGN_IDENTITY" \
  scripts/build-app.sh
codesign --verify --deep --strict build/Scrubby.app

echo "==> Notarizing (this usually takes a minute or two)"
rm -f build/Scrubby.zip
ditto -c -k --keepParent build/Scrubby.app build/Scrubby.zip
xcrun notarytool submit build/Scrubby.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple build/Scrubby.app
spctl --assess --type execute --verbose build/Scrubby.app

echo "==> Packaging"
rm -f build/Scrubby.zip
ditto -c -k --keepParent build/Scrubby.app build/Scrubby.zip
SHA="$(shasum -a 256 build/Scrubby.zip | cut -d' ' -f1)"

# Keep the Homebrew cask template in step with the release.
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" \
          -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" packaging/scrubby.rb

echo "==> Publishing $TAG on GitHub"
git tag -a "$TAG" -m "Scrubby $VERSION"
git push origin "$TAG"
gh release create "$TAG" build/Scrubby.zip --title "Scrubby $VERSION" --notes-file - <<NOTES
Download **Scrubby.zip**, unzip it, and drag Scrubby to your Applications folder.
Open it and follow the setup screen.

SHA-256: \`$SHA\`
NOTES

git add packaging/scrubby.rb
git commit -q -m "Record $TAG checksum in the Homebrew cask"
git push -q

# Publish the new version to the Homebrew tap, if it's checked out next to this repo.
TAP_DIR="${TAP_DIR:-../homebrew-tap}"
if [ -d "$TAP_DIR/Casks" ]; then
  echo "==> Updating Homebrew tap"
  sed '1,3d' packaging/scrubby.rb > "$TAP_DIR/Casks/scrubby.rb"
  git -C "$TAP_DIR" commit -q -am "scrubby $VERSION"
  git -C "$TAP_DIR" push -q
fi

echo "Released $TAG."
