import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";

const OPERATOR = "scripts/maintainers/prune-stale-branches.sh";
const COMMIT = "1".repeat(40);

test("verify-prs recognizes explicit current-contract mode and rejects a missing pair member", () => {
  const result = spawnSync("bash", [
    OPERATOR,
    "verify-prs",
    "--current-contract-commit",
    COMMIT,
  ], { encoding: "utf8" });

  assert.notEqual(result.status, 0, "a current contract commit without its path must block");
  assert.match(`${result.stdout}\n${result.stderr}`, /current_contract_(?:path|pair)_required/i);
});
