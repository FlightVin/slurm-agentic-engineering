# STUDY COMPLETE (2026-10-16 05:0x EDT): FINAL v16 written, audited, published, committed. Items below are the record.
# CHECKLIST — live plan (V8 workspace study; V8-A1..A6 + V8-A4 items 13–18 + owner audit rule 2026-10-12)
Rewritten from audit #1 (audits/audit-20261012-2345.md). Prior history: git (CHECKLIST.md @ 89092da) + log/2026-10.md.
Gates [X#] live in intermediate-analyses/2026-10-09-workspace-assets/acceptance-checklist.md.

## 0. NON-NEGOTIABLE — deep self-audit every 12 h (owner 23:10 Mon; PROJECT.md last section)
- [x] audit #1 23:45 Mon -> audits/audit-20261012-2345.md · [x] audit #2 00:35 Tue · [x] audit #3 12:35 Tue · [x] audit #4 00:45 Wed -> audits/audit-20261014-0045.md
- [x] audit #5 Wed 12:00 tick -> audits/audit-20261014-1345.md (85 rows; 1 correctness error = O5 L_R, V8-A9)
- [x] audit #6 Thu 00:00 tick -> audits/audit-20261015-0030.md (92 rows; #5 erratum: it said 85)
- [x] audit #7 Thu 12:00 tick -> audits/audit-20261015-1230.md (92 rows; cfgdiff_v2 comparator fixed, 34/34 clean)
- [x] audit #8 Fri 00:00 tick -> audits/audit-20261016-0045.md (92 rows; 0 correctness errors; current-code G1)
- [x] audit #9 not needed: FINAL done 04:53 Fri; audit cron deleted until the FINAL document is written (V8-A8/A9).
      Missed timer -> audit first at next wake-up; new amendment -> audit. Each: full procedure + gaps closed / open / new.
- [ ] every hourly check: CronList shows 325b4e64 (audits) + df36eb57 (hourly, V8-A9 text; replaced 28f6e384 11:1x); backstop 10715530 BeginTime Fri 23 Oct 12:15

## 0a. NON-NEGOTIABLE — V8-A9 (owner ~10:20 Wed 14 Oct; PROJECT.md last section): old O5 invalid; fix L_R; retrain all O5
- [x] amendment written to PROJECT.md (read back)
- [x] 5 V8-A8 O5 runs + chained devmetrics cancelled 10:2x (train 10797454/65/71/97, 10797502; dev 10797461/67/74/500/504)
- [x] backstop 10715530 moved Fri 16 -> Fri 23 Oct 12:15 EDT (scontrol StartTime; verified)
- [x] invalid set (32 completed runs, kept as record, status invalid_O5_loss_deviation): P2 λ=1 O5 ×8; strict λ=1 O5 ref
      (10717336); Stage B O5 ×7 (strict 4, hybrid 3); P2-sel O5 ×8; P3-sel O5 ×8. SWEEP-LEDGER rows marked; manifest
      status via the report tinker (manifest.py generates it). (The 8 strict λ=1 O5 P3 rows stay superseded_owner_A4.)
- [x] fix L_R: v8o5fix ACCEPTED 66dbbeb7 (13:4x). Method (b): q_u = min(1, max(Q0 .01, K 2 / min_b |U_sc|)), salt
      0x5EED0052; 16.58M expected sites (6.5%), 29.9 GB per copy (~60 GB peak); method (a) forbidden (~459 GB vs 187 GB
      free + 20%-free rule). v2: w = L_F weights over ALL sites, Σ (w/q) R, / S. Dev cache already q = 1 (exact).
  - [x] my test run: 31 pass (MC unbiased b40 +0.74 SE / b80 +0.10 SE vs v1 −262 / −178 SE; enumeration; gradcheck;
        no teacher grad; v1 bitwise unchanged); aux.py diff read; manifest-sha assert = real configs (c4d1bfaf9823)
  - [x] config diff tool: 9/9 v2 λ=1 exps differ only in o5_loss_version + output_dir (re-run on real run dirs)
  - [~] o5v2 cache: 16 train shards + dev submitted 13:4x (10802709…) -> consolidate --after all 16 -> check realised GB
        15:3x: 14/16 done (13 moved to general, 08 running); realised ≈ expected, 1.87 GB/shard; 4 preempted + requeued;
        shard 02 vs_old_o5_max_abs_diff 0.166 (fp16/bf16 across GPU types?) -> cosine check on overlap after consolidate
        16/16 shards DONE: 16,587,680 sites (expected 16,581,581), 29.96 GB; overall vs_old max |Δ| 0.30.
        consolidate 10802784 FAILED 15:53 (OSError 116 Stale file handle in memmap.flush: 8 workers writing one 30 GB
        NFS file). ONE recorded retry 10804638 (transient infra; inputs complete); if it fails again -> fix the write
        pattern via tinker, no further retry. Its afterany release made the 13 dependents eligible: re-pointed all 13
        to afterok:10804638 before any started (verified PENDING Dependency).
        retry 10804638 COMPLETED 16:0x: 16,587,680 sites, 29.92 GB, manifest c4d1bfaf (= training), teacher d9b7beec.
        old vs new teacher hidden on overlap (3,042 sites of a 60k sample): cos min .99982, median 1.0, 61% bitwise
        equal, R between targets mean 6.2e-6 (max 3.6e-4) vs R ~ .2 -> bf16 GPU rounding only; cache valid.
  - [x] dev o5v2 cache COMPLETED: 853,948 / 853,948 sites (q = 1, exact), reused from the old q=1 dev rows
  - [x] chained after consolidate 10802784: 4 v2 grad-ratio jobs (10802788/89/91/93) + 9 v2 λ=1 O5 runs (10802796…824)
  - [x] 2 cache shards moved to idle general (10802724/26) 13:4x
- [x] v8selo5 ACCEPTED 14:1x (my run: test_selo5 14/14; select()/rule untouched, load_rule default unchanged):
      --only-group O5 splices new O5 groups, postcheck non-O5 byte-identical, records o5_rerun; exp
      v8ws-select-B-o5v2.sh (needs LP_R_B80_HYB / LP_R_B80_STR / LP_R_B40); gen_psel_exps --o5v2 --selection FILE.
      Pre-existing stale tests: test_select_b A-only (top-level lambda_par_supplied), test_psel ×5 (pending_selection_B)
  - [x] v8ntpv2 ACCEPTED 14:4x (tinker test output: selo5 14, ntpv2 11 pass; select_b A-only = known stale):
        ntpv2 exps write <cell>-ntpv2.json (old kept), compare phase fails if nll/kl differ > 1e-6
  - [!] NTP v2 dev re-score 10803492/99 scored (JSON written, r.design o5v2) but FAILED compare: nll ≤ 9.3e-5,
        kl ≤ 3.7e-5 vs MY 1e-6 tolerance (too strict; FINDINGS dev-NLL precision: bf16 path +.00015, paired SE ~.0006).
        -> v8ntptol ACCEPTED (my run 32 pass; 2e-4 means, 2e-5 se, exact counts) -> resubmitted 10803641/42
           (devmetrics phase skips; compare reruns) -> COMPLETED 15:2x: both COMPARE OK (nll ≤ 9.3e-5, kl ≤ 3.7e-5,
           r ≤ 5.7e-6, r.design o5v2) -> the O5-only selection precheck inputs exist
- [x] report layer ACCEPTED f0422068 (v8a9rep3 merged with v8-ws; my run 114/114 pass incl. test_ntpv2); history: v8a9rep NOT accepted: merged-tree run 9 fail / 69 pass (3 new-test fixtures missing metrics.jsonl,
      test_item17 stub signature, 5 stale test_psel); o5_rerun schema read via fallback -> follow-up tinker v8a9rep2
  - v8a9rep2 BLOCKED (permissions: VAR= prefix / absolute python / git fetch refused; IMPLEMENTATION-LOG 15:40) ->
    merged tree pushed as inv/v8a9rep3 (c5398ba) -> tinker v8a9rep3 running (env-form test command; audit gate_b1 must
    FAIL, not crash, on a missing metrics.jsonl; o5_rerun new_selected read explicitly + real-code test)
- [x] (i) v2 gradient ratios DONE 16:0x (4 jobs): backbone ρ_R hybrid 2.695 (final) / 0.8304 (step0), strict 2.58 /
      0.9381 (old v1: 3.14/0.85, 2.89/0.95). λ_par(R) v2 = λ_par(F) = 0.0198381 b80 (orchestrator reading of V8-A4 item 1)
- [~] (ii) O5 v2 Stage B grid (assets/aux-weight-stageB-grid-o5v2.json): hybrid λ_R 0.01984, 0.03711, 0.07935, 0.1204,
      0.3711, 1.204; strict 0.01984, 0.03876, 0.07935, 0.3876, 1.066 (step0 ρ=0.1 0.1066 merged into 0.07935). 11 runs,
      NO cuts, submitted 16:4x with chained devmetrics (SWEEP-LEDGER). Anchors = v2 λ=1 runs.
  - [!] 17:1x DETERMINISTIC FAILURE of every v2 training run: config.py:123 allow-list rejects training.aux.o5_loss_version
        (4 λ=1 runs FAILED after ~25 min staging). Stopped the rest: 10 running v2 runs cancelled (correctness stop), 6
        pending + 7 chained devmetrics HELD; 4 devmetrics FAILED (no ckpt). Fix -> tinker v8o5cfg (allow-list + real
        generated-config validation test + search for other aux-key validators). Then: release ONE canary (strict λ=1
        ref) and confirm it passes step 1 + its first metrics line; only then --replace / release all 20 + 11 devmetrics.
  - [x] v8o5cfg ACCEPTED 17:4x (config.py allow-list + int 1/2 + O5-only; 12 real-config tests pass via train_one.sh ->
        load_config; no other aux-key validator found). Canary 10805885 (v2 strict λ=1 ref, new SHA) RUNNING on general
        17:4x -> CANARY OK 18:1x: step 271 loss 2.931, aux_r_raw 1.097 (per-site mean 1.126), 61,437 / 849,223 sites
        sampled (7.2% vs design 6.5%), 542k tok/s. -> 18:2x all 19 other v2 runs + 11 devmetrics resubmitted --replace at
        the fixed SHA (held old-SHA jobs replaced); 7 grid runs moved to idle general.
        19:3x: all 20 v2 runs training (general ~13.2k/h ETA ~02:30–03:30 Thu; preempt ~8.6k/h ETA ~07:30–09:30 Thu).
  - [x] real-run config diff (audits/cfgdiff_v2.py): #6 20/20, #7 34/34 CLEAN (P-sel vs old P-sel of the same cell)
  - [~] 8/11 dev-scored 07:3x Thu (all 5 strict); left hybrid .01984/.07935/1.204 (~08:30)
  - [ ] all 11 dev-scored -> run v8ws-select-B-o5v2 (LP_R_B80_HYB = LP_R_B80_STR = 0.0198381, LP_R_B40 = λ_par(F) b40)
- [x] (iii) Selection B O5-only re-run DONE 08:0x Thu (10812946; 11 v2 candidates, NTP -ntpv2 refs, postcheck OK: rule
      ea0b49e9, 30 non-O5 rows + 8 non-O5 entries byte-identical). hybrid m* 1.000 λ_R b80 .01984 / b40 .06370 (Δ −.0009 ±
      .0006; tie {.01984, .03711} -> smallest); strict m* 1.954 λ_R .03876 / .1244 (+.0098 ± .0008, "no swept weight
      helps"). Published to assets (sha 4ff969f9, byte-equal; old kept as .B-v1O5.json); PROJECT frozen-selection updated.
- [x] P-sel GPU-h + forecast reported to the owner 08:2x Thu (V8-A9 item 9): 16 runs ≈ 150 GPU-h training + ~20 GPU-h
      evals/item-9/A2/C3; S1 Fri ~08:30, S2 Fri ~08:00, S3 Fri ~06:00 (FINAL).
- [ ] (iv) v2 retrain: strict λ=1 O5 ref + 8 P2 λ=1 O5 (can start right after the cache; anchors for (ii)); 16 P-sel O5
      after (iii): 16 v2 P-sel scripts generated (gen_psel_exps O5 --o5v2 --selection assets file) 08:2x Thu
- [ ] (v) for every v2 cell: item-9 evals, A2/oracle-4, C3 audit, item-10 + item-17 O5 comparisons, dev learning gap
  - [x] C3 + slots on 20 trained v2 run dirs (10815448, 13:0x): 20/20 PASS (strict max|Δ suffix logit| 0 fp32/bf16;
        hybrid 27–40 > .01). A2 10815451 COMPLETED 13:5x: 28 models scored (20 v2 + 8 V8-A8 sweep), 0 errors.
  - [x] manifest.csv regenerated 16:4x Thu (fresh v8-ws worktree efa6bdd; backup manifest.pre-v8a9.csv): 328 rows, 24
        invalid_O5_loss_deviation, 24 v2 rows with λ_R from the O5 re-run; --check OK; gen_item9_bundle --resolve maps
        v2 P-sel cells to their run dirs (b80 reps -> the selected v2 sweep runs)
  - [x] item-9 bundle psel-o5v2-01 COMPLETED 19:3x: 9 cells × (WS-swap both splits + summary + slot redundancy), 0 errors
  - [x] ALL 16 P-sel O5 v2 + 9 λ=1 v2 trained 21:3x Thu (V8-A9 (iv) DONE)
  - [x] item-9 bundle psel-o5v2-02 DONE 23:2x: 7 cells, 0 errors -> item-9 complete for all 16 P-sel O5 v2 cells
- [x] V8-A9 (v) evaluations complete (C3 34/34, A2 34/34, item-9 16/16, learning gap) 23:2x Thu
  - [x] A2 rerun 10820948 DONE 22:1x: 14 new models, 0 errors; 34/34 v2 A2 summaries
  - [x] C3/slots rerun 10820947 DONE 21:5x: 34/34 v2 run dirs PASS (all λ=1, grid, P-sel)
  - [x] dev learning gap (v8ws-dev-oracle 10820956) DONE 21:3x: rows for 11 v2 grid + 2 v2 anchors + V8-A8 points
  - [~] (history) 12:2x: v8ws-audit-strict-psel 10815448 (C3 + slots) + v8ws-a2-ws-all 10815451 submitted for trained v2 cells;
        rerun both after P-sel; item-9 bundles after P-sel
  - plan (09:3x): C3 + slots = v8ws-audit-strict-psel (strict_audit --all globs run dirs, so v2 dirs are covered);
    A2 = v8ws-a2-ws-all (--all-ws); item-9 = regenerate bundles for the 16 -sel-o5v2 cells (gen_item9_bundle --all-psel);
    manifest.csv regenerated with v8a9rep3 code before the closeout aggregate; dev learning gap = v8ws-dev-oracle rerun
- [~] V8-A8 closeout: living v14 built 04:11 Fri (10821317). Full V8-A7 audit of v14 (04:2x–05:0x):
  - [x] header LIVING VERSION v14; coverage sums correct (INVALID column outside the total by design)
  - [x] required text: INVALID appendix + 'No conclusion…' (appendix + §8); method notes a–f; no stale V8-A6 text,
        no 'NA (complete)', no pending_selection_B; boundary pairs present (16/16, common h ≥ 80)
  - [x] numbers: 4 v2 cells (top-1, NLL, n, both splits) == recompute3.py; §3.3 O5 λ_R / m* == selection file
  - [x] record-only: report states 2 V8-A8 winners (hybrid O3 .02502, hybrid O4 .1406) == my paired check
        (.1406 vs .008797: +.00113 ± .00054, not a tie); FINDINGS corrected (it said one winner)
  - [x] old O5 values only in the appendix (393 rows, all labelled); 40 superseded P3 O5 rows outside = NA, no numbers
  - [x] links 69/69 resolve; STE measured 207/234 = 88.5% (≥ 80% target; no rewrite)
  - [!] ERROR: the 5 cancelled V8-A8 O5 points are labelled "NA — training"/"training" -> tinker v8a9cancel
  - [x] fix accepted (v8a9cancel) -> living v15 (04:37) re-verified: diff v14→v15 = header + the 10 status cells only
  - [x] audits/audit-20261016-0450-final.md written (clean after the fix)
  - [x] FINAL v16 built 04:53 (10823820): body == v15 except the header; published byte-identical (sha 19141407e82f);
        assets copied exactly; 69/69 links; draft unchanged
  - [x] crons 325b4e64 + df36eb57 deleted; backstop 10715530 cancelled; watchers stopped; standbys released
  - [x] recompute3.py (numpy) 01:0x: O5 re-run Δ reproduced exactly; V8-A8 hybrid O3 .02502 beats the selected O3 by
        −.00138 ± .00055 (2.5 SE) -> v14 must state the limitation (check record_only_check output); v2 cell values to compare

## 0b. NON-NEGOTIABLE — V8-A7 (owner ~13:00 Tue): (1) the rigorous audit comes BEFORE the final analysis is written;
##     (2) the orchestrator may stop ONLY after the final analysis file is written. Owner list: PROJECT.md V8-A7 item 3.

## 0d. V8-A8 (owner ~09:20 Wed) — 13 cut Stage B points (record only) -> rebuild -> full V8-A7 audit -> FINAL
- [x] amendment written + read back; timers: 4dbbbdc1 (Fri FINAL), 9b6df222 (Thu launch rule), e4f79445 (Fri post-freeze
      audit) DELETED; hourly f90dd7c3 replaced by V8-A8 hourly 28f6e384; 12-h audit 325b4e64 kept (CronList verified)
- [x] inv/v8cutb accepted; 26 scripts verified mechanically vs siblings (value-only); 13 training submitted 09:5x Wed
      (8 general running, 5 moved to preempt) + 13 devmetrics chained afterany; job IDs in SWEEP-LEDGER
- [~] config diff vs Stage B sibling (scratchpad/cfgdiff13.py): 12/13 checked (10:0x + 10:4x) = ONLY runtime.output_dir + the
      swept λ_E/λ_R; strict O5 λ_R 1.052 (started 10:4x) -> check when its run dir exists
- [x] all 8 V8-A8 O3/O4 trained + dev-scored 23:3x Wed (SWEEP-LEDGER status: COMPLETE development run; the 5 O5 points
      CANCELLED by V8-A9). Unpaired: only hybrid O3 λ_E .02502 (.8267) sits below its selected value -> record_only_check at rebuild
- [x] inv/v8cutrep accepted (58959c81): 13 = Stage B dev runs (x/34), sweep curves/CSV, §6/§7/§3.4 markers 'V8-A8, record
      only'; record_only_check() re-runs the frozen rule in memory (reproduces all 10 frozen groups exactly) -> §3.3 + §5
      limitation sentence if a point wins; tests 15 pass (my run) / known stale only
- [ ] after all 13 dev-scored: resubmit v8ws-dev-oracle (learning-gap table phase reruns over all dev JSONs; oracle cached)
      so the 13 enter the item-17 dev learning-gap rows
- [ ] rebuild final analysis -> full V8-A7 audit (every study script + collated result; recomputation sample; denominators,
      query sets, labels, statuses, links, ledger rows) -> fix + re-verify -> audits/ file -> MEASURED STE share (≥ 80%)
  - [x] code-path reviews of every study script: (a) training/data/model/eval — DONE 10:0x: masks T/V, eligibility,
        attention rule, dropout, loss normalisation, teacher alignment, budget, seeds, dev-only selection verified correct.
        CONFIRMED by me (aux.py:347-358): O5 L_R uses balanced weights recomputed on the 5% cached subset and / S5 ->
        neither the §6.1 mean nor unbiased (rare cells, e.g. h≥30 bins, drop out). Record only (no method change, no
        retrain; the 3 running V8-A8 O5 runs must match their siblings): FINDINGS + report limitation. Low: no teacher-
        manifest sha assert (L1), fp16 decision NLL clip 2^-24 (L2), O4 η fit on train (L3), separate aux grad clip (L4),
        make_config chunk_sessions not passed (L5, equal today), stale evidence_eval help (L6), WS-swap swaps content not
        positions + strict audit skips BOS (L7) -> report notes via tinker v8a8notes after v8a8fix is accepted; (b) analysis/selection/report/
        orchestration — DONE 10:1x: CONFIRMED by me: FINAL/LIVING/CUTOFF header text hard-codes the superseded Fri freeze
        (living.py:42-44); boundary factor pairs never reach §4/§3.1 (read_pairs keeps only full_eligible; report has 0
        boundary rows, no NA); history-plot denominators count superseded P3 λ=1 rows. Also: strict-audit exps abort on the
        first C3 fail (latent), C3-pending cells can enter aggregate/paired/plots (latent now: all cells C3 PASS), item-17
        k/N unlabelled, harvest-cap risk from logs, item-16 dev arm label, §5 dev seed-6 sentence, FINAL version default
        (-> 14), minor items. Selection/dev-only/frozen rule/m*×λ_par/record_only_check/tiers verified correct.
        -> inv/v8a8fix ACCEPTED 02c5b84f (10:5x): 55 pass, 3 fail = stale pending_selection_B fixtures (test_living ×2,
           test_analysis_report draft counts; Selection B exists) -> owner 11:0x: mark xfail(strict) + file-top reason
           -> v8xfail ACCEPTED (my run: 9 passed, 3 xfailed). Root cause: fx fixture reads the REAL selection file
           (MF.SELECTION not monkeypatched) -> durable fix in the report tinker. Harvest cap raised 2 -> 5 MB by owner (config.sh); audit-strict-psel harvested (3.5 MB)
  - [x] STE checker written (scratchpad/ste_check.py: prose sentences vs R-len ≤25/≤20, R-pass, R-tense, R-ing): v13 =
        150/172 = 87.2% compliant (owner-verbatim sentences account for several length fails). Re-measure on the FINAL text.
        Stale v13 line 'Stage B points cut_owner_A5 are cut ... keeps them cut' must be gone after the V8-A8 rebuild
  - timeline (09:45): general 8 runs ~17:15; preempt 4 ~18:15–20:00; last (strict O5 1.052) ~9 h after start;
    then dev scores + learning gap + rebuild ~1 h; audit fixes ~2–3 h; FINAL ~late Wed / early Thu
- [ ] FINAL build "FINAL, frozen <date time>" -> byte-equal publish -> disarm all study timers + backstop 10715530 -> commit

## 0c. V8-A7 execution plan (owner list; audit -> final analysis)
- [x] amendment + NON-NEGOTIABLE rules written and read back (9ad7459)
- [x] independent recomputation (scratchpad/recompute.py, numpy only, 13:10): per-cell top-1/NLL + denominators (5 cells ×
      2 splits), paired access diff (12.737 pp, SE .031 == paired.csv), dev Δ vs NTP ± SE for 3 candidates (== selection
      JSON) -> all match. Item-17 strict 1.63 reproduced: cell − std 5M = +0.225 nats (misleading ratio confirmed)
- [x] seed provenance: O1 s6 (P-sel eval, 7196ae8) and s7 (1bfca95) used identical eval code; NTP s6 (e4302c7) vs s7
      (662ea96) eval_ws diff adds only optional swap/pin args (default None) -> same scoring path
- [x] read-only code review (subagent): masks/eval/pairing/SE/selection correct; report-layer defects listed
- [x] report fixes ACCEPTED (inv/v8a7fixb, d8a12b3 era): C3-pending status, item-17 per-cell + 'cell − std 5M' + caveat, no
      lsweep fallback + provenance, two seed-noise columns, §3.5 resolution column, §8 V8-A3 text, mixed-λ pairs labelled,
      §4 / paired-summary / §2 split by tier, plot tiers + λ labels, precision + single-draw notes. Tested by me in the
      wllms env: 28 pass, 2 known stale; plots selftest OK 1.11 MB. Branch tree-copy had reverted state files -> restored
      before accept (code-only merge verified)
- [x] v8 PUBLISHED 16:2x (first build with V8-A7 fixes; pre-STE): 0 'NA (complete)', 7 'complete, C3 pending', item-17
      per-cell 'cell − std 5M' + caveat, §5 two label columns, §3.5 resolution column, §8 V8-A3 text; audit 135 PASS / 0 FAIL;
      65 links resolve; byte-equal; draft unchanged
- [x] language pass ACCEPTED (inv/v8ste; ~85% of prose sentences ASD-STE100 by the agent's hand count; owner sentences
      verbatim; numbers/labels/tables unchanged; my test run 26 pass / 3 known stale; code-only merge)
- [x] C3 on every cell: 10793341 (after the last cell) 183/183 pass · item-9 final sweep · A2 resubmit for late runs
- [x] P2-sel b80-hybrid-indep-d0 O3/O4/O5 complete (O3/O4 20:2x Tue, O5 01:55 Wed); ALL 152 production cells trained + evaluated
- [x] independent recomputation #2 (scratchpad/recompute2.py, 02:5x Wed): newest 5 cells (counts == canonical), WS-swap
      (+26.495 / −0.003 pp == summaries), A2 model/oracle-4/oracle-3 top-1 == summaries exactly, seed spreads (hybrid O1
      0.83 pp vs NTP 0.117 pp val_seen; strict 0.49 / 1.83) from the P-sel eval (no Stage A), item 16 O1 +0.0067 ± 0.0001
- [x] A2 final pass 10793301: 187 runs scored (0 failed; 189 summaries incl. std 5M/200M)
- [x] item-9 COMPLETE on 80/80 P-sel cells (03:1x Wed; scratchpad/item9_check.py on compute: 48 × wsswap×2+slot, 16 O3/O4 b40
      + evval×2, 16 O3/O4 b80 + evval×2 + dev evidence; 0 missing)
- [x] inv/v8aggfinal accepted (a029afe2): aggregate exps v13–v20 + v8ws-aggregate-final(-g).sh (--final, version 21)
- [x] v11 (03:28 Wed) built from the complete study: all 152 cells complete + audited (P1 16, P2 40, P2-sel 40, P3-sel 40,
      P4 16), items 16/18 complete, audit 157 PASS / 0 FAIL, item-9 40/40 + 40/40, oracle-4 WS rows present, V8-A7 text
      present, stale text absent, recomputed numbers match (scratchpad/report_check.py)
- [x] 95 'k/N PARTIAL' rows were superseded-by-design (P3 λ=1) -> inv/v8partial accepted (label 'k/N (N−k pairs need
      superseded P3 λ=1 cells; not run by design, V8-A4 item 7)'; tests 21 pass / 2 known stale)
- [x] FINAL ANALYSIS WRITTEN: v12 (03:48 Wed) passed report_check.py (0 PARTIAL rows, 0 'NA (complete)', coverage sums,
      V8-A7 text, recomputed numbers, one-factor dev rule, tier-separated plots) -> published (69 links, byte-equal, draft
      unchanged). V8-A7 stop rule satisfied. [ ] FINAL relabel at the Fri 12:00 freeze (cron 4dbbbdc1, v8ws-aggregate-final)
- [~] V8-A6 6-h refresh plan SUPERSEDED by V8-A8 (v12 03:48 + v13 07:44 published; no further refreshes)
- [ ] CPU standby 10793264 expires ~12:40 Wed: renew before the Thu 00:00 audit (collector needs it)

## 1. Every hourly wake-up (cron f90dd7c3 :07) — read STATE + this file + SWEEP-LEDGER first, update last
- [ ] counts + ETAs per cell / sweep / seed / control run; forecast row in intermediate-analyses (verify by reading back)
- [ ] preempt rate (bin/v8-preempt-rate.py on sacct -D 72 h) -> S1 (8) / S2 (8 + net preempt, MAIN) / S3 (32); S2 tier
      miss of Fri 10:00 -> tell owner AT ONCE (GPUs needed + rate); never conclude a miss from S1
- [ ] harvest; disk both filesystems (clean up only < 20% free); GPUs per pool; Restarts>0 pending jobs with all phases
      done -> move to general; eval phase > 30 min -> node check; preempted -> requeue as same run; no blind retries
- [ ] priority V8-A6 item 6: dev scoring > Stage B > items 16/18 > P-sel O1/O2 (strict first) > P-sel O3–O5 (strict
      first) > P4; critical path on general; queues full; never cancel running jobs for priority; P4 entries LAST in
      state/topup-queue.txt; top-up submitter (bin/v8-topup.sh, scratchpad/topup.log) alive; watcher re-armed
- [ ] commit; `ae submit` only on a clean pushed tree; commit LEDGER after each "submitted" line

## 2. Open gaps from audit #1 (fix order: correctness -> critical path -> missing evals -> tracking)
- [ ] G-A item-9 diagnostics (WS-swap both splits, slot redundancy, O3/O4 evidence real vs const WS val + dev)
  - [x] bundles psel-01/02/03 (O1/O2, 28 cells) submitted 23:3x: 10772642 / 10772688 / 10772691 (preempt); 01/02 RUNNING
        ~08:05 Tue, first cell's wsswap ×2 + summary + slot OK (~25 min per b40 cell)
  - [~] bundle 03 DONE 11:40 (10 hybrid: swap Δ within ±0.02 pp); bundle 01 DONE 11:46 (10 strict: Δ +11..+26 pp); 02 DONE 12:1x (hybrid O1 ≈ 0; strict O2 +15..+22); confirm every
        complete O1/O2 cell has wsswap ×2 + slot (rerun bundles for late cells)
  - [x] bundles psel-04/05/06 (strict O3/O4/O5) submitted 09:4x: 10781495 / 10781502 / 10781505
  - [x] bundles psel-07/08 submitted 12:3x (10784468 / 10784471); 06 DONE 12:4x
  - [x] sweep 1 DONE (8 bundles, 0 errors) + A2 182/0 failed
  - [~] final pass: bundles 01–07 (10793280–95, general) + 08 (10793299) and A2 (10793301) after the last training job ->
        verify 80/80 with audit_gt.py
  - [x] evval phase verified (bundle 04, b40-strict-causal-d0-O3-sel: L_E real .031 vs const .124)
  - [x] dev `evidence` phase works with -sel names (bundle 07: b80-hybrid-causal-d0-O4-sel L_E real 2.332 vs const 2.623,
        263,512 dev decisions); bundle 07 DONE 13:09 (2 cells; rest not yet trained -> final sweep)
- [ ] G-B oracle 4 (A2) for every WS model: v8a2ws accepted (exp v8ws-a2-ws-all: one model per process, resumable,
      ~4.2 GPU-h for 137 runs) -> 10773226 submitted 00:0x (preempt) -> harvest -> report §2 WS rows; resubmit after
      more cells finish (lists runs at start). A2 names = 5M-<run dir> (not manifest run_ids; map via audit.run_cell)
- [ ] G-C preemption loss per preemption measured (V8-A6 item 7): small tinker for v8-preempt-rate.py (lost steps
      since last checkpoint per preempted attempt); until then S2 uses 3% (bound: ckpt every 300 s + ~7 min restart)
- [ ] G-D tests: v8ws-tests-v8 10772853 DONE 02:11: 245 passed, 14 failed, 6 errors (2043 s, GPU node). The 3 never-
      verified files (test_ws_eval / test_wsswap / test_ws_train) PASS. Stale fixtures: test_psel ×5, test_living ×2,
      test_analysis_report ×1. Triage (inv/v8testfail, 02:20): test_devsel packed flag + std_e2e (max per-decision
      0.117 vs CPU ref; dev NLL is the selection metric), test_nows K0 == std rescore, test_select_b A-only bytes,
      test_vallabels device errors. v8testfail (code reading; 996ed89 accepted 4ad38a8): no code defect — CPU-default /
      device assumptions (devsel packed, vallabels ×5), test-order pollution (vallabels defaults), stale (select_b A-only
      now reads the B file), bf16/fp16 tolerance (nows K0). [x] v8ws-devprecision 04:34: bf16 shifts mean dev NLL +.00015 (2% of SE);
      paired shift −1.4e-6 -> selections unaffected (FINDINGS)
      [ ] apply the proposed test diffs (one tinker) + stale fixtures
- [x] G-E item 18 hybrid O1 s7: requeued 00:04, COMPLETED 00:17; dev .8496 (FINDINGS item 18)
- [x] G-H C3 rerun 10773738 COMPLETED 02:0x: 136 results, 0 fail; b40-hybrid-causal-d0-O2-sel must-change 33.1 (PASS)
- [ ] G-F report text: state the seed-noise threshold (max of NTP and O1 spread) explicitly; no method change

## 3. Controls and analyses
- [x] Item 18 analysis (FINDINGS, 00:30 Tue): O1 spread hybrid .0203 / strict .0253 vs NTP .0008 / .0134; hybrid O1 gain
      does not replicate at s7; no artifact found. [ ] owner: optional extra O1 seed per access (~18 GPU-h) — asked
- [x] Item 16 analysis on real data (v3/v4 §3.5; FINDINGS): DiD O1 −.0024 / O2 −.0069 dev, below the hybrid O1 seed spread
      .0204. [x] attribution: WS-swap Δ ≈ 0 on the hybrid O1-sel and O2-sel b80 cells -> DiD not carried by WS content
- [ ] Item 17 + item 10 for every complete P-sel cell (each living version; NA + reason otherwise)

## 4. Production completion (V8-A6 item 4 scope)
- [x] P1 16/16, P2 λ=1 40/40 complete + audited [verified audit #1]
- [ ] P3-sel 19/40 · P2-sel 16/40 (+1 evaluating) · P4 10/16 — all remaining queued/running; C3 audit rerun (bundled,
      `v8ws-audit-strict-psel`, verdicts read on cluster: distillates > 2 MB -> make that exp emit a summary)
- [ ] W1 config diff for the 12 hybrid Stage B + remaining P-sel (vs λ=1 twin where one exists): audit_gt.py does it

## 5. Living final analysis (V8-A6 items 1–2)
- [x] v1 19:46 Mon (96e8ffb) · v2 21:32 Mon (ae1973d)
- [x] **v3 PUBLISHED 00:05 Tue** (aggregate-v3 10772845, 17 min; audit 107 PASS / 0 FAIL): P2-sel 16/40, P3-sel 19/40,
      P4 10/16, item 16 3/3 (§3.5 first real output; dev paired == unpaired), item 18 3/4; 46 links resolve; byte-equal; draft unchanged
- [x] v4 PUBLISHED 00:3x Tue (f2e50a2; item 18 4/4; labels use O1 spread .0204/.0253; 46 links; byte-equal)
- [x] v5 PUBLISHED 05:0x Tue (aggregate-v5 10777492; audit 112 PASS / 0 FAIL): P2-sel 18/40, P3-sel 19/40, P4 12/16
- [x] v6 PUBLISHED 10:1x (aggregate-v6; audit 125 PASS / 0 FAIL): P2-sel 18/40, P3-sel 19/40, P4 12/16. DEFECT: §0 rows
      'complete, C3 not run' counted in no column (v6: 12 rows) -> FIXED inv/v8covcol accepted (new column; tier_rows raises
      if a row does not sum; test added, 9 pass, 2 stale-fixture fails as on base)
- [x] v7 PUBLISHED 12:5x Tue (audit 130 PASS / 0 FAIL; P2-sel 21/40, P3-sel 34/40, P4 14/16; first with the C3 column; rows sum)
- [x] v9 PUBLISHED 17:3x (P3-sel tier 40/40 complete + audited; C3 10789154 163/163; audit 137 PASS / 0 FAIL; first STE build)
- [x] v10 PUBLISHED 00:2x Wed (P4 tier 16/16 complete + audited; C3 10792674 167/167; audit 155 PASS / 0 FAIL; P2-sel 36/40)
- [ ] v11 on the P2-sel tier: C3 10793341 + aggregate-v11 10793342 (both after the last training job) -> check -> publish v7 on P3-sel tier complete (~16:25, per-job forecast); C3 rerun first (K16-b40-hybrid-indep-d02 + new cells)
- [ ] if an aggregate has not started within 6 h on the preempt CPU queue -> v1g-style general 1-GPU fallback

## 6. Deadlines (V8-A6 item 3)
- [ ] Thu 15 Oct 12:00 (cron 9b6df222): launch nothing ending after Fri 10:00 (hold such jobs; ledger them)
- [ ] Fri 16 Oct 12:00 (cron 4dbbbdc1): FINAL version; cancel remaining study jobs, ledger "not completed by Fri 12:00
      cutoff", delete partial outputs (record), stop submitter/watchers, delete hourly + audit crons; backstop 10715530
      (Fri 12:15) then cancelled if nothing remains

## 7. Housekeeping
- [x] CPU standby: 10772632 TIMED OUT 15:35 Tue (was mis-tracked as running) -> new 10793264 00:4x Wed (expires ~12:40 Wed;
      renew before then); duplicate 10793266 cancelled. Hourly check lists ae-dbg-cpu state
- [ ] 10739916 (b40 hybrid causal-d0 O2-sel) finished all phases 23:39 then PREEMPTED -> skip-through requeue pending; harvest after
- [x] 10716458 (no-op requeue of a finished P2 cell): ran 3 s and COMPLETED 12:1x Tue -> no owner decision needed
