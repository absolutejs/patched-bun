import {mkdtempSync, mkdirSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {test, expect} from 'bun:test';
const script = join(import.meta.dir, 'stamp-version.ts');
test('stamps version and revision without changing numeric compatibility', () => {
 const dir = mkdtempSync(join(tmpdir(), 'stamp-test-'));
 try {
 mkdirSync(join(dir, 'src/bun_core'), {recursive:true});
 const env = join(dir,'src/bun_core/env.rs');
 const global = join(dir,'src/bun_core/Global.rs');
 writeFileSync(env,'pub const VERSION: crate::Version = build_options::VERSION;\npub const VERSION_STRING: &str = const_format::formatcp!("{}.{}.{}", VERSION.major, VERSION.minor, VERSION.patch);');
 writeFileSync(global,'formatcp!("{}+{}", version_string, env::GIT_SHA_SHORT)');
 const run = (version:string) => Bun.spawnSync([process.execPath,script,dir,version]);
 expect(run('1.4.3+absolute.2').exitCode).toBe(0);
 expect(readFileSync(env,'utf8')).toContain('"1.4.3+absolute.2"');
 expect(readFileSync(env,'utf8')).toContain('pub const VERSION: crate::Version = build_options::VERSION;');
 expect(readFileSync(global,'utf8')).toContain('"{}.{}"');
 expect(run('1.4.3+absolute.2').exitCode).not.toBe(0);
 expect(run('1.4.3-absolute.2').exitCode).not.toBe(0);
 } finally {rmSync(dir,{recursive:true,force:true});}
});
