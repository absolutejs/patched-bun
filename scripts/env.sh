# Shared settings. Bun's source lives outside this repo, in a cache.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/VERSION"
SOURCE_DIR="${PATCHED_BUN_SOURCE:-$HOME/.cache/patched-bun/$UPSTREAM_TAG}"
BINARY="$SOURCE_DIR/build/release/bun"

PATCHED_VERSION="${RELEASE_TAG#bun-v}"
[[ "$PATCHED_VERSION" =~ ^${BUN_VERSION//./\.}\+absolute\.[0-9]+$ ]] || { echo "Invalid patched release identity: $RELEASE_TAG" >&2; exit 1; }
