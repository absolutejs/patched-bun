# Shared settings. Bun's source lives outside this repo, in a cache.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/VERSION"
SOURCE_DIR="${PATCHED_BUN_SOURCE:-$HOME/.cache/patched-bun/$UPSTREAM_TAG}"
BINARY="$SOURCE_DIR/build/release/bun"
