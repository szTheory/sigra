P=.planning/phases/253-fix-flaky-ci-and-preserve-required-checks; PF=$P/253-LOAD-RECOVERY-PR-MAIN-PREFLIGHT-R13.json; L=$P/253-LOAD-RECOVERY-PR-HTTP-LEDGER-R13.json; test -n "$(git log --diff-filter=A --format=%H -- "$PF")" && test ! -e "$L.lock" && S=$(git status --porcelain --untracked-files=all) && test -z "$S"
rc=$?; printf "VERIFY-EXIT %s\n" "$rc"; exit "$rc"
