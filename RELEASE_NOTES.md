Bun 1.4.4 with two changes AbsoluteJS needs and upstream has not shipped. Everything else is
stock Bun 1.4.4 (oven-sh/bun@38afee6c).

**New in `+absolute.2`: `lockdown()` in `bun:jsc`.** Called inside a Worker, it removes the `Bun`
global and `ShadowRealm` and makes every later `import()` reject. It is one-way and idempotent,
and it throws outside a Worker. Modules the Worker imported before the call keep working.

It closes the two ways sandboxed code in a stock Bun Worker reaches host authority, which no
JavaScript can close:

- `Bun` is non-configurable and read-only on every Worker global, so indirect eval
  (`(0, eval)("Bun")`) and the `Function` constructor reach it however the global is hardened, and a
  `ShadowRealm` hands out a fresh copy.
- `import("node:child_process")`, `import("node:fs")` and `import("bun:ffi")` load inside any
  Worker, with no eval needed.

`@absolutejs/isolated-jsc` 0.13 calls it after hardening a Worker-backend isolate, and its
`requireLockdown` option refuses to run unlocked.

**Carried over: `reactFastRefresh` on `new Bun.Transpiler()`**, the fix for
[oven-sh/bun#32919](https://github.com/oven-sh/bun/issues/32919) from the closed
[oven-sh/bun#32951](https://github.com/oven-sh/bun/pull/32951). Stock Bun 1.4.4 still ignores the
option.

Built for every platform Bun's release ships, the way Bun builds them: cross-compiled from one
Linux machine, release build, LTO where Bun enables it, nehalem baseline on x64, same zip names
and layout. Each zip has a `-profile` companion with the unstripped binary and symbols.

- macOS: `bun-darwin-aarch64`, `bun-darwin-x64`
- Windows: `bun-windows-x64`, `bun-windows-aarch64`
- Linux (glibc): `bun-linux-x64`, `bun-linux-aarch64`
- Linux (musl, Alpine; needs `libgcc libstdc++`, as stock Bun does): `bun-linux-x64-musl`, `bun-linux-aarch64-musl`
- Android: `bun-linux-x64-android`, `bun-linux-aarch64-android`
- FreeBSD: `bun-freebsd-x64`, `bun-freebsd-aarch64`

Verified before release: every binary has the right format for its platform; React Fast Refresh
and lockdown behave correctly on linux x64, x64 musl, arm64 and arm64 musl; Bun's transpiler suite
and lockdown tests pass, and Bun's `bun:jsc` and Worker suites show no new failures; checksums in
`SHASUMS256.txt`.

The AbsoluteJS CLI installs the right one for you; you do not need to download it by hand. macOS
binaries carry the build's ad-hoc signature (with Bun's JIT entitlements), not a Developer ID
signature, and Windows binaries are not Authenticode-signed, so a browser download may show a
Gatekeeper or SmartScreen prompt. Verify a manual download with `sha256sum -c SHASUMS256.txt`.

Build identity: `bun -v` and `Bun.version` report `1.4.4+absolute.2`. Install with BVM 0.1.5 or
later. The `+absolute.2` suffix is SemVer build metadata, preserving upstream version precedence.
