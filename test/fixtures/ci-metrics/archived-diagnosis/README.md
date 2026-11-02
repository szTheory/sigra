# Archived diagnosis test fixture

This reduced fixture exercises the two saved CI metrics failures, including passing Test D and failing Test Z. Its retained members are exact bytes from the original Phase 252 archive; provenance.json records their hashes. The fixture manifest and baseline are derived test inputs, explicitly marked fixture_only. The manifest status is test_fixture_only, so it is not a complete historical snapshot or acceptance evidence. No original archive, baseline, outcome or budget is changed.

The test still validates the complete retained dependency closure and rejects a changed archive. It does not require uploading the original 25 MiB archive to run those assertions in a future candidate.
