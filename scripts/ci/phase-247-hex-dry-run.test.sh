#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TDD_STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p "$TMP/bin"
git clone -q --shared "$ROOT" "$TMP/pinned"
git -C "$TMP/pinned" checkout -q --detach 6f8028658f0bdd7f26e13c3fe4d45437880c341b
if [ -n "$(git -C "$TMP/pinned" status --porcelain --untracked-files=all)" ]; then
  echo 'pinned source checkout is dirty' >&2
  exit 1
fi

cat >"$TMP/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  'api repos/szTheory/sigra/branches/main --jq .commit.sha') printf '%s\n' "${FIXTURE_MAIN_SHA:?}" ;;
  'api repos/szTheory/sigra/pulls/224') printf '{"state":"open","head":{"sha":"%s"},"base":{"sha":"%s"}}\n' "${FIXTURE_PR_HEAD:?}" "${FIXTURE_PR_BASE:?}" ;;
  "api repos/szTheory/sigra/pulls/${FIXTURE_EVIDENCE_PR:-987}") printf '{"state":"closed","merged":true,"head":{"sha":"%s"},"merge_commit_sha":"%s"}\n' "${FIXTURE_EVIDENCE_HEAD:?}" "${FIXTURE_EVIDENCE_MERGE:?}" ;;
  *) echo "unexpected gh call: $*" >&2; exit 91 ;;
esac
SH
chmod +x "$TMP/bin/gh"
cat >"$TMP/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "${CURL_STATUS:-404}"
SH
chmod +x "$TMP/bin/curl"
export PATH="$TMP/bin:$PATH" GH_TOKEN=fixture REPO_DIR="$TMP/pinned"
export FIXTURE_MAIN_SHA=e3883b72fb1df5ad6356ef10dbde408f18bbc3be
export FIXTURE_PR_HEAD=6f8028658f0bdd7f26e13c3fe4d45437880c341b
export FIXTURE_PR_BASE=e3883b72fb1df5ad6356ef10dbde408f18bbc3be

FIXTURE_MAIN_SHA=590eb4ed3323db11dd74326cbee00c9c7973e529
FIXTURE_PR_HEAD=563f411bc2659bb9ac1652d552ce58ffb0c876b1
FIXTURE_PR_BASE=590eb4ed3323db11dd74326cbee00c9c7973e529
export FIXTURE_MAIN_SHA FIXTURE_PR_HEAD FIXTURE_PR_BASE
if bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/superseded.json" >/dev/null 2>&1; then
  printf "TAP version 13\\nnot ok 1 - rejects superseded candidate\\n  ---\\n  expected: capture rejects the old PR #224 source SHA\\n  actual: old source was accepted\\n  ...\\n1..1\\n"
  exit 1
fi
FIXTURE_MAIN_SHA=e3883b72fb1df5ad6356ef10dbde408f18bbc3be
FIXTURE_PR_HEAD=6f8028658f0bdd7f26e13c3fe4d45437880c341b
FIXTURE_PR_BASE=e3883b72fb1df5ad6356ef10dbde408f18bbc3be
export FIXTURE_MAIN_SHA FIXTURE_PR_HEAD FIXTURE_PR_BASE

bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/baseline.json" >/dev/null
jq -e '.schema_version == 1 and .reviewed_base_sha == "e3883b72fb1df5ad6356ef10dbde408f18bbc3be" and .candidate_sha == "6f8028658f0bdd7f26e13c3fe4d45437880c341b" and .diff_algorithm == "git-diff-raw-v1" and (.diff_sha256 | test("^[0-9a-f]{64}$")) and (.diff_bytes > 0)' "$TMP/baseline.json" >/dev/null

expect_fail() {
  local name="$1"; shift
  if "$@" >"$TMP/$name.out" 2>&1; then echo "fixture unexpectedly passed: $name" >&2; exit 1; fi
}

