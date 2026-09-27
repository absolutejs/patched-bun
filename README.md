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

## Who uses it

- **AbsoluteJS CLI**: on stock Bun, `absolute dev` offers to install the release into its own
  cache (Install now / Ask later / Don't ask again). Your `bun` on PATH is never touched; the CLI
  runs the dev server on the patched binary once it is installed.
- **PAAS images** (Studio, control plane): install the release binary, checked against
  `SHASUMS256.txt`.

## Build and release (Linux x64, from this machine, no CI)

```bash
scripts/preflight.sh   # toolchain + memory/disk check; prints anything to install
scripts/build.sh       # fetch + patch source, release build, LTO off, JOBS=4 (~1-2 h)
scripts/verify.sh      # version, reactFastRefresh on/off/non-JSX, Bun's transpiler tests
scripts/release.sh     # zip + SHA-256, push this repo, GitHub release
```

## When upstream ships the fix

Stop releasing this. In AbsoluteJS, search for `BUN-REACT-REFRESH-LEGACY` and remove every
marked block, then raise `engines.bun` to the first Bun release that contains the fix.
