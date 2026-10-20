# Brief: v8ntptol — set the ntpv2 compare tolerance from the measured bf16 bound

Both v8ws-devmetrics-ntpv2-* jobs scored fine but FAILED their compare phase (scripts/v8/ntpv2_compare.py, tolerance 1e-6):
strict max |new−old| nll 1.3e-5, kl 3.7e-5; hybrid nll 9.3e-5, kl 1.1e-5 (same checkpoint, same dev data, different
GPU / run: bf16 autocast nondeterminism). FINDINGS "Dev-NLL precision" (v8ws-devprecision, 13 Oct) measured the
production bf16 path shift at +0.00015 on WS NTP dev NLL, paired SE ~0.0006, smallest selection margin ~0.001.
The 1e-6 tolerance in my previous brief was wrong.

Task:
1. ntpv2_compare.py: tolerance for nll / kl `mean` leaves = 2e-4 absolute (cite the FINDINGS bound in a comment), for
   `se` leaves 2e-5 absolute, and EXACT equality for every count leaf (n, sessions, sites_*); keep the cell / ckpt sha /
   r.design checks. Make the tolerance a named constant printed in the log line.
2. Confirm the exp's devmetrics phase is skipped on resubmit when the -ntpv2.json already exists (phase guard), so a
   resubmit re-runs only compare. If the guard would re-score, leave it (re-scoring is also fine) but say so.
3. Update tests/v8/test_ntpv2.py for the new tolerances (a 9e-5 nll diff passes, 3e-4 fails, a count diff fails).
   Run `CUDA_VISIBLE_DEVICES= $PY -m pytest -q -p no:cacheprovider tests/v8/test_ntpv2.py tests/v8/test_selo5.py`
   (PY=/data/user_data/$USER/envs/wllms/bin/python, PYTHONPATH=$PWD:/data/user_data/$USER/envs/v6extra); paste output.
Commit + push to inv/v8ntptol. End with `V8NTPTOL-READY <sha>`.

## Do NOT
- Do NOT touch dev_metrics.py, select_aux_weights.py, the rule, or any dev JSON.
- Do NOT edit agentic-engineering/state/*, PROJECT.md, intermediate-analyses/*, LEDGER.jsonl; do NOT submit jobs.
- Do NOT copy whole trees between worktrees.
