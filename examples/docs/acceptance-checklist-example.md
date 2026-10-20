# V8 acceptance checklist — concrete pass/fail gates (2026-10-09 20:45 EDT; rev. 21:00 for Amendment V8-A2)

Supplements PROJECT.md §8 gates 1–12 and Amendments V8-A1, V8-A2. A result enters the final tables only if every
applicable gate below passes; failures are listed in the missing-cell ledger with the failing gate id.
Status: [x] verified (evidence), [ ] pending, [!] gap being built.

## A. Scope / manifest (gate 1, V8-A1)
- [x] A1 manifest has 224 rows; 112 5M `planned`, 112 200M `out_of_scope_owner_A1` (both copies). Evidence: Counter check 20:40.
- [x] A2 no Slurm job, exp script or run dir trains a 200M model: sacct since 18:00, `grep train_one.sh` = 16 lines all `5M`,
      `runs/v8ws/` contains only `5M/`. One 30-update 200M throughput benchmark (tinker, random init, no weights saved)
      quarantined at `$PROJ_DATA/v8ws/quarantine-200M/bench200.jsonl`.
- [x] A3 teacher pinned to `seed-6-c11b76c35a8e/checkpoint-...28f193cd.pt`, sha256 prefix d9b7beec54d6 checked in-job.
- [x] A4 std 5M recipe (L5 d256 H4 i960, LR 1.125e-3, rows 16, T 9216) in every run's `config.yaml.used` (audit reads it); seeds: see S. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): A4 PASS on all 102 audited run dirs

## S. Seed provenance (Amendment V8-A2 item 5) — recovered, not chosen
Recovered from the ORIGINAL standard runs (evidence 2026-10-09 21:05):
- std 5M `naivepoker_v7_pretrain_5M_4epoch/std/4B/seed-6-4388e837adfe`: `config.yaml.used` data.seed 6 (l.19),
  training.seed 6 (l.68); `resolved_config.json` {data: 6, training: 6}; config embedded in final checkpoint
  `...fa343c0f.pt`: training.seed 6, data.seed 6; launch `v7f-train-5M-std.sh` (git 0746fae): `export SEED=6`,
  `train_one.sh std - $RUNS $WORK 1 $SEED`.
- std 200M `.../seed-6-c11b76c35a8e`: identical (6/6 in config, resolved config, checkpoint `...28f193cd.pt`; launch
  `export SEED=6`, `train_one.sh std - ... 4 $SEED`). The two originals differ in NO seed setting (only world size 1 vs 4).
Seed-consuming settings of the original trainer and V8 inheritance:
| setting | original mechanism | V8 |
|:--|:--|:--|
| model init + all torch/numpy/python RNG | training.seed -> random/np/torch/cuda manual_seed (train.py:208–213) | inherited: training.seed 6 |
| data order | data.seed -> per-epoch shuffle sha256(f"{seed}:{epoch}") in plan_epoch (session_loader.py:216) | inherited: data.seed 6, same function; bins are packed over WS-augmented lengths, so the realized bin plan differs from std's (unavoidable: sessions with > b hands are K positions longer) |
| model dropout RNG | none — the V7 model has no dropout (no dropout keys in either checkpoint's model config) | none |
| resume RNG | per-rank python/numpy/torch/cuda states saved in checkpoints | same mechanism |
| WS key dropout (new) | — | counter-based hash uniform(data.seed, epoch, global session id, PURPOSE_WS_DROP, slot) (data/ws.py:88–92); derived from data.seed 6, independent of torch RNG -> identical after resume |
- [x] S1 every running V8 run: data.seed 6 and training.seed 6 in config.yaml.used and resolved_config.json (checked 21:05).
- [x] S2 audit per finished run: seeds in config.yaml.used, resolved_config.json and the final checkpoint's embedded config
      == 6/6; else FAIL (gate S). — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): S2 + S3 PASS 102/102
- [x] S3 (tests/v8/test_aux_init.py, bfb875c; PASS on L40S 21:50: std/NTP/O1/O4 step-0 backbones torch.equal, global RNG
      equal) unit test: V8 backbone initial weights (step 0, before any update) == std 5M initial weights built from the std
      config with the same seed (the WS path must not consume RNG before/among backbone init); aux heads initialised
      after the backbone.

