Bun 1.4.2 with `reactFastRefresh` on `new Bun.Transpiler()`: the fix for
[oven-sh/bun#32919](https://github.com/oven-sh/bun/issues/32919), from the closed
[oven-sh/bun#32951](https://github.com/oven-sh/bun/pull/32951). Everything else is stock
Bun 1.4.2 (oven-sh/bun@744846f8). Stock Bun 1.4.1 and 1.4.2 still ignore the option.

The fix itself is unchanged from `bun-v1.4.0-absolute.2`; only the patch's regression test was
re-based onto 1.4.2's test file. Bun 1.4.1 is skipped on purpose: it shipped a `bun build`
regression (nested `var` renamed to a `let` binding's name) that 1.4.2 fixes.

Built for every platform Bun's release ships, the way Bun builds them: cross-compiled from one
Linux machine, release build, LTO where Bun enables it, nehalem baseline on x64, same zip names
and layout. Each zip has a `-profile` companion with the unstripped binary and symbols.

- macOS: `bun-darwin-aarch64`, `bun-darwin-x64`
- Windows: `bun-windows-x64`, `bun-windows-aarch64`
- Linux (glibc): `bun-linux-x64`, `bun-linux-aarch64`
- Linux (musl, Alpine; needs `libgcc libstdc++`, as stock Bun does): `bun-linux-x64-musl`, `bun-linux-aarch64-musl`
- Android: `bun-linux-x64-android`, `bun-linux-aarch64-android`
- FreeBSD: `bun-freebsd-x64`, `bun-freebsd-aarch64`

Verified before release: every binary has the right format for its platform; the React Fast
Refresh transform works on linux x64, x64 musl, arm64 and arm64 musl; Bun's transpiler test suite
passes (237 tests); checksums in `SHASUMS256.txt`.

The AbsoluteJS CLI installs the right one for you; you do not need to download it by hand. macOS
binaries carry the build's ad-hoc signature (with Bun's JIT entitlements), not a Developer ID
signature, and Windows binaries are not Authenticode-signed, so a browser download may show a
Gatekeeper or SmartScreen prompt. Verify a manual download with `sha256sum -c SHASUMS256.txt`.

This release goes away once Bun ships the fix upstream.
