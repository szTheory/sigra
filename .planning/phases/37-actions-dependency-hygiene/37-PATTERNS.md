# Phase 37 — Pattern map

## SHA + version comment (canonical)

From `.github/workflows/ci.yml`:

```yaml
- uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5  # v4.3.1
```

**Rule:** Full 40-char lowercase hex + one space + `# vMAJOR.MINOR.PATCH` aligned with the tag the SHA points to (impostor-commit hygiene).

## Permissions default

`ci.yml` sets top-level `permissions: contents: read`; jobs that publish artifacts or Pages keep explicit job-level overrides — preserve when touching workflows.

## Matrix / injection hardening

`install_matrix` uses `MATRIX_FLAGS: ${{ matrix.flags }}` env indirection — unrelated to action bumps; do not regress.

## Analog files

| Role | Path |
|------|------|
| Primary CI | `.github/workflows/ci.yml` |
| Pages publish | `.github/workflows/playwright-github-pages.yml` |
| Dependabot config | `.github/dependabot.yml` |
