const fs = require('fs');
const f = 'C:\\Program Files\\Huawei\\DevEco Studio\\tools\\hvigor\\hvigor\\src\\base\\internal\\lifecycle\\init.js';
const s = fs.readFileSync(f, 'utf8');
const idx = s.indexOf('exitIfNotExists');
console.log('idx:', idx);
console.log(s.substring(idx - 600, idx + 400));
