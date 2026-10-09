#!/usr/bin/env bash
# Hermetic workflow-run, PR, and ci-gate identity contract for the guarded release merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/release-candidate-preflight.sh"
CI_WORKFLOW="${ROOT}/.github/workflows/ci.yml"
MERGE_WORKFLOW="${ROOT}/.github/workflows/release-pr-automerge.yml"
REPOSITORY="szTheory/sigra"
EXPECTED_SHA="0123456789abcdef0123456789abcdef01234567"
APPROVED_SHA="bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
OTHER_SHA="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

if [[ ! -f "$SCRIPT" ]]; then
  echo "FATAL: preflight helper missing at $SCRIPT" >&2
  exit 2
fi

write_valid_fixtures() {
  cat > "$TMP/event.json" <<JSON
{"repository":"$REPOSITORY","workflow_name":"CI","run_id":12345,"event":"push","head_branch":"release-please--branches--main","head_sha":"$EXPECTED_SHA","conclusion":"success"}
JSON
  cat > "$TMP/run.json" <<JSON
{"repository":"$REPOSITORY","workflowName":"CI","databaseId":12345,"event":"push","headBranch":"release-please--branches--main","headSha":"$EXPECTED_SHA","conclusion":"success","url":"https://github.com/$REPOSITORY/actions/runs/12345"}
JSON
  cat > "$TMP/prs.json" <<JSON
[{"number":224,"state":"OPEN","title":"chore(main): release 1.6.0","baseRefName":"main","headRefName":"release-please--branches--main","headRefOid":"$EXPECTED_SHA","headRepository":{"nameWithOwner":"$REPOSITORY"},"labels":[{"name":"autorelease: pending"}],"url":"https://github.com/$REPOSITORY/pull/224"}]
JSON
  cat > "$TMP/jobs.json" <<'JSON'
[{"name":"ci-gate","conclusion":"success"}]
JSON
  cat > "$TMP/changelog.md" <<'MD'
# Changelog

## Unreleased

<!-- Release Please notes are placed in versioned sections. -->

## [1.6.0] (2026-10-08)

### Adopter notes

- Generated Phoenix hosts let users confirm accounts by email link or displayed code without changing the current session.
- Generated confirmation screens retry safely with missing or malformed links and clear stale error feedback.
- Branding profiles support dark logos and dark accents tuned to accessible contrast.
- Chimeway decodes magic-link tokens before recipient lookup and keeps authentication recipient references opaque.
- Existing generated host files remain host-owned; apps can selectively adopt confirmation updates.

MD
  cat > "$TMP/claims.json" <<JSON
{
  "schema_version":1,
  "source_ledger":{
    "path":".planning/phases/247-release-candidate-and-repository-readiness/247-RELEASE-READINESS.json",
    "sha256":"cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
    "validated_candidate_sha":"$APPROVED_SHA",
    "selected_source_sha":"$OTHER_SHA",
    "source_ci_run_id":111,
    "hex_dry_run_run_id":222
  },
  "approved_source_blobs":{
    "priv/templates/sigra.install/core/confirmation_live.ex":"1111111111111111111111111111111111111111",
    "lib/sigra/branding.ex":"2222222222222222222222222222222222222222",
    "lib/sigra/branding/contrast.ex":"3333333333333333333333333333333333333333",
    "test/sigra/branding_test.exs":"4444444444444444444444444444444444444444",
    "lib/sigra/integrations/chimeway.ex":"5555555555555555555555555555555555555555",
    "test/sigra/integrations/chimeway_test.exs":"6666666666666666666666666666666666666666",
    "test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex":"7777777777777777777777777777777777777777"
  },
  "claim_sources":[
    {"claim":"Generated Phoenix hosts support confirmation by email link or displayed code without changing an existing session.","source":"priv/templates/sigra.install/core/confirmation_live.ex","evidence":"Phase246 exact-source required CI passed","source_paths":["priv/templates/sigra.install/core/confirmation_live.ex"]},
    {"claim":"Generated confirmation retries handle missing or malformed links safely and clear stale error feedback.","source":"priv/templates/sigra.install/core/confirmation_live.ex at tested source 90ec16f and promoted main 590eb4e","evidence":"four approved source blobs match; Phase246 CI passed","source_paths":["priv/templates/sigra.install/core/confirmation_live.ex"]},
    {"claim":"Branding profiles can use separate dark logos and contrast-derived dark accents.","source":"lib/sigra/branding.ex, lib/sigra/branding/contrast.ex, test/sigra/branding_test.exs","evidence":"selected-main CI passed","source_paths":["lib/sigra/branding.ex","lib/sigra/branding/contrast.ex","test/sigra/branding_test.exs"]},
    {"claim":"Chimeway magic-link handling decodes tokens before lookup and uses opaque recipient references.","source":"lib/sigra/integrations/chimeway.ex and test/sigra/integrations/chimeway_test.exs","evidence":"selected-main CI passed","source_paths":["lib/sigra/integrations/chimeway.ex","test/sigra/integrations/chimeway_test.exs"]},
    {"claim":"Previously generated host files remain host-owned and need selective adoption for confirmation changes.","source":"priv/templates/sigra.install/core/confirmation_live.ex and installed host fixture","evidence":"generated-host install smoke and Playwright required CI passed","source_paths":["priv/templates/sigra.install/core/confirmation_live.ex","test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex"]}
  ]
}
JSON
  cat > "$TMP/source-blobs.json" <<'JSON'
{
  "priv/templates/sigra.install/core/confirmation_live.ex":"1111111111111111111111111111111111111111",
  "lib/sigra/branding.ex":"2222222222222222222222222222222222222222",
  "lib/sigra/branding/contrast.ex":"3333333333333333333333333333333333333333",
  "test/sigra/branding_test.exs":"4444444444444444444444444444444444444444",
  "lib/sigra/integrations/chimeway.ex":"5555555555555555555555555555555555555555",
  "test/sigra/integrations/chimeway_test.exs":"6666666666666666666666666666666666666666",
  "test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/confirmation_live.ex":"7777777777777777777777777777777777777777"
}
JSON
}

