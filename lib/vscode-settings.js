// No dependencies. JSONC is read without eval; edits preserve comments and other keys.
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
function parse(text) {
  let clean = '', string = false, escape = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i], next = text[i + 1];
    if (string) {
      clean += c;
      if (escape) escape = false;
      else if (c === '\\') escape = true;
      else if (c === '"') string = false;
    } else if (c === '"') { string = true; clean += c; }
    else if (c === '/' && next === '/') {
      clean += '  '; i++;
      while (i + 1 < text.length && text[i + 1] !== '\n') { clean += ' '; i++; }
    } else if (c === '/' && next === '*') {
      clean += '  '; i++;
      while (i + 1 < text.length && !(text[i + 1] === '*' && text[i + 2] === '/')) { i++; clean += text[i] === '\n' ? '\n' : ' '; }
      if (i + 2 >= text.length) throw Error('Comentário incompleto');
      clean += '  '; i += 2;
    } else clean += c;
  }
  // Replace trailing commas only outside strings, keeping character positions.
  string = false; escape = false;
  const chars = clean.split('');
  for (let i = 0; i < clean.length; i++) {
    const c = clean[i];
    if (string) { if (escape) escape = false; else if (c === '\\') escape = true; else if (c === '"') string = false; }
    else if (c === '"') string = true;
    else if (c === ',' && /^\s*[}\]]/.test(clean.slice(i + 1))) chars[i] = ' ';
  }
  const trailingComma = /,\s*}\s*$/.test(clean);
  clean = chars.join('');
  const value = JSON.parse(clean);
  if (!value || Array.isArray(value) || typeof value !== 'object') throw Error('Esperado objeto JSONC');
  // Locate top-level values for precise replacement, rejecting duplicate keys.
  const spans = {}; const re = /"(?:\\.|[^"\\])*"|[{}\[\],:]|[^\s{}\[\],:]+/g;
  const tokens = [...clean.matchAll(re)]; let depth = 0;
  for (let i = 0; i < tokens.length; i++) {
    const t = tokens[i][0];
    if (t === '{' || t === '[') depth++;
    else if (t === '}' || t === ']') depth--;
    else if (depth === 1 && t[0] === '"' && tokens[i + 1] && tokens[i + 1][0] === ':') {
      const key = JSON.parse(t);
      if (Object.prototype.hasOwnProperty.call(spans, key)) throw Error('Chave duplicada: ' + key);
      const start = tokens[i + 2].index; let j = i + 2, inner = 0;
      for (; j < tokens.length; j++) {
        const token = tokens[j][0];
        if (inner === 0 && (token === ',' || token === '}')) break;
        if (token === '{' || token === '[') inner++;
        if (token === '}' || token === ']') inner--;
      }
      const prev = tokens[j - 1]; spans[key] = [start, prev.index + prev[0].length];
    }
  }
  return {value, spans, trailingComma, close: clean.lastIndexOf('}')};
}
function safe(file, root) {
  for (let p = file; ; p = path.dirname(p)) {
    if (fs.existsSync(p) || (() => { try { return fs.lstatSync(p).isSymbolicLink(); } catch (_) { return false; } })()) {
      if (fs.lstatSync(p).isSymbolicLink()) throw Error('Link simbólico preservado: ' + p);
    }
    if (p === root || p.startsWith(root + path.sep)) throw Error('Destino dentro do clone');
    if (p === path.dirname(p)) break;
  }
}
function main() {
  const [mode, file, manifest, root, key, expected] = process.argv.slice(2);
  safe(path.resolve(file), fs.realpathSync(root));
  const exists = fs.existsSync(file), text = exists ? fs.readFileSync(file, 'utf8') : '{}';
  const local = parse(text), manifestText = fs.readFileSync(manifest, 'utf8'), desired = JSON.parse(manifestText);
  const digest = crypto.createHash('sha256').update((exists ? 'yes' : 'no') + text + manifestText).digest('hex');
  if (mode === 'hash') { console.log(digest); return; }
  if (mode === 'keys') { Object.keys(desired).forEach(k => console.log(k)); return; }
  const keys = key ? [key] : Object.keys(desired);
  if (mode === 'plan') {
    for (const k of keys) {
      if (JSON.stringify(local.value[k]) === JSON.stringify(desired[k])) console.log('[SKIP] ' + k);
      else console.log('[REVIEW] ' + k + ': ' + (Object.prototype.hasOwnProperty.call(local.value, k) ? 'conflito, local=' + JSON.stringify(local.value[k]) : 'ausente') + ' -> ' + JSON.stringify(desired[k]));
    }
    return;
  }
  if (mode !== 'apply' || !Object.prototype.hasOwnProperty.call(desired, key) || expected !== digest) throw Error('Arquivo mudou após a revisão; reexecute');
  if (JSON.stringify(local.value[key]) === JSON.stringify(desired[key])) return;
  let next;
  if (local.spans[key]) {
    const [start, end] = local.spans[key]; next = text.slice(0, start) + JSON.stringify(desired[key]) + text.slice(end);
  } else {
    // A comma on its own line also handles comments after the previous value.
    const prefix = text.slice(0, local.close);
    const comma = Object.keys(local.value).length && !local.trailingComma ? ',' : '';
    next = prefix + '\n' + comma + JSON.stringify(key) + ': ' + JSON.stringify(desired[key]) + '\n' + text.slice(local.close);
  }
  parse(next); // Validate before backup or any write.
  fs.mkdirSync(path.dirname(file), {recursive: true});
  const lock = file + '.config-workplace-lock'; fs.mkdirSync(lock);
  let temp;
  try {
    const current = fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '{}';
    if (current !== text || fs.existsSync(file) !== exists) throw Error('Alteração concorrente');
    safe(path.resolve(file), fs.realpathSync(root));
    const work = fs.mkdtempSync(path.join(path.dirname(file), '.config-workplace-'));
    temp = path.join(work, 'settings.json');
    if (exists) {
      fs.copyFileSync(file, path.join(work, 'backup.json'), fs.constants.COPYFILE_EXCL);
      fs.chmodSync(path.join(work, 'backup.json'), 0o600);
      console.log('[BACKUP] ' + path.join(work, 'backup.json'));
    }
    fs.writeFileSync(temp, next, {mode: exists ? fs.statSync(file).mode & 0o777 : 0o600, flag: 'wx'});
    if (fs.existsSync(file) !== exists || (exists && fs.readFileSync(file, 'utf8') !== text)) throw Error('Alteração concorrente');
    fs.renameSync(temp, file);
    console.log('[CONFIGURED] ' + key);
  } finally { if (temp && fs.existsSync(temp)) fs.unlinkSync(temp); fs.rmdirSync(lock); }
}
try { main(); } catch (error) { console.error('[REVIEW] ' + error.message); process.exitCode = 1; }
