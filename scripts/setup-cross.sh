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
PATCHED_BUN_SOURCE="${PATCHED_BUN_SOURCE:-$user_home/.cache/patched-bun/bun-v1.4.0}"
export PATCHED_BUN_SOURCE
. "$(dirname "$0")/env.sh"
# Bun's installers look tools up on PATH (`require bun`); root's PATH has
# neither your bun nor rustup, so put your own toolchain first.
export PATH="$user_home/.bun/bin:$user_home/.cargo/bin:/usr/lib/llvm-21/bin:$PATH"
command -v bun >/dev/null || { echo "bun not found in $user_home/.bun/bin"; exit 1; }
# Fetch Bun's helper scripts (xmac.mjs) from the pinned commit, not Bun's main branch.
export BUN_BOOTSTRAP_REPO_REF="$UPSTREAM_COMMIT"

sudo -u "$SUDO_USER" "$ROOT/scripts/source.sh" >/dev/null
bootstrap="$SOURCE_DIR/scripts/bootstrap.sh"
[ "$(tail -1 "$bootstrap")" = 'main "$@"' ] || { echo "Bun's bootstrap.sh changed shape; review this script."; exit 1; }
functions="$(mktemp)"
trap 'rm -f "$functions"' EXIT
sed '$d' "$bootstrap" > "$functions"

set +eu
. "$functions"
check_operating_system
check_user
check_package_manager
# Bun gates these on its CI build host; this machine is ours.
ci=1

install_packages nasm ruby-full libtool libtool-bin xz-utils unzip zip file jq skopeo binutils-aarch64-linux-gnu
install_macos_sdk
install_windows_sysroot
install_linux_glibc_sysroot
install_linux_musl_sysroot
install_android_ndk
install_freebsd_sysroot
set -eu

missing=0
for path in /opt/macos-sdk /opt/winsysroot /opt/linux-sysroot-glibc /opt/linux-sysroot-glibc-arm64 \
  /opt/linux-sysroot-musl /opt/linux-sysroot-musl-arm64 /opt/android-ndk /opt/freebsd-sysroot /opt/freebsd-sysroot-arm64; do
  if [ -d "$path" ] && [ -n "$(ls -A "$path")" ]; then echo "  ok   $path"; else echo "  MISSING $path"; missing=1; fi
done
[ $missing = 0 ] && echo "Cross-compile sysroots ready." || { echo "Some sysroots are missing; see the output above."; exit 1; }
