# Phase253 load recovery — current source and installed SDK audit

Status: planning input, no native/application/setup/database/Playwright CLI/browser/GitHub command executed. Scope: new36–47 PLANs and NEW253-LOAD-RECOVERY support only. Existing01–35/evidence/Windows/config/shared tracking/product sources remain untouched by this planner. Full canonical prompt was materialized at /private/tmp/sigra253-load-planner-prompt.txt; unresolved template tokens are not authority.

Capture boundary supplied by root:28db5bb2f58ad790ff14e67e0c5f37fe6337ad4b; preservation capture6308a7815c6749746f029b92fbfaf1cc5c83edba covers424 exact recoverable planning paths. Current observed concurrent root HEAD:cb5340d381137d6efe7fc9fc585bd8e353052bcf; branch:phase-244-playwright-measurement. Root owns concurrent tracking; no branch switch. Unrelated dirty config remains unstaged with its prior exact blob/ref.

## Current implemented and missing code

| Current source fact | Concrete recovery owner |
|---|---|
|canonicalize.ts statically imports parse5; installed8.0.1 is ESM-only; Node20.18.1 transformed spec requires it and fails before any selected test|36 async native import and awaited existing writers, tested through actual pinned transform/spec collection|
|renderSha256 currently returns string; bundle.ts/writeBundleLocal synchronously consume it; these are the two current writers|36 update internal return types/callers and preserve canonicalization/hash manifests|
|Pinned Playwright1.59.1 config FullProjectInternal merges config.use/projectConfig.use/CLI use; spec has its own three-argument readiness helper and fonts contract|Preserve both facts; do not invent baseURL loss or ignored readiness arguments|
|registrationControls.mjs directly runs in opt-in callbacks, yet old source freeze omits it and canonicalizer|39 complete new tracked source closure, old frozen blobs retained|
|verifyNativeControlAttempt rejects any Demo Credentials header and all zero-byte logs, including legitimate marker/quietdrop|37 exact marker acceptance; independent query required before empty drop log allowed|
|runLoggedTree close handler clears escalation timer; current test waits1900ms and does not test resistant descendants|38 event/IPC teardown counterexample and bounded owned-group correction if demonstrated|
|ci-registration-recovery.test.mjs reads active acceptedEvidence/current phase/ref; repro.test.sh pins active freeze/head|38 temporary committed-tree fixtures and optional explicit saved-audit mode|
|New runner currently permits only CR-DARK-FIRST and creates historical243044/fourlaunch/fivespent ledger|39 new additive four-slot CLI with276453/fivelaunch/sixspent; legacy spent modes stay refusing|
|PR collector does not exist; verifier supports legacy/transport/preflight/canary, no pr/completion|42 creates callable modes/tests before final source freeze|
|HTTPS live allocation _validate_allocation caps max_requests117 and rejects extra fields|42 explicitly adds typed canary117 versus production120 purpose; no blanket ceiling relaxation|
|Publisher source_variants uses unregistered fixture path; verify_publication demands published-local-fixture origin and fixed refs|44 explicit registered-path fixture, actual-github origin/source verification, scoped frozen refs/docs publication|
|Old778be9 packing is stale; entire product delta must be regenerated after final code|44 recomputes complete path/mode/blob graph and<=24 projection before publication|
|15/18/19/20/26 implemented helpers remain source owners;27 halted and Task2/WINDOWS11 unrun|Reuse source;36–47 have no halted27 dependency and no historical pass synthesis|

