import assert from "node:assert/strict";
import test from "node:test";
import {
  CANDIDATE_COMMAND,
  parseRefInventory,
  runFixtureCase,
} from "./verify-object-fetch-isolation.mjs";

test("configured origin fetch obtains the exact object without changing refs, symbolic HEAD or FETCH_HEAD in both states", () => {
  assert.equal(
    CANDIDATE_COMMAND,
    "/usr/bin/git -c gc.auto=0 -c maintenance.auto=false fetch --refmap= --no-tags --no-write-fetch-head origin refs/heads/gh-pages",
  );

  for (const fetchHead of ["present", "absent"]) {
    const result = runFixtureCase({ fetchHead });
    assert.equal(result.status, "passed", JSON.stringify(result));
    assert.equal(result.fetch_exit_code, 0);
    assert.equal(result.object_readable_before, false);
    assert.equal(result.object_readable_after, true);
    assert.equal(result.ref_inventory_equal, true);
    assert.equal(result.symbolic_head_equal, true);
    assert.equal(result.fetch_head_equal, true);
    assert.equal(result.tracking_ref_equal, true);
    assert.equal(result.tracking_baseline_equal, true);
    assert.equal(result.old_tracking_oid, result.old_origin_gh_pages_oid);
    assert.equal(result.old_tracking_oid, result.tracking_oid_after);
  }
});

test("a nonzero exact-object fetch returns a blocked case", () => {
  const result = runFixtureCase({
    fetcher: () => ({ status: 9, stdout: "", stderr: "fixture fetch failure" }),
  });
  assert.equal(result.status, "blocked");
  assert.ok(result.failed_predicates.includes("fetch_failed"));
});

test("a zero-exit fetch that leaves the exact object unreadable returns a blocked case", () => {
  const result = runFixtureCase({
    fetcher: () => ({ status: 0, stdout: "", stderr: "" }),
  });
  assert.equal(result.status, "blocked");
  assert.ok(result.failed_predicates.includes("object_unreadable_after_fetch"));
});

test("a changed or extra tracking ref returns a blocked case", () => {
  const result = runFixtureCase({
    fetcher: ({ runFetch, runGit, checkout, newOid }) => {
      const fetched = runFetch();
      runGit(checkout, ["update-ref", "refs/remotes/origin/gh-pages", newOid]);
      runGit(checkout, ["update-ref", "refs/heads/injected", newOid]);
      return fetched;
    },
  });
  assert.equal(result.status, "blocked");
  assert.ok(result.failed_predicates.includes("ref_inventory_changed"));
  assert.ok(result.failed_predicates.includes("tracking_ref_changed"));
});

test("a changed symbolic HEAD returns a blocked case", () => {
  const result = runFixtureCase({
    fetcher: ({ runFetch, runGit, checkout, oldTrackingOid }) => {
      const fetched = runFetch();
      runGit(checkout, ["update-ref", "refs/heads/injected", oldTrackingOid]);
      runGit(checkout, ["symbolic-ref", "HEAD", "refs/heads/injected"]);
      return fetched;
    },
  });
  assert.equal(result.status, "blocked");
  assert.ok(result.failed_predicates.includes("symbolic_head_changed"));
});

test("a changed FETCH_HEAD returns a blocked case", () => {
  const result = runFixtureCase({
    fetchHead: "present",
    fetcher: ({ runFetch, writeFetchHead }) => {
      const fetched = runFetch();
      writeFetchHead(Buffer.from("unexpected FETCH_HEAD\n"));
      return fetched;
    },
  });
  assert.equal(result.status, "blocked");
  assert.ok(result.failed_predicates.includes("fetch_head_changed"));
});

test("duplicate names in a ref inventory are explicitly reported", () => {
  const oid = "a".repeat(40);
  const raw = `refs/heads/main\tcommit\t${oid}\t\t\t\nrefs/heads/main\tcommit\t${oid}\t\t\t\n`;
  assert.deepEqual(parseRefInventory(raw).duplicate_ref_names, ["refs/heads/main"]);
});
