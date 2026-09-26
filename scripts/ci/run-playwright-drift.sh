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
  local label="$1" output_root="$2" browser_root="$3" base_url="$4" expected_version="$5"
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
    printf '{"@playwright/test":"%s","playwright":"%s","playwright-core":"%s"}\n' "$expected_version" "$expected_version" "$expected_version" > "$ARTIFACT_DIR/logs/${label}-package-trio.json"
    printf 'unverified\n' > "$ARTIFACT_DIR/logs/${label}-package-trio-status.txt"
    if [[ "$expected_version" == 1.59.1 ]]; then
      npm install --package-lock-only --ignore-scripts --save-exact @playwright/test@1.59.1
    fi
    npm ci
    local package_version playwright_version core_version
    package_version="$(node -p "require('./node_modules/@playwright/test/package.json').version")"
    playwright_version="$(node -p "require('./node_modules/playwright/package.json').version")"
    core_version="$(node -p "require('./node_modules/playwright-core/package.json').version")"
    [[ "$package_version" == "$expected_version" && "$playwright_version" == "$expected_version" && "$core_version" == "$expected_version" ]] || fail "expected consistent Playwright trio $expected_version, got @playwright/test=$package_version playwright=$playwright_version playwright-core=$core_version"
    printf '{"@playwright/test":"%s","playwright":"%s","playwright-core":"%s"}\n' "$package_version" "$playwright_version" "$core_version" > "$ARTIFACT_DIR/logs/${label}-package-trio.json"
    printf 'verified\n' > "$ARTIFACT_DIR/logs/${label}-package-trio-status.txt"
    if [[ "$SCOPE" == full ]]; then
      PLAYWRIGHT_BROWSERS_PATH="$browser_root" npx playwright install chromium webkit
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
browser_a="$WORK_ROOT/browsers-1.59.1"
browser_b="$WORK_ROOT/browsers-1.62.1"
[[ "$browser_a" != "$browser_b" ]] || fail "version-specific browser cache roots must not alias"
set +e
run_capture render-a "$capture_a" "$browser_a" http://localhost:4001 1.59.1
capture_a_status=$?
run_capture render-b "$capture_b" "$browser_b" http://localhost:4002 1.62.1
capture_b_status=$?
set -e

for version in 1.59.1 1.62.1; do
  manifest="$ARTIFACT_DIR/${version}-browsers.json"
  if curl --fail --silent --show-error "https://raw.githubusercontent.com/microsoft/playwright/v${version}/packages/playwright-core/browsers.json" -o "$manifest" && \
     jq -e '.browsers[] | select(.name == "chromium") | {revision, browserVersion}' "$manifest" > "$ARTIFACT_DIR/${version}-chromium.json"; then
    sha256sum "$manifest" > "$ARTIFACT_DIR/${version}-browsers.sha256"
    printf 'verified\n' > "$ARTIFACT_DIR/${version}-browser-manifest-status.txt"
  else
    printf '{"revision":"unknown","browserVersion":"unknown"}\n' > "$ARTIFACT_DIR/${version}-chromium.json"
    printf '\n' > "$ARTIFACT_DIR/${version}-browsers.sha256"
    printf 'unverified\n' > "$ARTIFACT_DIR/${version}-browser-manifest-status.txt"
  fi
