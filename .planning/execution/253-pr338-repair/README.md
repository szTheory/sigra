# PR338 offline repair

All five diagnosed defects are implemented in `16800f4319cdd0e2554938071d4ebc48caa969ac` and verified locally. No CI was launched and no GitHub requests were made by this repair.

The assembled candidate contains all 1,485 product paths with the exact modes and blob identities in that commit. Its full library suite passed (2,656 tests, 33 doctests, three properties), its metrics tests passed (48 shell checks plus four diagnosis tests), and its generated docs match the indexed output. The local audit browser regression passed with retries zero. Transport, publisher and PR collector suites passed 87, 125 and 111 tests. repair.json binds the logs and all counts.

The initial assembled tree exposed an additional consequence of the missing-input defect: the original 3 MiB baseline and 25 MiB archive cannot fit the unchanged upload limits. The self-contained metrics fixture retains exact original member bytes and their hashes, has a deliberately non-acceptance status, and preserves the same failure and tamper assertions. The six smaller immutable historical files are copied with checked hashes. The repaired candidate projects 19/24 publication requests and a largest tree body of 2,092,801/2,097,152 bytes. This is an offline projection, not a new allocation or approval.

The earlier diagnosis incorrectly called the two browser commands mutually exclusive branches; they actually record selection and then execute it. Both are now checked separately.

The example app's broader precommit command stops at an existing `/dev/mailbox` route warning. The temporary candidate directory initially selected Python 3.9, which cannot parse these saved timestamp precisions; the same candidate passed with Python 3.14. These are recorded separately and were not hidden or converted into CI results.

Plan171 remains halted at 19/120 requests. All original receipts, placeholders, budgets, summaries and Plan179/180 evidence remain byte-identical. Plan172 and phase verification are still incomplete. The next action is a proposal for hosted proof of the repaired source, requiring a fresh explicit source/approval decision. Do not resume a closed runner or reuse the old canary for this changed source.

Next command:

```text
$gsd-quick "Phase 253: prepare a hosted-proof proposal for repaired source 16800f431; preserve PR338 halt and all closed budgets; do not launch CI"
```
