#!/usr/bin/env bash
# One-time: installs everything Bun's release host has for cross-compiling
# every platform from one Linux machine, using Bun's own bootstrap installers
# (scripts/bootstrap.sh at the pinned Bun commit) rather than our own copies:
#   /opt/macos-sdk                 macOS SDK, from Apple's CDN (xmac)
#   /opt/winsysroot                MSVC CRT + Windows SDK, from Microsoft's CDN (xwin)
#   /opt/linux-sysroot-glibc{,-arm64}, /opt/linux-sysroot-musl{,-arm64}
#   /opt/android-ndk, /opt/freebsd-sysroot{,-arm64}
# Run with sudo: sudo ~/abs/patched-bun/scripts/setup-cross.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "Run with sudo: sudo $0"; exit 1; }
[ -n "${SUDO_USER:-}" ] || { echo "Run through sudo from your own account, not as root directly."; exit 1; }
user_home="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
# The source tree of the Bun in VERSION, so its installers match the LLVM and
# sysroots that Bun release pins (root's $HOME is not yours, hence the override).
PATCHED_BUN_SOURCE="${PATCHED_BUN_SOURCE:-$user_home/.cache/patched-bun/$(. "$(dirname "$0")/../VERSION"; echo "$UPSTREAM_TAG")}"
export PATCHED_BUN_SOURCE
. "$(dirname "$0")/env.sh"
# Bun's installers look tools up on PATH (`require bun`); root's PATH has
# neither your bun nor rustup, so put your own toolchain first.
export PATH="$user_home/.bun/bin:$user_home/.cargo/bin:/usr/lib/llvm-23/bin:$PATH"
command -v bun >/dev/null || { echo "bun not found in $user_home/.bun/bin"; exit 1; }
# Fetch Bun's helper scripts (xmac.mjs) from the pinned commit, not Bun's main branch.
export BUN_BOOTSTRAP_REPO_REF="$UPSTREAM_COMMIT"

sudo -u "$SUDO_USER" "$ROOT/scripts/source.sh" >/dev/null
bootstrap="$SOURCE_DIR/scripts/bootstrap.sh"

sysroots=(/opt/macos-sdk /opt/winsysroot /opt/linux-sysroot-glibc /opt/linux-sysroot-glibc-arm64
  /opt/linux-sysroot-musl /opt/linux-sysroot-musl-arm64 /opt/android-ndk /opt/freebsd-sysroot /opt/freebsd-sysroot-arm64)
check_sysroots() {
  local missing=0 path
  for path in "${sysroots[@]}"; do
    if [ -d "$path" ] && [ -n "$(ls -A "$path")" ]; then echo "  ok   $path"; else echo "  MISSING $path"; missing=1; fi
  done
  [ $missing = 0 ] && echo "Cross-compile sysroots ready." || { echo "Some sysroots are missing; see the output above."; return 1; }
}

# Bun 1.4.3 replaced scripts/bootstrap.sh with scripts/build/ci-images/spec.ts,
# which generates its CI images' setup instead of keeping installer functions.
# Its pinned sysroots (macOS SDK 26.5, Windows SDK 10.0.26100, NDK r27c,
# glibc 2.31, FreeBSD 14.3) are the ones this script already installed from
# 1.4.x's bootstrap.sh, so on 1.4.3 only what lives inside LLVM's own resource
# directory has to follow the new LLVM: libclang-rt-<major>-dev (from
# `llvm.sh <major> all`) brings the Windows and Linux builtins, and the Android
# NDK's builtins and libunwind are linked in, as spec.ts's androidNdk tool does.
if [ ! -f "$bootstrap" ]; then
  [ -x /usr/lib/llvm-23/bin/clang ] || { echo "LLVM 23 is not installed; run: wget https://apt.llvm.org/llvm.sh -O - | sudo bash -s -- 23 all"; exit 1; }
  echo "=== android runtimes into $(clang --version | head -1)"
  resource_dir="$(clang -print-resource-dir)"
  [ -d "$resource_dir" ] || { echo "clang has no resource directory at $resource_dir; install LLVM first"; exit 1; }
  prebuilt=/opt/android-ndk/toolchains/llvm/prebuilt/linux-x86_64
  ndk_clang="$(ls "$prebuilt/lib/clang/" | head -n1)"
  ndk_runtime="$prebuilt/lib/clang/$ndk_clang/lib/linux"
  api_level=28
  for arch in aarch64 x86_64; do
    triple="$resource_dir/lib/$arch-unknown-linux-android$api_level"
    mkdir -p "$resource_dir/lib/linux/$arch" "$triple"
    ln -sfn "$ndk_runtime/libclang_rt.builtins-$arch-android.a" "$resource_dir/lib/linux/"
    ln -sfn "$ndk_runtime/$arch/libunwind.a" "$resource_dir/lib/linux/$arch/"
    ln -sfn "$ndk_runtime/libclang_rt.builtins-$arch-android.a" "$triple/libclang_rt.builtins.a"
    ln -sfn "$ndk_runtime/$arch/libunwind.a" "$triple/libunwind.a"
  done
  ls "$resource_dir/lib/windows" >/dev/null 2>&1 || { echo "no Windows builtins in $resource_dir; run: wget https://apt.llvm.org/llvm.sh -O - | sudo bash -s -- 23 all"; exit 1; }
  echo "  ok   android + windows runtimes in $resource_dir"
  check_sysroots
  exit $?
