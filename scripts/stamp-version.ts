// Called after applying patches; never changes upstream numeric compatibility fields.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
const [source, version] = process.argv.slice(2);
if (!source || !/^\d+\.\d+\.\d+\+absolute\.\d+$/.test(version ?? "")) {
  throw new Error("usage: stamp-version.ts <source> <X.Y.Z+absolute.N>");
}
function replaceOnce(file: string, before: string, after: string) {
  const path = join(source, file);
  const text = readFileSync(path, "utf8");
  if (text.split(before).length !== 2) throw new Error(`Upstream version definition changed: ${file}`);
  writeFileSync(path, text.replace(before, after));
}
replaceOnce("src/bun_core/env.rs",
  'const_format::formatcp!("{}.{}.{}", VERSION.major, VERSION.minor, VERSION.patch)',
  JSON.stringify(version));
// Metadata already starts with +; append the upstream SHA within that metadata.
replaceOnce("src/bun_core/Global.rs",
  'formatcp!("{}+{}", version_string, env::GIT_SHA_SHORT)',
  'formatcp!("{}.{}", version_string, env::GIT_SHA_SHORT)');
