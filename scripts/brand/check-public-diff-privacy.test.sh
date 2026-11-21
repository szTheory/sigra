#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/check-public-diff-privacy.pl"
ACCOUNT="$(id -un)"
TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-public-privacy.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

fail() {
  printf 'privacy integration test failed: %s\n' "$1" >&2
  exit 1
}

begin_case() {
  local name="$1"
  local git_name="${2:-Fixture Reviewer}"
  REPO="$TEMP_ROOT/$name"
  SYNTHETIC_HOME="$TEMP_ROOT/home-$name"
  mkdir -p "$REPO/brand" "$SYNTHETIC_HOME"
  git -C "$REPO" init -q
  git -C "$REPO" config user.name "$git_name"
  git -C "$REPO" config user.email 'reviewer@example.test'
  cat > "$REPO/brand/index.html" <<'HTML'
<!doctype html>
<a href="https://brand.example.test/">Brand</a>
HTML
  git -C "$REPO" add brand/index.html
  git -C "$REPO" commit -qm 'privacy fixture base'
  BASE="$(git -C "$REPO" rev-parse HEAD)"
}

add_line() {
  local path="$1"
  local line="$2"
  mkdir -p "$REPO/$(dirname -- "$path")"
  printf '%s\n' "$line" >> "$REPO/$path"
  git -C "$REPO" add -- "$path"
}

run_guard() {
  (
    cd "$REPO"
    HOME="$SYNTHETIC_HOME" perl "$GUARD" "$BASE" "$@"
  )
}

expect_pass() {
  local description="$1"
  shift
  local output
  if ! output="$(run_guard "$@" 2>&1)"; then
    [[ "$output" != *"$ACCOUNT"* ]] || fail "$description exposed the runtime account token"
    printf '%s\n' "$output" >&2
    fail "$description should pass"
  fi
  [[ "$output" == *'privacy gate passed'* ]] || fail "$description omitted its pass result"
  [[ "$output" != *"$ACCOUNT"* ]] || fail "$description exposed the runtime account token"
}

expect_fail_rule() {
  local description="$1"
  local expected_rule="$2"
  local forbidden_value="$3"
  shift 3
  local output
  if output="$(run_guard "$@" 2>&1)"; then
    fail "$description should fail"
  fi
  [[ "$output" == *"privacy gate: prohibited value detected (rule $expected_rule)"* ]] ||
    fail "$description failed under an unexpected rule"
  [[ "$output" == *'privacy gate failed:'* ]] || fail "$description omitted its failure result"
  [[ "$output" != *"$ACCOUNT"* ]] || fail "$description exposed the runtime account token"
  [[ -z "$forbidden_value" || "$output" != *"$forbidden_value"* ]] ||
    fail "$description exposed its matched value"
}

[[ -n "$ACCOUNT" ]] || fail 'runtime account did not resolve'

begin_case exact_header
add_line 'test/fixtures/ci/tracked-privacy-exceptions.tsv' \
  "# tracked-privacy-exceptions-v1 maintainer-token=$ACCOUNT"
expect_pass 'exact policy header'

begin_case exact_header_same_git_name "$ACCOUNT"
add_line 'test/fixtures/ci/tracked-privacy-exceptions.tsv' \
  "# tracked-privacy-exceptions-v1 maintainer-token=$ACCOUNT"
expect_pass 'exact policy header when Git name equals runtime account'

begin_case same_fixture_extra_token
add_line 'test/fixtures/ci/tracked-privacy-exceptions.tsv' \
  "# tracked-privacy-exceptions-v1 maintainer-token=$ACCOUNT"
add_line 'test/fixtures/ci/tracked-privacy-exceptions.tsv' "reviewer=$ACCOUNT"
expect_fail_rule 'second token in the approved fixture' account_name "$ACCOUNT"

begin_case other_path_token
add_line 'docs/review.txt' "Reviewed by $ACCOUNT."
expect_fail_rule 'runtime token in another added path' account_name "$ACCOUNT"

begin_case malformed_header
add_line 'test/fixtures/ci/tracked-privacy-exceptions.tsv' \
  "prefix # tracked-privacy-exceptions-v1 maintainer-token=$ACCOUNT"
expect_fail_rule 'malformed policy header' account_name "$ACCOUNT"

begin_case commit_message_token
git -C "$REPO" -c user.name='Fixture Reviewer' -c user.email='reviewer@example.test' \
  commit --allow-empty -qm "Reviewed by $ACCOUNT."
expect_fail_rule 'runtime token in a commit message' account_name "$ACCOUNT"

begin_case include_file_token
mkdir -p "$REPO/test/fixtures/ci"
printf 'reviewer=%s\n' "$ACCOUNT" > "$REPO/test/fixtures/ci/tracked-privacy-exceptions.tsv"
expect_fail_rule 'runtime token in an explicitly included file' account_name "$ACCOUNT" \
  --include 'test/fixtures/ci/tracked-privacy-exceptions.tsv'

begin_case git_name
add_line 'docs/review.txt' 'Reviewed by Fixture Reviewer.'
expect_fail_rule 'configured multi-word Git name' git_user_name 'Fixture Reviewer'

begin_case home_prefix
add_line 'docs/review.txt' "Local path: $SYNTHETIC_HOME/private"
expect_fail_rule 'synthetic HOME prefix' home_prefix "$SYNTHETIC_HOME"

begin_case brand_origin
add_line 'docs/review.txt' 'Brand source: https://brand.example.test/identity'
expect_fail_rule 'resolved brand origin' brand_origin 'brand.example.test'

begin_case non_test_email
NON_TEST_EMAIL='fixture'
NON_TEST_EMAIL+='@example.'
NON_TEST_EMAIL+='com'
add_line 'docs/review.txt' "Contact: $NON_TEST_EMAIL"
expect_fail_rule 'non-test email address' non_test_email "$NON_TEST_EMAIL"

begin_case allowed_test_email
add_line 'docs/review.txt' 'Contact: fixture@example.test'
expect_pass 'allowed .test email address'

printf 'privacy integration controls passed\n'
