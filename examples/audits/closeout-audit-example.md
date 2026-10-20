# Closeout audit before FINAL — 2026-10-16 04:20–04:50 EDT (V8-A7 full audit required by V8-A8 item 5 / V8-A9 item 10)

Object of the audit: living v14 (`v8ws-aggregate` 10821317, built 2026-10-16 04:11 EDT at commit ee790a2), then the
re-verify build v15 (10823716, 04:37 EDT, commit f037ad5) after one fix. Previous scheduled audit: audit-20261016-0045
(#8). All study training and evaluation was complete before the rebuild (V8-A8 8/8 O3/O4 record-only runs; V8-A9 O5 v2:
grid 11/11, λ=1 9/9, P-sel 16/16, C3 34/34, A2 34/34, item-9 16/16, dev learning gap).

## 1. Code paths re-read and tested (every script written in this study)
| area | what was checked | evidence |
|:--|:--|:--|
| training / data / model / eval | masks T/V, eligibility, attention rule, dropout, loss normalisation, teacher alignment, budget, seeds | read-only review 2026-10-14 (FINDINGS "Training-side code audit"); one deviation found (O5 L_R) -> V8-A9 |
| O5 v2 loss | IPW estimator unbiased (MC + enumeration), gradcheck, no teacher grad, v1 bitwise unchanged; config validation of the real generated configs | tests 31 + 12 pass (my runs / tinker output); canary training run (aux_r_raw 1.097 ≈ per-site 1.126, 7.2% sites vs 6.5% design) |
| o5v2 teacher cache | realised 16,587,680 sites vs 16,581,581 expected; old/new teacher hidden on overlap cos ≥ .9998 | consolidate log; o5cos.py |
| selection | frozen rule ea0b49e9 byte-identical; O5-only re-run postcheck (30 non-O5 rows + 8 entries byte-identical); dev-only inputs; paired SE; m* per boundary | postcheck log; recompute3.py reproduces the O5 Δ to 6 decimals |
| analysis / report layer | v8a8fix, v8a9rep(3), v8a9cancel accepted after tests (114/114 merged; 3/3) | test runs |
| config diffs | V8-A9 item 7 on REAL run dirs: 34/34 v2 runs differ from their old counterparts only in o5_loss_version, λ_R and output paths | audits/cfgdiff_v2.py (audit #7) |

## 2. Collated results checked against ground truth
| check | result |
|:--|:--|
| gates, current code | 152/152 in-scope rows (128 non-O5 + 24 v2 O5) PASS A4, B1, B2, C3, S2, S3 on both splits; 0 λ mismatch; seeds 6/6; 1 ckpt/run (audit_gt.py, audit #8); rebuild audit 156 PASS / 0 FAIL / 28 never-trained superseded |
| independent recomputation (numpy, no project code) | 4 v2 cells (P2 λ=1 and P-sel, b40 + b80, both accesses): focal / opponent legal top-1, legal NLL and eligible n on both splits == the report rows to the printed precision; denominators == canonical h ≥ b counts |
| selection numbers | §3.3 O5: hybrid λ_R .01984 (b40 .06370, m* 1.0001), strict .03876 (b40 .1244, m* 1.954) == selection file sha 4ff969f9 |
| record-only (V8-A8 item 3) | report states 2 winners: hybrid O3 λ_E .02502 and hybrid O4 λ_E .1406. My paired dev checks: O3 .02502 vs selected −.00138 ± .00055; O4 .1406 vs selected −.00269 ± .00050; O4 .008797 also below the selection but worse than .1406 by .00113 ± .00054 (> 1 SE, not a tie); all other V8-A8 points worse than their selection. Report matches. |
| denominators / query sets | coverage table: complete + audited = total in every tier; INVALID column outside the total by design; boundary pairs on the common h ≥ 80 query set present (16/16) |
| labels / statuses | old O5: 393 appendix rows, all labelled "INVALID: O5 loss deviation (V8-A9)"; no old O5 value outside the appendix (the 40 superseded P3 O5 rows outside it are NA, no numbers); "No conclusion in this document uses these results" in the appendix and §8; method notes a–f present; no "NA (complete)", no pending_selection_B, no stale V8-A6 freeze text |
| links | 69/69 relative links resolve |
| ledger rows | LEDGER.jsonl vs sacct: 468 expids, 0 failed latest attempt, 0 duplicate active (audit #8) |
| ASD-STE100 share (MEASURED) | scratchpad/ste_check.py on v14 prose: 207 / 234 sentences = 88.5% (target ~80%; no correction needed) |

## 3. Errors found and fixed
1. **Status label (fixed, re-verified).** v14 labelled the 5 V8-A8 O5 sweep points that V8-A9 item 4 cancelled
   (hybrid λ_R .1181/.3181/1.181, strict .3463/1.052) as "NA — training" / "training". Fix: inv/v8a9cancel (named
   constant, label "cancelled (V8-A9 item 4: old O5 loss)"; test fails without the fix). Re-verified on v15: the 10
   status cells now read "cancelled (…)"; the v14→v15 diff is exactly those 10 cells + the version header (22 diff
   lines); no other report content changed, so every check in §2 carries over to v15.
2. **Tracking (fixed).** FINDINGS said only one V8-A8 point would have won; corrected to two (O3 .02502, O4 .1406).

## 4. Known, recorded, not errors in the report
- Two tests read the LIVE selection file and now fail on data drift (test_v8a9rep real-file test: "already carries an
  o5_rerun record"; test_living_a8 record_only_check: 41 vs 37 candidates). They fail identically without any code
  change; the code paths they cover were verified directly above (record-only check reproduced by hand).
- λ values of P-sel rows print with the manifest's full text precision (e.g. "R 0.124443825366"); consistent with the
  manifest, cosmetic only.

## 5. Verdict
After fix 1 the audit is clean: no correctness error, no unverified number in the sampled set, every denominator /
label / status / link / ledger row checked. FINAL (v16) may be built.
