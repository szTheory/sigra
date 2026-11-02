import assert from "node:assert/strict";
import test from "node:test";
import {
  deriveExpectedMismatchKeys,
  evaluateHistoricalRow,
  validateAudit,
  validateFinal,
} from "./prune-stale-branches-pr-audit.mjs";

const BASELINE_COMMIT = "9c0a6b818d2d58858b5db274cc1cf0a9803f69f5";
const STATE_BLOB = "913e4d0ab10cfa3b4fb42bd4d347d47f5832dc85";
const EVIDENCE_BLOB = "eb9f3fa848e41578bd6f6d03d375f66207bbc8e9";
const OLD_MAIN = "fed35a4a3725d217486f45a571421dbbf5721765";
const OLD_219 = "f06137b2ac0e9b2094aa1250e3c036b41e997651";
const MAIN_SHA = "a".repeat(40);
const HEAD_SHA = "b".repeat(40);
const STAMP = "2026-09-27T20:00:00Z";

const historical = Array.from({ length: 10 }, (_, index) => ({
  number: 266 + index,
  baseRefName: "main",
  baseRefOid: OLD_MAIN,
})).concat({ number: 219, baseRefName: "main", baseRefOid: OLD_219 });

const identity = (number) => ({
  number,
  state: "OPEN",
  base: { repository: "szTheory/sigra", ref: "main", sha: MAIN_SHA },
  head: { repository: "szTheory/sigra", ref: `fixture/pr-${number}`, sha: HEAD_SHA },
});

const source = (endpoint, extra = {}) => ({
  endpoint,
  requested_at: STAMP,
  completed_at: STAMP,
  status: "ok",
  ...extra,
});

function resolvedRow(number) {
  return {
    key: { number, base_ref: "main", base_sha: number === 219 ? OLD_219 : OLD_MAIN },
    historical_source: { commit: BASELINE_COMMIT, state_blob: STATE_BLOB, evidence_blob: EVIDENCE_BLOB },
    current_inventory: identity(number),
    current_pr: identity(number),
    exact_refs: {
      base: { api: { status: "ok", repository: "szTheory/sigra", branch: "main", ref: "refs/heads/main", sha: MAIN_SHA }, ls_remote: { status: "ok", repository: "szTheory/sigra", ref: "refs/heads/main", sha: MAIN_SHA } },
      head: { api: { status: "ok", repository: "szTheory/sigra", branch: `fixture/pr-${number}`, ref: `refs/heads/fixture/pr-${number}`, sha: HEAD_SHA }, ls_remote: { status: "ok", repository: "szTheory/sigra", ref: `refs/heads/fixture/pr-${number}`, sha: HEAD_SHA } },
    },
    provenance: {
      inventory: source("repos/szTheory/sigra/pulls?state=open", { page: 1, page_complete: true }),
      detail: source(`repos/szTheory/sigra/pulls/${number}`),
      base_api: source("repos/szTheory/sigra/git/ref/heads/main"),
      base_ls_remote: source("git ls-remote https://github.com/szTheory/sigra.git refs/heads/main"),
      head_api: source(`repos/szTheory/sigra/git/ref/heads/fixture%2Fpr-${number}`),
      head_ls_remote: source(`git ls-remote https://github.com/szTheory/sigra.git refs/heads/fixture/pr-${number}`),
    },
    disposition: "resolved",
    unresolved_reasons: [],
    ancestry: { historical_sha_readable: true, historical_sha_is_ancestor: true },
  };
}

function validAudit() {
  const rows = historical.map(({ number }) => resolvedRow(number));
  const inventory = rows.map((row) => row.current_inventory).concat([identity(224), identity(283)]);
  return {
    schema_version: 1,
    audit_id: "fixture-audit-245-07",
    baseline: {
      commit: BASELINE_COMMIT,
      state_blob: STATE_BLOB,
      evidence_blob: EVIDENCE_BLOB,
      default_ref: "refs/heads/main",
      default_sha: "5a00b90d2314bc93f27aec4090b5928018743d1b",
      historical_mismatch_keys: historical.map(({ number, baseRefOid }) => ({ number, base_ref: "main", base_sha: baseRefOid })).sort((a, b) => a.number - b.number),
    },
    full_open_pr_inventory: {
      complete: true,
      pages: [source("repos/szTheory/sigra/pulls?state=open&per_page=100&page=1", { page: 1, item_count: inventory.length, numbers: inventory.map((item) => item.number), has_next: false })],
      items: inventory,
    },
    rows,
  };
}

function validIntegrity(audit) {
  return {
    schema_version: 1,
    integrity_id: "fixture-integrity-245-07",
    outcome: "passed",
    audit: { audit_id: audit.audit_id, source_commit: "1".repeat(40), source_blob: "2".repeat(40) },
    baseline: { commit: BASELINE_COMMIT, state_blob: STATE_BLOB, evidence_blob: EVIDENCE_BLOB },
    verify_prs: { command: `bash scripts/maintainers/prune-stale-branches.sh verify-prs --pr-state-commit ${BASELINE_COMMIT} --identity-audit audit.json --integrity-output integrity.json`, exit_status: 0 },
    fresh_open_pr_inventory: { complete: true },
    checked_historical_rows: audit.rows.map((row) => ({ key: row.key, disposition: row.disposition, unresolved_reasons: row.unresolved_reasons })),
    reasons: [],
  };
}

