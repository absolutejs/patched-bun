#!/usr/bin/env bash
# Publishes every built artifact as a GitHub release of this repo from this
# machine (no CI minutes). Refuses to publish unless verify.sh passes and every
# target in build.sh was built. Creates the public repo on first use.
set -euo pipefail
. "$(dirname "$0")/env.sh"
dist="$SOURCE_DIR/build/dist"
"$ROOT/scripts/verify.sh"
expected=$(grep -oE '^  "[a-z0-9-]+:' "$ROOT/scripts/build.sh" | tr -d ' ":')
missing=()
for name in $expected; do
  for zip in "bun-$name.zip" "bun-$name-profile.zip"; do [ -f "$dist/$zip" ] || missing+=("$zip"); done
done
[ ${#missing[@]} = 0 ] || { echo "Not releasing; missing: ${missing[*]}"; exit 1; }

# Sign the checksum list with the AbsoluteJS release key (Ed25519). bvm only
# installs an AbsoluteJS build whose SHASUMS256.txt.sig verifies against the
# public key it embeds, so an unsigned release is never published. The private
# key stays on this machine (back it up offline); override the path with
# ABSOLUTEJS_RELEASE_KEY.
key="${ABSOLUTEJS_RELEASE_KEY:-$HOME/.local/share/absolutejs/keys/bvm-release-ed25519.pem}"
[ -r "$key" ] || { echo "Not releasing; no release signing key at $key"; exit 1; }
openssl pkeyutl -sign -inkey "$key" -rawin -in "$dist/SHASUMS256.txt" -out "$dist/SHASUMS256.txt.sig.bin"
openssl pkey -in "$key" -pubout | openssl pkeyutl -verify -pubin -inkey /dev/stdin -rawin \
  -in "$dist/SHASUMS256.txt" -sigfile "$dist/SHASUMS256.txt.sig.bin" >/dev/null
base64 -w0 "$dist/SHASUMS256.txt.sig.bin" > "$dist/SHASUMS256.txt.sig" && echo >> "$dist/SHASUMS256.txt.sig"
rm -f "$dist/SHASUMS256.txt.sig.bin"

cd "$ROOT"
gh repo view "$REPO" >/dev/null 2>&1 || gh repo create "$REPO" --public --description "Bun $BUN_VERSION with the reactFastRefresh fix AbsoluteJS needs (oven-sh/bun#32919), until upstream ships it" >/dev/null
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$REPO.git"
git push -q origin main
gh release create "$RELEASE_TAG" -R "$REPO" --target main --title "Bun $BUN_VERSION + reactFastRefresh ($RELEASE_TAG)" \
  --notes-file RELEASE_NOTES.md "$dist"/*.zip "$dist/SHASUMS256.txt" "$dist/SHASUMS256.txt.sig"
echo "Released: https://github.com/$REPO/releases/tag/$RELEASE_TAG"
