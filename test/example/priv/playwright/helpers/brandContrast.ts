// test-only: WCAG contrast helpers for computed CSS colours.
//
// Moved out of tests/admin-theme.spec.ts without a behaviour change so more
// than one spec can reuse them. Chromium reports computed colours as `rgb()`,
// `rgba()` or `oklab()` strings; `rgbChannels` normalises all three to
// 0..255 sRGB channels, and `contrastRatio` is the WCAG 2.x ratio.
//
// tests/demo-showcase.spec.ts keeps its own, differently shaped helpers.

export function rgbChannels(value: string): [number, number, number] {
  if (value.startsWith("oklab(")) {
    return oklabChannels(value);
  }

  const channels = value
    .match(/[\d.]+/g)
    ?.slice(0, 3)
    .map(Number);
  if (!channels || channels.length < 3) {
    throw new Error(`Expected a CSS rgb color, got ${value}`);
  }

  const rgb = channels.some((channel) => channel > 1)
    ? channels
    : channels.map((channel) => channel * 255);

  return [rgb[0], rgb[1], rgb[2]];
}

export function oklabChannels(value: string): [number, number, number] {
  const raw = value.match(/[-\d.]+%?/g)?.slice(0, 3);

  if (!raw || raw.length < 3) {
    throw new Error(`Expected a CSS oklab color, got ${value}`);
  }

  // Lightness may serialize as a percentage (e.g. "62.8%"); normalize to 0..1.
  const [lightness, a, b] = raw.map((token) =>
    token.endsWith("%") ? Number(token.slice(0, -1)) / 100 : Number(token),
  );

  const longL = lightness + 0.3963377774 * a + 0.2158037573 * b;
  const longM = lightness - 0.1055613458 * a - 0.0638541728 * b;
  const longS = lightness - 0.0894841775 * a - 1.291485548 * b;
  const l = longL ** 3;
  const m = longM ** 3;
  const s = longS ** 3;

  // Ottosson reference LMS→linear-sRGB matrix (each row sums to 1.0, so a
  // neutral OKLab color maps to neutral RGB). The previous constants summed to
  // 0.50/1.00/1.03 and turned white into cyan.
  return [
    linearSrgbToChannel(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    linearSrgbToChannel(
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    ),
    linearSrgbToChannel(-0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s),
  ];
}

function linearSrgbToChannel(value: number) {
  const bounded = Math.min(Math.max(value, 0), 1);
  const srgb =
    bounded <= 0.0031308
      ? 12.92 * bounded
      : 1.055 * bounded ** (1 / 2.4) - 0.055;

  return srgb * 255;
}

export function relativeLuminance([r, g, b]: [number, number, number]) {
  const [sr, sg, sb] = [r, g, b].map((channel) => {
    const value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });

  return 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
}

export function contrastRatio(foreground: string, background: string) {
  const foregroundLuminance = relativeLuminance(rgbChannels(foreground));
  const backgroundLuminance = relativeLuminance(rgbChannels(background));
  const lighter = Math.max(foregroundLuminance, backgroundLuminance);
  const darker = Math.min(foregroundLuminance, backgroundLuminance);

  return (lighter + 0.05) / (darker + 0.05);
}
