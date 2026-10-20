# Brief: v8o5fix — fix the O5 representation loss L_R (owner Amendment V8-A9, PROJECT.md last section; read it first)

## Defect (confirmed)
model/aux.py:347-358: L_R uses only the Q5 = 0.05 hash subset of cached teacher hidden states (teacher_cache.o5_include),
recomputes balanced_weights on that subset, and divides by counts["S5"]. This is neither the §6.7 mean (same session and
role x distance weighting as L_F: sum over sessions of the mean over nonempty cells of cell means, / S) nor unbiased.

## Required design (method (b) of V8-A9 item 6; method (a) is out: all h>=40 sites ~256M x 1792 B ~ 459 GB > 187 GB free,
and the owner storage rule keeps >= 20% of the 500 GB /data free)
1. **Version flag.** New config key `training.aux.o5_loss_version` (absent / 1 = old behaviour, kept bit-identical for
   reproducing old runs; 2 = fixed). The v2 teacher-hidden subset must be found by code from the version (for example a
   sibling dir `o5v2/` next to the existing O5 cache under the same teacher dir), NOT by a new config path, so a new run's
   config differs from its old counterpart only in o5_loss_version, lambda_R and output paths.
2. **Pre-declared stratified inclusion with IPW.** Measure first (CPU, from the existing flat O1/O2 store: per-session
   cell sizes |U_sc| at b = 40 and b = 80 over all h >= b sites, 6 cells = role x dist bins [0,10),[10,30),[30,inf)).
   Then define, deterministically from data only (never from a model), a per-site inclusion probability
   q_u = min(1, max(q0, k / min_b |U_{s,c_b(u)}|)) taken over the boundaries b in {40, 80} for which the site is
   eligible, and include site u iff site_uniform(seed, h, i, NEW_SALT) < q_u. Choose q0 and k so the expected v2 hidden
   storage is <= 60 GB (report the expected and the realised GB), with k >= 2 (each nonempty (session, cell) expects
   >= 2 sampled sites, or all of them). Store q_u (float32) next to each cached hidden row.
3. **Estimator (v2).** w_u = balanced_weights over ALL h >= b sites of the micro-step's sessions (full counts from the
   O1/O2 store, which covers every eligible site), then L_R = sum over sampled sites of (w_u / q_u) R_u, times
   world_size / counts["S"] (the L_F normaliser). E[L_R] over the inclusion design = the exact §6.7 mean. L_F, O1–O4 and
   the NTP term are untouched (diff must show it).
4. **Dev metric.** scripts/v8/dev_metrics.py r (balanced, the L_R form) must use the same exact-mean definition: build
   the dev O5 hidden cache with q = 1 (all dev h >= 40 sites) if it is <= 10 GB, else the same IPW design; report which.
   The per_site r form stays as a diagnostic. Selection eligibility "R below matched NTP" uses the v2 balanced form.
5. **Teacher cache.** Extend scripts/v8/teacher_cache.py + scripts/v8/mk_teacher_exps.py with a v2-O5-only mode that
   writes the o5v2 subset (and q) for train and dev without rewriting O1/O2/O3/O4 files; emit the sharded exps
   (16 train shards + 1 dev + consolidate, same style as v8ws-teacher-o12-*.sh) under agentic-engineering/exp/ with
   names v8ws-teacher-o5v2-*.sh. Keep the TeacherStore alignment assertions; add the two asserts from audit item L1
   (store meta manifest_sha256 == training manifest sha; len(ptr)-1 == loader session count) in AuxTrainer.__init__.
6. **Gradient-ratio exps.** grad_ratio.py must measure R with the v2 estimator when o5_loss_version = 2; emit
   v8ws-gradratio-o5v2-<cell>-{final,step0}.sh for both representative cells (matched NTP checkpoint + step 0, V8-A5
   item 3), R term only is enough.
7. **Exp generators.** gen_sweep_exps.py / gen_psel_exps.py / mk_aux_exps.py (whichever emit O5 train exps) accept
   o5_loss_version 2 and produce run ids / exp names with suffix `-o5v2` so old run dirs are never touched. Do not emit
   the production exps yet beyond a generator that I can call; DO emit the strict λ = 1 O5 reference and the 8 P2 λ = 1
   O5 cells as v2 exps (same configs as their old counterparts except o5_loss_version, output paths).
8. **Config diff tool.** scripts/v8/o5v2_config_diff.py: for each new v2 run config vs its old counterpart, print the
   differing keys; exit 1 if anything other than training.aux.o5_loss_version, training.aux.lambda_R and output paths
   differs.

## Proof (tests/v8/test_o5v2.py), all required by V8-A9 item 7
- Fixture with unequal cell sizes (several sessions, some cells of size 1, some > 50): Monte-Carlo over >= 2000 salts the
  mean of the v2 estimator equals the exact mean (sum_s mean_c mean_u R / S) within 3 SE; also an exact enumeration
  check on a tiny case. Show the v1 estimator fails the same test (documents the bias).
- Gradient check: torch.autograd.gradcheck (float64) of L_R v2 wrt the projection weights and the student hidden.
- No teacher gradient: teacher hidden tensors have requires_grad False / grad None after backward; student grads nonzero.
- v1 path unchanged: old config -> identical loss value to the current code on a fixture.
- Run: `CUDA_VISIBLE_DEVICES= $PY -m pytest -q tests/v8/test_o5v2.py tests/v8/test_aux_losses.py tests/v8/test_grad_ratio.py`.

## Deliverables
Commit + push to inv/v8o5fix. Report: the measured cell-size table, chosen q0/k, expected GB, cost estimate of the cache
build (GPU-h, from the old o12 shards ~37 min each), the list of emitted exps, test output (or the exact command if you
cannot run the env python). End with `V8O5FIX-READY <sha>`.

## Do NOT
- Do NOT change L_F, O1–O4, NTP, masks, data loading, eval, or any other objective; do NOT change the frozen selection
  rule (select_aux_weights rule section must stay byte-identical, rule_sha256 ea0b49e9).
- Do NOT modify, move or delete existing teacher-cache files, run dirs, or results; do NOT write under $PROJ_DATA except
  test scratch.
- Do NOT submit Slurm jobs or run training / cache builds; do NOT edit agentic-engineering/state/*, PROJECT.md,
  intermediate-analyses/*, LEDGER.jsonl, or the old exp scripts.
- Do NOT copy whole trees between worktrees; do NOT touch report code (living.py, final_report.py, plots.py).
