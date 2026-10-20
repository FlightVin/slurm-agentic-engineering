# Brief: v8o5cfg — config validation rejects training.aux.o5_loss_version (blocks every V8-A9 O5 v2 run)

Every O5 v2 training job failed at train start (after teacher staging):
  ValueError: training.aux needs objective and teacher_dir; allowed keys ['eps', 'lambda_E', 'lambda_F', 'lambda_K',
  'lambda_R', 'objective', 'tau', 'teacher_dir']
Source: config.py:123-126 (`allowed` set). scripts/v8/make_config.py --o5-loss-version 2 writes training.aux.o5_loss_version.

Task:
1. config.py: allow `o5_loss_version`; require it to be the int 1 or 2 when present, and only with objective O5 (raise
   otherwise). Nothing else changes (absent key = old behaviour, so old configs validate identically).
2. Tests (tests/v8/test_o5v2.py or a new test file):
   a. generate the REAL config of the v2 strict λ=1 reference exactly as train_one.sh does (scripts/v8/make_config.py with
      the same arguments the exp agentic-engineering/exp/v8ws-train-5M-K4-b80-strict-indep-d0-O5-o5v2.sh passes, incl.
      --o5-loss-version 2) and run it through config.py validation: must pass;
   b. the same for one v2 sweep exp (v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2.sh) and one old
      O5 config (no key): must pass; o5_loss_version 3, "2" (string), or with objective O1: must raise;
   c. search the repo for any OTHER validator / schema / allow-list of training.aux keys (grep `lambda_R`, `teacher_dir`,
      `allowed`) that would reject the key at a later stage (train.py, model/aux.py, checkpoint load / final_ckpt,
      eval_ws, dev_metrics, audit A4 config checks, resume path) and fix + test each one found; list them in the report.
3. Run (exact form; the allow-list matches the first word):
   env CUDA_VISIBLE_DEVICES= PYTHONPATH=$PWD:/data/user_data/vineethb/envs/v6extra /data/user_data/vineethb/envs/wllms/bin/python -m pytest -q -p no:cacheprovider tests/v8/test_o5v2.py <your new test file> tests/v8/test_ws_train.py -k "not slow"
   and paste the summary line.
Commit + `git push origin HEAD:inv/v8o5cfg`. End with `V8O5CFG-READY <sha>`.

## Do NOT
- Do NOT change the loss, the estimator, the cache, or any other objective; do NOT change other validation rules.
- Do NOT edit agentic-engineering/state/*, PROJECT.md, intermediate-analyses/*, LEDGER.jsonl, or any exp script; do NOT submit jobs.
- Do NOT copy whole trees between worktrees.
