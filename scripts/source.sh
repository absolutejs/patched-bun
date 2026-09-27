#!/usr/bin/env bash
# Puts stock Bun at the pinned commit in the cache and applies patches/ on top.
# Safe to rerun: tracked files are reset each time; build/ is kept so rebuilds are incremental.
set -euo pipefail
. "$(dirname "$0")/env.sh"
if [ ! -d "$SOURCE_DIR/.git" ]; then
  mkdir -p "$(dirname "$SOURCE_DIR")"
  git clone -q --depth 1 --branch "$UPSTREAM_TAG" https://github.com/oven-sh/bun.git "$SOURCE_DIR"
fi
git -C "$SOURCE_DIR" checkout -q -f --detach "$UPSTREAM_COMMIT"
git -C "$SOURCE_DIR" clean -fdq -e build
[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" = "$UPSTREAM_COMMIT" ] || { echo "source is not at $UPSTREAM_COMMIT"; exit 1; }
for patch in "$ROOT"/patches/*.patch; do
  git -C "$SOURCE_DIR" apply --whitespace=nowarn "$patch"
  echo "applied $(basename "$patch")"
done
echo "source ready: $SOURCE_DIR"