done
revision_a="$(jq -r '.revision' "$ARTIFACT_DIR/1.59.1-chromium.json")"
revision_b="$(jq -r '.revision' "$ARTIFACT_DIR/1.62.1-chromium.json")"
for spec in "render-a:1.59.1:$capture_a" "render-b:1.62.1:$capture_b"; do
  IFS=: read -r label version root <<< "$spec"
  if [[ "$(cat "$ARTIFACT_DIR/${version}-browser-manifest-status.txt")" == verified && "$(cat "$ARTIFACT_DIR/logs/${label}-package-trio-status.txt")" == verified ]]; then
    installed="$root/test/example/priv/playwright/node_modules/playwright-core/browsers.json"
    expected="$ARTIFACT_DIR/${version}-chromium.json"
    installed_revision="$(jq -er '.browsers[] | select(.name == "chromium") | .revision' "$installed")"
    installed_browser_version="$(jq -er '.browsers[] | select(.name == "chromium") | .browserVersion' "$installed")"
    [[ "$installed_revision" == "$(jq -er '.revision' "$expected")" ]] || fail "$label installed Chromium revision does not match tagged browsers.json"
    [[ "$installed_browser_version" == "$(jq -er '.browserVersion' "$expected")" ]] || fail "$label installed Chromium version does not match tagged browsers.json"
  fi
done
node "$ROOT/scripts/ci/measure-playwright-drift.mjs" build-manifest \
  --source-sha "$SOURCE_SHA" --run-id "$RUN_ID" --branch "$BRANCH" --scope "$SCOPE" \
  --inventory-file "$INVENTORY_JSON" --render-a "$capture_a" \
  --render-b "$capture_b" --artifact-dir "$ARTIFACT_DIR" \
  --package-a '1.59.1' --package-b '1.62.1' \
  --package-trio-a "$(cat "$ARTIFACT_DIR/logs/render-a-package-trio.json")" \
  --package-trio-b "$(cat "$ARTIFACT_DIR/logs/render-b-package-trio.json")" \
  --chromium-revision-a "$revision_a" --chromium-revision-b "$revision_b" \
  --chromium-version-a "$(jq -er '.browserVersion' "$ARTIFACT_DIR/1.59.1-chromium.json")" \
  --chromium-version-b "$(jq -er '.browserVersion' "$ARTIFACT_DIR/1.62.1-chromium.json")" \
  --browser-manifest-url-a 'https://raw.githubusercontent.com/microsoft/playwright/v1.59.1/packages/playwright-core/browsers.json' \
  --browser-manifest-url-b 'https://raw.githubusercontent.com/microsoft/playwright/v1.62.1/packages/playwright-core/browsers.json' \
  --browser-manifest-sha-a "$(awk '{print $1}' "$ARTIFACT_DIR/1.59.1-browsers.sha256")" \
  --browser-manifest-sha-b "$(awk '{print $1}' "$ARTIFACT_DIR/1.62.1-browsers.sha256")" \
  --package-trio-status-a "$(cat "$ARTIFACT_DIR/logs/render-a-package-trio-status.txt")" \
  --package-trio-status-b "$(cat "$ARTIFACT_DIR/logs/render-b-package-trio-status.txt")" \
  --browser-manifest-status-a "$(cat "$ARTIFACT_DIR/1.59.1-browser-manifest-status.txt")" \
  --browser-manifest-status-b "$(cat "$ARTIFACT_DIR/1.62.1-browser-manifest-status.txt")" \
  --runner-image "${RUNNER_IMAGE:-unknown}" \
  --artifact-identifier "${PHASE244_ARTIFACT_NAME:-phase-244-playwright-measurement-${RUN_ID}}" \
  --run-url "${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-szTheory/sigra}/actions/runs/${RUN_ID}" \
  --expected-imagemagick-package '8:6.9.12.98+dfsg1-5.2build2' \
  --capture-status-a "${capture_a_status:-0}" --capture-status-b "${capture_b_status:-0}" \
  --comparator-version-file "$ARTIFACT_DIR/comparator-version.txt" --output "$ARTIFACT_DIR/measurement.json"

[[ "$capture_a_status" == 0 ]] || fail "render-a Playwright capture failed; inspect uploaded logs"
[[ "$capture_b_status" == 0 ]] || fail "render-b Playwright capture failed; inspect uploaded logs"

echo "Measurement completed for $SOURCE_SHA (run $RUN_ID); manifest: $ARTIFACT_DIR/measurement.json"
