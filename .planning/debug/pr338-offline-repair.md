---
status: fixing
trigger: "Phase 253: fix the five PR338 defects offline; preserve historical evidence and budgets; no CI"
---

## Symptoms

Expected: a published candidate contains the immutable inputs its tests require; browser contracts reflect actual commands and canonical URLs; generated docs match source; JSON receipts remain valid and failures save partial evidence.
Actual: PR338 run 39651372938 failed four root jobs, then receipt decoding failed after transaction 19.
Errors and reproduction: see ../execution/253-171-diagnosis/diagnosis.json and its original failure excerpts. All symptoms were supplied by the prior diagnosis; no further user interview is needed.

## Current Focus

hypothesis: five independent local defects explain the observed failures.
next_action: repair the five defects together, then test the assembled candidate offline.

## Evidence

- Entry tree clean at 33de9bc4a. Existing planning bytes are recoverable from that commit.
- Inspection corrects the inventory diagnosis: the two commands are selection (--list) and execution, not mutually exclusive branches. Both must own the same specs exactly once.
- No GitHub calls, CI launch, budget renewal or acceptance replay is authorized in this session.

## Resolution

Pending local implementation and verification. Plan171 remains halted and phase verification remains incomplete.
