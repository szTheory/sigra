# Independent Phase256 Source-Lineage Review — Revision02

**Verdict: REQUEST_CHANGES**

Revision02 resolves the prior producer rejection. The production producer and persisted readback now use the same exact base/final environment profile, and the new test exercises both paths with retained role content and the exact diagnostics projection. I found one remaining path-isolation gap: a symlinked `objects/info` parent is accepted even though the code claims to reject symlinked object-store paths. A local probe reproduced it.

## Reviewed identities

| Item | SHA256 |
|---|---|
| Cumulative revision02 patch, `revision02/LOCAL-FIX.patch` | `b99898446a7cb65785f1958476255c6432d068ea55dcbff08ddb3512bfb959be` |
| Incremental patch, `revision02/REVISION02.patch` | `eed0299e25f06e2aaf9d371e0ec02e2fc48ac97f2de3dcd2a403e32506310a49` |
| Reviewed `scripts/ci/ci-repaired-comparison.py` | `85e7dbf0c16fa2f33fd696b84945d53b2951f666e46dc61983d250938621dfc7` |
| Reviewed `scripts/ci/ci-repaired-comparison.test.py` | `e55906f820526b5953d6eaacb9048266e3a9869234b4e1f2c61c0c89244ab510` |
| Revision02 `LOCAL-FIX.json` | `ef29b08dcae34efc8062e58076e8f1913dc2da8bbf61da70037100751c3e2f97` |
| Revision02 `VERIFICATION.json` | `4ff61d6f266fa1d61b84690493d3142f668dae20b8892785bba807189a47d1a3` |
| Prior review, `INDEPENDENT-REVIEW.md` | `7d9bf8e70712a5c6e260f211e5812e68a2ec2a308fe8fc4be103d90d7772696c` |

The cumulative and incremental patch hashes match `LOCAL-FIX.json`; both reviewed file hashes match its revision02 bindings. The original retained source identities and evidence hashes are listed in the prior review and were unchanged for this revision.

## Findings

### WR-01: Symlinked `objects/info` escapes the checked object-store path

**Classification:** WARNING

**File:** `scripts/ci/ci-repaired-comparison.py:4001-4007, 5499-5503`; called reader `scripts/ci/ci_metrics_security.py:78-88`

**Issue:** The new directory handling rejects a symlinked `objects.git`, a symlinked `objects` directory in the bound reader, and a symlinked `alternates` file. It does not reject a symlinked `objects/info` directory. In that case `alternates.is_file()` follows the link, while `alternates.is_symlink()` is false for the regular file at its target. I reproduced `contract_git_reader` accepting an `objects/info` symlink to a directory outside the object store when that directory's `alternates` file contained the expected root object path. The producer/readback checks have the same parent-component gap. The bound reader validates the alternate once before its sequence of Git reads, so a local writer able to change the external target can also change the alternate list between validation and later reads. This violates the fail-closed symlink/alternate isolation expected for this source proof.

**Fix:** Validate every component from `objects.git` through `objects/info/alternates`, including `objects/info`, as a non-symlink contained path before use. Apply the same rule in the shared bound reader. Add a regression with a valid alternate file behind an `objects/info` symlink and assert rejection before Git reads begin.

## Re-check of revision02

- **Prior blocker resolved:** The shared `_phase256_verify_environment_profile` now runs in both `_phase256_fresh_preparation_verify_sources` and `_phase256_verify_selected_repair_blobs`. It accepts the exact pinned workspace report action and no longer has the earlier `RUNNER_TEMP`-only producer gate.
- **Final/base proof preserved:** The helper still pins each role's installed-main base, selected base blobs, and exact final blobs. The production producer and readback share the same check, avoiding drift between them.
- **Treatment and scope preserved:** The four-path treatment validation remains strict in production. The feasibility gate still requires one candidate ref update and zero control requests, mutations, and workloads. Source, tree, archive, helper digest, object-store root, and replay checks remain present.
- **Regression evidence:** The new test calls the production source-proof producer, checks its persisted receipt with readback, and uses projected retained-role bytes plus the exact Plan01 diagnostics patch. It mutates the actual action response while refreshing producer-supplied hashes; the pinned final profile rejects those changes. The fixture stubs Git transport metadata and does not create an actual Phase256 object store or source proof; `VERIFICATION.json` correctly records `actual_phase256_source_proof: false`.
- **Directory correction:** Using `required=False` is necessary because the object repository is a directory. The added directory and alternate checks fix the previous `is_file()` rejection; they need the additional `objects/info` component check described above to keep symlink isolation fail closed.

No source files were modified for this review. No network, GitHub, hosted workflow, commit, or measurement action was performed.
