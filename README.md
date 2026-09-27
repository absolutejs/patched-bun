# AbsoluteJS patched Bun

Bun 1.4.0 plus one fix AbsoluteJS needs and upstream has not shipped yet:
**`reactFastRefresh` on `new Bun.Transpiler()`** ([oven-sh/bun#32919](https://github.com/oven-sh/bun/issues/32919),
fix in the closed [oven-sh/bun#32951](https://github.com/oven-sh/bun/pull/32951), backported unchanged
in [`patches/`](patches)).

Without it, React edits in `absolute dev` fall back to a full page reload and lose component
state, because `Bun.Transpiler` never injects the `$RefreshReg$` / `$RefreshSig$` calls React
Fast Refresh needs.

## What is in this repo

Only the patch and the scripts that build and release it. Bun's source is fetched at the pinned
commit ([`VERSION`](VERSION)) into `~/.cache/patched-bun/`, outside this repo, and the patches are
applied fresh on every build. Binaries are attached to this repo's GitHub releases.

## Platforms

Every platform Bun's own release ships, built the way Bun builds them: all cross-compiled from one
Linux machine (Bun's release host does the same, see `.buildkite/ci.mjs` `buildPlatforms`), release
build type, LTO where Bun enables it, x64 targeting the nehalem baseline, same zip names and layout.

| Zip | | Zip | |
|---|---|---|---|
| `bun-linux-x64` | glibc | `bun-darwin-aarch64` | Apple Silicon |
| `bun-linux-aarch64` | glibc | `bun-darwin-x64` | Intel Mac |
| `bun-linux-x64-musl` | Alpine | `bun-windows-x64` | |
| `bun-linux-aarch64-musl` | Alpine | `bun-windows-aarch64` | |
| `bun-linux-x64-android` | | `bun-freebsd-x64` | |
| `bun-linux-aarch64-android` | | `bun-freebsd-aarch64` | |

Each also has a `-profile` zip (unstripped binary with symbols), as Bun's release does.

Differences from Bun's official binaries: macOS builds carry the build's ad-hoc signature (with
Bun's JIT entitlements) rather than a Developer ID signature, and Windows builds are not
Authenticode-signed. Both run normally when installed by the AbsoluteJS CLI or PAAS; a browser
download may show a Gatekeeper or SmartScreen prompt. Bun's link-order file (a small startup
optimization traced in Bun's CI) is not used.

## Who uses it

- **AbsoluteJS CLI**: on stock Bun, `absolute dev` offers to install the release for your platform
  into its own cache (Install now / Ask later / Don't ask again). Your `bun` on PATH is never
  touched; the CLI runs the dev server on the patched binary once it is installed.
- **PAAS images** (Studio, control plane): install the linux release, checked against
  `SHASUMS256.txt`.

## Build and release (from a Linux x64 machine, no CI)

```bash
sudo scripts/setup-cross.sh   # once: macOS SDK, Windows sysroot, glibc/musl/Android/FreeBSD sysroots (Bun's own installers)
scripts/preflight.sh          # toolchain, memory and disk check
scripts/build.sh              # every target; TARGETS="linux-x64 darwin-aarch64" for a subset
scripts/verify.sh             # formats, React refresh behavior (native, and Docker for musl/arm64), checksums
scripts/release.sh            # push this repo, GitHub release with every zip + SHASUMS256.txt
```

## When upstream ships the fix

Stop releasing this. In AbsoluteJS, search for `BUN-REACT-REFRESH-LEGACY` and remove every
marked block, then raise `engines.bun` to the first Bun release that contains the fix.