## B. Four-epoch proof (gate 9)
- [x] B1 (Amendment V8-A3) PASS iff DONE.json exists, final_ckpt.py passes (budget_complete, step == configured
      steps, tokens == budget) AND |steps x 16 − sum of the 4 epoch plan bin counts| / sum <= 2%. Sums of plans (seed 6):
      K4-b40 1,740,500; K4-b80 1,739,563; K16-b40 1,746,865; K16-b80 1,743,083 (aux cells share their NTP cell's plan).
      Deviation reported per cell. (History: a stricter zero-tolerance B1 was briefly adopted 21:00–22:40 and is superseded.) — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): B1 PASS 102/102
- [x] B2 exactly one checkpoint file in the run dir at completion (rolling policy) and its sha256 == DONE.json. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): B2 PASS 102/102; dev/control dirs 1 ckpt each
- [ ] B3 attempts/requeues recorded (sacct restart count) — resume used the same world size (1).

## C. Mask / leakage (gates 6–8) — unit level done, production level added
- [x] C1 unit: dense mask == rule for all 8 variants; flex vs dense fwd+grad parity on GPU (tests/v8/test_ws.py, 29 pass).
- [x] C2 unit: strict invariance with all-layer WS K/V pinned; independent slots isolated; no cross-session leak.
- [x] C3 PRODUCTION strict audit (new): for every trained STRICT checkpoint, on 32 real val_seen sessions, pin WS
      states and replace all prefix tokens by a permutation of another session's prefix -> max |Δ suffix logit| ≤ 1e-3
      (bf16 tolerance; fp32 path ≤ 1e-5). For HYBRID checkpoints the same perturbation must CHANGE suffix logits
      (sanity that the test can fail). Fail -> quarantine checkpoint. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): PASS 101/101 trained rows (1 SKIP still evaluating); 136/136 in 10769750. Audit #2 (00:35 Tue): 101/102 — b40-hybrid-causal-d0-O2-sel evaluated after the C3 run -> rerun 10773738
- [x] C4 PRODUCTION dropout off at eval: eval_ws keeps all slots (assert keep==1 for every WS position). — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): eval_ws.py:54 WSSpec(dropout=0.0) for every WS ckpt (structural; no per-position assert)

## D. Suffix-only scoring (gates 4, 11)
- [x] D1 eval_ws asserts per decision h>=b <=> V(target)=1 (test_ws_eval).
- [x] D2 every reported metric row has coverage_kind and boundary; no metric row uses a decision with h<b (audit
      recomputes eligible mask from labels and compares counts). — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): PASS both splits, 101 complete rows
- [x] D3 suffix-token NLL denominator identical across all models at a given (split, b), and == std comparator's. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): PASS both splits (== std comparator den)

## E. Query-set equality (gate 11)
- [x] E1 canonical query sets `$PROJ_DATA/v8ws/queries/<split>-b<b>.npz` + sha256 (v8base).
- [x] E2 for every run x split x b: (sess, role, h) arrays of eligible decisions byte-equal to the canonical set;
      same for std 5M, std 200M rows and oracle-1..3 joins. Oracle 4 rows equal the A2 frozen-manifest subset. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): PASS both splits, 101 rows (oracle-4 joins for WS models still missing, see G6)
- [x] E3 eligible ACTION decisions (h >= b): val_seen b40 19,057,792 / b80 5,951,378; val_unseen b40 18,879,445 /
      b80 5,881,624 (v8base labels; independently recounted from manifest shards 21:00).
- [x] E4 eligible SUFFIX-TOKEN targets under V (original tokens from BOH of hand b+1 to session end): val_seen b40
      145,200,076 / b80 45,377,976; val_unseen b40 144,878,549 / b80 45,150,558; inserted sessions val_seen
      86,931 / 48,650, val_unseen 85,865 / 47,652. Every model's suffix-NLL denominator must equal these. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): covered by D3 PASS

## F. Scoring invariants (gate 11)
- [x] F1 top1<=top2<=top4; legal>=all-action; top-k==1 where menu size<=k; p_legal in [0,1]; NaN only where ineligible. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): PASS both splits
- [x] F2 empty cells -> NA with reason, never 0; partial runs show completed/expected shards and are never ranked. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): PASS; living v2 NA rows carry reasons

## G. Comparisons the final report must contain (PROJECT §3.1, §6, §7, §10)
- [ ] G1 WS vs std 5M and std 200M on identical suffix queries, val_seen and val_unseen separately.
- [ ] G2 WS vs oracles 1–3 (full validation coverage) and oracle 4 (A2 sampled coverage, strict-flagged sites kept
      in denominators) — separate coverage columns.
