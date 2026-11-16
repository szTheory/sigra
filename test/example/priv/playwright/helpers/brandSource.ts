// test-only: read the expected value of a brand token from its source.
//
// A Playwright pin that keeps its own literal copy of a token value goes stale
// the next time the token moves, and a pin that reads nothing passes
// vacuously. These helpers read the expected value at test time from the two
// sources of truth (the shipped template stylesheet, and the brand book's
// brand/tokens.json) and throw when they cannot find it, so an unreadable
// source is a red test and never a green one.
//
// Nothing is read at import time: every read happens inside a call, so merely
// listing the specs (`playwright test --list`) touches no file.

import { existsSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

export type Theme = "light" | "dark";

export interface TemplateTokens {
  /** Declarations of the light `:root` block, token name to declared value. */
  root: Record<string, string>;
  /** Declarations of the `:root` block inside `@media (prefers-color-scheme: dark)`. */
  dark: Record<string, string>;
}

export interface BrandColorToken {
  $value: { hex: string };
  $description?: string;
}

export interface BrandTokens {
  color: {
    light: Record<string, BrandColorToken>;
    dark: Record<string, BrandColorToken>;
    [group: string]: Record<string, BrandColorToken>;
  };
  [group: string]: unknown;
}

const TEMPLATE_STYLESHEET = join(
  "priv",
  "templates",
  "sigra.install",
  "admin",
  "sigra_admin.css",
);

/**
 * The repository root. This file lives in
 * test/example/priv/playwright/helpers, five levels below it.
 */
export function repoRoot(): string {
  const root = resolve(__dirname, "..", "..", "..", "..", "..");
  if (!existsSync(join(root, "brand", "tokens.json"))) {
    throw new Error(
      `repoRoot() resolved to ${root}, which has no brand/tokens.json; ` +
        "the helpers directory moved relative to the repository root",
    );
  }
  return root;
}

function stripComments(css: string): string {
  return css.replace(/\/\*[\s\S]*?\*\//g, "");
}

/** Index of the `}` that closes the `{` at `open`, or -1 when unbalanced. */
function matchingBrace(css: string, open: number): number {
  let depth = 0;
  for (let i = open; i < css.length; i += 1) {
    if (css[i] === "{") depth += 1;
    if (css[i] === "}") {
      depth -= 1;
      if (depth === 0) return i;
    }
  }
  return -1;
}

/**
 * The body of the first block at brace depth 0 whose prelude matches
 * `prelude`, or null. A depth-0 scan, so a `:root` nested in an `@media` or an
 * `@layer` is never mistaken for the top-level one.
 */
function topLevelBlockBody(css: string, prelude: RegExp): string | null {
  let depth = 0;
  let preludeStart = 0;
  for (let i = 0; i < css.length; i += 1) {
    const char = css[i];
    if (char === "{") {
      if (depth === 0 && prelude.test(css.slice(preludeStart, i).trim())) {
        const close = matchingBrace(css, i);
        return close === -1 ? null : css.slice(i + 1, close);
      }
      depth += 1;
    } else if (char === "}") {
      depth -= 1;
      if (depth === 0) preludeStart = i + 1;
    } else if (char === ";" && depth === 0) {
      preludeStart = i + 1;
    }
  }
  return null;
}

function declarations(body: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const match of body.matchAll(/(--[A-Za-z0-9_-]+)\s*:\s*([^;]+);/g)) {
    out[match[1]] = match[2].replace(/\s+/g, " ").trim();
  }
  return out;
}

/**
 * The `--sg-*` declarations of the shipped template stylesheet: the first
 * top-level `:root` block (light) and the `:root` block inside the top-level
 * `@media (prefers-color-scheme: dark)` block (dark). Whitespace in a value is
 * collapsed, so a value that wraps over several lines reads as one line.
 *
 * Throws when either block cannot be found or declares nothing.
 */
export function readTemplateTokens(): TemplateTokens {
  const path = join(repoRoot(), TEMPLATE_STYLESHEET);
  const css = stripComments(readFileSync(path, "utf8"));

  const rootBody = topLevelBlockBody(css, /^:root$/);
  const darkMedia = topLevelBlockBody(
    css,
    /^@media\s*\(\s*prefers-color-scheme\s*:\s*dark\s*\)$/,
  );
  const darkBody = darkMedia ? topLevelBlockBody(darkMedia, /^:root$/) : null;

  const root = rootBody ? declarations(rootBody) : {};
  const dark = darkBody ? declarations(darkBody) : {};

  if (Object.keys(root).length === 0) {
    throw new Error(`No light :root token declarations found in ${path}`);
  }
  if (Object.keys(dark).length === 0) {
    throw new Error(
      `No dark :root token declarations found under ` +
        `@media (prefers-color-scheme: dark) in ${path}`,
    );
  }

  return { root, dark };
}

/**
 * The declared value of a token as shown in `theme`: the dark block's value
 * when the theme is dark and the token is declared there, otherwise the light
 * `:root` value (a token that never changes between themes is declared once).
 *
 * Throws, naming the token, when neither block declares it: a pin that cannot
 * read its source must fail, not pass.
 */
export function tokenValue(theme: Theme, name: string): string {
  const tokens = readTemplateTokens();
  const value =
    theme === "dark" && name in tokens.dark
      ? tokens.dark[name]
      : tokens.root[name];

  if (value === undefined) {
    throw new Error(
      `Token ${name} is not declared in the ${theme} token blocks of ` +
        `${TEMPLATE_STYLESHEET}`,
    );
  }

  return value;
}

/** brand/tokens.json, parsed. Read at call time. */
export function brandTokensJson(): BrandTokens {
  const path = join(repoRoot(), "brand", "tokens.json");
  return JSON.parse(readFileSync(path, "utf8")) as BrandTokens;
}

/** `#RRGGBB` (either case) to the `rgb(r, g, b)` string Chromium computes. */
export function hexToRgbString(hex: string): string {
  const match = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex.trim());
  if (!match) {
    throw new Error(`Expected a #RRGGBB colour, got ${JSON.stringify(hex)}`);
  }
  const [r, g, b] = [match[1], match[2], match[3]].map((pair) =>
    parseInt(pair, 16),
  );
  return `rgb(${r}, ${g}, ${b})`;
}
