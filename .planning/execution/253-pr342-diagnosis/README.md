# PR342: actual failure and local repairs

The approved repaired collector worked: draftPR342/run39711884498 completed with a failure, and the independent checker correctly refused it. Exact attempt bytes are committed at72103017d. The closed window used53requests and761seconds, created one PR, launched its automatic run, and performed zero dispatches/reruns. No old allocation was reused.

The library failure is reproduced against the actual tested workflow: an old exact `branches: [main]` assertion rejected the additional isolated docs-proof base. The repaired assertion still requires exact main membership. Production and actual docs variants pass4tests each; removed-main/mainish mutations each fail as expected.

The two hosted browser failures waited for LiveView connection on rendered pages. Local reproduction exposed a harness weakness: HTTP can respond before app.js exists because asset download/build runs asynchronously in watchers. The unmodified two cases pass once assets exist. The harness now builds assets synchronously before boot. Full local smoke passes8admin tests with its1intentional skip, plus confirmation and revocation journeys. No readiness selector, browser retry or timeout was weakened. The hosted server log is unavailable, so this does not prove the precise hosted socket failure or claim hosted repair success.

The full final local run used official esbuild0.25.4, supplied from a local cached tarball at the assets.build boundary to bypass npm metadata502. It ran real mix/assets/browser commands. Earlier local failure and diagnostic variants remain recorded. Unknown admin hook console warnings were observed separately and were not changed or claimed as the connection cause.

Lessons applied: test the generated docs workflow as well as the developer workflow; distinguish HTTP readiness from available client assets; keep ordinary development repairs inside172; preserve real hosted failures; do not start another proof window simply because an offline test passes. The7startup/guard tests passed before this attempt,10native contracts and full browser smoke passed after these product changes. Both CI requirements and whole-phase verification remain open.

Next command: `$gsd-execute-phase 253 --gaps-only`. Continue offline from these saved results. No new quick, automatic CI launch, budget renewal or completed172 summary.