- [!] G3 paired factor ablations (4v16, hybrid v strict, b40 v b80 incl. common h>=80 intersection, causal v indep,
      d0 v d0.2): every pair differing in exactly one factor; per-pair diff with session-clustered SE + distribution.
- [!] G4 aux ablations: each O vs matched NTP cell; O2 v O1; O3,O4 v O2; O3 v O4; O5 v O2.
- [~] G5 (audit #4: item-9 on 75/79 complete P-sel cells; final pass running; O3/O4 evval + dev evidence verified) history-bin / group plots with matched baselines/oracles; slot-redundancy measurement (mean pairwise cosine
      of final-layer WS states) per WS model; O3/O4 evidence ranking with real vs constant WS at eval.
- [~] G6 (audit #4: A2 182 summaries, 0 failed; final pass chained) WS models + std 200M scored on the A2 279-session sampled cohort (std 5M existing file covers only 58). — [!] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): OPEN: WS models never scored (exp never submitted) -> inv/v8a2ws

## G'. Draft and final report (Amendment V8-A2)
- [ ] G'1 by 13:00 EDT 10-10: `intermediate-analyses/2026-10-09-workspace-final-analysis-draft.md`, labelled DRAFT,
      built ONLY from cells passing B1+B2+E2–E4+F1 on both val_seen and val_unseen, ordered P1→P4, with std 5M/200M
      and oracle tables on matched queries, coverage table and missing-cell ledger for all 224 manifest rows.
- [ ] G'2 eval priority: any cell finishing training before ~12:00 is evaluated on both splits before 13:00
      (in-job eval phases; re-check at each wake-up; separate eval jobs if an in-job eval fails).
- [~] G'3 SUPERSEDED by V8-A6 (gates X1–X8): the final-analysis file is a living version from Tue 13 Oct 14:00,
      frozen Fri 16 Oct 12:00.

- [x] C5 RESOLVED 00:10 (b9ee325): NUMERICS. Exact flex invariance on L40S, 128 cases (8 variants x K4/16 x b40/80 x
      fp32/bf16 x TF32 on/off): future, cross-session, strict prefix, independent slots, dropped keys -> max|delta| = 0;
      flex key sets == dense mask exactly. Parity gap uniform and equal to plain causal mask's; L40S failure was TF32 state
      leaked by an earlier test. Gate-8 parity now pins TF32 per case (fp32 tolerances unchanged).

## H. Operations
- [x] H1 (V8-A2; backstop now Fri 16 Oct 12:15, verified audit #1) NO training cancellation at 12:45. Old guard 10714526 cancelled. Runaway guard only: a job past its
      walltime is ended by Slurm; any ae-v8ws-* job still alive at the end-state backstop (2026-10-12 18:00 EDT) is
      cancelled and logged.
- [ ] H2 wake-up EVERY HOUR through completion (session timers on the owner's laptop; V8-A2 item 4): completion counts + ETAs from per-run progress, harvest eval
      outputs, disk/GPU/preemption check, requeue failed/preempted jobs (after diagnosis), re-rank queue by priority,
      update intermediate analysis; material results reflected within 20 min.
- [x] H3 /data free > 50 GB at all times (now 290 GB free of 500 GB). — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): /data 212 GB free (58% used)

## W. Amendment V8-A4 — auxiliary-weight development sweep (added 2026-10-10 15:00)
- [ ] W1 every sweep run's config.yaml.used differs from its production cell's ONLY in the swept λ key(s), output_dir and
      the signature line (config diff). Done for the 3 hybrid λ_K runs (11:15): only lambda_K/output_dir/signature.
- [x] W2 selection used no validation data: select_aux_weights.py input list contains only files under
      `$PROJ_DATA/v8ws/dev/` / dev manifest; the script refuses any val_seen/val_unseen/evals path (tested). — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): 116 selection inputs, 0 validation paths
- [x] W3 `aux-weight-selection.json` exists, its SHA-256 is recorded in PROJECT.md (V8-A4 frozen selection) and in
      STATE before the first P2-sel/P3-sel submission. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): file sha 54450305 == sidecar == PROJECT; rule hash recomputes to ea0b49e9
- [x] W4 every P2-sel/P3-sel manifest row and run config records its selected λ, equal to the JSON value. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): 0 λ mismatches manifest vs config.yaml.used; 22 λ=1-twin diffs = λ keys + output_dir only
- [x] W5 manifest counts after V8-A4: 224 original rows + 80 new (P2-sel 40, P3-sel 40) = 304; 40 P3 λ=1 rows
      `superseded_owner_A4`; unique run IDs asserted before scheduling. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): 304 rows; 40 superseded_owner_A4
