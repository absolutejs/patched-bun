#!/usr/bin/env bash
# Builds the patched Bun for every platform Bun's own release ships, all
# cross-compiled from this Linux x64 machine the way Bun's release host does
# (.buildkite/ci.mjs buildPlatforms): release build type, LTO where Bun's
# release enables it, x64 targeting the nehalem baseline, and the same zip
# layout (bun-<triplet>.zip + bun-<triplet>-profile.zip).
#
#   scripts/build.sh                       # every target, in the order below
#   TARGETS="linux-x64 darwin-aarch64" scripts/build.sh
#   JOBS=8 scripts/build.sh                # parallel jobs (default: all cores)
#
# Needs scripts/setup-cross.sh (once, with sudo) for the cross sysroots.
set -euo pipefail
. "$(dirname "$0")/env.sh"

# name:os:arch:abi:lto — ordered by who needs it first. LTO mirrors Bun's
# ltoDefault (release + linux/darwin/windows); android and windows-aarch64
# are forced off by Bun's config (no LTO WebKit prebuilt), freebsd is off.
ALL_TARGETS=(
  "linux-x64:linux:x64::on"
  "darwin-aarch64:darwin:aarch64::on"
  "darwin-x64:darwin:x64::on"
  "windows-x64:windows:x64::on"
  "linux-aarch64:linux:aarch64::on"
  "linux-x64-musl:linux:x64:musl:on"
  "linux-aarch64-musl:linux:aarch64:musl:on"
  "windows-aarch64:windows:aarch64::off"
  "linux-x64-android:linux:x64:android:off"
  "linux-aarch64-android:linux:aarch64:android:off"
  "freebsd-x64:freebsd:x64::off"
  "freebsd-aarch64:freebsd:aarch64::off"
)
wanted="${TARGETS:-}"
JOBS="${JOBS:-$(nproc)}"
export CARGO_BUILD_JOBS="$JOBS"
export PATH="/usr/lib/llvm-21/bin:$PATH"

"$ROOT/scripts/source.sh"
cd "$SOURCE_DIR"
dist="$SOURCE_DIR/build/dist"
mkdir -p "$dist"
log="$SOURCE_DIR/build/build-log.txt"
failed=()

zip_dir() { # zip_dir <buildDir> <name> <files...>: Bun's makeZip layout
  local dir="$1" name="$2"; shift 2
  rm -rf "${dir:?}/$name" "$dist/$name.zip" && mkdir -p "$dir/$name"
  for f in "$@"; do [ -e "$dir/$f" ] && cp -R "$dir/$f" "$dir/$name/"; done
  (cd "$dir" && zip -qr "$dist/$name.zip" "$name") && rm -rf "${dir:?}/$name"
}

for entry in "${ALL_TARGETS[@]}"; do
  IFS=: read -r name os arch abi lto <<<"$entry"
  if [ -n "$wanted" ] && [[ " $wanted " != *" $name "* ]]; then continue; fi
  triplet="bun-$name"
  dir="build/$name"
  # --canary=off as Bun's release pipeline passes (.buildkite/ci.mjs): the
  # default is a canary build, which reports 1.4.0-canary.1, turns on Bun's
  # experimental "bake" server features and makes `bun upgrade` track canary.
  args=(--profile=release --canary=off --os="$os" --arch="$arch" --lto="$lto" --buildDir="$dir" -j"$JOBS")
  [ -n "$abi" ] && args+=(--abi="$abi")
  echo "=== $triplet ($(date +%H:%M)) bun scripts/build.ts ${args[*]}" | tee -a "$log"
  start=$(date +%s)
  if ! bun scripts/build.ts "${args[@]}" 2>&1 | tee -a "$log"; then
    echo "=== $triplet FAILED after $(( ($(date +%s) - start) / 60 )) min" | tee -a "$log"
    failed+=("$name")
    continue
  fi
  exe=""; [ "$os" = windows ] && exe=".exe"
  # The stripped binary alone, and the unstripped one with its symbols.
  zip_dir "$dir" "$triplet" "bun$exe"
  if [ "$(uname -m)-$os-$arch-$abi" = "x86_64-linux-x64-" ]; then
    (cd "$dir" && ./bun-profile "$SOURCE_DIR/scripts/features.mjs" >/dev/null 2>&1) || true
  fi
  zip_dir "$dir" "$triplet-profile" "bun-profile$exe" features.json "bun-profile.pdb" "bun-profile.dSYM"
  echo "=== $triplet built in $(( ($(date +%s) - start) / 60 )) min" | tee -a "$log"
done

(cd "$dist" && rm -f SHASUMS256.txt && sha256sum -- *.zip > SHASUMS256.txt)
echo "Artifacts: $dist"
ls -la "$dist"
[ ${#failed[@]} = 0 ] || { echo "Failed: ${failed[*]} (see $log)"; exit 1; }