jq 'del(.diff_bytes)' "$TMP/baseline.json" >"$TMP/missing-field.json"
expect_fail missing-field env REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/missing-field.json"
jq '.reviewed_base_sha = "1111111111111111111111111111111111111111"' "$TMP/baseline.json" >"$TMP/wrong-base.json"
expect_fail wrong-base env REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/wrong-base.json"
jq '.candidate_sha = "1111111111111111111111111111111111111111"' "$TMP/baseline.json" >"$TMP/wrong-candidate.json"
expect_fail wrong-candidate env REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/wrong-candidate.json"
jq '.diff_algorithm = "unknown"' "$TMP/baseline.json" >"$TMP/wrong-algorithm.json"
expect_fail wrong-algorithm env REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/wrong-algorithm.json"
jq '.diff_sha256 = "0000000000000000000000000000000000000000000000000000000000000000"' "$TMP/baseline.json" >"$TMP/changed-diff.json"
expect_fail changed-diff env REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/changed-diff.json"
expect_fail missing-baseline env REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/absent.json"
expect_fail missing-read-only-token env -u GH_TOKEN -u GITHUB_TOKEN REPO_DIR="$TMP/pinned" bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/no-token.json"

FIXTURE_PR_HEAD=563f411bc2659bb9ac1652d552ce58ffb0c876b1
export FIXTURE_PR_HEAD
expect_fail superseded-candidate bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/superseded.json"
FIXTURE_PR_HEAD=1111111111111111111111111111111111111111
export FIXTURE_PR_HEAD
expect_fail stale-head bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/stale.json"
FIXTURE_PR_HEAD=6f8028658f0bdd7f26e13c3fe4d45437880c341b
FIXTURE_PR_BASE=1111111111111111111111111111111111111111
export FIXTURE_PR_HEAD FIXTURE_PR_BASE
expect_fail changed-pr-base bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/changed-base.json"
FIXTURE_PR_BASE=e3883b72fb1df5ad6356ef10dbde408f18bbc3be
FIXTURE_MAIN_SHA=1111111111111111111111111111111111111111
export FIXTURE_PR_HEAD FIXTURE_MAIN_SHA
expect_fail advanced-main bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/advanced.json"