- [x] W6 sweep runs are development runs: listed in agentic-engineering/state/SWEEP-LEDGER.md, never in production tables. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): sweep dirs not manifest rows; audit iterates the manifest only
- [ ] W7 O4 η recorded: b40 7.853e-4, b80 5.204e-4, rule median_u mean_{i<=b} d_i(u) over registered TRAIN queries
      (teacher_cache.py:486/520) — no validation data; deviation from PROJECT §6.6 ("choose η on development data") noted.
- [x] W8 selection rule frozen before any Stage A sweep dev result: aux-weight-selection.json rule_sha256
      ea0b49e93ae7513358375f82f2aeba91bfda3c3d20cf74220c0388c2f03560ee, committed eca6ffa 17:55:48 EDT; only NTP and λ=1
      P2 reference dev outputs had been read. select_aux_weights.py must refuse a changed rule hash (item 14 build).
- [x] W9 (item 13) selection stored as m* per (objective, access, term); every production row records m*, λ_par(b) and
      λ = m*·λ_par(b) for its boundary; b40 λ_par(R) measured before any b40 O5 production cell. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): m*, λ_par b80/b40, λ per boundary in all 10 groups
- [x] W10 (item 14) the 1-SE tie uses the session-clustered SE of the paired difference on identical dev sessions; every
      candidate's paired Δ vs matched NTP ± SE is in the JSON. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): paired vs_ntp diff + se on all 37 candidates
- [ ] W11 (item 15) Stage B grids derived from measured per-term grad-norm ratios (0.1..1, 4 points) + λ_par×{1,4} +
      production refs (λ_E 0.1, λ_R 1); ratios, grids and GPU cost reported to the owner before submission.
- [ ] W12 (item 16) K=0 O1/O2 control runs identical to std 5M except the aux term on b80 suffix sites (config diff vs
      V7 std 5M; matched K=0 NTP reference run if not an exact match).
- [ ] W13 (item 17) gap-closed and oracle-2/3 excess NLL reported for every P-sel cell (val, per role/split/boundary) and
      every sweep candidate (dev).
- [x] W14 (item 18) seed-7 runs (offset +1 recorded) for matched NTP and selected-λ O1 at both representative cells,
      in a separate run root (runs-seed) so the production audit never sees them. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): seed-7 dirs under $PROJ_DATA/runs-seed/ (3 done, hybrid O1 s7 training); diffs = seed, output_dir, budget −0.0018%
- [ ] W15 (V8-A5 2–3) Stage B grid: ρ measured on matched NTP ckpts + step-0 init (not λ=1 ckpts); ρ points within 1.5×
      of λ_par×{1,4} merged; λ=1 anchors are the existing hybrid P2 / strict reference runs with λ_F = 1 (recorded).
- [~] W16 (V8-A5 6–7) SUPERSEDED by V8-A6 (2026-10-11 16:25): Tue 12:00 deadline, guard and fallback cancelled. Kept: the
      Stage B trims already made (13 points cut, recorded in SWEEP-LEDGER and reported 08:15 Oct 11), not restored.

## X. Amendment V8-A6 (owner, 2026-10-11 16:25) — living final analysis, Friday cutoff, both partitions
- [x] X1 `2026-10-09-workspace-final-analysis.md` v1 delivered by 14:00 EDT Tue 13 Oct from complete + audited cells only. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): v1 96e8ffb 19:46 Mon 12 Oct
- [x] X2 every version's header: version number, timestamp, cell counts per tier, "LIVING VERSION, updated until Fri 16 Oct
      12:00" (or "FINAL, frozen Fri 16 Oct 12:00"); explicit missing-cell ledger; no partial result presented as complete
      or ranked; every item-10 and item-17 comparison computable from complete cells, the rest NA with the reason. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): v2 header/ledger/NA verified
