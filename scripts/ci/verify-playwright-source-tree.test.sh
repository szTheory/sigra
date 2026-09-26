#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT/scripts/ci/verify-playwright-source-tree.sh"
TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

fail() { echo "verify-playwright-source-tree.test: FAIL: $*" >&2; exit 1; }

write_tree() {
  local root="$1" version="$2"
  mkdir -p "$root/src" "$root/test/example/priv/playwright"
  printf 'same source\n' > "$root/src/app.ex"
  printf '{"devDependencies":{"@playwright/test":"%s"}}\n' "$version" > \
    "$root/test/example/priv/playwright/package.json"
  printf '{"packages":{"":{"devDependencies":{"@playwright/test":"%s"}},"node_modules/@playwright/test":{"version":"%s","resolved":"https://registry.npmjs.org/@playwright/test/-/playwright-test-%s.tgz","integrity":"sha512-%s"},"node_modules/playwright":{"version":"%s","resolved":"https://registry.npmjs.org/playwright/-/playwright-%s.tgz","integrity":"sha512-%s"},"node_modules/playwright-core":{"version":"%s","resolved":"https://registry.npmjs.org/playwright-core/-/playwright-core-%s.tgz","integrity":"sha512-%s"}}}\n' \
    "$version" "$version" "$version" "$version" "$version" "$version" "$version" "$version" "$version" "$version" > \
    "$root/test/example/priv/playwright/package-lock.json"
}

run_guard() {
  local reference="$1" install="$2" version="$3"
  bash "$GUARD" "$reference" "$install" "$version" 2>&1
}

expect_failure() {
  local expected_path="$1" output="$2"
  [[ "$output" == *"$expected_path"* ]] || fail "expected diagnostic naming $expected_path, got: $output"
}

REFERENCE="$TMP_ROOT/reference"
BASELINE="$TMP_ROOT/baseline"
CANDIDATE="$TMP_ROOT/candidate"
write_tree "$REFERENCE" 1.62.1
cp -R "$REFERENCE" "$BASELINE"
cp -R "$REFERENCE" "$CANDIDATE"

# Only the selected Playwright trio may transform for the 1.59.1 install.
write_tree "$BASELINE" 1.59.1
if ! run_guard "$REFERENCE" "$BASELINE" 1.59.1 >/dev/null; then
  echo "not ok 1 - matching source roots allow the expected Playwright dependency transform"
  echo "  ---"
  echo "  expected: valid 1.59.1 trio and matching source inventory pass"
  echo "  actual: source-tree guard rejected the valid transform"
  echo "  ..."
  echo "1..1"
  exit 1
fi
run_guard "$REFERENCE" "$CANDIDATE" 1.62.1 >/dev/null || fail "matching candidate tree was rejected"

cp -R "$REFERENCE" "$TMP_ROOT/edited"
printf 'changed source\n' > "$TMP_ROOT/edited/src/app.ex"
output="$(run_guard "$REFERENCE" "$TMP_ROOT/edited" 1.62.1 || true)"
expect_failure src/app.ex "$output"

cp -R "$REFERENCE" "$TMP_ROOT/added"
printf 'untracked input\n' > "$TMP_ROOT/added/src/untracked.ex"
output="$(run_guard "$REFERENCE" "$TMP_ROOT/added" 1.62.1 || true)"
expect_failure src/untracked.ex "$output"

cp -R "$REFERENCE" "$TMP_ROOT/removed"
rm "$TMP_ROOT/removed/src/app.ex"
output="$(run_guard "$REFERENCE" "$TMP_ROOT/removed" 1.62.1 || true)"
expect_failure src/app.ex "$output"

cp -R "$REFERENCE" "$TMP_ROOT/changed-package"
node -e 'const fs=require("fs"); const p=process.argv[1]; const j=JSON.parse(fs.readFileSync(p)); j.description="unexpected"; fs.writeFileSync(p, JSON.stringify(j, null, 2)+"\n")' \
  "$TMP_ROOT/changed-package/test/example/priv/playwright/package.json"
output="$(run_guard "$REFERENCE" "$TMP_ROOT/changed-package" 1.62.1 || true)"
expect_failure test/example/priv/playwright/package.json "$output"

cp -R "$REFERENCE" "$TMP_ROOT/wrong-version"
node -e 'const fs=require("fs"); const p=process.argv[1]; const j=JSON.parse(fs.readFileSync(p)); j.packages["node_modules/playwright"].version="9.9.9"; fs.writeFileSync(p, JSON.stringify(j, null, 2)+"\n")' \
  "$TMP_ROOT/wrong-version/test/example/priv/playwright/package-lock.json"
output="$(run_guard "$REFERENCE" "$TMP_ROOT/wrong-version" 1.62.1 || true)"
expect_failure 'playwright version' "$output"

RUNNER="$ROOT/scripts/ci/run-playwright-drift.sh"
function_body() {
  local function_name="$1"
  awk -v function_name="$function_name" \
    '$0 ~ "^" function_name "\\(\\) \\{" { inside=1 } inside { print } inside && /^}/ { exit }' "$RUNNER"
}

assert_guard_follows_install() {
  local function_name="$1" body npm_line guard_line install_line
  body="$(function_body "$function_name")"
  [[ -n "$body" ]] || fail "runner wiring: missing $function_name function"
  npm_line="$(grep -n -m1 'npm ci' <<< "$body" | cut -d: -f1 || true)"
  guard_line="$(grep -n -m1 'verify-playwright-source-tree.sh' <<< "$body" | cut -d: -f1 || true)"
  install_line="$(grep -n -m1 'npx playwright' <<< "$body" | cut -d: -f1 || true)"
  [[ -n "$npm_line" ]] || fail "runner wiring: $function_name has no npm ci"
  [[ -n "$guard_line" ]] || fail "runner wiring: $function_name does not invoke the source-tree guard"
  [[ -n "$install_line" ]] || fail "runner wiring: $function_name has no subsequent Playwright command"
  (( guard_line == npm_line + 1 )) || fail "runner wiring: $function_name guard must immediately follow npm ci"
  (( guard_line < install_line )) || fail "runner wiring: $function_name reaches Playwright before the source-tree guard"
}

assert_guard_follows_install run_capture
assert_guard_follows_install prepare_system_dependencies
[[ "$(grep -c 'tar -xf - -C.*REFERENCE_TREE' "$RUNNER")" -eq 1 ]] || \
  fail "runner wiring: expected one immutable measured-SHA reference archive"
run_capture_body="$(function_body run_capture)"
guard_line="$(grep -n 'verify-playwright-source-tree.sh' <<< "$run_capture_body" | cut -d: -f1 || true)"
backup_line="$(grep -n '\.baseline-backup' <<< "$run_capture_body" | head -1 | cut -d: -f1 || true)"
[[ -n "$backup_line" && "$guard_line" -lt "$backup_line" ]] || \
  fail "runner wiring: snapshot backup must happen after the post-install guard"

echo "verify-playwright-source-tree.test: all source-tree fixtures passed"
