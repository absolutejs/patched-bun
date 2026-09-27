Bun 1.4.0 with `reactFastRefresh` on `new Bun.Transpiler()` — the fix for
[oven-sh/bun#32919](https://github.com/oven-sh/bun/issues/32919), backported unchanged from the
closed [oven-sh/bun#32951](https://github.com/oven-sh/bun/pull/32951).

Everything else is stock Bun 1.4.0 (oven-sh/bun@34cbb9a4). Linux x64 only.

The AbsoluteJS CLI installs this automatically when you choose **Install now**; you do not need to
download it by hand. Verify a manual download with `sha256sum -c SHASUMS256.txt`.

This release goes away once Bun ships the fix upstream.
