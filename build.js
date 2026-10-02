// Bundles src/*.js (ES modules) into a single self-contained dist/speed.html.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(ROOT, 'src');
const ENTRY = 'main.js';
const IMPORT_RE = /^\s*import\s[\s\S]*?from\s*['"]\.\/([^'"]+)['"];?/gm;

function orderFiles() {
  const order = [];
  const seen = new Set();
  const visit = (file) => {
    if (seen.has(file)) return;
    seen.add(file);
    const code = fs.readFileSync(path.join(SRC, file), 'utf8');
    for (const m of code.matchAll(IMPORT_RE)) visit(m[1]);
    order.push(file);
  };
  visit(ENTRY);
  return order;
}

function strip(code) {
  return code
    .replace(IMPORT_RE, '')
    .replace(/^export\s+(?=(?:async\s+)?(?:function|const|let|class)\b)/gm, '')
    .replace(/^export\s*\{[^}]*\};?/gm, '');
}

export function buildBundle() {
  const names = new Map();
  const parts = orderFiles().map((file) => {
    const code = strip(fs.readFileSync(path.join(SRC, file), 'utf8'));
    for (const m of code.matchAll(/^(?:async\s+)?(?:function\*?|const|let|class)\s+([A-Za-z_$][\w$]*)/gm)) {
      if (names.has(m[1])) throw new Error(`duplicate top-level name "${m[1]}" in ${file} and ${names.get(m[1])}`);
      names.set(m[1], file);
    }
    return `// ---- ${file} ----\n${code}`;
  });
  const js = `(() => {\n'use strict';\n${parts.join('\n')}\n})();\n`;
  new vm.Script(js); // syntax check
  return js;
}

export function buildHtml() {
  const template = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
  const js = buildBundle();
  return template.replace('<!--BUNDLE-->', () => `<script>\n${js}</script>`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const dist = path.join(ROOT, 'dist');
  fs.mkdirSync(dist, { recursive: true });
  const html = buildHtml();
  // speed.html is the shareable single file; index.html is the same page for web hosting.
  for (const name of ['speed.html', 'index.html']) fs.writeFileSync(path.join(dist, name), html);
  console.log(`built dist/speed.html + dist/index.html (${(html.length / 1024).toFixed(1)} KB)`);
}
