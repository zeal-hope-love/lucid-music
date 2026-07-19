const fs = require('fs');
const p = 'c:\\Users\\PoXia\\DevEcoStudioProjects\\lucid_music\\entry';
console.log('exists:', fs.existsSync(p));
try { console.log('stat:', JSON.stringify(fs.statSync(p))); } catch(e) { console.log('stat err:', e.message); }
const bp = p + '\\build-profile.json5';
console.log('build-profile exists:', fs.existsSync(bp));
const op = p + '\\oh-package.json5';
console.log('oh-package exists:', fs.existsSync(op));
const sm = p + '\\src\\main';
console.log('src/main exists:', fs.existsSync(sm));
