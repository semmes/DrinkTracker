#!/usr/bin/env node
// Renders Tallyist's App Store creative assets from banner.html, exports them
// the way App Store Connect takes them, and checks them. See README.md.
//
//   node render.js                      all six assets into ./out
//   node render.js --out DIR            somewhere else
//   node render.js --theme dark         one appearance (dark | light)
//   node render.js --fmt search         one placement (universal | header | search)
//   node render.js --guides             draw the safe area and the 4% inset (proofs only)
//
// Needs Node 18+ and Playwright with a Chromium: `npm i -g playwright` and
// `npx playwright install chromium`. A global install is found through
// `npm root -g`; PLAYWRIGHT_MODULE, a path to the module, overrides it.
// Exits 1 if any check fails.

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = (name, fallback) => { const i = args.indexOf('--' + name); return i >= 0 ? args[i + 1] : fallback; };
const OUT = path.resolve(opt('out', path.join(__dirname, 'out')));
const THEMES = (opt('theme', 'all') === 'all' ? ['dark', 'light'] : [opt('theme')]);
const FORMATS = (opt('fmt', 'all') === 'all' ? ['header', 'search', 'universal'] : [opt('fmt')]);
const GUIDES = args.includes('--guides');

const SIZES = { universal: [5244, 2950], header: [3840, 1646], search: [3840, 2560] };
const NAMES = { universal: 'universal', header: 'header', search: 'search-results' };

function globalModule(name) {
  try { return path.join(require('child_process').execSync('npm root -g', { encoding: 'utf8' }).trim(), name); }
  catch (e) { return null; }
}
let playwright;
for (const candidate of [process.env.PLAYWRIGHT_MODULE, 'playwright', globalModule('playwright')].filter(Boolean)) {
  try { playwright = require(candidate); break; } catch (e) { /* next */ }
}
if (!playwright) { console.error('Playwright not found: `npm i -g playwright`, or set PLAYWRIGHT_MODULE.'); process.exit(1); }

