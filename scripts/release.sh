#!/usr/bin/env bash
# Packages the built binary and publishes a GitHub release of this repo from
# this machine (no CI minutes). Creates the public repo on first use.
set -euo pipefail
. "$(dirname "$0")/env.sh"
"$ROOT/scripts/verify.sh" >/dev/null
out="$SOURCE_DIR/build/absolutejs-release" && rm -rf "$out" && mkdir -p "$out/bun-linux-x64"
cp "$BINARY" "$out/bun-linux-x64/bun"
(cd "$out" && zip -qr bun-linux-x64.zip bun-linux-x64 && sha256sum bun-linux-x64.zip > SHASUMS256.txt && cat SHASUMS256.txt)
cd "$ROOT"
gh repo view "$REPO" >/dev/null 2>&1 || gh repo create "$REPO" --public --description "Bun $BUN_VERSION with the reactFastRefresh fix AbsoluteJS needs (oven-sh/bun#32919), until upstream ships it" >/dev/null
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"
git push -q origin main
gh release create "$RELEASE_TAG" -R "$REPO" --target main --title "Bun $BUN_VERSION + reactFastRefresh ($RELEASE_TAG)" --notes-file RELEASE_NOTES.md "$out/bun-linux-x64.zip" "$out/SHASUMS256.txt"
echo "Released: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
