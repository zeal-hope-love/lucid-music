const fs = require('fs');
const p = 'c:\\Users\\PoXia\\DevEcoStudioProjects\\lucid_music\\entry';
console.log('input :', p);
try {
  const rp = fs.realpathSync.native(p);
  console.log('real  :', rp);
  console.log('equal :', rp === p);
} catch(e) {
  console.log('realpath err:', e.message);
}
// also test project root
const root = 'c:\\Users\\PoXia\\DevEcoStudioProjects\\lucid_music';
try {
  const rp = fs.realpathSync.native(root);
  console.log('root real:', rp, 'equal:', rp === root);
} catch(e) { console.log('root err:', e.message); }