// --- PNG: assert 8-bit RGB with no alpha, and add an sRGB chunk after IHDR ---
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
function crc32(buf) { let c = -1; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function chunk(type, data) {
  const t = Buffer.from(type, 'ascii'), len = Buffer.alloc(4), crc = Buffer.alloc(4);
  len.writeUInt32BE(data.length); crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
function finishPNG(buf, [w, h]) {
  const ihdr = { w: buf.readUInt32BE(16), h: buf.readUInt32BE(20), depth: buf[24], colour: buf[25] };
  const problems = [];
  if (ihdr.w !== w || ihdr.h !== h) problems.push(`size ${ihdr.w}x${ihdr.h}, expected ${w}x${h}`);
  if (ihdr.depth !== 8 || ihdr.colour !== 2) problems.push(`bit depth ${ihdr.depth}, colour type ${ihdr.colour} (want 8-bit RGB, no alpha)`);
  const types = []; for (let i = 8; i < buf.length;) { const n = buf.readUInt32BE(i); types.push(buf.toString('ascii', i + 4, i + 8)); i += 12 + n; }
  if (types.includes('tRNS')) problems.push('has a tRNS (transparency) chunk');
  const out = types.includes('sRGB') ? buf : Buffer.concat([buf.subarray(0, 33), chunk('sRGB', Buffer.from([0])), buf.subarray(33)]);
  return { out, problems };
}

// --- The code points a font maps, from its Windows Unicode cmap (format 4) ---
// banner.html lists the code points its fonts cover (COVERED) and stops on a
// headline character outside them; this checks that list against the fonts
// themselves, so a new subset cannot leave it stale.
const FONTS = ['InterDisplay-Bold.otf', 'Inter-Medium.otf'];
function cmapRanges(file) {
  const b = fs.readFileSync(file);
  let cmap, sub;
  for (let i = 0, n = b.readUInt16BE(4); i < n; i++)
    if (b.toString('ascii', 12 + 16 * i, 16 + 16 * i) === 'cmap') cmap = b.readUInt32BE(20 + 16 * i);
  for (let i = 0, n = cmap === undefined ? 0 : b.readUInt16BE(cmap + 2); i < n; i++) {
    const rec = cmap + 4 + 8 * i;
    if (b.readUInt16BE(rec) === 3 && b.readUInt16BE(rec + 2) === 1) sub = cmap + b.readUInt32BE(rec + 4);
  }
  if (sub === undefined || b.readUInt16BE(sub) !== 4) throw new Error(`${path.basename(file)} has no format 4 Unicode cmap`);
  const segs = b.readUInt16BE(sub + 6) / 2;
  const ends = sub + 14, starts = ends + 2 * segs + 2, deltas = starts + 2 * segs, offsets = deltas + 2 * segs;
  const ranges = [];
  for (let s = 0; s < segs; s++) {
    const start = b.readUInt16BE(starts + 2 * s), end = b.readUInt16BE(ends + 2 * s);
    const delta = b.readUInt16BE(deltas + 2 * s), ro = b.readUInt16BE(offsets + 2 * s);
    for (let c = start; c <= end && c !== 0xFFFF; c++) {
      const indexed = ro === 0 ? c : b.readUInt16BE(offsets + 2 * s + ro + 2 * (c - start));
      const glyph = ro !== 0 && indexed === 0 ? 0 : (indexed + delta) & 0xFFFF;
      if (glyph === 0) continue;   // .notdef: not covered
      const last = ranges[ranges.length - 1];
      if (last && c === last[1] + 1) last[1] = c; else ranges.push([c, c]);
    }
  }
  return ranges;
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await playwright.chromium.launch({
    args: ['--force-color-profile=srgb', '--disable-lcd-text', '--font-render-hinting=none'],
  });
  const rows = [];
  let failed = false, coverageChecked = false;
  for (const theme of THEMES) for (const fmt of FORMATS) {
    const [w, h] = SIZES[fmt];
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    page.on('pageerror', e => console.error('page error:', String(e)));
    const url = 'file://' + path.join(__dirname, 'banner.html') + `?fmt=${fmt}&theme=${theme}${GUIDES ? '&guides=1' : ''}`;
    await page.goto(url);
    await page.waitForFunction('window.__done === true', null, { timeout: 180000 });
    if (!coverageChecked) {
      coverageChecked = true;
      const listed = JSON.stringify(await page.evaluate('COVERED'));
      const hex = n => '0x' + n.toString(16).toUpperCase();
      for (const font of FONTS) {
        const ranges = cmapRanges(path.join(__dirname, 'fonts', font));
        if (JSON.stringify(ranges) === listed) continue;
        console.error(`COVERED in banner.html is not fonts/${font}'s character map, which is ${ranges.map(([a, b]) => `[${hex(a)}, ${hex(b)}]`).join(', ')}`);
        failed = true;
      }
    }
    const error = await page.evaluate('window.__error');
    if (error) { console.error(`${theme}/${fmt}: ${error}`); failed = true; await page.close(); continue; }
    const r = await page.evaluate('window.__report');
    const { out, problems } = finishPNG(await page.screenshot({ type: 'png' }), [w, h]);
    await page.close();
    const file = path.join(OUT, `tallyist-${NAMES[fmt]}${theme === 'light' ? '-light' : ''}-${w}x${h}${GUIDES ? '-guides' : ''}.png`);
    fs.writeFileSync(file, out);
    // Key elements sit 4% inside the safe area. The universal's month starts
    // below it on purpose.
    if (!r.headlineInset) problems.push('headline not 4% inside the safe area');
    if (!r.counterInset) problems.push('counter not 4% inside the safe area');
    if (!r.monthInset && fmt !== 'universal') problems.push('month not 4% inside the safe area');
    // The headline holds 4.5:1, the bar the design system sets for accent text,
    // against every pixel behind it. The count and the ＋ are parts of the drawn
    // counter, a picture of the app's interface, and are held to 3:1, the bar
    // for graphics. The count's pair is the app's own: in the light set, white
    // on 450 is 4.42:1, which the app's 68pt numeral carries as large text but
    // which falls short of 4.5:1 for text at the 12 to 15 points the art's
    // numeral shows at on an iPhone (README.md, "What render.js checks").
    const bars = { headlineContrast: 4.5, tintedWordContrast: 4.5, countContrast: 3, plusContrast: 3 };
    for (const [k, bar] of Object.entries(bars))
      if (r[k] < bar) problems.push(`${k} ${r[k]}:1 is under ${bar}:1`);
    if (problems.length) failed = true;
    rows.push({ file: path.relative(process.cwd(), file), ...r, problems });
  }
  await browser.close();
  for (const r of rows) {
    console.log(`${r.problems.length ? 'FAIL' : 'ok  '} ${r.file}`);
    console.log(`     4% inside the safe area: headline ${r.headlineInset}, counter ${r.counterInset}, month ${r.monthInset}` +
      ` · contrast: headline ${r.headlineContrast}:1, tinted word ${r.tintedWordContrast}:1, count ${r.countContrast}:1, plus ${r.plusContrast}:1`);
    for (const p of r.problems) console.log('     - ' + p);
  }
  process.exit(failed ? 1 : 0);
})();