assert_content_rejected() {
  local description="$1"
  run_content_preflight
  if [[ "$RC" -ne 0 ]] && grep -Fq 'source-backed adopter summary is absent' <<<"$OUT"; then
    pass "$description"
  else
    fail "$description did not fail the source-summary gate: $OUT"
  fi
}

run_preflight() {
  set +e
  OUT="$(bash "$SCRIPT" --repository "$REPOSITORY" \
    --event-run "$TMP/event.json" --queried-run "$TMP/run.json" \
    --pull-requests "$TMP/prs.json" --gate-jobs "$TMP/jobs.json" 2>&1)"
  RC=$?
  set -e
}

run_content_preflight() {
  set +e
  OUT="$(bash "$SCRIPT" --repository "$REPOSITORY" \
    --event-run "$TMP/event.json" --queried-run "$TMP/run.json" \
    --pull-requests "$TMP/prs.json" --gate-jobs "$TMP/jobs.json" \
    --changelog "$TMP/changelog.md" --claims "$TMP/claims.json" \
    --source-blobs "$TMP/source-blobs.json" 2>&1)"
  RC=$?
  set -e
}

echo "Test A: matching completed push run and one current PR head -> PASS"
write_valid_fixtures
run_preflight
if [[ "$RC" -eq 0 ]] && jq -e --arg sha "$EXPECTED_SHA" '.verdict == "PASS" and .pr_number == 224 and .head_sha == $sha' >/dev/null 2>&1 <<<"$OUT"; then
  pass "matching event, queried run, PR head, and ci-gate are accepted"
else
  fail "matching identity rejected (rc=$RC): $OUT"
fi

echo "Test B: synthetic pull_request workflow run -> rejected"
write_valid_fixtures
jq '.event = "pull_request"' "$TMP/event.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/event.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "pull_request run is rejected"; else fail "synthetic pull_request run accepted"; fi

echo "Test C: queried run head differs from event/PR -> rejected"
write_valid_fixtures
jq --arg sha "$OTHER_SHA" '.headSha = $sha' "$TMP/run.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/run.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "mismatched queried run head is rejected"; else fail "mismatched queried run head accepted"; fi

