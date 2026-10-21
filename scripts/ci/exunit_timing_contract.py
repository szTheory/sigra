"""Validate source-bound ExUnit reports emitted by the two mix ci invocations."""

EXPECTED_REPORTS = {
    "main": "ci-exunit-timing-main.json",
    "threadline_guard": "ci-exunit-timing-threadline-guard.json",
}
RESULTS = {"passed", "failed", "skipped"}


def _nonnegative_count(value):
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate(metadata, reports, artifact_names, run_id, attempt):
    diagnostics = []
    expected_metadata = [
        {"invocation": invocation, "path": filename}
        for invocation, filename in EXPECTED_REPORTS.items()
    ]
    if metadata.get("exunit_reports") != expected_metadata:
        diagnostics.append("exunit_producer_report_contract_missing")

    expected_artifact = f"library-test-timing-{run_id}-{attempt}"
    if metadata.get("timing_artifact_name") != expected_artifact or any(
        artifact_names.get(invocation) != expected_artifact
        for invocation in EXPECTED_REPORTS
    ):
        diagnostics.append("exunit_timing_artifact_not_bound_to_library_job")

    normalized = {}
    summaries = []
    rows = []
    for invocation in EXPECTED_REPORTS:
        report = reports.get(invocation)
        if (
            not isinstance(report, dict)
            or report.get("complete") is not True
            or report.get("unit") != "microsecond"
            or report.get("invocation") != invocation
        ):
            diagnostics.append(
                f"complete_exunit_{invocation}_timing_missing_or_wrong_invocation"
            )
            continue

        report_rows = report.get("tests")
        if not isinstance(report_rows, list) or any(
            not isinstance(row, dict)
            or row.get("invocation") != invocation
            or not isinstance(row.get("test_id"), str)
            or not _nonnegative_count(row.get("duration_us"))
            or row.get("unit") != "microsecond"
            or row.get("result") not in RESULTS
            or row.get("duration_us") < 0
            for row in report_rows
        ):
            diagnostics.append(f"exunit_{invocation}_test_identity_invalid")
            continue
        if not report_rows:
            diagnostics.append(f"exunit_{invocation}_report_empty")
            continue

        counts = report.get("counts")
        count_keys = ("passed", "failed", "skipped", "excluded")
        if not isinstance(counts, dict) or any(
            not _nonnegative_count(counts.get(key)) for key in count_keys
        ):
            diagnostics.append(f"exunit_{invocation}_counts_invalid")
            continue
        row_counts = {result: sum(row["result"] == result for row in report_rows) for result in RESULTS}
        if any(counts[result] != row_counts[result] for result in RESULTS) or sum(counts.values()) != len(report_rows) + counts["excluded"]:
            diagnostics.append(f"exunit_{invocation}_counts_do_not_match_rows")
            continue
        aliases = {"passed": "passed", "failed": "failed", "skipped": "skipped", "excluded": "excluded"}
        if any(report.get(f"{key}_count") != counts[value] for key, value in aliases.items()):
            diagnostics.append(f"exunit_{invocation}_count_fields_mismatch")
            continue
        if not _nonnegative_count(report.get("suite_elapsed_us")) or not _nonnegative_count(report.get("run_us")):
            diagnostics.append(f"exunit_{invocation}_duration_units_invalid")
            continue
        if not _nonnegative_count(report.get("test_duration_sum_us")) or report.get("test_duration_sum_us") != sum(
            row["duration_us"] for row in report_rows
        ):
            diagnostics.append(f"exunit_{invocation}_duration_total_mismatch")
            continue

        normalized[invocation] = report
        summaries.append(
            {
                "invocation": invocation,
                "tests": len(report_rows),
                "passed": report.get("passed_count"),
                "failed": report.get("failed_count"),
                "skipped": report.get("skipped_count"),
                "excluded": report.get("excluded_count"),
                "suite_elapsed_us": report.get("suite_elapsed_us"),
                "test_duration_sum_us": report.get("test_duration_sum_us"),
            }
        )
        for row in report_rows:
            rows.append({**row, "identity": f"{invocation}:{row['test_id']}"})

    return {
        "valid": not diagnostics and len(normalized) == len(EXPECTED_REPORTS),
        "diagnostics": sorted(set(diagnostics)),
        "reports": summaries,
        "tests": rows,
        "normalized": normalized,
    }
