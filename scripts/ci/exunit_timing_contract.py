"""Validate source-bound ExUnit reports emitted by the two mix ci invocations."""

EXPECTED_REPORTS = {
    "main": "ci-exunit-timing-main.json",
    "threadline_guard": "ci-exunit-timing-threadline-guard.json",
}


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
            or not isinstance(row.get("duration_us"), int)
            or row.get("duration_us") < 0
            for row in report_rows
        ):
            diagnostics.append(f"exunit_{invocation}_test_identity_invalid")
            continue
        if report.get("test_duration_sum_us") != sum(
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
