# Repaired local ledger preservation: same paired PR action

The prior exact bundle stopped after one read-only rate-limit request; no refs, PRs or CI were created. Its result is preserved at afe01a308. The writer could not create its recovery ref under the filesystem sandbox. An offline reproduction also proves that inheriting the temporary candidate object store would lose recovery bytes after cleanup.

The new local adapter always stores recovery blobs and refs in the permanent repository object store. A real dirty-ledger write and byte-for-byte read-back must pass before allocating a window or making any HTTP request. Execute with permission to write Git metadata. Regression tests cover repeated ledger writes, cleanup of the temporary object store, denied ref writes, and the actual operator ordering.

The product source5e13621e5, candidate and three proposed refs are unchanged. Publish three create-only refs, open two draft PRs, collect their two automatic CI runs. Zero dispatches, reruns, merges or canary runs. Both PR families must use the same exact source freeze. Main/ref checks precede writes.

Proposed new limits:23 publication requests and120 shared PR requests,60 minutes each. The previous attempt used1; total remains at most144 across it and this continuation. The actual prepared publication sequence still uses15. Every prior window remains closed. Rate budget must exceed250;403/429 stop immediately. One collector per run polls at60 seconds.

Fresh approval is required because the prepared code and bundle hash changed and the once-only previous run is closed. Plan172 requires approval of the exact bundle; the execution skill requires preserving checkpoint handling. Record the new literal answer and hash in the two approval templates, commit them, then run once. No user approval exists for this new hash. Even a successful pair leaves CIREL-01 not reproduced and Phase253 incomplete.
