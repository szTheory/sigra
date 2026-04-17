#!/usr/bin/env bash
# Assemble a static tree for GitHub Pages: one folder per run under runs/,
# each containing playwright-report/ and test-results/ (videos, traces).
#
# Merges existing runs/ from the remote gh-pages branch (when present), adds
# the current run, then drops run folders whose YYYYMMDD- prefix is older than
# RETENTION_DAYS (default 7). Writes index.html at the site root.
#
# Env:
#   PW_ROOT          — absolute path to test/example/priv/playwright (required)
#   SITE_ROOT        — output directory (default: $GITHUB_WORKSPACE/_sigra_playwright_site)
#   RETENTION_DAYS   — default 7
#   RUN_SLUG         — default ${RUN_DATE}-${GITHUB_RUN_ID}; must start with YYYYMMDD-
#   GITHUB_WORKSPACE — used for SITE_ROOT default
#   GITHUB_REPOSITORY, GITHUB_TOKEN — optional; when set, merge runs from origin gh-pages

set -euo pipefail

PW_ROOT="${PW_ROOT:?PW_ROOT is required}"
SITE_ROOT="${SITE_ROOT:-${GITHUB_WORKSPACE:-$(pwd)}/_sigra_playwright_site}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
RUN_DATE="${RUN_DATE:-$(date -u +%Y%m%d)}"
RUN_SLUG="${RUN_SLUG:-${RUN_DATE}-${GITHUB_RUN_ID:-local}}"

if [[ ! -f "$PW_ROOT/playwright-report/index.html" ]]; then
  echo "assemble-playwright-gh-pages-site: missing $PW_ROOT/playwright-report/index.html" >&2
  exit 1
fi

rm -rf "$SITE_ROOT"
mkdir -p "$SITE_ROOT/runs"

merge_remote_runs() {
  if [[ -z "${GITHUB_REPOSITORY:-}" || -z "${GITHUB_TOKEN:-}" ]]; then
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  if git clone --depth=1 --branch=gh-pages "https://x-access-token:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY}.git" "$tmp/repo" 2>/dev/null; then
    if [[ -d "$tmp/repo/runs" ]]; then
      shopt -s dotglob nullglob
      local e
      for e in "$tmp/repo/runs"/*; do
        [[ -d "$e" ]] || continue
        cp -a "$e" "$SITE_ROOT/runs/"
      done
      shopt -u dotglob nullglob
    fi
  fi
  rm -rf "$tmp"
}

merge_remote_runs

mkdir -p "$SITE_ROOT/runs/$RUN_SLUG"
cp -a "$PW_ROOT/playwright-report" "$SITE_ROOT/runs/$RUN_SLUG/"
if [[ -d "$PW_ROOT/test-results" ]]; then
  cp -a "$PW_ROOT/test-results" "$SITE_ROOT/runs/$RUN_SLUG/"
fi
if [[ -d "$PW_ROOT/artifacts/admin-checkpoints" ]]; then
  mkdir -p "$SITE_ROOT/runs/$RUN_SLUG/artifacts/admin-checkpoints"
  shopt -s nullglob
  for _f in "$PW_ROOT/artifacts/admin-checkpoints"/*; do
    cp -a "$_f" "$SITE_ROOT/runs/$RUN_SLUG/artifacts/admin-checkpoints/"
  done
  shopt -u nullglob
fi

# Portable "N days ago" as YYYYMMDD (GNU date and BSD date differ).
cutoff="$(python3 -c "from datetime import datetime, timedelta, timezone; print((datetime.now(timezone.utc) - timedelta(days=int(\"${RETENTION_DAYS}\"))).strftime(\"%Y%m%d\"))")"
shopt -s nullglob
for d in "$SITE_ROOT/runs"/*/; do
  [[ -d "$d" ]] || continue
  base="$(basename "$d")"
  if [[ "$base" =~ ^([0-9]{8})- ]]; then
    day="${BASH_REMATCH[1]}"
    if [[ "$day" < "$cutoff" ]]; then
      rm -rf "$d"
    fi
  fi
done
shopt -u nullglob

{
  echo '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
  echo '<title>Sigra Playwright reports</title>'
  echo '<style>body{font-family:system-ui,sans-serif;max-width:56rem;margin:2rem auto;line-height:1.45;padding:0 1rem}'
  echo 'code{background:#f6f8fa;padding:0 .2em;border-radius:4px}a{color:#0969da}</style></head><body>'
  echo '<h1>Sigra Playwright browser reports</h1>'
  echo '<p>Browse the HTML report per run (includes screenshots and, when enabled, <strong>videos</strong> under attachments). Each run folder keeps <code>playwright-report/</code> and <code>test-results/</code> side by side so relative links resolve.</p>'
  echo '<ul>'
  mapfile -t runs < <(ls -1 "$SITE_ROOT/runs" 2>/dev/null | sort -r)
  if [[ ${#runs[@]} -eq 0 ]]; then
    echo '  <li>(no runs)</li>'
  else
    for slug in "${runs[@]}"; do
      echo "  <li><a href=\"runs/${slug}/playwright-report/index.html\">${slug}</a></li>"
    done
  fi
  echo '</ul>'
  echo "<p><small>Runs with a <code>YYYYMMDD-</code> prefix older than ${RETENTION_DAYS} days are removed on each publish. Site is updated from GitHub Actions.</small></p>"
  echo '</body></html>'
} >"$SITE_ROOT/index.html"

echo "assemble-playwright-gh-pages-site: wrote $SITE_ROOT ($(du -sh "$SITE_ROOT" | cut -f1))"
