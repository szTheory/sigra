# Phase 254 approved preparation result

The approved amendment and both preparation invocations were executed. Candidate [run 40035537413](https://github.com/szTheory/sigra/actions/runs/40035537413) passed. Its authenticated browser reports retain all 105 product cases and 3 setup cases when compared with the retained original baseline reports. This does not supply the missing current baseline execution or a timing comparison.

Baseline [run 40035528418](https://github.com/szTheory/sigra/actions/runs/40035528418) concluded `cancelled`: `admin_checkpoints` and `design_gallery` reached their 30-minute job limits during `npm exec playwright install-deps chromium webkit`. Both were still downloading Ubuntu packages. Phoenix and browser tests did not start in those jobs. The reason for slow package transfers is not established. The aggregate browser check and `ci-gate` failed as required.

The failed baseline WebKit jobs used image `ubuntu24 / 20261023.334.3`; the candidate's successful WebKit jobs used `ubuntu24 / 20261012.334.1`. Per-owner image assignment is incompatible for three owners. Equal sets of image versions would conceal that difference, so the collector now checks images by the job doing the work. Logs, annotations, source bindings and raw files are preserved; see `RESULT.json`, `IMAGE-COMPATIBILITY.json`, and `FINAL-RECOVERY.json`.

This separate allowance is closed: 2 invocations, 0 retries, 202 actual HTTP requests, all requests within 60 minutes. The previous 2 failed invocations and 186 requests remain unchanged. There are 0 measured samples and no opened 48-hour window; all 40 measured invocations remain unspent. Neither requirement CISPEED-01 nor CISPEED-02 is accepted. Implementation is complete; comparison and whole-phase verification remain pending.

Local collector checks passed: 10 attempt/protocol tests, 48 metrics checks, 23 security tests, shell syntax and scoped whitespace checks. See `LOCAL-VERIFICATION.json`. No published workflow snapshot, main branch, timeout or required check was changed during closeout.

Next command: `$gsd-execute-phase 254`, conditional on resolving WebKit system-package installation and compatible runner images before another baseline invocation. An additional invocation needs explicit additional authority; the two spent allowances do not permit another retry. Diagnose that environment prerequisite within the existing plan; do not create another numbered repair plan or start Phase 255. No future notification was scheduled.
