# Browser controls verified; final phase verification is unblocked

The previous handoff incorrectly treated the old Plan16/control-recovery halts as the latest control result. Plan83 completed the later R5 proof. The existing read-only verifier reopens the preserved accepted R4 first window and all three R5 second windows, including their native reports, traces, source identities and database receipts. It passes now.

`controls.json` independently checks those reports: 22 rows across desktop, mobile and dark projects. Thirteen positive rows passed. Nine deliberate negative rows failed in the intended way and retained their traces; they are never relabeled as native passes. Each fresh second-window database had zero copies of the collision account before registration and one afterward. Passing second-window controls retained no traces. The existing verifier checks the original assertion details and sanitized trace contents.

The tested registration spec, helpers, recovery config, authentication code, schema and dependency locks match product `a87664733` byte for byte. Relevant later differences are the CI reloader setting and the HTML report output directory. The new setting has its own regression/counterexample evidence, nine fresh targeted passes and 108 ordinary integration passes. Moving the HTML directory does not change test bodies, transport holds or trace retention. Repeating these completed controls is unnecessary.

Fresh offline checks revalidated the nine targeted results, 108 integration results, six hosted canary outcomes, normal PR343/docs PR344 and unchanged gate inputs. Forty-eight unit contracts pass; configuration tests pass with seeds101/202/303 (three each). No app, database, browser, CI run or GitHub request was started by this review.

## Why final verification was stuck

Seventy-three never-executed recovery recipes still had active PLAN frontmatter. GSD therefore skipped them as blocked by old halts and could not reach final verification. They are now explicitly `status: superseded`, with original paths, Git blobs, hashes, objectives and replacement evidence in `RETIREMENTS.json`. Their exact original bytes remain at `de9bccb356087b11cebade820c612b5cd5c1b5ca` and were read back immediately before editing.

These instructions were retired, not executed or declared successful. No SUMMARY was invented. All 29 failed attempts and their records remain unchanged. No old approval, acceptance allowance or browser budget was reopened. The complete historical inventory remains 183 plans: 81 completed implementations, 29 halts and 73 retired unused recipes. The active index contains 110 summarized historical records and zero incomplete plans.

The final verifier must still assess the current evidence against both original requirements. CIREL-01 is not marked complete by this review. The controlled loader/reloader counterexample reproduces the original module error; the original hosted schedule remains inferred, not traced. Older frozen acceptance readers and stopped attempts retain their original outcomes. No new no-flake claim or waiver is made.

## Exact next command

```text
$gsd-execute-phase 253
```

Use the unfiltered command. `--gaps-only` finding no matching plans exits before verification. Fresh `init.execute-phase` and `phase-plan-index` now show zero incomplete or runnable plans, and the verification owner routes the missing report to execute-phase. It can proceed through its normal final security, code-review, regression and verification gates without dispatching another plan. Phase253 is not yet verified or marked complete.

Phase254 readiness was checked: pending, with no context, research or plans. After actual253 completion, recheck it before `$gsd-discuss-phase 254`. No later phase has started.
