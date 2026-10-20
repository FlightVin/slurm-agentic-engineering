# Brief: v8xfail — mark three stale tests as expected failures (owner instruction, 2026-10-14)

These three tests fail on v8-ws (02c5b84f+) only because their fixtures expect `pending_selection_B` manifest rows.
Selection B ran on Mon 12 Oct 19:14 (aux-weight-selection.json exists), so the real ledger now has 0 such rows and the
expected counts move to not_started / complete:
- tests/v8/test_living.py::test_missing_ledger_covers_every_row
- tests/v8/test_living.py::test_na_rows_when_inputs_missing
- tests/v8/test_analysis_report.py::test_draft_only_complete_cells

Task:
1. Mark each with `@pytest.mark.xfail(strict=True, reason="stale fixture: expects pending_selection_B rows; Selection B
   ran 2026-10-12 19:14, so none remain (owner-approved xfail 2026-10-14)")`. strict=True so an unexpected pass is
   reported.
2. Add a short comment block at the top of each of the two files explaining which tests are marked xfail and why (same
   reason, plus: the code under test is unchanged; only the fixture expectation is stale).
3. Run: `CUDA_VISIBLE_DEVICES= $PY -m pytest -q tests/v8/test_living.py tests/v8/test_analysis_report.py` and paste the
   summary line (expect 3 xfailed, 0 failed). If you cannot run the env python, say so and give the exact command.
4. Commit and push to inv/v8xfail. End your report with `V8XFAIL-READY <sha>`.

## Do NOT
- Do NOT change any assertion, fixture, or non-test file; do NOT touch any other test.
- Do NOT edit agentic-engineering/*, intermediate-analyses/*, scripts/*, model/*.
- Do NOT submit jobs or copy trees between worktrees.
