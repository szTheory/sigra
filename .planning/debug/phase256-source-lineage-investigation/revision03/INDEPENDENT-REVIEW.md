# Independent Phase256 Source-Lineage Review — Revision03

**Verdict: APPROVE**

Revision03 closes the remaining symlink-parent gap. The source producer and receipt reader validate the object-store layout before discovering root objects, and the shared Git reader validates it on construction and again before every Git command. The regression covers all three mutable components and confirms invalid layouts fail before transport.

Approval is limited to the reviewed source-proof implementation and its offline retained-source fixture. No actual Phase256 source store or `SOURCE-CHECK` was created or verified, and no hosted action or measurement was authorized or performed by this review.

## Reviewed identities

| Item | SHA256 |
|---|---|
| Cumulative revision03 patch, `revision03/LOCAL-FIX.patch` | `80e77f49db28e2fe824cd0f0ab091df86dd71d3dc36bb52ab8a449bd9a82983d` |
| Incremental patch, `revision03/REVISION03.patch` | `5d614f479975f501a7a6a7d9d3a6f5066c7070f918c3e27e0f0d4d27cbcee1d3` |
| Reviewed `scripts/ci/ci-repaired-comparison.py` | `536e2eb198d72c70c91a3a303ffbb991292807291182ac6357bde6e37ab40850` |
| Reviewed `scripts/ci/ci-repaired-comparison.test.py` | `b7b5951434855642ed2a2a1a6fa4a11ae864dc5c310ee854108c34cf4ede4251` |
| Reviewed `scripts/ci/ci_metrics_security.py` | `d634b587e15d6f12801a91d127bea94503d0912450428a098eba22d69a85a8fe` |
| Revision03 `LOCAL-FIX.json` | `05f4a337a456ddbde96d975a541fb9e7738eec0935607b547a8710d569db0047` |
| Revision03 `VERIFICATION.json` | `f07e47f105ed1d49af628665b2257522cd8ac345db9fc8a49a9afa241064109a` |
| Prior revision02 review | `dc443d4c1e460de7543e9bb013cb6ffd8f08ee5d07deb0041356e510b631fbd7` |

The cumulative and incremental patch hashes match the revision03 identity record, and the reviewed source hashes match its file bindings. The earlier review artifacts remain unchanged.

## Findings

No current BLOCKER or WARNING findings remain in the reviewed Phase256 source-lineage changes.

## Review evidence and limits

- **Symlink and alternate isolation:** `contract_git_alternates_path` checks that `objects.git`, `objects`, `objects/info`, and `objects/info/alternates` are the expected directory/file types, resolve to themselves, are not symlinks, and remain inside the object repository. The Phase256 producer and persisted-receipt reader call it before root-object discovery. `contract_git_reader` calls it when constructed and before each Git command, then checks that the alternate file still names only the expected root object directory.
- **Regression coverage:** The producer/readback fixture tests symlinked `objects`, `objects/info`, and `alternates` at each Phase256 entry point, checks zero intercepted Git transport for those invalid layouts, and tests mutation after a bound reader has been created. The normal path still seals and reads back the retained-role projection. The revision02 reader fails against the new symlink cases; the fixed reader passes; removing the layout guard causes the regression to fail.
- **Source-proof behavior:** The shared exact environment base/final profile still runs in both producer and readback. Candidate-only changes remain restricted to the four approved paths; source, tree, archive, helper, and one-update/zero-control-preparation-I/O checks remain intact.
- **Verification boundary:** The retained-source fixture stubs immutable Git transport metadata and uses exact projected bytes; it does not create an actual Phase256 object store or source commits. `VERIFICATION.json` records `actual_phase256_source_proof: false`. The object-store inventory integration was not run because it creates Git objects, which was outside this review's scope.

No source files were modified for this review. No network, GitHub, hosted workflow, commit, Git object creation, or measurement action was performed.
