# Brief: v8a9cancel — wrong status label for the 5 cancelled V8-A8 O5 Stage B points (closeout audit finding)

The v14 final analysis (living build) lists these 5 V8-A8 record-only O5 sweep points in the INVALID appendix with
status "NA — training" (cell table) / "training" (ledger/run-state table):
  K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.1181, -lr0.3181, -lr1.181
  K4-b80-strict-indep-d0-O5-lf0.00496-lr0.3463, -lr1.052
They are NOT training: the owner's Amendment V8-A9 item 4 cancelled them (Slurm CANCELLED 2026-10-14 10:2x; their run
dirs exist with partial checkpoints and no DONE.json). The run-state code infers "training" from a run dir without
DONE.json.

Task:
1. In the report layer (scripts/v8/living.py and/or final_report.py, wherever the Stage B / sweep run state is derived),
   add a named constant for exactly these 5 cells (V8-A9 item 4) and give them the status
   "cancelled (V8-A9 item 4: old O5 loss)" everywhere a status or NA reason is printed (appendix cell table, appendix
   ledger/run states, coverage if they appear). They stay in the INVALID appendix with that label. No other cell changes.
   Do not infer "cancelled" from Slurm at build time (no sacct calls in the report).
2. Check that no other cell in the report can get "training" when its run dir lacks DONE.json but no job is running:
   list every place that maps "run dir without DONE.json" -> "training" and report whether any other real cell is
   affected (all study training is finished; only these 5 dirs are unfinished on purpose).
3. Test: extend tests/v8/test_v8a9rep.py (or a new test) with a fixture where those 5 cells have a run dir without
   DONE.json: the built report shows "cancelled (V8-A9 item 4: old O5 loss)" and never "training" for them.
   Run (exact form; the allow-list matches the first word):
   env CUDA_VISIBLE_DEVICES= PYTHONPATH=$PWD:/data/user_data/vineethb/envs/v6extra /data/user_data/vineethb/envs/wllms/bin/python -m pytest -q -p no:cacheprovider tests/v8/test_v8a9rep.py tests/v8/test_living.py tests/v8/test_living_a8.py tests/v8/test_v8a8fix.py
   and paste the summary line.
Commit + `git push origin HEAD:inv/v8a9cancel`. End with `V8A9CANCEL-READY <sha>`.

## Do NOT
- Do NOT change any number, selection, gate, audit, aggregate or paired code, or any other status.
- Do NOT edit agentic-engineering/state/*, PROJECT.md, intermediate-analyses/*, LEDGER.jsonl; do NOT submit jobs.
- Do NOT copy whole trees between worktrees.
