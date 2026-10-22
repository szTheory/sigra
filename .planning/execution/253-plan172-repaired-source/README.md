# Plan 172: repaired source, smallest remaining proof

PR341 passed on the older code. PR342 failed. The latest repairs change the asset-build harness and a library assertion, so a new docs PR cannot be paired with PR341 under the existing exact-source rule. The regression here rejects that combination.

The prepared objects contain the exact product bytes from `5e13621e5`. The new normal candidate is `c8443e2bd9576bb0284d6c78a7212659a5af85fd`; its docs base is `4524f17e1b791dd4d2c2ae597c053a8e37e8095e`; its docs head is `a4c2b64119fa89ada8a6dbbe1f729a24fb6bfc21`. The packed objects have been imported into a disposable Git object store and read back. The docs base changes only the branch filter; the docs PR changes only one guide. Nothing was published. The known main parent has not been checked against GitHub.

Recommend one new normal/docs pair on this repaired source. Keep the old canaries with their actual original identities. All six gate inputs, including the recorder's imported report module, are byte-identical; every verifier statement except the reviewed PR comparison repair is unchanged. Mutation checks reject a change to any gate input or the canary verifier. This supports keeping the old gate-behavior results without another seven-run matrix. An independent consumer must enforce this comparison when combining the results; this file alone grants no acceptance.

`proposal.json` lists the exact candidate refs and proposed actions. The runtime operator, guards, frozen collection input and end-to-end offline startup tests still need to be assembled. This is an offline proposal, not an executable approval bundle. No approval is pending; no budget or CI permission was renewed.

The original registration failure is still not reproduced. Even two green PRs would leave that requirement open. The 29 historical halts and 73 blocked plans also remain visible. Keep these separate from fixing the two PR342 failures, so another green run is never mistaken for whole-phase completion.

Next: `$gsd-execute-phase 253 --gaps-only`, continuing the same Plan172 offline to finish its executable paired-proof bundle. Do not create a quick task or another plan number. Preserve Plan179's receipt, Plan180's history, prior outputs and closed limits.
