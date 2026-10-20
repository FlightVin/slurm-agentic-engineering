# Brief: v8a9rep3 — make the merged V8-A9 report layer pass its tests

Your worktree branch inv/v8a9rep3 ALREADY contains v8-ws (with the accepted v8selo5, v8ntpv2, v8ntptol changes) merged
with inv/v8a9rep (report/manifest/audit layer for Amendment V8-A9; read its commit messages and tests/v8/test_v8a9rep.py).
No git fetch/merge is needed.

How to run Python here (the permission allow-list matches the FIRST word; a leading `VAR=` or an absolute python path is
refused). Use exactly this form:
  env CUDA_VISIBLE_DEVICES= PYTHONPATH=$PWD:/data/user_data/vineethb/envs/v6extra /data/user_data/vineethb/envs/wllms/bin/python -m pytest -q -p no:cacheprovider <files>

Failures in my run of this exact tree (9 fail / 69 pass):
1. tests/v8/test_v8a9rep.py ::test_pipeline_excludes_old_o5_and_uses_v2, ::test_appendix_label_sentence_and_no_old_value_in_main,
   ::test_no_fallback_when_v2_missing: FileNotFoundError scripts/v8/audit.py:212 for runs/5M/K4-b80-strict-indep-d0/
   seed-6-abc/metrics.jsonl. Cause: the lfx fixture's `_devrun` (tests/v8/test_living.py:46) writes a dev run dir with
   only DONE.json for the strict representative cell, and `_with_o5` re-runs the full pipeline, whose audit then reads that
   dir as the production NTP run. Fix BOTH: (a) audit.gate_b1 (and any sibling reader) must turn a missing / unreadable
   metrics.jsonl into a FAIL gate with a reason, never an exception; (b) the test fixture must not depend on that: make
   `_with_o5` keep the dev-only dir out of the production audit (or give it a valid fixture run) — choose what reflects
   real data (in real data the representative NTP cell's run dir IS a complete production run).
2. tests/v8/test_v8a7.py::test_item17_cell_table_and_note: TypeError at scripts/v8/living.py:1593, the test's stub lambda
   takes 1 positional arg but 2 were given (v8a9rep changed the call). Update the stub to the new signature; keep asserts.
3. tests/v8/test_psel.py: 5 failures (pending_selection_B vs not_started etc.) because its fixture reads the REAL
   selection file. Monkeypatch MF.SELECTION to a fixture file (as v8a9rep did for fx); keep the assertions' intent.
4. o5_rerun schema: the accepted scripts/v8/select_aux_weights.py writes o5_rerun = {old_selected, new_selected (brief
   fields), candidates [{group, cell, path, sha256, lam, m}], ntp, lambda_par_supplied, o5_loss_version 2, previous} and
   replaces the top-level `selected` O5 entries with full new entries naming -o5v2 cells. manifest.o5_views reads
   o5_rerun["selected"] (absent) and only works through the fallback. Make it read `new_selected` explicitly (fallback
   kept), read λ_par(R) from `lambda_par_supplied` / the new entries' lambda_par_b80/_b40, and add ONE test that builds a
   selection file with the real `select_aux_weights` O5 re-run code path (rerun_o5 / splice helpers) on fixture
   candidates, then checks manifest.selection_view, the living O5 rows and `gen_psel_exps --o5v2 --selection` all give
   the same new λ_R.
5. Run and paste the summary line of:
   tests/v8/test_v8a9rep.py tests/v8/test_selo5.py tests/v8/test_ntpv2.py tests/v8/test_living.py tests/v8/test_analysis_report.py
   tests/v8/test_v8a8fix.py tests/v8/test_v8a7.py tests/v8/test_base_manifest.py tests/v8/test_psel.py tests/v8/test_analysis_paired.py
   tests/v8/test_base_aggregate.py tests/v8/test_living_a8.py tests/v8/test_v8partial.py tests/v8/test_analysis_audit.py
   (test_select_b::test_a_only_reproduces_pre_change_selection is a known pre-existing failure; leave it.)
Commit + `git push origin HEAD:inv/v8a9rep3`. End with `V8A9REP3-READY <sha>`.

## Do NOT
- Do NOT weaken or delete assertions; do NOT change non-O5 numbers, selection logic, the rule, training/eval code.
- Do NOT edit agentic-engineering/state/*, PROJECT.md, intermediate-analyses/*, LEDGER.jsonl; do NOT submit jobs.
- Do NOT copy whole trees between worktrees.
