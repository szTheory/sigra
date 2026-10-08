#!/usr/bin/env bash
# Hermetic workflow-run, PR, and ci-gate identity contract for the guarded release merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/release-candidate-preflight.sh"
CI_WORKFLOW="${ROOT}/.github/workflows/ci.yml"
MERGE_WORKFLOW="${ROOT}/.github/workflows/release-pr-automerge.yml"
REPOSITORY="szTheory/sigra"
EXPECTED_SHA="0123456789abcdef0123456789abcdef01234567"
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

### Added

- Generated email-confirmation screens accept pasted six-digit codes.
- Generated Phoenix hosts support confirmation by email link or displayed code without changing an existing session.
- Generated confirmation retries handle missing or malformed links safely and clear stale error feedback.
- Branding profiles support a separate dark-theme logo. When no dark accent is configured, Sigra preserves an accent that already meets contrast and adjusts only its lightness when needed; the admin customizer shows how the dark accent was resolved.
- OAuth callbacks can opt into returning validated provider identity evidence, including issuer, subject, and authentication time when available.
- Chimeway auth-message integrations support opaque recipient references and resolve magic-link tokens before recipient lookup.

### Upgrade notes

Existing generated files remain host-owned; updating the dependency does not overwrite customized confirmation screens. Existing apps can selectively adopt the generated confirmation LiveView changes from the upgrade guide. The confirmation recovery changes require no database migration.
MD
  cat > "$TMP/ledger.json" <<JSON
{
  "source_selection":{"status":"ready","selected_source_sha":"$OTHER_SHA"},
  "final_validation":{"valid":true,"status":"ready","checked":{"pr_head_sha":"$EXPECTED_SHA"}},
  "final_readiness":{
    "source_sha":"$EXPECTED_SHA",
    "docs":{"candidate_summary_under_versioned_heading":true,"candidate_summary_only_unreleased":false},
    "claim_sources":[
      {"claim":"Generated Phoenix hosts support confirmation by email link or displayed code without changing an existing session.","source":"priv/templates/sigra.install/core/confirmation_live.ex","evidence":"exact-source required CI passed","source_paths":["priv/templates/sigra.install/core/confirmation_live.ex"],"source_paths_present":true,"source_sha":"$EXPECTED_SHA","ci_run_id":12345},
      {"claim":"Generated confirmation retries handle missing or malformed links safely and clear stale error feedback.","source":"priv/templates/sigra.install/core/confirmation_live.ex","evidence":"exact-source required CI passed","source_paths":["priv/templates/sigra.install/core/confirmation_live.ex"],"source_paths_present":true,"source_sha":"$EXPECTED_SHA","ci_run_id":12345},
      {"claim":"Branding profiles can use separate dark logos and contrast-derived dark accents.","source":"lib/sigra/branding.ex","evidence":"selected-main CI passed","source_paths":["lib/sigra/branding.ex"],"source_paths_present":true,"source_sha":"$EXPECTED_SHA","ci_run_id":12345},
      {"claim":"Chimeway magic-link handling decodes tokens before lookup and uses opaque recipient references.","source":"lib/sigra/integrations/chimeway.ex","evidence":"selected-main CI passed","source_paths":["lib/sigra/integrations/chimeway.ex"],"source_paths_present":true,"source_sha":"$EXPECTED_SHA","ci_run_id":12345},
      {"claim":"Previously generated host files remain host-owned and need selective adoption for confirmation changes.","source":"priv/templates/sigra.install/core/confirmation_live.ex","evidence":"generated-host install smoke passed","source_paths":["priv/templates/sigra.install/core/confirmation_live.ex"],"source_paths_present":true,"source_sha":"$EXPECTED_SHA","ci_run_id":12345}
    ]
  }
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
    --changelog "$TMP/changelog.md" --ledger "$TMP/ledger.json" 2>&1)"
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

echo "Test H: valid 1.6.0 changelog and source-bound candidate ledger -> PASS"
write_valid_fixtures
run_content_preflight
if [[ "$RC" -eq 0 ]] && jq -e '.verdict == "PASS" and .version == "1.6.0"' >/dev/null 2>&1 <<<"$OUT"; then
  pass "versioned candidate content and all source-backed ledger rows are accepted"
else
  fail "valid candidate content rejected (rc=$RC): $OUT"
fi
write_valid_fixtures
jq 'del(.final_readiness.docs.candidate_summary_only_unreleased)' "$TMP/ledger.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/ledger.json"
run_content_preflight
if [[ "$RC" -eq 0 ]]; then pass "current ledger schema with omitted optional Unreleased flag is accepted"; else fail "current ledger schema rejected (rc=$RC): $OUT"; fi

echo "Test I: candidate note stranded under Unreleased -> rejected"
write_valid_fixtures
awk '1; /^## Unreleased$/ { print ""; print "- Generated confirmation updates remain unreleased." }' \
  "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "candidate-specific Unreleased note is rejected"; else fail "stranded Unreleased note accepted"; fi

echo "Test J: duplicate normalized version note -> rejected"
write_valid_fixtures
awk '1; /^### Added$/ { print ""; print "- CHIMEWAY auth-message integrations support opaque recipient references and resolve magic-link tokens before recipient lookup!" }' \
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
awk '!/Generated Phoenix hosts support confirmation/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing generated-confirmation source summary is rejected"
write_valid_fixtures
awk '!/Generated confirmation retries handle/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing generated-confirmation recovery summary is rejected"
write_valid_fixtures
awk '!/Branding profiles support a separate dark-theme logo/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing branding source summary is rejected"
write_valid_fixtures
awk '!/Chimeway auth-message/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing Chimeway source summary is rejected"
write_valid_fixtures
awk '!/Existing generated files remain host-owned/' "$TMP/changelog.md" > "$TMP/changed.md" && mv "$TMP/changed.md" "$TMP/changelog.md"
assert_content_rejected "missing generated-host upgrade summary is rejected"

echo "Test M: invalid readiness ledger or missing claim evidence -> rejected"
write_valid_fixtures
jq '.final_validation.status = "blocked"' "$TMP/ledger.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/ledger.json"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "blocked candidate ledger is rejected"; else fail "blocked candidate ledger accepted"; fi
write_valid_fixtures
jq --arg sha "$OTHER_SHA" '.final_readiness.claim_sources[0].source_sha = $sha' "$TMP/ledger.json" > "$TMP/changed.json" && mv "$TMP/changed.json" "$TMP/ledger.json"
run_content_preflight
if [[ "$RC" -ne 0 ]]; then pass "source-backed ledger row bound to a different source is rejected"; else fail "mismatched source row accepted"; fi

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
   && grep -q 'contents/CHANGELOG.md?ref=' "$MERGE_WORKFLOW"; then
  pass "candidate content is fetched as data and final reread uses an exact-head merge guard"
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
