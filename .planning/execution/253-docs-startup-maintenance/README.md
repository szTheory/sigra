# Plan172: collector startup repair

The approved docs-only attempt stopped after one rate-limit read. No refs, PR or CI run were created. Its exact files are committed at43b661d2b; approval at8b95471e1 records the literal answer `yeah i approve`. That window stays closed.

The publisher used a bare `import execution_guard`. The operator's Python process inserted the runtime folder into its import search path, so its offline check succeeded. The real collector uses Python stdin inside a shell subprocess and had no such search path. Its approval check therefore failed before collection. The actual preserved command output names ModuleNotFoundError.

The replacement bundle loads the guard by the publisher file's exact sibling path. It preserves sourcea6838a8f9, checker63feb218d, all existing objects and refs, the original canary matrix and normal PR341 results, every historical halt and all closed allocations. Only the missing docs-only proof may run, under a separately approved window with the same120-request/60-minute limits, one draft PR, zero dispatches and zero reruns.

Seven tests pass. The added regression launches the actual shell from an unrelated working directory without PYTHONPATH. It reproduces the old import failure. It then invokes the replacement collector, reaches the request guard, and proves no ledger transaction or publication receipt exists. Existing legacy approval is used only to exercise the offline section validator; the new request guard rejects it for live execution. The replacement operator now invokes that subprocess regression before creating any allocation, including on --run. Its unapproved --run also stops before creating runtime state.

Lesson: a successful in-process helper import does not test a shell subprocess's Python imports. Preflight must exercise the same process boundary as the actual execution. Tests must cover that boundary before opening a once-only window. Retain successful evidence rather than rerunning canaries and the normal PR after a local harness failure.

Current status: implementation repair verified offline; Plan172 missing its actual docs-only hosted result; Phase253 verification not started. CIREL-01 remains partial_not_reproduced; CIREL-02 remains unaccepted_missing_docs_only. No new quick task or numbered plan was created. After approval of the replacement request, continue `$gsd-execute-phase 253 --gaps-only` inline.
