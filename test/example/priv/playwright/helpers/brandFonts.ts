// test-only: a font guard that cannot pass vacuously.
//
// The example self-hosts the brand book's two web faces in
// priv/static/assets/css/sigra_admin_brand.css, and links that stylesheet on
// every page. `document.fonts.check()` is vacuously true for a family that was
// never declared (there is nothing to load, so nothing is "not loaded"), and
// `document.fonts.ready` resolves at once when nothing has requested a face.
// So this guard forces the load of each face and then reads the FontFace
// entries themselves: a face that is undeclared, 404s, or fails to decode has
// no entry with status "loaded", and the failure names the face.

import { expect, type Page } from "@playwright/test";

export const BRAND_FONT_FAMILIES = ["Instrument Sans", "Red Hat Mono"] as const;

export interface FontFaceReport {
  family: string;
  status: string;
}

interface FontProbe {
  faces: FontFaceReport[];
  /** family to the rejection text, for a face whose load() rejected. */
  loadErrors: Record<string, string>;
}

/**
 * Asserts that both book faces (Instrument Sans and Red Hat Mono) are declared
 * on the page and have loaded.
 */
export async function assertBrandFontsLoaded(page: Page): Promise<void> {
  const probe: FontProbe = await page.evaluate(async () => {
    const loadErrors: Record<string, string> = {};
    const requests: [string, string][] = [
      ["Instrument Sans", '16px "Instrument Sans"'],
      ["Red Hat Mono", '13px "Red Hat Mono"'],
    ];

    // load() rejects when a declared face's file cannot be fetched or decoded.
    // Record that per face so the failure below names the face, rather than
    // surfacing as one anonymous evaluate() error.
    for (const [family, font] of requests) {
      try {
        await document.fonts.load(font);
      } catch (error) {
        loadErrors[family] = String(error);
      }
    }
    await document.fonts.ready;

    const faces: { family: string; status: string }[] = [];
    document.fonts.forEach((face) => {
      faces.push({ family: face.family, status: face.status });
    });
    return { faces, loadErrors };
  });

  for (const family of BRAND_FONT_FAMILIES) {
    const loaded = probe.faces.some(
      (face) => face.family.includes(family) && face.status === "loaded",
    );
    const seen =
      probe.faces.length === 0
        ? "no FontFace entries at all"
        : probe.faces.map((face) => `${face.family} (${face.status})`).join(", ");
    const loadError = probe.loadErrors[family]
      ? `; load() rejected: ${probe.loadErrors[family]}`
      : "";

    expect(
      loaded,
      `${family} must be declared and loaded (the book's self-hosted face)` +
        `${loadError}; document.fonts holds: ${seen}`,
    ).toBe(true);
  }
}
