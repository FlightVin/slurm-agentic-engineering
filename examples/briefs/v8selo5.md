# Brief: v8selo5 — Selection B re-run for the O5 group only (owner Amendment V8-A9 item 8 (iii); PROJECT.md last section)

Context: every O5 run trained with the old L_R (o5_loss_version 1) is invalid. New O5 runs use o5_loss_version 2 and the
run/cell suffix `-o5v2` (scripts/v8/train_one.sh, gen_sweep_exps --o5v2). A new O5 Stage B grid (λ_R points, both
access modes, b80 representative cells, λ_F at the Selection A value per access) will be trained and dev-scored by
scripts/v8/dev_metrics.py (r.balanced = the exact-mean v2 form). The frozen rule (rule_sha256 ea0b49e9…) and every
non-O5 selected value must stay unchanged.

Task (code only; I will run it as a job later):
1. scripts/v8/select_aux_weights.py: add `--only-group O5` (or equivalent) that:
   - reads the CURRENT frozen selection file (intermediate-analyses/2026-10-09-workspace-assets/aux-weight-selection.json);
   - re-runs `select()` with the UNCHANGED rule section on the given O5 v2 candidates (dev JSONs) + matched NTP dev JSONs
     (and the same --std / --oracle-dir inputs as Selection B), for the (O5, hybrid, R) and (O5, strict, R) groups only;
   - takes λ_par(R) per boundary from `--lambda-par` (supplied, recorded under lambda_par_supplied with its source);
   - writes a new file in which every non-O5 group, candidate list and selected entry is byte-for-byte identical to the
     current file (postcheck: assert, and print the per-group comparison), the O5 groups are replaced, and a field
     `o5_rerun` records: date, reason "V8-A9 O5 loss deviation", old O5 selected values, new ones, candidate list, and
     `o5_loss_version: 2`;
   - asserts the rule section is byte-identical (rule_sha256 == ea0b49e9…) and that no input path contains val_seen,
     val_unseen or evals/v7f-labels/val_ (the existing forbidden_inputs check);
   - never overwrites the current file: output to --out; the previous file is preserved by the caller.
2. Emit agentic-engineering/exp/v8ws-select-B-o5v2.sh (CPU, gpus=0, like v8ws-select-B) that runs it with
   `--only-group O5`, candidates = $PROJ_DATA/v8ws/dev/metrics/*-O5-*-o5v2.json (b80 representative cells), NTP =
   the two matched NTP dev JSONs used by Selection B, out = $AE_RESULTS/aux-weight-selection.json; λ_par(R) values
   passed via env vars LP_R_B80_HYB / LP_R_B80_STR / LP_R_B40 (I fill them from the v2 ratio run); fail loudly if any is unset.
3. scripts/v8/gen_psel_exps.py --o5v2 must read λ_R from a given selection file (flag) for the 16 P-sel O5 v2 cells.
4. Tests (tests/v8/test_selo5.py): fixture with fake dev JSONs: non-O5 groups byte-identical; O5 groups replaced; rule
   hash unchanged; a val path in candidates raises. Run them with
   `CUDA_VISIBLE_DEVICES= $PY -m pytest -q tests/v8/test_selo5.py tests/v8/test_select_b.py tests/v8/test_devsel.py`.
Commit + push to inv/v8selo5. End with `V8SELO5-READY <sha>`.

## Do NOT
- Do NOT change the rule section, `select()` semantics, tie/eligibility logic or any non-O5 output.
- Do NOT read or reference val_seen / val_unseen data.
- Do NOT edit agentic-engineering/state/*, PROJECT.md, intermediate-analyses/*, LEDGER.jsonl, or old exp scripts.
- Do NOT submit jobs; do NOT touch model/, train.py, report code (living.py, final_report.py, plots.py, manifest.py).
- Do NOT copy whole trees between worktrees.
