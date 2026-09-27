// Daemonizes the API server: detached spawn so it survives the launching
// shell (mirrors how pg_ctl keeps Postgres alive across calls).
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const out = fs.openSync('/tmp/api.log', 'a');
const child = spawn(process.execPath, [path.join(__dirname, '..', 'dist', 'src', 'main.js')], {
  detached: true,
  stdio: ['ignore', out, out],
  env: { ...process.env, PORT: '3000' },
});
child.unref();
console.log('api daemon pid', child.pid);
