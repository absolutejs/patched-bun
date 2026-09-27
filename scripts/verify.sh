#!/usr/bin/env bash
# Proves the binary is Bun 1.4.0 with a working reactFastRefresh on Bun.Transpiler.
set -euo pipefail
. "$(dirname "$0")/env.sh"
BIN="${1:-$BINARY}"
[ "$("$BIN" --version)" = "$BUN_VERSION" ] || { echo "expected version $BUN_VERSION"; exit 1; }
"$BIN" -e '
const out = new Bun.Transpiler({ loader: "tsx", reactFastRefresh: true }).transformSync(
  "import { useState } from \"react\"; export function App() { const [n] = useState(0); return <h1>{n}</h1>; }");
if (!out.includes("$RefreshReg$") || !out.includes("$RefreshSig$")) { console.error(out); throw new Error("no refresh registrations"); }
const off = new Bun.Transpiler({ loader: "tsx" }).transformSync("export function App() { return <h1/>; }");
if (off.includes("$RefreshReg$")) throw new Error("refresh injected without the option");
const ts = new Bun.Transpiler({ loader: "ts", reactFastRefresh: true }).transformSync("export const a = 1;");
if (ts.includes("$RefreshReg$")) throw new Error("refresh injected for a non-JSX loader");
console.log("reactFastRefresh: ok");
'
(cd "$SOURCE_DIR" && "$BIN" test test/bundler/transpiler/transpiler.test.js 2>&1 | tail -4)
