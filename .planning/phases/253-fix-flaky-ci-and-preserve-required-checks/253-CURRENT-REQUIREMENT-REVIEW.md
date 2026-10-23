# Phase253 current requirement review

CIREL-02 is complete. Retained normal PR343/docs PR344 and six hosted fixture outcomes establish useful required work and non-green failed/missing work. Gate inputs are unchanged. No hosted rerun is proposed.

CIREL-01 remains incomplete. The original registration crashed before account insertion because Ecto.Queryable was unavailable. A controlled real-reloader/OTP-handler interleaving reproduces that exact module error;the original hosted schedule remains inferred. Fix a87664733 disables unnecessary CI hot reloading. Configuration regression/negative control,compile/endpoint inspection and nine fresh targeted browser passes establish the implemented fix and targeted validation.

Normal browser integration has not run on this fixed source. The earlier normal PR predates it. The prepared integration bundle freezes108tests across five existing PR groups,including three design authentication setup cases. Thirteen runner tests and43 existing unit contracts pass;three configuration tests pass with each seed101/202/303. No browser,app,database,CI or GitHub request ran in this preparation.

The new proposal permits at most five fresh group invocations,once each,zero retries,first-failure stop,3600seconds including cleanup and1800seconds per group. It is not approved. Prior nine-run permission is consumed;all older stopped attempts/expired slots remain unchanged.

The normal library/gate source is unchanged relative to5e13621e5;the only product differences are development endpoint configuration and its new regression test. That new test has direct scoped coverage;no fresh full mix ci/hosted result is claimed.

D-08/D-09/D-10 readiness,isolation and trace browser controls remain separate missing proof. Plan16 and its control-recovery receipts remain halted. Passing ordinary integration and unit checks cannot close them. Canonical phase verification also remains missing.

Current bundle:`.planning/execution/253-registration-integration/README.md`;checks:`CHECKS.json` there. Targeted result:`.planning/execution/253-registration-postfix/RESULT.json`;actual evidence eb2e23a14. Exact prior review and all earlier history remain recoverable at 6a0b66f014e4b51ff6d3ca6cf43de8459d0a1ca5;hash/read-back in integration/prior-state.json. No new numbered plan or old budget change.

Next after an explicit decision approving the exact integration proposal:`$gsd-debug continue phase253-registration-timeout`. Phase254 readiness was rechecked:pending,no context/research/plans. After actual253completion,recheck before `$gsd-discuss-phase 254`.
