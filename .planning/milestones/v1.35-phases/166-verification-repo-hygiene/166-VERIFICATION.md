# Phase 166 Verification

**Status:** passed

Final verification commands run after the last `brandbook/` edit:

- `jq . brandbook/tokens.json` -> `tokens.json: OK`
- `find brandbook -maxdepth 2 -name '*.svg' -print0 | xargs -0 -n1 xmllint --noout` -> `svg xml: OK`
- Python `HTMLParser().feed(Path('brandbook/index.html').read_text())` -> `index.html html.parser: OK`
- `find brandbook -type f -size +250k -print; du -sh brandbook` -> no files over 250K, `132K brandbook`
- Playwright + axe smoke through a temporary local HTTP server:
  - desktop 1440x1200: `OK (9 sections, 10 images, axe 0, body 1440/1440)`
  - mobile 390x1200: `OK (9 sections, 10 images, axe 0, body 390/390)`

Screenshots from the final smoke were written outside the repo at:

- `/tmp/sigra-brandbook-desktop.png`
- `/tmp/sigra-brandbook-mobile.png`
