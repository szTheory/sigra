#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
tmp_dir="$(mktemp -d /tmp/253-canary-contract.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT
repo="$tmp_dir/repo"
mkdir -p "$repo/scripts/ci" "$repo/.github/workflows" \
  "$repo/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks"

for file in ci-gate-canary.sh ci-gate-canary.test.sh ci-hosted-gate-verify.py \
  ci-hosted-gate-verify.test.py ci-browser-records.mjs honest-skip-verdict.sh ci-hosted-transport.py; do
  cp "$ROOT/scripts/ci/$file" "$repo/scripts/ci/$file"
done
cp "$ROOT/.github/workflows/ci.yml" "$repo/.github/workflows/ci.yml"
for file in ci-observe.yml release-pr-automerge.yml release-run-observer.yml; do
  cp "$ROOT/.github/workflows/$file" "$repo/.github/workflows/$file"
done
cat > "$repo/.github/workflows/ci.yml" <<'WORKFLOW'
name: Phase 253 Gate Canary
on:
  workflow_dispatch:
    inputs: {}
permissions:
  contents: read
jobs:
  producers:
    strategy:
      matrix:
        seam: [non_admin_smoke, admin_behavior, admin_checkpoints, design_gallery, demo_showcase]
  verdict: {}
  verifier:
    permissions:
      contents: read
      actions: read
WORKFLOW
cp "$ROOT/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml" \
  "$repo/.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml"
git -C "$repo" init -q -b main
git -C "$repo" config user.name "Sigra test fixture"
git -C "$repo" config user.email "fixture@example.invalid"
git -C "$repo" add scripts/ci .github/workflows/ci.yml \
  .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-WORKFLOW.yml
git -C "$repo" commit -qm "fixture: candidate helper source"
candidate="$(git -C "$repo" rev-parse HEAD)"
fixture_blob="$(git -C "$repo" rev-parse HEAD:.github/workflows/ci.yml)"
git -C "$repo" commit --allow-empty -qm "fixture: sealed workflow identity"
fixture_commit="$(git -C "$repo" rev-parse HEAD)"
fixture_ref="refs/heads/gsd/253-replan-canary-fixture-contract-$RANDOM"
git -C "$repo" update-ref "$fixture_ref" "$fixture_commit"

python3 - "$repo" "$candidate" "$fixture_commit" "$fixture_blob" "$fixture_ref" <<'PY'
import hashlib, json, pathlib, sys
repo=pathlib.Path(sys.argv[1])
candidate,fixture,blob,ref=sys.argv[2:]
source_paths=[
  "scripts/ci/ci-gate-canary.sh",
  "scripts/ci/ci-gate-canary.test.sh",
  "scripts/ci/ci-hosted-gate-verify.py",
  "scripts/ci/ci-hosted-gate-verify.test.py",
  "scripts/ci/ci-hosted-transport.py",
]
source={name:hashlib.sha256((repo/name).read_bytes()).hexdigest() for name in source_paths}
scenarios={"count":6,"optional_infrastructure_retry":1,"cases":[
 {"name":name,"expected_outcome":outcome} for name,outcome in [
  ("full-pass","success"),("docs-only","success"),("actual-failure","failure"),
  ("missing-seam","failure"),("unexpected-skip","failure"),("cancelled","cancelled")]]}
freeze={
 "schema_version":"sigra.recovery-canary-freeze/v1",
 "identity":{"candidate_helper_commit":candidate,"fixture_workflow_commit":fixture,
  "fixture_workflow_blob":blob,"fixture_ref":ref,"old_failed_run_id":"38347679431",
  "old_failed_fixture_ref":"refs/heads/old-failed-fixture",
  "old_failed_fixture_blob":"0"*40},
 "scenarios":scenarios,
 "bounds":{"max_requests":120,"max_actual_tiny_jobs":45,"max_minutes":60,
  "max_infrastructure_retries":1,"max_dispatch_input_keys":10,
  "max_dispatch_input_chars":65535,"max_artifact_compressed_bytes":2097152,
  "max_artifact_extracted_bytes":4194304},
 "required_checks":["Library tests","Example unit smoke (ExUnit + ConnTest)",
  "Install smoke (fresh phx.new + sigra.install)",
  "Example HTTP smoke (boot + curl critical routes)",
  "Example Playwright smoke (full lifecycle)"],
 "workflow":{"permissions":{"contents":"read"},"trigger":["workflow_dispatch"],
  "jobs":{"tiny_producers":5,"verdict":1,"independent_verifier":1,"observer_trigger":False}},
 "historical":{"previous_accounted_or_reserved_requests":20,"previous_exact_http_count_proven":False},
 "source_sha256":source,
}
path=repo/".planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json"
path.write_text(json.dumps(freeze,indent=2)+"\n")
PY

cd "$repo"
bash scripts/ci/ci-gate-canary.sh --check-only \
  --recovery-freeze .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-FREEZE.json
[[ "$(git rev-parse "$fixture_ref")" == "$fixture_commit" ]]
[[ "$(git rev-parse "$fixture_commit:.github/workflows/ci.yml")" == "$fixture_blob" ]]
[[ ! -e .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-REQUESTS.json ]]
[[ ! -e .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-RECOVERY-CANARY-EVIDENCE.json ]]
# Live modes need the reviewed revision freeze and its committed canary approval (253-91); no request is attempted.
if bash scripts/ci/ci-gate-canary.sh --scenario full-pass --revision-freeze "$tmp_dir/absent-freeze.json" >"$tmp_dir/live.out" 2>"$tmp_dir/live.err"; then
  echo "ci-gate-canary tests: FAIL: a live mode ran without a reviewed revision freeze" >&2
  exit 1
fi
grep -q 'revision-freeze' "$tmp_dir/live.err"
if bash scripts/ci/ci-gate-canary.sh --rerun --revision-freeze "$tmp_dir/absent-freeze.json" >"$tmp_dir/rerun.out" 2>"$tmp_dir/rerun.err"; then
  echo "ci-gate-canary tests: FAIL: a rerun invocation was accepted" >&2
  exit 1
fi
grep -qi 'rerun' "$tmp_dir/rerun.err"
bash scripts/ci/ci-gate-canary.sh --help | grep -q -- '--publish-only'
echo "ci-gate-canary tests passed (synthetic fixture repo; no active phase refs or ledgers)"