Node20 native dynamic import is supported for ESM from CommonJS. See [Node20.18.1 module documentation](https://nodejs.org/download/release/v20.18.1/docs/api/esm.html#import-expressions). Whether the pinned transformer preserves the actual corrected expression is deliberately tested in36, not inferred from a successful test import using another runtime.

Installed Playwright code read:lib/common/testLoader.js loadTestFile(file,config,testErrors) registers/collects actual suite via requireOrImport and suite.allTests; lib/common/configLoader.js loadConfig loads full source config; lib/transform/transform.js requireOrImport/transformHook implement CJS/ESM handling. Resolve package root via installed package metadata; internal file read/use is version-pinned verification, never an edit to ignored runtime mirror. Offline collection runs Node processes only and denies actual runner/browser/app/network paths; --list/CLI is not used.

## Exact current tracked source hashes

| Path | SHA256 |
|---|---|
|scripts/ci/ci-registration-recovery.mjs|ba4ab52a3b4bda8ebc705f9343f9e1a236ec30e5d0d317a273980ea3a61dc3ba|
|scripts/ci/ci-registration-recovery.test.mjs|ad310fda7f96ab5b3d52143721af3f864242d566e10d30701fdaa28fab63dc56|
|scripts/ci/ci-registration-repro.test.sh|e31d046850580882260467c95efee609f58a846ac94a3bb83003eaf0dfb3f790|
|test/example/priv/playwright/lib/eval/canonicalize.ts|a7cb76ac8232e5018807f49c963e57f75cbf12c7b405a9b279d65caf3b2b8067|
|test/example/priv/playwright/lib/eval/bundle.ts|f74594785956f23dedb3c5a704ac379d8cf55e4676c1f0467026b3469c3d2649|
|test/example/priv/playwright/helpers/registrationControls.mjs|be0a9c0c747023841666bc05bdac6867bdd3ea42a7b0df3f50d7f936cf5d4f6f|
|test/example/priv/playwright/tests/admin-eval.spec.ts|50d4d65a03a3a9ab7ab7d32ebfe91376095f02ddf00ca778b8aceb6f861fb192|
|test/example/priv/playwright/playwright.config.ts|2c071469d70eb3f57e68aee223a9233fcc41d9264ced8c8fb3693337487b517e|
|test/example/priv/playwright/package-lock.json|fe47b376881df4fe68b5e91248f1d80d721adbbe4aad701a715acee8c6acd1f5|
|scripts/ci/ci-git-publication.py|2eafadc89e15171b98af22f348b02886b017c3b2eafda95b5c7c481bf93a7d54|
|scripts/ci/ci-hosted-transport.py|9a12fde8776950b6dde855c510bd786bb9028336b2a121fc173e47c7487d65c1|
|scripts/ci/ci-hosted-gate-verify.py|e575ca05249ce5e7a4dbcb17f49df45de62c4fb776c61c891827ef3016be396c|
|scripts/ci/ci-gate-canary.sh|55a340e8b0f10787168d92f44259bfeb278408d8feaf90501ff6f5a43435bcfb|

New not-yet-existing product executables/config/fixture paths are declared in Artifacts sections and created/tested before use. Existing named sources must pass git ls-files; ignored installed code is read-only runtime identity, not files_modified.

## Installed SDK behavior and future disposition

Runtime query observed @opengsd/gsd-core1.16.0. estimate-calibration observed factor1, applied:false, sample_count0, confidence:low; plan estimates use that factor/confidence. Graphify reports disabled; no graph dependency claim. Project skill directories contain no applicable SKILL.md.

plan-scan drops PLAN status:superseded, filters SUMMARY status:blocked from countable pairing, but counts halted/superseded summaries. plan-dependency-graph recognizes literal halted/blocked and computes transitive blocked_by. phase-plan-index requires summary completion on every dependency for readiness. A paired historical disposition does not erase blocked_by or make a failed plan execute successfully.

Installed execute-phase first skips has_summary:true, separately rejects blocked-and-incomplete, and only resumes full gates with no active filter and no unsummarized blocked responsibility.43 MUST test actual SDK queries and the installed has_summary-first filtering in temporary committed repositories; a failure to reach that route is a durable SDK blocker, not authority to alter old plans or invent a successful summary. It then prepares accepted-only responsibility mapping and root-only bundle; no disposition bytes during planning.

Current actual implementation11 of35; halted6 =02/07/09/12/16/27; unstarted/blocked18 =08/10/13/14/17/21/22/23/24/25/28/29/30/31/32/33/34/35. After actual12 recovery implementations and18 honest routing summaries,47 pairs exist while actual implementation count remains distinct and six historical halts stay literal. Both requirements must pass strict completion before root applies any eighteen-summary bundle.

| Installed SDK file | SHA256 |
|---|---|
|/Users/jon/.codex/gsd-core/bin/gsd-tools.cjs|4a2774598f6a1de9b63bbcbe71b4dff795b036fd061a80a3f2ab37a35bd63c3a|
|/Users/jon/.codex/gsd-core/bin/lib/plan-scan.cjs|11731a44cf7b1f3d8a7e0fa469425b3b4317598cf9118a97f976243a96f61d8e|
|/Users/jon/.codex/gsd-core/bin/lib/plan-dependency-graph.cjs|d0b053bdbe4fad0010b4adb95e2f55af786cb7c1bf3da036ed6302db5f7e5cbc|
|/Users/jon/.codex/gsd-core/bin/lib/phase.cjs|5906c52e9c03fabd189a08f4f0f9749b94fb22719124fe2ea528b6fee9d08f6d|
|/Users/jon/.codex/gsd-core/bin/lib/phase-locator.cjs|ba9c2ec24dbd5aaab115ce3406224ad75640b0093ab2e484ec2272892fbcf77f|
|/Users/jon/.codex/gsd-core/bin/lib/init.cjs|123feeaada39b2ebaa65290b16f15ca76868d7c32564567921d8da3d9667e500|
|/Users/jon/.codex/gsd-core/workflows/execute-phase.md|f80f810faa31b363a7859c7caa0556710b7d323b8aaca47b851d498c99aea752|

## Preserved failed27 identities

Native freeze SHA256:bef539ef0803a5e035266fd2d5334b02dc87893c285114e7f70cbec3b46a0778. Native evidence SHA256:e9982fd5a787777cc00defacd3b88ac41edfee21e08df5e62234e6dfe2319ab0. Actual33409ms and one CLI, no selected rows. Original preservation refs and raw report digest remain in the existing summary/closeout. Safe log marker never replaces absent test results or independent DB absence.

Old failed16 assessment preserves nine historical blob identities at35b49354050660a0f808291e2422de108834ef87;39 reads/verifies every exact commit/blob and native receipt readback. Failed27 source map has ten entries below but still lacks direct controls/canonicalizer dependencies:

| Historical failed27 source path | Git blob |
|---|---|
|scripts/ci/ci-registration-repro.sh|3a98aad5fe7b59753ceed5858012efcb00bf7f4e|
|scripts/ci/ci-registration-recovery.mjs|572fd804c91d05f7d3e40c40977a7302ca4d1af3|
|scripts/ci/ci-registration-recovery.test.mjs|6a7e243fdc4fadcf871574a4870bc63a26408dac|
|scripts/ci/ci-playwright-report.mjs|51cfe7d0f600477a100ac45eeb61becb0f75e749|
|test/example/priv/playwright/playwright.config.ts|96ac3495464c36fdfcc604f99c130aee12f289b0|
|test/example/priv/playwright/tests/admin-eval.spec.ts|b9c3e564918699599ef89cb65cface046761d195|
|test/example/priv/playwright/helpers/adminFlows.ts|ddf7dbf5df0d6c2350af6f72741ce318fa50b16e|
|test/example/priv/playwright/package-lock.json|c429e4a05fb5606a7fbc9d128a2d46af068c50f5|
|test/example/mix.lock|1a7d84c08459b3911da3899ec36a9282430750b4|
|.github/workflows/ci.yml|072a1ea3793213309d89f0c46d75810c6b7df341|

## All original35 PLAN identities

These hashes are inventory; recovery copies are root's verified capture/commits/refs. Inventory hashes alone are not preservation copies.

| Original plan | SHA256 |
|---|---|
|253-01-PLAN.md|9a8e18eceb01e13db0589855c2a1243f697d268b70f07ee073de90ddd9b24b63|
|253-02-PLAN.md|ca9a7ca565420322972f5a843029efef01eb20c39135d37ef52c0dc3f9115b45|
|253-03-PLAN.md|25e2226bd83cbf57dc144731d373678018e7da6a174a6168504c6d621e499f0c|
|253-04-PLAN.md|7d66cf40623446642aac5ccc53e17660ca13d3e25dee1f7b208bb0177ac22e0a|
|253-05-PLAN.md|96d9b8ae67f3a628bc6eff8dde8974040f635b6d48a6f19cb1ab9eb59f29ec44|
|253-06-PLAN.md|6e83d388d66dbeea4beebd21dd1ecd73034824dd6450514ed134fedc4661f37a|
|253-07-PLAN.md|91cb5172420d002cec86cbd1603be5b0f6b9187db367a8512d93f4aba17ca15f|
|253-08-PLAN.md|a65884a70992d6261e609cac731f90d357fc4395c0cadecbb762bb05a3601468|
|253-09-PLAN.md|d86806b9dfa929bb19a29c907582d1212900d2b91a4e051f6286628f0d1edca4|
|253-10-PLAN.md|c3b6240b1c95bd65448f68fc7d5d54e0ba70b90d766380889402758b61240f34|
|253-11-PLAN.md|ba051a82d5145b2cce491d3e4800417b03012244bb41a0ecd57c3fe47ad8d01b|
|253-12-PLAN.md|6db2445f21d793e5a651b673a0150d01f691211ed74a8d42054666a4ee69ab33|
|253-13-PLAN.md|16c458406ca333eac6db2d8150c36734c53063dbcad37177064b534fedc5ae33|
|253-14-PLAN.md|ce6cdcb30bf9472b1849df30cc2777dff7dd59cbce40486d82d0244378989cc9|
|253-15-PLAN.md|823b401f191adc8ab102e8b392a4495410dbe5fcb49d4ac53606dd62ab42c7bb|
|253-16-PLAN.md|cc57e323b81d242597c86541cde3f47ebb40a66e8ee4153f7382770f30fc37de|
|253-17-PLAN.md|74b8a8d0ed6de9b00d5c562ab6f458973d7136a56a5655f1e3edf2edb9c5b188|
|253-18-PLAN.md|c4696a34cd2ec299f19c900ccd9a37d38fcbc01b9bcb3b683663d41780f075da|
|253-19-PLAN.md|22be54dca53ae084c597cfd03054f411bac820df69bf2e6ec72a761e79cf035e|
|253-20-PLAN.md|b6e5cb64d7fff979e95f991529b6a431d4f660b5555dcbc7342248a1bb66f773|
|253-21-PLAN.md|dd2a668631568a9bb7857c2c50ef3a3747f35e5140fb3e1446202fd9af2607b5|
|253-22-PLAN.md|fe1b86e2bc5b1bdae9be3c2a0bed8213d7e7f6dd93d51346acbb8aa833588a91|
|253-23-PLAN.md|77d98a1aeddb9d9902c7093fdd1bb7c4d2f461bac797a3724d080de5b5a395dd|
|253-24-PLAN.md|d868523f6df3bd2ac6b52a780b8425741dcd6e91580ed3bc650ff87ab9107690|
|253-25-PLAN.md|be7b7480209289e398ef0107c986a6606c33a045fb5baf8d6cab24ae12829039|
|253-26-PLAN.md|405898075dae27c4d8c5362ddbee577ab75e3d35998142e737b54a6fa76d660d|
|253-27-PLAN.md|544c1f36977ead7ee4b19c78d082cc212ef106b2a6d6e02c8741c859d03befd4|
|253-28-PLAN.md|15d82c6c7c01dd97b7a875c2f7acef1a0e93f3cee691ce523b43bddd525516b4|
|253-29-PLAN.md|44d38222cbcd94d4baea4837a3beca5768634118a668def2b44b372eae920000|
|253-30-PLAN.md|d0b8b29d1bc854065e92fa745dc361d448d627c1b859d0490d0450e1187ee2a3|
|253-31-PLAN.md|6845a9040d4e34d313b161198bebd84862558e4fb3a4875f203ac7678c4cbaa0|
|253-32-PLAN.md|e66c3a6258914addf2c7b89155ea7e75aab05c758f68a986a85b3dfc4606ff11|
|253-33-PLAN.md|c527d8b0ac01d55185b9abf1c4431de8ecd7885aec2facc06c5c52c4088e2f7d|
|253-34-PLAN.md|b491e3d894dcd8670bd6c5084f5bc07c56a7a2041075f384e79e99a4c527f86d|
|253-35-PLAN.md|1a98efdc8df0575e5e0aa75205344f116572e4cd8197caef49e36c7c5cc951b9|

All originals were read for recovery responsibility coverage. New plans are append-only; original existing hashes are checked against capture before final planning commit.

## Scope and routes

No external product API integration is added. Existing GitHub evidence transport capability coverage in canonical COVERAGE.md is retained unchanged;42/44 finish its already authorized proof modes. No ORM/schema/public auth/generated host/UI change. Preserve sg-* and admin contracts if actual future cause would touch UI; such a cause outside this internal harness scope remains an explicit blocker.

Implementation command after planning/review: $gsd-execute-phase253 --gaps-only. After accepted implementations and root's exact disposition application/final index: unfiltered $gsd-execute-phase253 for security/code review/Nyquist/regression/goal verification. phase.complete only after actual pass. Only then inspect Phase254 readiness/context before naming its discuss/plan/execute route; do not start254 in recovery.