echo "Test D: missing run head identity -> rejected"
write_valid_fixtures
jq 'del(.headSha)' "$TMP/run.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/run.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "missing queried run head is rejected"; else fail "missing queried run head accepted"; fi

echo "Test E: multiple matching open candidates -> rejected"
write_valid_fixtures
jq '.[0].number = 225' "$TMP/prs.json" > "$TMP/changed.json"
jq -s '.[0] + .[1]' "$TMP/prs.json" "$TMP/changed.json" > "$TMP/prs.json.tmp" && mv "$TMP/prs.json.tmp" "$TMP/prs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "multiple open release candidates are rejected"; else fail "multiple candidates were treated as one"; fi

echo "Test H: valid 1.6.0 changelog and Phase 247 source-claim manifest -> PASS"
write_valid_fixtures
run_content_preflight
if [[ "$RC" -eq 0 ]] && jq -e --arg approved "$APPROVED_SHA" '.verdict == "PASS" and .version == "1.6.0" and .source_blobs_verified == true and .approved_candidate_sha == $approved and (.source_ledger_sha | test("^[0-9a-f]{64}$"))' >/dev/null 2>&1 <<<"$OUT"; then
  pass "versioned candidate content and approved source-blob manifest are accepted and reported"
else
  fail "valid candidate content rejected (rc=$RC): $OUT"
fi

echo "Test H2: repository CHANGELOG release section satisfies Phase 247 source claims -> PASS"
write_valid_fixtures
cp "$ROOT/CHANGELOG.md" "$TMP/changelog.md"
run_content_preflight
if [[ "$RC" -eq 0 ]] && jq -e '.verdict == "PASS" and .source_blobs_verified == true' >/dev/null 2>&1 <<<"$OUT"; then
  pass "repository changelog source-backed summaries satisfy the actual candidate-content gate"
else
  fail "repository changelog does not satisfy the candidate-content gate (rc=$RC): $OUT"
fi

echo "Test I: candidate note stranded under Unreleased -> rejected"
write_valid_fixtures
awk '1; /^## Unreleased$/ { print ""; print "- Generated confirmation updates remain unreleased." }' \
  "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "candidate-specific Unreleased note is rejected"; else fail "stranded Unreleased note accepted"; fi

echo "Test J: duplicate normalized version note -> rejected"
write_valid_fixtures
awk '1; /^### Adopter notes$/ { print ""; print "- CHIMEWAY decodes MAGIC-LINK tokens before recipient lookup and keeps authentication recipient references opaque!" }' \
  "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "duplicate note after punctuation/case normalization is rejected"; else fail "duplicate versioned note accepted"; fi

echo "Test K: missing or duplicated release version section -> rejected"
write_valid_fixtures
sed -i.bak 's/## \[1.6.0\]/## [1.5.9]/' "$TMP/changelog.md" && rm "$TMP/changelog.md.bak"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "missing titled version section is rejected"; else fail "missing version section accepted"; fi
write_valid_fixtures
awk '1; index($0, "## [1.6.0]") == 1 { print ""; print "## [1.6.0] (duplicate)" }' \
  "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "duplicate titled version section is rejected"; else fail "duplicate version section accepted"; fi

echo "Test L: each source-backed adopter summary absent from version section -> rejected"
write_valid_fixtures
awk '!/Generated Phoenix hosts let users confirm accounts/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing generated-confirmation source summary is rejected"
write_valid_fixtures
awk '!/Generated confirmation screens retry safely/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing generated-confirmation recovery summary is rejected"
write_valid_fixtures
awk '!/Branding profiles support dark logos/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing branding source summary is rejected"
write_valid_fixtures
awk '!/Chimeway decodes magic-link tokens/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing Chimeway source summary is rejected"
write_valid_fixtures
awk '!/Existing generated host files remain host-owned/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing generated-host upgrade summary is rejected"

