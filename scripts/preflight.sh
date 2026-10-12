#!/usr/bin/env bash
# Checks everything the build needs before an hour-long compile starts.
set -u
ok=1
need() { if command -v "$1" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; else printf '  MISSING %s  (%s)\n' "$1" "$2"; ok=0; fi; }
echo "Toolchain:"
need clang-23 "wget https://apt.llvm.org/llvm.sh -O - | sudo bash -s -- 23 all"
need ld.lld-23 "same LLVM 23 install"
need cmake "sudo apt install cmake"
need ninja "sudo apt install ninja-build"
need go "sudo apt install golang"
need ruby "sudo apt install ruby-full"
need libtoolize "sudo apt install libtool libtool-bin"
need pkg-config "sudo apt install pkg-config"
need nasm "sudo apt install nasm"
need xz "sudo apt install xz-utils"
need zip "sudo apt install zip"
need rustup "https://rustup.rs"
need bun "stock bun is used to run the build scripts"
if command -v clang-23 >/dev/null; then clang-23 --version | head -1 | grep -q '23\.1\.' || echo "  note: Bun 1.4.3 asks for LLVM 23.1.x (scripts/build/ci-images/spec.ts); found $(clang-23 --version | head -1)"; fi
free_gb=$(free -g | awk '/^Mem:/{print $7}')
disk_gb=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc 0-9)
echo "Resources: ${free_gb}GB memory available, ${disk_gb}GB disk free (budget ~10GB per target, ~120GB for all 12; close other heavy work first)"
[ "$disk_gb" -ge 150 ] || { echo "  not enough disk"; ok=0; }
[ "$free_gb" -ge 8 ] || echo "  warning: under 8GB available memory; the build may be killed. Close other agents, browsers and dev servers."
[ $ok = 1 ] && echo "Ready to build." || { echo "Install the missing pieces, then rerun."; exit 1; }