- [x] X3 (audit #2: v1 19:46, v2 21:32, v3 00:05 item 16, v4 00:3x item 18 — git log) updates every 6 h and on each selection / control (item 16 or 18) / complete tier; commit log shows the cadence.
- [ ] X4 seed variance: limitation stated (strict +0.0134 dev NLL ≈ 13× paired SE); every strict selected-λ effect compared
      with the item-18 seed spread and labelled "within seed noise" when smaller; no selection changed because of it.
- [ ] X5 Friday cutoff: from Thu 12:00 no job launched whose measured duration + evals ends after Fri 10:00; at Fri 12:00
      the final is frozen, still-running study jobs cancelled, ledgered "not completed by Fri 12:00 cutoff", partial outputs
      deleted per storage rules.
- [x] X6 (audit #3 12:30: general 8/8, preempt 23/24 GPUs, no study job pending) capacity: both partitions used (general 8 + preempt), preempt queue kept non-empty with runnable work, critical
      path on general, no GPU idle while a runnable job waits; top-up submitter log shows each queue at its limit.
- [~] X7 (audit #3: hourly rates + per-job tier simulation since 05:36; loss per preemption still a 3% bound) forecasts: hourly measured preempt rate (72 h, 24 h, median wait, loss per preemption) and three scenarios (S1
      general, S2 general + measured net preempt = main, S3 all 32); any S2 tier miss of Fri 10:00 reported to the owner.
- [x] X8 the old draft `...-final-analysis-draft.md` frozen as of 2026-10-11 16:25 with a pointer to the new file. — [x] audit #1 (10-12 23:45, audits/audit-20261012-2345.md): draft frozen + pointer verified

## V9. NON-NEGOTIABLE — Amendment V8-A9 (owner ~10:20 Wed 14 Oct): O5 loss deviation
- [x] V9-1 (manifest.csv 24 invalid rows; kept) every old-loss O5 run (P2 λ=1 O5 ×8, strict λ=1 O5 ref, Stage B O5 ×7, P2-sel/P3-sel O5 ×16) has manifest /
      ledger status `invalid_O5_loss_deviation`, is kept (not deleted) and is not counted as failed or missing.
      [x] SWEEP-LEDGER marked 10:3x Wed; manifest.csv regenerated 16:4x Thu (24 invalid rows).
- [x] V9-2 (FINAL v16: 393 appendix rows labelled; sentence in appendix + §8) the final analysis labels every old O5 number, comparison, sweep curve, plot and learning-gap row "INVALID: O5
      loss deviation (V8-A9)" or puts it in a marked appendix, and states that no conclusion uses them.
- [x] V9-3 the 5 in-flight V8-A8 O5 runs + their dev jobs are cancelled (sacct CANCELLED 10:2x Wed); 8 O3/O4 continue.
- [x] V9-4 backstop 10715530 BeginTime moved to 2026-10-23T12:15 (scontrol show job, 10:2x Wed).
- [x] V9-5 (audit #5, 13:4x; my test run 31 pass; v8o5fix 66dbbeb7) fixed L_R (o5_loss_version 2) passes: E[estimator] = exact mean on unequal cells; gradcheck; no teacher gradient;
      v1 path unchanged; method choice, reason and cost recorded.
- [x] V9-6 (audit #6: real run dirs 20/20 clean, cfgdiff_v2.py) config diff: every v2 run differs from its old counterpart only in o5_loss_version, λ_R and output paths.
- [x] V9-7 (Selection B O5 re-run 08:0x Thu, postcheck OK) v2 gradient ratios (NTP ckpt + step 0), O5 Stage B grid run in full (no cuts) + dev-scored; Selection B
      re-run for O5 only with rule ea0b49e9 unchanged and all other groups identical; m*, λ_R at b40/b80 recorded.
- [x] V9-8 (audit #8: 9/9 λ=1 + 16/16 P-sel trained; 152/152 in-scope PASS incl. 24 v2) v2 strict λ=1 O5 ref, 8 P2 λ=1 O5, 16 P-sel O5 complete (4 epochs, budget exact) + audited (C1–C3).
- [x] V9-9 (FINAL v16: item-9 16/16, A2 34/34, C3 34/34, item-10/17 from v2 cells) item-9, A2/oracle-4, item-10, item-17 O5 comparisons rebuilt from v2 cells only.
- [~] V9-7 progress (audit #6): v2 ratios + 11-point grid running, no cuts.
- [x] V9-10 (08:2x Thu) GPU-h + 3-scenario forecast reported before the P-sel O5 submit.

## FINAL (2026-10-16 04:53 EDT)
- [x] FINAL v16 published byte-identical; closeout audit audits/audit-20261016-0450-final.md clean after 1 fix; STE 88.5%;
      timers + backstop disarmed.

- 2026-10-16: owner asked for one document. Deleted the superseded draft (2026-10-09-workspace-final-analysis-draft.md) and the
  living log (2026-10-09-workspace-intermediate-analyses.md); both are recoverable with `git show 283e0487:intermediate-analyses/<file>`.
  The single deliverable is intermediate-analyses/2026-10-09-workspace-final-analysis.md (FINAL v16).