echo "Test M: invalid Phase 247 provenance or changed approved source blob -> rejected"
write_valid_fixtures
jq '.source_ledger.sha256 = "invalid"' "$TMP/claims.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/claims.json"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "malformed source-ledger provenance digest is rejected"; else fail "malformed source-ledger digest accepted"; fi
write_valid_fixtures
jq --arg path "lib/sigra/branding.ex" --arg sha "$OTHER_SHA" '.[$path] = $sha' "$TMP/source-blobs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/source-blobs.json"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "candidate source blob drift from Phase 247 approval is rejected"; else fail "changed approved source blob accepted"; fi
write_valid_fixtures
jq 'del(."lib/sigra/branding.ex")' "$TMP/source-blobs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/source-blobs.json"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "incomplete current source-blob map is rejected"; else fail "incomplete source-blob map accepted"; fi

echo "Test N: wrong base, title, repository, label, or ci-gate result -> rejected"
write_valid_fixtures
jq '.[0].baseRefName = "develop"' "$TMP/prs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/prs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "wrong PR base is rejected"; else fail "wrong PR base accepted"; fi
write_valid_fixtures
jq '.[0].labels = []' "$TMP/prs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/prs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "missing autorelease: pending label is rejected"; else fail "missing release label accepted"; fi
write_valid_fixtures
jq '.[0].headRepository.nameWithOwner = "fork/sigra"' "$TMP/prs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/prs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "fork-owned candidate is rejected"; else fail "fork-owned candidate accepted"; fi
write_valid_fixtures
jq '.[0].title = "chore(main): release 1.6.0-beta.1"' "$TMP/prs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/prs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "non-final Release Please title is rejected"; else fail "invalid release title accepted"; fi
write_valid_fixtures
jq '.[0].conclusion = "failure"' "$TMP/jobs.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/jobs.json"
run_preflight
if [[ "$RC" -ne 0 ]]; then pass "failed ci-gate is rejected"; else fail "failed ci-gate accepted"; fi

echo "Test O: workflow rechecks exact state and uses match-head squash merge"
if grep -q 'gh pr merge' "$MERGE_WORKFLOW" \
   && grep -q -- '--match-head-commit' "$MERGE_WORKFLOW" \
   && grep -q 'RELEASE_PLEASE_TOKEN' "$MERGE_WORKFLOW" \
   && grep -q 'Fresh final-state' "$MERGE_WORKFLOW" \
   && grep -q 'capture_candidate initial' "$MERGE_WORKFLOW" \
   && grep -q 'capture_candidate final' "$MERGE_WORKFLOW" \
   && grep -q 'contents/CHANGELOG.md?ref=' "$MERGE_WORKFLOW" \
   && grep -q "contents/\${path}?ref=" "$MERGE_WORKFLOW" \
   && grep -q '248-AUTOMERGE-CLAIMS.json' "$MERGE_WORKFLOW"; then
  pass "candidate changelog and approved source blobs are fetched as data before the exact-head merge guard"
else
  fail "candidate data fetch, final reread, dedicated release token, or match-head merge guard is missing"
fi

echo "Test F: CI push trigger includes exactly the Release Please branch and preserves ci-gate"
if grep -q 'branches: \[main, release-please--branches--main\]' "$CI_WORKFLOW" \
   && grep -q '^  pull_request:' "$CI_WORKFLOW" && grep -q '^  ci-gate:' "$CI_WORKFLOW"; then
  pass "push target added without removing pull_request or ci-gate"
else
  fail "CI event contract is missing the exact release branch or existing gate"
fi

echo "Test G: merge workflow consumes completed CI workflow_run on the Release Please branch"
if grep -q 'workflow_run:' "$MERGE_WORKFLOW" \
   && grep -q 'workflows: \["CI"\]' "$MERGE_WORKFLOW" \
   && grep -q 'release-please--branches--main' "$MERGE_WORKFLOW" \
   && grep -q 'release-candidate-preflight.sh' "$MERGE_WORKFLOW"; then
  pass "trusted workflow_run route is present"
else
  fail "workflow_run route or preflight helper call is missing"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then
  echo "release-candidate-preflight.test: FAIL"
  exit 1
fi
echo "release-candidate-preflight.test: PASS"