git clone -q --shared "$ROOT" "$TMP/evidence"
git -C "$TMP/evidence" checkout -q --detach e3883b72fb1df5ad6356ef10dbde408f18bbc3be
mkdir -p "$TMP/evidence/.planning/phases/247-release-candidate-and-repository-readiness"
export REPO_DIR="$TMP/evidence" FIXTURE_MAIN_SHA=e3883b72fb1df5ad6356ef10dbde408f18bbc3be FIXTURE_PR_BASE=e3883b72fb1df5ad6356ef10dbde408f18bbc3be
bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" capture-baseline "$TMP/baseline-before-merge.json" >/dev/null
mkdir -p "$TMP/evidence/.planning/phases/247-release-candidate-and-repository-readiness" "$TMP/evidence/.github/workflows" "$TMP/evidence/scripts/ci"
cp "$ROOT/.github/workflows/phase-247-hex-dry-run.yml" "$TMP/evidence/.github/workflows/"
cp "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" "$TMP/evidence/scripts/ci/"
cp "$ROOT/scripts/ci/phase-247-hex-dry-run.test.sh" "$TMP/evidence/scripts/ci/"
cp "$TMP/baseline-before-merge.json" "$TMP/evidence/.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json"
git -C "$TMP/evidence" add .github/workflows/phase-247-hex-dry-run.yml scripts/ci/phase-247-hex-dry-run.sh scripts/ci/phase-247-hex-dry-run.test.sh .planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json
git -C "$TMP/evidence" -c user.name=fixture -c user.email=fixture@example.invalid commit -qm evidence
FIXTURE_EVIDENCE_HEAD=$(git -C "$TMP/evidence" rev-parse HEAD)
FIXTURE_BLOB=$(git -C "$TMP/evidence" rev-parse HEAD:.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json)
git -C "$TMP/evidence" -c user.name=fixture -c user.email=fixture@example.invalid commit --allow-empty -qm merge
FIXTURE_EVIDENCE_MERGE=$(git -C "$TMP/evidence" rev-parse HEAD)
git -C "$TMP/evidence" -c user.name=fixture -c user.email=fixture@example.invalid commit --allow-empty -qm 'subsequent approved evidence fix'
FIXTURE_MAIN_SHA=$(git -C "$TMP/evidence" rev-parse HEAD)
export FIXTURE_EVIDENCE_HEAD FIXTURE_EVIDENCE_MERGE FIXTURE_MAIN_SHA
# The release PR remains at its original reviewed base after the evidence-only
# main advance; no base update is needed to preserve its fixed head SHA.
export FIXTURE_PR_BASE=e3883b72fb1df5ad6356ef10dbde408f18bbc3be EVIDENCE_PR_NUMBER=987 EVIDENCE_PR_HEAD_SHA="$FIXTURE_EVIDENCE_HEAD" EVIDENCE_MANIFEST_BLOB_ID="$FIXTURE_BLOB"
export GITHUB_REF=refs/heads/main GITHUB_REPOSITORY=szTheory/sigra GITHUB_SHA="$FIXTURE_MAIN_SHA" GITHUB_RUN_ID=12345 GITHUB_RUN_ATTEMPT=1
export GITHUB_WORKFLOW_REF=szTheory/sigra/.github/workflows/phase-247-hex-dry-run.yml@refs/heads/main
export GITHUB_RUN_STARTED_AT=2026-10-08T00:00:00Z
export CANDIDATE_SHA=6f8028658f0bdd7f26e13c3fe4d45437880c341b HEX_RELEASE_BEFORE_STATUS=404 DRY_RUN_OUTCOME=success DRY_RUN_KEY_PRESENT=true
bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/evidence/.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json" >/dev/null
bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" write-receipt "$TMP/receipt.json" "$TMP/evidence" "$TMP/pinned" >/dev/null
jq -e '.verdict == "passed" and .credential_name == "HEX_DRY_RUN_API_KEY" and .credential_present and .hex_release_before_http_status == 404 and .hex_release_after_http_status == 404 and .checked_out_sha == "6f8028658f0bdd7f26e13c3fe4d45437880c341b" and .evidence_pr_head_sha == env.FIXTURE_EVIDENCE_HEAD' "$TMP/receipt.json" >/dev/null
expect_fail wrong-evidence-pr env EVIDENCE_PR_NUMBER=988 bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/evidence/.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json"
expect_fail wrong-manifest-blob env EVIDENCE_MANIFEST_BLOB_ID=0000000000000000000000000000000000000000 bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" verify-baseline "$TMP/evidence/.planning/phases/247-release-candidate-and-repository-readiness/247-CANDIDATE-DIFF-BASELINE.json"
expect_fail untrusted-main env GITHUB_REF=refs/heads/evidence/test bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" write-receipt "$TMP/untrusted-main.json" "$TMP/evidence" "$TMP/evidence"
expect_fail changed-candidate-checkout bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" write-receipt "$TMP/changed-checkout.json" "$TMP/evidence" "$TMP/evidence"
export DRY_RUN_OUTCOME=failure DRY_RUN_KEY_PRESENT=true
expect_fail unsuccessful-dry-run bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" write-receipt "$TMP/unsuccessful.json" "$TMP/evidence" "$TMP/pinned"
export DRY_RUN_OUTCOME=failure DRY_RUN_KEY_PRESENT=false
expect_fail missing-key-receipt bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" write-receipt "$TMP/missing-key-receipt.json" "$TMP/evidence" "$TMP/pinned"
jq -e '.verdict == "failed" and .credential_present == false and .dry_run_outcome == "failure"' "$TMP/missing-key-receipt.json" >/dev/null
export DRY_RUN_OUTCOME=success DRY_RUN_KEY_PRESENT=true CURL_STATUS=200
expect_fail unexpected-hex bash "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" write-receipt "$TMP/unexpected-hex.json" "$TMP/evidence" "$TMP/pinned"
jq -e '.verdict == "failed" and .hex_release_after_http_status == 200' "$TMP/unexpected-hex.json" >/dev/null

if rg -n 'mix hex\.publish(?! --dry-run --yes)' "$ROOT/scripts/ci/phase-247-hex-dry-run.sh" "$ROOT/.github/workflows/phase-247-hex-dry-run.yml" --pcre2; then
  echo 'fixture found a release-changing command' >&2
  exit 1
fi
if rg -n 'secrets\.HEX_API_KEY' "$ROOT/.github/workflows/phase-247-hex-dry-run.yml"; then
  echo 'fixture found the write-capable Hex secret' >&2
  exit 1
fi
# Emit a TAP summary so the source-rebind assertion can be classified as RED.
printf 'TAP version 13\n'
printf '# phase-247 dry-run fixtures: 18 passed\n'
if jq -e 'has("started_at") and has("finished_at") and (.started_at | type == "string") and (.finished_at | type == "string")' "$TMP/receipt.json" >/dev/null; then
  printf 'ok 1 - receipt records workflow start and finish timestamps\n'
  printf '1..1\n'
else
  printf 'not ok 1 - receipt records workflow start and finish timestamps\n'
  printf '  ---\n  expected: started_at and finished_at ISO timestamps\n  actual: receipt omits one or both run timestamps\n  ...\n1..1\n'
  exit 1
fi