fi

[ "$(tail -1 "$bootstrap")" = 'main "$@"' ] || { echo "Bun's bootstrap.sh changed shape; review this script."; exit 1; }
functions="$(mktemp)"
trap 'rm -f "$functions"' EXIT
# FreeBSD moves end-of-life releases (14.3, which Bun 1.4.0 pins) off
# download.freebsd.org to its archive server; use the archive when needed.
# The archive is HTTP only, so every base.txz is checked against a pinned SHA-256.
sed -e '$d' \
  -e 's|base_txz=$(download_file "https://download.freebsd.org/releases/${fbsd_arch}/${freebsd_ver}-RELEASE/base.txz")|base_txz=$(download_file "$(freebsd_base_url "${fbsd_arch}" "${freebsd_ver}")"); freebsd_check "${fbsd_arch}" "${freebsd_ver}" "$base_txz" \|\| exit 1|' \
  "$bootstrap" > "$functions"
grep -q 'freebsd_check' "$functions" || { echo "Bun's FreeBSD installer changed shape; review this script."; exit 1; }
freebsd_base_url() {
  local current="https://download.freebsd.org/releases/$1/$2-RELEASE/base.txz"
  if curl -fsIL -o /dev/null --max-time 30 "$current"; then echo "$current"
  else echo "http://ftp-archive.freebsd.org/pub/FreeBSD-Archive/old-releases/$1/$2-RELEASE/base.txz"; fi
}
# SHA-256 of base.txz from each release's MANIFEST, checked against the files
# themselves when pinned (2026-09-27).
freebsd_check() { # freebsd_check <arch> <version> <file>
  local expected
  case "$1-$2" in
  amd64-14.3) expected=e38b5cf756d60086a6c2f736eff19cc7685f7e2313e31d14342fc8df57200a92 ;;
  arm64-14.3) expected=f83e824cb7a20dbadb2888a8bd253e6a1ac35024cc6dc8af9f3e229f75ec7129 ;;
  *)
    echo "No pinned checksum for FreeBSD $2 $1. Take base.txz's SHA-256 from that release's MANIFEST," >&2
    echo "confirm the downloaded file matches it, and add it to freebsd_check in $0." >&2
    return 1 ;;
  esac
  if [ -f "$3" ] && [ "$(sha256sum "$3" | cut -d' ' -f1)" = "$expected" ]; then
    echo "  FreeBSD $2 $1 base.txz: checksum ok" >&2
  else
    echo "FreeBSD $2 $1 base.txz does not match its pinned SHA-256 ($expected); not installing it." >&2
    return 1
  fi
}

# Every step by default; name steps to rerun only those, e.g. `sudo setup-cross.sh freebsd`.
steps=("$@")
[ ${#steps[@]} -gt 0 ] || steps=(packages macos windows glibc musl android freebsd)

set +eu
. "$functions"
check_operating_system
check_user
check_package_manager
# Bun gates these on its CI build host; this machine is ours.
ci=1

for step in "${steps[@]}"; do
  echo "=== $step"
  case "$step" in
  packages) install_packages nasm ruby-full libtool libtool-bin xz-utils unzip zip file jq skopeo binutils-aarch64-linux-gnu ;;
  macos) install_macos_sdk ;;
  windows) install_windows_sysroot ;;
  glibc) install_linux_glibc_sysroot ;;
  musl) install_linux_musl_sysroot ;;
  android) install_android_ndk ;;
  freebsd) install_freebsd_sysroot ;;
  *) echo "unknown step $step (packages macos windows glibc musl android freebsd)"; exit 1 ;;
  esac
done
set -eu

check_sysroots
