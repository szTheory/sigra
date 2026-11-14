# Independent Phase256 Source-Lineage Review

**Verdict: REQUEST_CHANGES**

The final-blob/base-profile proof is a sound replacement for the inherited-delta signature check in the readback verifier, and the four-path treatment check remains strict. The complete production source-proof producer still has a stale `RUNNER_TEMP`-only check, so it rejects the actual retained action blobs before it reaches the corrected readback verifier. The new focused test does not invoke that producer path.

## Reviewed identities

| Item | SHA256 |
|---|---|
| Submitted patch, `LOCAL-FIX.patch` | `3ba700ddf03304510ea69f17eef50ecb45baf79b438173aa81b8a36cf0322a75` |
| Reviewed `scripts/ci/ci-repaired-comparison.py` | `92586714e02fb8d9648863a9fc03b9acd54192136c77df6dc566c9f1f3e416d7` |
| Reviewed `scripts/ci/ci-repaired-comparison.test.py` | `ca79aaa29711828ce6aa785c10484f16dfc4eca6070d91c4bdd4a4ea63408115` |
| `LOCAL-FIX.json` | `705a343243c5b159640534992cebbb8f3545e2997dd6986d64eaf91f6044312c` |
| `PROOF.json` | `66db2bc9b8b30d615e9ceb83e7c76aa2d05038344a93686e8fe1d18d23384992` |
| `SESSION.md` | `ef8db8aa41d2d285e351c60b1b8747d5841c079cd7acc7db642249855e13bf79` |
| `READY-SOURCE.json` | `10f6426ea3067b9f5db72f842557cc29da9fc578422a3c90fdbbdebf5ee6b2a3` |
| `READY-SOURCE.patch` | `c20a9f16392201288a2fc1da3a5e0b3f750984fc237f2b800d75d6ead6ba98d2` |
| Retained Plan10 `PREP-CONTRACT.json` | `3958ff1e364649378c64fa547d29928f542343e200a7962d3c09237d38097416` |
| Retained `SOURCES.json` | `020d05b2fe9cf6b2a378c000296b9ffde7bce6dabb88adb973aa2d12f0609e6d` |
| Retained `common.patch` | `aa2fecc41f3bff8ac327b662a170259cd5415ed186ecc8fd60e4ef298398ac86` |
| Approved `treatment.patch` | `4671882c00c31a8405db2ba41a786235d132a2e806cff306d2176921bf4e9c83` |

The reviewed retained role commits were candidate `856c02bbd0dac83a29e388a0644d0fd51839b38f` and control `de7d80d67de7c9f57e0a67cff90b36620c384f01`, both based on `970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d` in the pinned Plan10 contract.

## Findings

### BL-01: Source-proof producer rejects both retained action blobs

**Classification:** BLOCKER

**File:** `scripts/ci/ci-repaired-comparison.py:5644-5650` (test gap at `scripts/ci/ci-repaired-comparison.test.py:1814`)

**Issue:** `_phase256_fresh_preparation_verify_sources` still requires the action text to contain `--report "$RUNNER_TEMP/playwright-os-deps.json"` at line 5647. The exact candidate and control action blobs instead pass `--report "$GITHUB_WORKSPACE/test/example/priv/playwright/artifacts/ci-setup/os-deps.json"` (both have that invocation at lines 177 and 180). The exact Plan01 diagnostics patch modifies only `.github/workflows/ci.yml` and `scripts/ci/ci-diagnostics-canary.test.py`; it does not change either action blob. Therefore the producer raises `phase256_environment_repair_hunk_missing:<role>` for these source roles before it creates `SOURCE-CHECK.json` or calls the corrected `_phase256_verify_selected_repair_blobs` logic. The later readback check's support for both report layouts does not make the source proof producible.

The new positive test builds a projection from the real retained role blobs and applies the exact Plan01 diagnostics patch, but at line 1814 it calls `_phase256_verify_selected_repair_blobs` directly. It never executes the producer's environment gate, which is why this deterministic rejection is not covered by the passing focused test.

**Fix:** Make the producer's environment validation use the same exact final action/workflow profile as the readback verifier and accept the workspace report path when the pinned diagnostic capture verifies it. Add a regression that executes the production producer path against both projected roles and asserts it writes the bound source check; keep the missing/altered path cases rejected.

## Review of requested proof properties

- **Final-tree and installed-base assurance:** The new verifier requires the role base to equal the pinned installed-main SHA, checks all eight selected environment blobs against that base, then checks every final role blob against an exact expected hash. The three workflow/action/phase232 test blobs that differ from the base are pinned per role; the remaining selected environment blobs stay pinned to the base profile. This is more precise than requiring the historical composite patch's old additions and deletions to appear in a later diff. I independently checked the raw base and retained-role blob hashes; the post-diagnostics final hashes are pinned in the production code and the positive fixture constructs them from the retained role blobs plus the exact patch.
- **Candidate-only treatment:** The production verifier still checks the complete source diff's changed-path list against exactly the approved four paths and compares the changed-line signature with the approved treatment. The retained candidate/control diff itself contains exactly those four paths. The diagnostics patch is applied to both projected roles, so it does not add shared diagnostic changes to the candidate-only treatment.
- **Sources, store, helper, and limits:** The patch leaves the exact source/ref/tree/archive checks, bound object-store checks, helper digest and replay checks, and the one-update/zero-control-preparation-I/O feasibility checks in place. I found no weakening in those checks in the submitted diff. The current Phase256 artifact still has no new source store or source commits, so this review does not certify a generated Phase256 source proof.
- **Workspace report layout:** The retained action blobs and diagnostics capture evidence justify accepting the workspace report path alongside the runner-temp layout. The inconsistency is in the producer's stale single-layout predicate, not in that evidence.
- **Counterfactual test quality:** The blob mutations change bytes from the real retained source content and refresh the supplied hashes before checking that pinned content rejects them. That is a meaningful final-hash guard test. Its limitation is the missing production-producer call described in BL-01.

No source files were modified for this review. No network, GitHub, hosted workflow, commit, or measurement action was performed.
