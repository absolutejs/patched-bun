# AbsoluteJS patched Bun

Bun 1.4.0 plus one fix AbsoluteJS needs and upstream has not shipped yet:
**`reactFastRefresh` on `new Bun.Transpiler()`** ([oven-sh/bun#32919](https://github.com/oven-sh/bun/issues/32919),
fix in the closed [oven-sh/bun#32951](https://github.com/oven-sh/bun/pull/32951), backported unchanged).

Without it, React edits in `absolute dev` fall back to a full page reload and lose component
state, because `Bun.Transpiler` never injects the `$RefreshReg$` / `$RefreshSig$` calls React
Fast Refresh needs.

## Branch layout

`absolutejs/v1.4.0` has two commits: stock Bun 1.4.0 exactly as released
(oven-sh/bun@34cbb9a4), then the backport. `git show HEAD` is the whole patch.

## Who uses it

- **AbsoluteJS CLI**: on stock Bun, `absolute dev` offers to install this build into its own
  cache (Install now / Ask later / Don't ask again). Your `bun` on PATH is never touched; the
  CLI runs the dev server on the patched binary when it is installed.
- **PAAS images** (Studio, control plane): install the release binary, checked against
  `SHASUMS256.txt`.

## Build and release (on a Linux x64 machine, no CI)

```bash
absolutejs/preflight.sh   # toolchain + memory/disk check; prints what to install
absolutejs/build.sh       # release build, LTO off, JOBS=4 by default (~1-2 h)
absolutejs/verify.sh      # version, reactFastRefresh on/off/non-JSX, Bun's transpiler tests
absolutejs/release.sh     # zip + SHA-256, push branch + tag, GitHub release
```

## When upstream ships the fix

Stop releasing this. In AbsoluteJS, search for `BUN-REACT-REFRESH-LEGACY` and remove every
marked block, then raise `engines.bun` to the first Bun release that contains the fix.
