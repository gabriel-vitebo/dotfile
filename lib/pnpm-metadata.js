'use strict';
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', s => { input += s; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input), range = data.engines.node;
    if (!/^\d+\.\d+\.\d+$/.test(data.version)) throw Error('Versão inválida');
    // Fail closed if the registry introduces a range grammar not supported here.
    const version = process.versions.node.split('.').map(Number);
    const allowed = range.split('||').some(clause => clause.trim().split(/\s+/).every(part => {
      const match = /^(>=|>|<=|<|=)?(\d+)(?:\.(\d+))?(?:\.(\d+))?$/.exec(part);
      if (!match) throw Error('Requisito Node requer revisão: ' + range);
      const target = match.slice(2).map(v => Number(v || 0));
      let cmp = 0;
      for (let i = 0; i < 3; i++) { if (version[i] !== target[i]) { cmp = version[i] > target[i] ? 1 : -1; break; } }
      return {'>=': cmp >= 0, '>': cmp > 0, '<=': cmp <= 0, '<': cmp < 0, '=': cmp === 0}[match[1] || '='];
    }));
    if (!allowed) throw Error('Node ' + process.versions.node + ' incompatível com pnpm ' + data.version + ' (' + range + '); Node preservado');
    console.log(data.version);
  } catch (err) { console.error('[REVIEW] ' + err.message); process.exitCode = 1; }
});
