#!/usr/bin/env bash
# Checks every built artifact. The patch is platform-independent Rust, so the
# behavior test runs where the binary can run: natively for linux-x64, and in
# Docker for musl (Alpine) and arm64 (when QEMU binfmt is registered). The
# rest are checked for the right file format and architecture.
set -euo pipefail
. "$(dirname "$0")/env.sh"
dist="$SOURCE_DIR/build/dist"
behavior='
const out = new Bun.Transpiler({ loader: "tsx", reactFastRefresh: true }).transformSync(
  "import { useState } from \"react\"; export function App() { const [n] = useState(0); return <h1>{n}</h1>; }");
if (!out.includes("$RefreshReg$") || !out.includes("$RefreshSig$")) { console.error(out); throw new Error("no refresh registrations"); }
const off = new Bun.Transpiler({ loader: "tsx" }).transformSync("export function App() { return <h1/>; }");
if (off.includes("$RefreshReg$")) throw new Error("refresh injected without the option");
const ts = new Bun.Transpiler({ loader: "ts", reactFastRefresh: true }).transformSync("export const a = 1;");
if (ts.includes("$RefreshReg$")) throw new Error("refresh injected for a non-JSX loader");
if (Bun.version !== "'"$BUN_VERSION"'") throw new Error("version " + Bun.version);
console.log("reactFastRefresh ok on " + process.platform + "-" + process.arch);
'
expect_format() { # expect_format <name> <file(1) pattern>
  local zip="$dist/bun-$1.zip" tmp; tmp=$(mktemp -d)
  [ -f "$zip" ] || { echo "  skip $1 (not built)"; return; }
  unzip -q "$zip" -d "$tmp"
  local bin; bin=$(find "$tmp" -type f -name 'bun*' | head -1)
  if file -b "$bin" | grep -qE "$2"; then echo "  ok   $1: $(file -b "$bin" | cut -c1-70)"; else echo "  FAIL $1: $(file -b "$bin")"; fail=1; fi
  rm -rf "$tmp"
}
run_in() { # run_in <name> <docker image> <platform>
  local zip="$dist/bun-$1.zip" tmp; tmp=$(mktemp -d)
  [ -f "$zip" ] || return
  if [ "$3" = linux/arm64 ] && [ "$(uname -m)" != aarch64 ] && [ ! -e /proc/sys/fs/binfmt_misc/qemu-aarch64 ]; then
    echo "  skip $1: no arm64 emulation (register it with: docker run --privileged --rm tonistiigi/binfmt --install arm64)"
    return
  fi
  unzip -q "$zip" -d "$tmp"
  docker pull -q --platform "$3" "$2" >/dev/null
  # Bun's musl builds need libgcc and libstdc++, as Bun's own Alpine image installs.
  local prepare=":"; [[ "$2" == alpine* ]] && prepare="apk add -q --no-progress libgcc libstdc++ >/dev/null"
  if docker run --rm --platform "$3" -e BEHAVIOR="$behavior" -v "$tmp/bun-$1:/b:ro" "$2" \
    sh -c "$prepare && exec /b/bun -e \"\$BEHAVIOR\"" 2>&1 | sed 's/^/       /'; then :; else echo "  FAIL $1 behavior"; fail=1; fi
  rm -rf "$tmp"
}
fail=0
echo "Formats:"
expect_format linux-x64 'ELF 64-bit.*x86-64'
expect_format linux-aarch64 'ELF 64-bit.*aarch64'
expect_format linux-x64-musl 'ELF 64-bit.*x86-64'
expect_format linux-aarch64-musl 'ELF 64-bit.*aarch64'
expect_format linux-x64-android 'ELF 64-bit.*x86-64'
expect_format linux-aarch64-android 'ELF 64-bit.*aarch64'
expect_format darwin-aarch64 'Mach-O 64-bit.*arm64'
expect_format darwin-x64 'Mach-O 64-bit.*x86_64'
expect_format windows-x64 'PE32\+.*x86-64'
expect_format windows-aarch64 'PE32\+.*Aarch64'
expect_format freebsd-x64 'ELF 64-bit.*x86-64.*FreeBSD'
expect_format freebsd-aarch64 'ELF 64-bit.*aarch64.*FreeBSD'
echo "Behavior:"
if [ -f "$dist/bun-linux-x64.zip" ]; then
  tmp=$(mktemp -d); unzip -q "$dist/bun-linux-x64.zip" -d "$tmp"
  "$tmp/bun-linux-x64/bun" -e "$behavior" | sed 's/^/       /' || fail=1
  (cd "$SOURCE_DIR" && "$tmp/bun-linux-x64/bun" test test/bundler/transpiler/transpiler.test.js 2>&1 | tail -3 | sed 's/^/       /')
  rm -rf "$tmp"
fi
if command -v docker >/dev/null; then
  run_in linux-x64-musl alpine:3.22 linux/amd64
  run_in linux-aarch64 debian:13-slim linux/arm64
  run_in linux-aarch64-musl alpine:3.22 linux/arm64
fi
echo "Checksums:"
(cd "$dist" && sha256sum -c SHASUMS256.txt | sed 's/^/  /') || fail=1
[ $fail = 0 ] && echo "All built artifacts verified." || { echo "Verification failed."; exit 1; }