test("derives the exact 11 base mismatch keys from the immutable historical baseline", () => {
  const keys = deriveExpectedMismatchKeys(
    { pull_requests: historical },
    { wave3_classification: { default_ref: "refs/heads/main", default_oid: "5a00b90d2314bc93f27aec4090b5928018743d1b" } },
  );
  assert.equal(keys.length, 11);
  assert.deepEqual(keys, historical.map(({ number, baseRefOid }) => ({ number, base_ref: "main", base_sha: baseRefOid })).sort((a, b) => a.number - b.number));
});

test("accepts only a complete one-to-one set with corroborated current identities", () => {
  const result = validateAudit(validAudit());
  assert.deepEqual(result.errors, []);
  assert.equal(result.resolved_count, 11);
});

test("rejects a missing historical row", () => {
  const audit = validAudit();
  audit.rows.pop();
  assert.match(validateAudit(audit).errors.join("\n"), /missing.*historical|row_count|missing_key/i);
});

test("rejects a duplicate historical row", () => {
  const audit = validAudit();
  audit.rows.push(structuredClone(audit.rows[0]));
  assert.match(validateAudit(audit).errors.join("\n"), /duplicate|row_count/i);
});

test("incomplete PR pagination cannot resolve a row", () => {
  const row = resolvedRow(219);
  assert.equal(evaluateHistoricalRow(row, false).disposition, "unresolved");
  const audit = validAudit();
  audit.full_open_pr_inventory.complete = false;
  audit.full_open_pr_inventory.pages[0].has_next = true;
  assert.match(validateAudit(audit).errors.join("\n"), /row_disposition_not_corroborated/);
  audit.rows = audit.rows.map((row) => {
    const evaluation = evaluateHistoricalRow(row, false);
    return { ...row, disposition: evaluation.disposition, unresolved_reasons: evaluation.reasons };
  });
  assert.equal(validateAudit(audit).valid, true, "a fully sourced audit can validly preserve an incomplete inventory as unresolved");
});

test("a list/detail identity disagreement remains unresolved", () => {
  const row = resolvedRow(219);
  row.current_pr.base.sha = "c".repeat(40);
  const result = evaluateHistoricalRow(row, true);
  assert.equal(result.disposition, "unresolved");
  assert.ok(result.reasons.some((reason) => /inventory|detail/i.test(reason)));
});

test("the audit preserves an API disagreement as a specific unresolved row", () => {
  const audit = validAudit();
  const row = audit.rows.find((candidate) => candidate.key.number === 219);
  row.exact_refs.base.api.sha = "c".repeat(40);
  row.exact_refs.base.api.status = "disagreement";
  const evaluation = evaluateHistoricalRow(row, true);
  row.disposition = evaluation.disposition;
  row.unresolved_reasons = evaluation.reasons;
  const result = validateAudit(audit);
  assert.equal(result.valid, true);
  assert.equal(result.resolved_count, 10);
  assert.ok(row.unresolved_reasons.some((reason) => reason.includes("base_github_ref_disagrees_with_pr")));
});

test("head-ref drift remains unresolved", () => {
  const row = resolvedRow(219);
  row.exact_refs.head.ls_remote.sha = "c".repeat(40);
  assert.equal(evaluateHistoricalRow(row, true).disposition, "unresolved");
});

test("missing exact refs and unavailable provenance remain unresolved", () => {
  const row = resolvedRow(219);
  row.exact_refs.base.api.sha = null;
  row.provenance.base_api.status = "unavailable";
  assert.equal(evaluateHistoricalRow(row, true).disposition, "unresolved");
});

test("ancestry alone cannot resolve a row without exact identity corroboration", () => {
  const row = resolvedRow(219);
  row.exact_refs.base.api.sha = "c".repeat(40);
  row.provenance.base_api.status = "disagreement";
  row.ancestry = { historical_sha_readable: true, historical_sha_is_ancestor: true };
  assert.equal(evaluateHistoricalRow(row, true).disposition, "unresolved");
});

test("final validation accepts a fully pinned pass and rejects a mismatched exit code", () => {
  const audit = validAudit();
  const integrity = validIntegrity(audit);
  assert.equal(validateFinal(audit, integrity).valid, true);
  integrity.verify_prs.exit_status = 1;
  assert.ok(validateFinal(audit, integrity).errors.includes("passed_integrity_has_nonzero_verify_prs_exit"));
});

test("final validation accepts a specific blocked handoff with unresolved PR identity", () => {
  const audit = validAudit();
  const row = audit.rows.find((candidate) => candidate.key.number === 219);
  row.exact_refs.base.api.sha = "c".repeat(40);
  row.exact_refs.base.api.status = "disagreement";
  const evaluation = evaluateHistoricalRow(row, true);
  row.disposition = evaluation.disposition;
  row.unresolved_reasons = evaluation.reasons;
  const integrity = validIntegrity(audit);
  integrity.outcome = "blocked";
  integrity.verify_prs.exit_status = 1;
  integrity.reasons = ["fresh_pr_identity_unresolved:219:current_base_github_ref_disagrees_with_pr"];
  integrity.checked_historical_rows = audit.rows.map((item) => ({ key: item.key, disposition: item.disposition, unresolved_reasons: item.unresolved_reasons }));
  assert.deepEqual(validateFinal(audit, integrity).errors, []);
});
