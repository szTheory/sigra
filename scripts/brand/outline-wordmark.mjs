#!/usr/bin/env node
// Phase 179 (BRAND2-04): Outline OFL font glyphs for "sigra" into per-glyph SVG <path> elements.
//
// Usage: node scripts/brand/outline-wordmark.mjs <font.ttf> <wght> <output.svg>
// Run from repo root. Font must be in scripts/brand/fonts/ (gitignored). Run npm install in scripts/brand/ first.
//
// CRITICAL: Always use .toPathData({ decimalPlaces: 2 }) — the object form.
// Never use .toPathData(2) — the integer shorthand sets flipY: false in opentype.js v2.0 → upside-down wordmark.

import { createRequire } from 'module';
import { writeFileSync, readFileSync } from 'fs';

const require = createRequire(import.meta.url);
const opentype = require('opentype.js');

const [, , fontPath, wghtStr, outPath] = process.argv;

if (!fontPath || !wghtStr || !outPath) {
  console.error('Usage: node scripts/brand/outline-wordmark.mjs <font.ttf> <wght> <output.svg>');
  console.error('Example: node scripts/brand/outline-wordmark.mjs scripts/brand/fonts/SpaceGrotesk[wght].ttf 700 /tmp/sigra-sg.svg');
  process.exit(1);
}

const wght = Number(wghtStr) || 700;

// Load font and set variable weight axis.
// opentype.js v2.0 deprecated loadSync for the Node.js file:// path form.
// Use opentype.parse(readFileSync(path).buffer) — the recommended path for Node CLI scripts.
const fontBuffer = readFileSync(fontPath);
const font = opentype.parse(fontBuffer.buffer);
if (font.variation) {
  font.variation.set({ wght });
} else {
  console.warn(`Warning: ${fontPath} is not a variable font (no fvar table). Using default weight.`);
}

// Work at font's native unitsPerEm (1000 or 2048 UPM) for maximum path precision.
// Scale via SVG viewBox, not by using a small pixel fontSize.
const fontSize = font.unitsPerEm;

// Collect per-glyph paths via forEachGlyph with kerning enabled.
// Pass y = fontSize as the baseline so all paths have positive Y values after the default flipY: true flip.
const paths = [];
let totalWidth = 0;

// Some variable fonts (e.g. Inter) have CCMP lookup tables with subtable formats not yet
// supported by opentype.js 2.0.0. If forEachGlyph throws, fall back to direct charToGlyphIndex
// iteration which bypasses the GSUB/Bidi processing layer entirely.
try {
  font.forEachGlyph('sigra', 0, fontSize, fontSize, { kerning: true }, (glyph, x, y) => {
    // ALWAYS use the object form { decimalPlaces: 2 } — inherits flipY: true (the default in opentype.js v2.0).
    // NEVER use .toPathData(2) — the integer shorthand explicitly sets flipY: false in v2.0 → upside-down output.
    // CRITICAL: pass `font` as the 5th getPath argument — glyph.getPath only applies the
    // font.variation axis coordinates (set above) when it receives the font object. Without it,
    // every weight renders at the variable font's default (lightest) master. Passing font also
    // hvar-adjusts glyph.advanceWidth in place BEFORE forEachGlyph advances x, so letter spacing
    // matches the instanced weight.
    const d = glyph.getPath(x, y, fontSize, {}, font).toPathData({ decimalPlaces: 2 });
    paths.push(`<path id="g-${paths.length}" d="${d}" />`);
    totalWidth = x + (glyph.advanceWidth || 0) * (fontSize / font.unitsPerEm);
  });
} catch (err) {
  // Fallback: iterate glyphs directly by character index, applying manual kern table lookups.
  // This skips the GSUB/Bidi layer (CCMP, liga, calt) which opentype.js may not fully support
  // for certain variable font configurations. For the 5-letter string "sigra", no ligatures apply.
  console.warn(`Warning: forEachGlyph threw (${err.message.split('\n')[0]}); falling back to direct glyph iteration.`);
  const text = 'sigra';
  let xPos = 0;
  for (let i = 0; i < text.length; i++) {
    const glyphIndex = font.charToGlyphIndex(text[i]);
    const glyph = font.glyphs.get(glyphIndex);
    // Pass `font` so the variation axis coordinates are applied (see note above) and
    // glyph.advanceWidth is hvar-adjusted before we read it below.
    const d = glyph.getPath(xPos, fontSize, fontSize, {}, font).toPathData({ decimalPlaces: 2 });
    paths.push(`<path id="g-${i}" d="${d}" />`);
    const advance = (glyph.advanceWidth || 0) * (fontSize / font.unitsPerEm);
    if (i < text.length - 1) {
      const nextIndex = font.charToGlyphIndex(text[i + 1]);
      const kernVal = font.getKerningValue(glyph, font.glyphs.get(nextIndex));
      xPos += advance + kernVal * (fontSize / font.unitsPerEm);
    } else {
      xPos += advance;
    }
    totalWidth = xPos;
  }
}

// Compute viewBox with 5% padding on each side.
// vbX is negative so the left glyph stroke edge isn't clipped.
const vbPad = fontSize * 0.05;
const vbX = -vbPad;
const vbW = totalWidth + vbPad * 2;
// Cap-height (approx 0.75 × UPM) plus descender room (approx 0.3 × UPM) gives 1.05 × UPM.
// Use 1.3 × UPM for comfortable descender room + overflow for motif modifications.
const vbH = fontSize * 1.3;

// Use font's embedded metadata for the provenance desc.
const fontName = font.getEnglishName('fullName') || font.getEnglishName('postScriptName') || fontPath;
const provenance = `Font: ${fontName} wght=${wght}. OFL licensed. Outlined with opentype.js 2.0.0. Generated ${new Date().toISOString().slice(0, 10)}.`;

// Build SVG with accessibility shell pattern from brandbook/logo-primary.svg.
// Use fill="currentColor" on the glyph group so dark-mode SVGs inherit correctly via CSS.
const svg = `<svg xmlns="http://www.w3.org/2000/svg"
  viewBox="${vbX.toFixed(0)} 0 ${vbW.toFixed(0)} ${vbH.toFixed(0)}"
  role="img"
  aria-labelledby="title desc"
>
  <title id="title">sigra wordmark outline</title>
  <desc id="desc">${provenance}</desc>
  <g id="glyphs" fill="currentColor">
${paths.map((p) => '    ' + p).join('\n')}
  </g>
</svg>`;

writeFileSync(outPath, svg);
console.log(`Wrote ${outPath} (${paths.length} glyphs, width ≈ ${totalWidth.toFixed(0)} UPM)`);
