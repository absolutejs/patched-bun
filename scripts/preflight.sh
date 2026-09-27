#!/usr/bin/env bash
# Checks everything the build needs before an hour-long compile starts.
set -u
ok=1
need() { if command -v "$1" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; else printf '  MISSING %s  (%s)\n' "$1" "$2"; ok=0; fi; }
echo "Toolchain:"
need clang-21 "wget https://apt.llvm.org/llvm.sh -O - | sudo bash -s -- 21 all"
need ld.lld-21 "same LLVM 21 install"
need cmake "sudo apt install cmake"
need ninja "sudo apt install ninja-build"
need go "sudo apt install golang"
need ruby "sudo apt install ruby-full"
need libtoolize "sudo apt install libtool libtool-bin"
need pkg-config "sudo apt install pkg-config"
need rustup "https://rustup.rs"
need bun "stock bun is used to run the build scripts"
if command -v clang-21 >/dev/null; then clang-21 --version | head -1 | grep -q '21\.1\.8' || echo "  note: Bun asks for LLVM 21.1.8; found $(clang-21 --version | head -1)"; fi
free_gb=$(free -g | awk '/^Mem:/{print $7}')
disk_gb=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc 0-9)
echo "Resources: ${free_gb}GB memory available, ${disk_gb}GB disk free (need ~10GB disk; close other heavy work first)"
[ "$disk_gb" -ge 15 ] || { echo "  not enough disk"; ok=0; }
[ "$free_gb" -ge 8 ] || echo "  warning: under 8GB available memory; the build may be killed. Close other agents, browsers and dev servers."
[ $ok = 1 ] && echo "Ready to build." || { echo "Install the missing pieces, then rerun."; exit 1; }
