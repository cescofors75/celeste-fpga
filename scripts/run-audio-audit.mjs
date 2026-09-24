import {spawnSync} from 'node:child_process';
import {existsSync} from 'node:fs';
import os from 'node:os';
import path from 'node:path';
const bundled=path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');
const python=process.env.CELESTE_AUDIT_PYTHON||(existsSync(bundled)?bundled:'python');
const result=spawnSync(python,['scripts/audio_audit.py',...process.argv.slice(2)],{stdio:'inherit'});
if(result.error)throw result.error;
process.exit(result.status??1);
