#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_DIR="${PHASE244_ARTIFACT_DIR:-${RUNNER_TEMP:-/tmp}/phase-244-playwright-measurement}"
WORK_ROOT="${PHASE244_WORK_ROOT:-${RUNNER_TEMP:-/tmp}/phase-244-playwright-checkouts}"
SOURCE_SHA="${GITHUB_SHA:-}"
RUN_ID="${GITHUB_RUN_ID:-}"
BRANCH="${GITHUB_REF_NAME:-}"
SCOPE="${PHASE244_CAPTURE_SCOPE:-tracer}"

fail() {
  echo "run-playwright-drift: FAIL: $*" >&2
  exit 1
}

[[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "GITHUB_SHA must be a full commit SHA"
[[ "$RUN_ID" =~ ^[0-9]+$ ]] || fail "GITHUB_RUN_ID must be numeric"
[[ "$BRANCH" == phase-244/* ]] || fail "only phase-244/* evidence branches may run measurement"
[[ "$SCOPE" == tracer || "$SCOPE" == full ]] || fail "PHASE244_CAPTURE_SCOPE must be tracer or full"
command -v compare >/dev/null || fail "ImageMagick compare is not installed"
command -v identify >/dev/null || fail "ImageMagick identify is not installed"

mkdir -p "$ARTIFACT_DIR/logs" "$ARTIFACT_DIR/render-a" "$ARTIFACT_DIR/render-b" "$ARTIFACT_DIR/diffs" "$WORK_ROOT"
compare -version > "$ARTIFACT_DIR/comparator-version.txt" 2>&1
identify -version >> "$ARTIFACT_DIR/comparator-version.txt" 2>&1
imagemagick_package_version="$(dpkg-query -W -f='${Version}' imagemagick)"
[[ "$imagemagick_package_version" == '8:6.9.12.98+dfsg1-5.2build2' ]] || fail "expected Ubuntu ImageMagick package 8:6.9.12.98+dfsg1-5.2build2, got ${imagemagick_package_version}"
printf '\nimagemagick=%s\n' "$imagemagick_package_version" >> "$ARTIFACT_DIR/comparator-version.txt"

INVENTORY_JSON="$ARTIFACT_DIR/inventory.json"
node "$ROOT/scripts/ci/measure-playwright-drift.mjs" inventory --source-sha "$SOURCE_SHA" > "$INVENTORY_JSON"

run_capture() {
  local label="$1" output_root="$2" browser_root="$3" base_url="$4"
  local project
  mkdir -p "$output_root" "$browser_root" "$output_root/.baseline-backup" || return $?
  git -C "$ROOT" archive --format=tar "$SOURCE_SHA" | tar -xf - -C "$output_root" || return $?
  while IFS= read -r -d '' snapshot_dir; do
    mv "$snapshot_dir" "$output_root/.baseline-backup/" || return $?
  done < <(find "$output_root/test/example/priv/playwright/tests" -mindepth 1 -maxdepth 1 -type d -name '*-snapshots' -print0)

  local package_dir="$output_root/test/example/priv/playwright"
  (
    set -euo pipefail
    cd "$package_dir"
    npm ci
    local package_version
    package_version="$(node -p "require('./node_modules/@playwright/test/package.json').version")"
    [[ "$package_version" == 1.59.1 ]] || fail "expected locked Playwright 1.59.1, got $package_version"
    printf '%s\n' "$package_version" > "$ARTIFACT_DIR/logs/${label}-package-version.txt"
    if [[ "$SCOPE" == full ]]; then
      PLAYWRIGHT_BROWSERS_PATH="$browser_root" npx playwright install --with-deps chromium webkit
    else
      PLAYWRIGHT_BROWSERS_PATH="$browser_root" npx playwright install chromium
    fi
    if [[ "$SCOPE" == tracer ]]; then
      SIGRA_EXAMPLE_URL="$base_url" PLAYWRIGHT_BROWSERS_PATH="$browser_root" npx playwright test tests/admin-checkpoints.spec.ts \
        --project=admin-checkpoints-chromium --update-snapshots=all --retries=0
    else
      for project in admin-checkpoints-chromium admin-checkpoints-mobile admin-checkpoints-dark \
        admin-design-chromium admin-design-mobile admin-design-dark demo-showcase-chromium; do
        case "$project" in
          admin-checkpoints-*) spec=tests/admin-checkpoints.spec.ts ;;
          admin-design-*) spec=tests/admin-design.spec.ts ;;
          demo-showcase-*) spec=tests/demo-showcase.spec.ts ;;
        esac
        SIGRA_EXAMPLE_URL="$base_url" PLAYWRIGHT_BROWSERS_PATH="$browser_root" npx playwright test "$spec" \
          --project="$project" --update-snapshots=all --retries=0
      done
    fi
  ) >"$ARTIFACT_DIR/logs/${label}-capture.log" 2>&1 || return $?
}

capture_a="$WORK_ROOT/render-a"
capture_b="$WORK_ROOT/render-b"
set +e
run_capture render-a "$capture_a" "$WORK_ROOT/browsers" http://localhost:4001
capture_a_status=$?
run_capture render-b "$capture_b" "$WORK_ROOT/browsers" http://localhost:4002
capture_b_status=$?
set -e

revision_a="$(curl --fail --silent --show-error https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json | jq -er '.browsers[] | select(.name == "chromium") | .revision')"
revision_b="$(curl --fail --silent --show-error https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json | jq -er '.browsers[] | select(.name == "chromium") | .revision')"
node "$ROOT/scripts/ci/measure-playwright-drift.mjs" build-manifest \
  --source-sha "$SOURCE_SHA" --run-id "$RUN_ID" --branch "$BRANCH" --scope "$SCOPE" \
  --inventory-file "$INVENTORY_JSON" --render-a "$capture_a" \
  --render-b "$capture_b" --artifact-dir "$ARTIFACT_DIR" \
  --package-a "$(cat "$ARTIFACT_DIR/logs/render-a-package-version.txt")" \
  --package-b "$(cat "$ARTIFACT_DIR/logs/render-b-package-version.txt")" \
  --chromium-revision-a "$revision_a" --chromium-revision-b "$revision_b" \
  --expected-imagemagick-package '8:6.9.12.98+dfsg1-5.2build2' \
  --capture-status-a "${capture_a_status:-0}" --capture-status-b "${capture_b_status:-0}" \
  --comparator-version-file "$ARTIFACT_DIR/comparator-version.txt" --output "$ARTIFACT_DIR/measurement.json"

[[ "$capture_a_status" == 0 ]] || fail "render-a Playwright capture failed; inspect uploaded logs"
[[ "$capture_b_status" == 0 ]] || fail "render-b Playwright capture failed; inspect uploaded logs"

echo "Measurement completed for $SOURCE_SHA (run $RUN_ID); manifest: $ARTIFACT_DIR/measurement.json"
