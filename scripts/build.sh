#!/usr/bin/env bash
# Release build of the patched source, capped so a 12GB WSL machine survives it.
set -euo pipefail
. "$(dirname "$0")/env.sh"
"$ROOT/scripts/source.sh"
cd "$SOURCE_DIR"
export PATH="/usr/lib/llvm-21/bin:$PATH"
JOBS="${JOBS:-4}"
export CARGO_BUILD_JOBS="$JOBS"
start=$(date +%s)
bun scripts/build.ts --profile=release --lto=off -j"$JOBS"
echo "Built in $(( ($(date +%s) - start) / 60 )) min: $BINARY ($("$BINARY" --version))"
