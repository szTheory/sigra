---
status: resolved
trigger: "Phase 253: fix the five PR338 defects offline; preserve historical evidence and budgets; no CI"
---

## Symptoms

Expected: a published candidate contains the immutable inputs its tests require; browser contracts reflect actual commands and canonical URLs; generated docs match source; JSON receipts remain valid and failures save partial evidence.
Actual: PR338 run 39651372938 failed four root jobs, then receipt decoding failed after transaction 19.
Errors and reproduction: see ../execution/253-171-diagnosis/diagnosis.json and its original failure excerpts. All symptoms were supplied by the prior diagnosis; no further user interview is needed.

## Current Focus

hypothesis: five independent local defects explain the observed failures.
next_action: prepare a source-specific hosted-proof proposal; do not launch CI.

## Evidence

- Entry tree clean at 33de9bc4a. Existing planning bytes are recoverable from that commit.
- Inspection corrects the inventory diagnosis: the two commands are selection (--list) and execution, not mutually exclusive branches. Both must own the same specs exactly once.
- No GitHub calls, CI launch, budget renewal or acceptance replay is authorized in this session.

## Resolution

Five fixes implemented at 16800f4319cdd0e2554938071d4ebc48caa969ac. All scoped local checks passed; see ../execution/253-pr338-repair/repair.json for exact output, candidate parity, limits and the unrelated precommit warning. Plan171 remains halted and phase verification remains incomplete.
