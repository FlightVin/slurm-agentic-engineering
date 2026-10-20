# Sweep ledger — Amendment V8-A4 development runs (NOT production cells; never in production tables)
λ_par (b80, from training logs 15:00): K 0.01984, F 0.01984, E 1.400e-4, R 9.920e-4. Dev split only for selection.
λ_par (b40, from training logs): K 0.0636927, F 0.0636927, E 4.4919e-4, R 3.18547e-3 (R measured 18:23 from the first 2
finished b40 O5 λ=1 runs, as the frozen rule requires before any b40 O5 production cell; rule JSON itself unchanged).
| stage | objective | access | cell | swept | value | expid | job | status |
|:--|:--|:--|:--|:--|--:|:--|:--|:--|
| A | O1 | hybrid | K4-b80-hybrid-indep-d02 | λ_K | 0.005 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O1-lk0.005 | 10722521 | submitted 14:55 (moved to general 15:03) |
| A | O1 | hybrid | K4-b80-hybrid-indep-d02 | λ_K | 0.02 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O1-lk0.02 | 10720953 | sig dd05787358fe; training 100% (final ckpt 19:14) + both val evals done 19:28, then marked PREEMPTED at the final listing (earlier "~90%" was wrong, corrected 03:28 Oct 11); pending requeue on general skips through, then dev scoring 10727394 runs |
| A | O1 | hybrid | K4-b80-hybrid-indep-d02 | λ_K | 0.1 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O1-lk0.1 | 10720955 | TRAINED 18:38 (sig 5e73e819cb8a); devmetrics DONE 18:54 (10724346) |
| A | O1 | hybrid | K4-b80-hybrid-indep-d02 | λ_K | 0.3 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O1-lk0.3 | 10720957 | TRAINED 18:12 (sig f311628016e6); devmetrics DONE 18:38 (10724270, with sessions npz) |
| A | O1 | strict | K4-b80-strict-indep-d0 | λ_K | 0.005 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O1-lk0.005 | 10722524 | submitted 14:55 (moved to general 15:03) |
| A | O1 | strict | K4-b80-strict-indep-d0 | λ_K | 0.02 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O1-lk0.02 | 10722525 | submitted 14:55 (moved to general 15:03) |
| A | O1 | strict | K4-b80-strict-indep-d0 | λ_K | 0.1 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O1-lk0.1 | 10722526 | submitted 14:55 (moved to general 15:03) |
| A | O1 | strict | K4-b80-strict-indep-d0 | λ_K | 0.3 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O1-lk0.3 | 10722527 | submitted 14:55 (moved to general 15:03) |
| A | O2 | hybrid | K4-b80-hybrid-indep-d02 | λ_F | 0.00496 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O2-lf0.00496 | 10722583 | submitted 15:02 (preempt) |
| A | O2 | hybrid | K4-b80-hybrid-indep-d02 | λ_F | 0.01984 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O2-lf0.01984 | 10722584 | submitted 15:02 (preempt) |
| A | O2 | hybrid | K4-b80-hybrid-indep-d02 | λ_F | 0.07935 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O2-lf0.07935 | 10722585 | submitted 15:02 (preempt) |
| A | O2 | hybrid | K4-b80-hybrid-indep-d02 | λ_F | 0.3174 | v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O2-lf0.3174 | 10722588 | submitted 15:02; moved to general 17:50 |
| A | O2 | strict | K4-b80-strict-indep-d0 | λ_F | 0.00496 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O2-lf0.00496 | 10722589 | submitted 15:02 (preempt) |
| A | O2 | strict | K4-b80-strict-indep-d0 | λ_F | 0.01984 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O2-lf0.01984 | 10722590 | submitted 15:02 (preempt) |
| A | O2 | strict | K4-b80-strict-indep-d0 | λ_F | 0.07935 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O2-lf0.07935 | 10722592 | submitted 15:02; moved to general 17:50 |
| A | O2 | strict | K4-b80-strict-indep-d0 | λ_F | 0.3174 | v8ws-lsweep-5M-K4-b80-strict-indep-d0-O2-lf0.3174 | 10722594 | submitted 15:02; moved to general 17:50 |
| A | sel | both | — | rule ea0b49e9 | — | v8ws-select-A | 10730739 | submitted 07:30 Oct 11 (general), afterany the last 2 dev scores 10727402/09; DEV only; output selection/aux-weight-selection.json (+ .rule-frozen.json copy) |
| ref | λ=1 | strict | K4-b80-strict-indep-d0 | O3 / O4 | 1 | v8ws-train-5M-K4-b80-strict-indep-d0-O3 / -O4 | 10717345 / 10717352 | Stage B anchors; moved preempt -> general 07:29 Oct 11, running |
| ref | O1–O5 | strict | K4-b80-strict-indep-d0 | all λ=1 | 1 | v8ws-train-5M-K4-b80-strict-indep-d0-O1..O5 | 10717325/30/45/52/36 | released 14:56 (were held P3) — O5: invalid_O5_loss_deviation (V8-A9) |
| B | O3 | both | rep. cells | λ_E (λ_F = selected) | grid per V8-A5 item 2 (ρ points from NTP/step-0 grads, merged within 1.5× of λ_par×{1,4}) | – | – | after λ_F selection |
| B | O4 | both | rep. cells | λ_E (λ_F = selected) | grid per V8-A5 item 2 (ρ points from NTP/step-0 grads, merged within 1.5× of λ_par×{1,4}) | – | – | after λ_F selection |
| B | O5 | both | rep. cells | λ_R (λ_F = selected) | grid per V8-A5 item 2 | – | – | after λ_F selection |
Stage B grid FINAL (19:40; aux-weight-stageB-grid.json sha256 95d7ebac…; λ_F = selected per access at submission):
| B | O3 | hybrid | λ_E | 1.4e-4, 5.6e-4, 8.85e-4, 8.85e-3, 0.025, 0.25 (6) |
| B | O4 | hybrid | λ_E | 1.4e-4, 5.6e-4, 8.8e-4, 8.8e-3, 0.0141, 0.141 (6) |
| B | O5 | hybrid | λ_R | 9.92e-4, 3.97e-3, 0.0318, 0.118, 0.318, 1.18 (6) |
| B | O3 | strict | λ_E | 1.4e-4, 5.6e-4, 5.05e-3, 0.0246, 0.246 (5; 5.05e-4 merged into 5.6e-4) |
| B | O4 | strict | λ_E | 1.4e-4, 5.6e-4, 4.11e-3, 0.0138, 0.138 (5; 4.11e-4 merged into 5.6e-4) |
| B | O5 | strict | λ_R | 9.92e-4, 3.97e-3, 0.0346, 0.105, 0.346, 1.05 (6) |
Total 34 runs. Ratio points = λ at ρ 0.1/1 under the NTP-final and step-0 measurements (backbone ρ, active updates).
**V8-A6 (owner, 16:25 Oct 11): the V8-A5 Tuesday deadline is cancelled, but the 13 Stage B cuts below are KEPT (not
restored, to avoid delaying Selection B). Stage B runs and their dev scoring are the critical path on general.**

**Stage B SUBMITTED 08:10 Oct 11 — 21 of 34 (V8-A5 deadline-guard trims; forecast far past 09:00 Tue).** λ_F fixed at the
Selection A value: hybrid 0.01984 (m*_F 1.00), strict 0.00496 (m*_F 0.25). Trim rule: keep λ_par×1 + the points with log m
closest to log m*_F (hybrid 3/term, strict 4/term; strict '4 points' read the same way — recorded interpretation).
| B | O3 | strict | λ_E | KEEP 1.4e-4 (10730922), 5.6e-4 (10730926), 5.05e-3 (10730931), 0.0246 (10730933); CUT 0.246 |
| B | O4 | strict | λ_E | KEEP 1.4e-4 (10730936), 5.6e-4 (10730937), 4.11e-3 (10730938), 0.0138 (10730941); CUT 0.138 |
| B | O5 | strict | λ_R | KEEP 9.92e-4 (10730942), 3.97e-3 (10730944), 0.0346 (10730948), 0.105 (10730949); CUT 0.346, 1.05 — O5: invalid_O5_loss_deviation (V8-A9) |
| B | O3 | hybrid | λ_E | KEEP 1.4e-4 (10730951), 5.6e-4 (10730955), 8.85e-4 (10730956); CUT 8.85e-3, 0.025, 0.25 |
| B | O4 | hybrid | λ_E | KEEP 1.4e-4 (10730960), 5.6e-4 (10730962), 8.8e-4 (10730963); CUT 8.8e-3, 0.0141, 0.141 |
| B | O5 | hybrid | λ_R | KEEP 9.92e-4 (10730964), 3.97e-3 (10730967), 0.0318 (10730970); CUT 0.118, 0.318, 1.18 — O5: invalid_O5_loss_deviation (V8-A9) |
**V8-A9 (owner, ~10:20 Wed 14 Oct): every O5 run trained with the old L_R (5% subset, re-balanced, / S5) has status
`invalid_O5_loss_deviation` (kept as a record; not failures, not deleted): Stage B O5 ×7, strict λ=1 O5 ref, P2 λ=1 O5 ×8,
P2-sel/P3-sel O5 ×16. The 5 V8-A8 O5 points were cancelled. A new O5 Stage B grid (o5_loss_version 2) follows below when
submitted.**

**V8-A8 (owner, 09:20 Wed 14 Oct): the 13 CUT points are now run as record-only Stage B points (no re-selection; frozen rule
ea0b49e9 and selected λ unchanged). Rows below are updated as they train and are dev-scored.**
| B (V8-A8 record-only) | 3 | hybrid | K4-b80-hybrid-indep-d02-O3-lf0.01984-le0.008847 | train 10797405 | devmetrics 10797408 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 17:xx Wed; dev NLL .8346 ± .0076; KL .0739 (bal .0681); L_E real .0374 < constWS .0726 (unpaired; record only, frozen rule ea0b49e9) |
| B (V8-A8 record-only) | 3 | hybrid | K4-b80-hybrid-indep-d02-O3-lf0.01984-le0.02502 | train 10797412 | devmetrics 10797416 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 18:xx Wed; dev NLL .8267 ± .0076; KL .0660 (bal .0607); L_E real .0372 < constWS .0889. UNPAIRED value is below the selected hybrid O3 (≈ .8282 = NTP .8335 − .0053): may win under the frozen rule -> record_only_check (paired SE) at the rebuild; if it wins, report states it as a limitation (V8-A8 item 3); no action (record only, rule ea0b49e9) |
| B (V8-A8 record-only) | 3 | hybrid | K4-b80-hybrid-indep-d02-O3-lf0.01984-le0.2502 | train 10797419 | devmetrics 10797423 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 17:xx Wed; dev NLL .8303 ± .0076; KL .0699 (bal .0644); L_E real .0386 < constWS .0401 (unpaired; record only, frozen rule ea0b49e9) |
| B (V8-A8 record-only) | 4 | hybrid | K4-b80-hybrid-indep-d02-O4-lf0.01984-le0.008797 | train 10797427 | devmetrics 10797435 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 17:xx Wed; dev NLL .8309 ± .0076; KL .0697 (bal .0640); L_E real 2.3085 < constWS 2.3499 (unpaired; record only, frozen rule ea0b49e9) |
| B (V8-A8 record-only) | 4 | hybrid | K4-b80-hybrid-indep-d02-O4-lf0.01984-le0.01406 | train 10797438 | devmetrics 10797442 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 17:xx Wed; dev NLL .8355 ± .0076; KL .0737 (bal .0685); L_E real 2.3217 < constWS 2.3333 (unpaired; record only, frozen rule ea0b49e9) |
| B (V8-A8 record-only) | 4 | hybrid | K4-b80-hybrid-indep-d02-O4-lf0.01984-le0.1406 | train 10797444 | devmetrics 10797449 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 18:xx Wed; dev NLL .8298 ± .0076; KL .0691 (bal .0640); L_E real 2.3103 < constWS 2.3347 (record only, rule ea0b49e9) |
| B (V8-A8 record-only) | 5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.1181 | train 10797454 | devmetrics 10797461 (afterany) | submitted 09:5x Wed 14 Oct — CANCELLED 10:2x Wed (V8-A9 item 4; old O5 loss) |
| B (V8-A8 record-only) | 5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.3181 | train 10797465 | devmetrics 10797467 (afterany) | submitted 09:5x Wed 14 Oct — CANCELLED 10:2x Wed (V8-A9 item 4; old O5 loss) |
| B (V8-A8 record-only) | 5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr1.181 | train 10797471 | devmetrics 10797474 (afterany) | submitted 09:5x Wed 14 Oct — CANCELLED 10:2x Wed (V8-A9 item 4; old O5 loss) |
| B (V8-A8 record-only) | 3 | strict | K4-b80-strict-indep-d0-O3-lf0.00496-le0.2464 | train 10797477 | devmetrics 10797480 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 23:xx Wed; dev NLL 1.0258 ± .0070; KL .2626 (bal .2762); L_E real .0345 < constWS .0717; worse than the selected strict O3 (≈ .9741) (record only, rule ea0b49e9) |
| B (V8-A8 record-only) | 4 | strict | K4-b80-strict-indep-d0-O4-lf0.00496-le0.1383 | train 10797484 | devmetrics 10797493 (afterany) | submitted 09:5x Wed 14 Oct — COMPLETE development run 23:xx Wed; dev NLL 1.0471 ± .0071; KL .2838 (bal .3042); L_E real 2.3054 < constWS 2.4364; worse than the selected strict O4 (≈ .9903) (record only, rule ea0b49e9) |
| B (V8-A8 record-only) | 5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr0.3463 | train 10797497 | devmetrics 10797500 (afterany) | submitted 09:5x Wed 14 Oct — CANCELLED 10:2x Wed (V8-A9 item 4; old O5 loss) |
| B (V8-A8 record-only) | 5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr1.052 | train 10797502 | devmetrics 10797504 (afterany) | submitted 09:5x Wed 14 Oct — CANCELLED 10:2x Wed (V8-A9 item 4; old O5 loss) |
Exp names: v8ws-lsweep-5M-<cell>-O<n>-lf<λ_F>-l{e,r}<λ>. Cut points (13) = the large-m ratio points; reported to owner 08:15.
Strict λ=1 anchor O5 10717336 moved to general 08:12 (O3/O4 anchors running since 07:29).
| B-anchor | O3/O4/O5 | hybrid | K4-b80-hybrid-indep-d02 | all λ=1 (λ_F = 1, NOT selected) | 1 | P2 cells (finished) | – | production-value anchors (V8-A5 item 2) |
| B-anchor | O3/O4/O5 | strict | K4-b80-strict-indep-d0 | all λ=1 (λ_F = 1, NOT selected) | 1 | refs 10717345/52/36 | – | production-value anchors (V8-A5 item 2) |
| seed | NTP | hybrid | K4-b80-hybrid-indep-d02 | seed | 7 | v8ws-seed7-5M-K4-b80-hybrid-indep-d02 | 10724008 | COMPLETED ~12:50 Oct 11, harvested; val (reporting) vs seed 6: focal top-1 +0.06 / +0.03 pp, opp −0.29 / −0.25 pp, suffix NLL +.0020 / +.0022 (seen / unseen); config differs only in seed + bin packing; dev scoring 10736162 |
| seed | NTP | strict | K4-b80-strict-indep-d0 | seed | 7 | v8ws-seed7-5M-K4-b80-strict-indep-d0 | 10724014 | COMPLETED ~12:35 Oct 11, harvested; val (reporting) vs seed 6: focal top-1 −0.97 / −1.15 pp, opp −0.02 / −0.06 pp, suffix NLL +.0034 / +.0040 (seen / unseen); same config except seed + seed-dependent bin packing (108,722 vs 108,724 steps), NTP code path unchanged between commits; dev scoring 10735874 |
| seed | NTP | hybrid | K4-b80-hybrid-indep-d02 | seed | 7 | v8ws-seed7-5M-K4-b80-hybrid-indep-d02 | 10723979 | CANCELLED 17:58 before start (resubmitted) |
| seed | NTP | strict | K4-b80-strict-indep-d0 | seed | 7 | v8ws-seed7-5M-K4-b80-strict-indep-d0 | 10723985 | CANCELLED 17:58 before start (resubmitted) |
| seed | NTP | hybrid | K4-b80-hybrid-indep-d02 | seed | 7 | v8ws-seed7-5M-K4-b80-hybrid-indep-d02 | 10723995 | CANCELLED 17:59 before start (resubmitted) |
| seed | NTP | strict | K4-b80-strict-indep-d0 | seed | 7 | v8ws-seed7-5M-K4-b80-strict-indep-d0 | 10724000 | CANCELLED 17:59 before start (resubmitted) |
| seed | O1 sel λ | hybrid | K4-b80-hybrid-indep-d02 | λ_K 0.1, seed | 7 | v8ws-seed7-5M-K4-b80-hybrid-indep-d02-O1-lk0.1 | 10730971 | submitted 08:10 Oct 11 (general); runs-seed root; trained 108722 steps 23:52 Mon; FAILED on the run_dir-…-s7.txt path bug; requeued same run 00:04 Tue (Nice 0); devmetrics 10742357 running |
| seed | O1 sel λ | strict | K4-b80-strict-indep-d0 | λ_K 0.02, seed | 7 | v8ws-seed7-5M-K4-b80-strict-indep-d0-O1-lk0.02 | 10730974 | submitted 08:10 Oct 11 (general) |
| ctrl16 | NTP | K=0 | K0-b80-std | – | – | v8ws-train-5M-K0-b80-std | 10724421 | submitted 18:55 (matched K=0 NTP reference); moved to general 08:12 Oct 11 |
| ctrl16 | O1 | K=0 | K0-b80-std | λ_K | 0.1 (hybrid m* 5.04 × λ_par b80) | v8ws-train-5M-K0-b80-std-O1-lk0.1 | 10730976 | submitted 08:10 Oct 11 (general); hybrid m* because K=0 = full attention |
| ctrl16 | O2 | K=0 | K0-b80-std | λ_F | 0.01984 (hybrid m* 1.00 × λ_par b80) | v8ws-train-5M-K0-b80-std-O2-lf0.01984 | 10730978 | submitted 08:10 Oct 11 (general) |
Hybrid λ=1 references = existing P2 cells; NTP references = existing P1 cells (b80-hybrid-indep-d02, b80-strict-indep-d0).
SUPERSEDED: the 09:40 rule "lowest val_seen b80 legal action NLL among λ with KL below NTP" (val data) — cancelled by
V8-A4 (owner, 14:50); no λ was ever selected under it. The running runs' exp-script HYPOTHESIS lines still quote it
(pinned scripts, not edited); the runs are rescored on the DEV split under V8-A4 item 5.

Dev scoring (23:15): devmetrics jobs 10727369–10727438 for all 14 remaining Stage A candidates + strict O1/O2 λ=1 refs,
each afterany its training job, all on the general queue (strict O1 lk0.005 trained 23:05, no dependency).

P-sel (09:40 Oct 11): inv/v8psel accepted c53dd33 -> manifest 304 rows, 32 O1/O2 -sel exp scripts (not yet submitted:
general 50-job cap; queued after the 10 devmetrics top-ups). λ (b80 / b40): O1 hybrid 0.1 / 0.321033, strict 0.02 /
0.0642067; O2 hybrid 0.01984 / 0.0636988, strict 0.00496 / 0.0159247. Representative b80 cells (hybrid-indep-d02,
strict-indep-d0) × O1/O2 reuse the Stage A sweep run dirs (identical config, seed 6) -> eval-only into <cell>-sel.
O3–O5 P-sel = NTP + λ_F(Selection A O2, per access)·L_F + λ_E|λ_R(Selection B)·L (model/aux.py; O1 has no F term).

## Dev metrics (dev split only; b80 suffix; NLL = legal action NLL focal+opp pooled ± session-clustered SE)
| model | NLL | KL per-site | KL balanced | note |
|:--|--:|--:|--:|:--|
| std 5M (V7, K=0) | .8328 ± .0075 | .0715 | .0654 | item-17 gap-closed base |
| std 200M (V7, K=0; = teacher) | .7661 ± .0077 | .00008 | .0001 | gap-closed top; KL≈0 sanity PASS (teacher cache = this model) |
Dev oracle tables (v8ws-dev-oracle 10724268, 19:02; existing dev data only): excess NLL vs oracle 2 (focal) / oracle 3 (opp):
std 5M +.123 / +.294; std 200M +.061 / +.223 (item 17 baselines).
| NTP hybrid K4-b80-hybrid-indep-d02 | .8335 ± .0075 | .0732 | .0678 | eligibility bar (hybrid) |
| NTP strict K4-b80-strict-indep-d0 | .9860 ± .0071 | .2233 | .2294 | eligibility bar (strict) |
| NTP strict seed 7 (K4-b80-strict-indep-d0-s7, item 18) | .9994 ± .0071 | .2376 | .2440 | seed swing +.0134 NLL vs seed 6 (not used in Selection A) |
| NTP hybrid seed 7 (K4-b80-hybrid-indep-d02-s7, item 18) | .8327 ± .0076 | .0745 | .0687 | seed swing −.0008 NLL vs seed 6 |
| O1 strict λ_K .02 seed 7 (K4-b80-strict-indep-d0-O1-lk0.02-s7, item 18) | .9938 ± .0071 | .2316 | .2344 | seed swing +.0253 vs s6 .9685 (NTP +.0134); O1 − NTP: s6 −.0175, s7 −.0056 (same sign; paired SE from aggregate). Reporting only |
| O1 hybrid λ_K 0.1 seed 7 (K4-b80-hybrid-indep-d02-O1-lk0.1-s7, item 18; 10742357 00:04 Tue) | .8496 ± .0076 | .0882 | .0823 | seed swing +.0203 vs s6 .8293 (NTP −.0008); O1 − NTP: s6 −.0041, s7 +.0169 (sign flips); KL above NTP s7 (.0745). Train KL last quarter .0945 vs s6 .0729; same eligible sites; teacher lookup by session gid + legal-target assert -> no alignment artifact found. Val focal top-1 85.71/85.52 vs s6 86.62/86.40. Reporting only |
| O1 K=0 std λ_K 0.1 (K0-b80-std-O1-lk0.1, item 16; 10769798 21:42) | .8335 ± .0076 | .0722 | .0663 | r_ls .1824; unpaired vs K4 hybrid O1 λ .1 ≈ .8294 (NTP .8335 − .0041) and std 5M .8328; paired contrasts in living v3 (inv/v8item16). Reporting only |
| O2 K=0 std λ_F .01984 (K0-b80-std-O2-lf0.01984, item 16; 10769811 22:52) | .8395 ± .0075 | .0780 | .0719 | r_ls .1929; unpaired: vs K0 NTP +.0043 (K4 hybrid O2 vs K4 NTP −.0026). Paired in living v3. Reporting only |
| NTP K=0 std (K0-b80-std, item-16 matched reference; 10771928 23:16) | .8352 ± .0076 | .0744 | .0684 | r_ls .1847; K0 O1 − K0 NTP ≈ −.0017, K0 O2 − K0 NTP ≈ +.0043 (unpaired); K4 hybrid NTP .8335. Reporting only |
| O4 λ=1 hybrid anchor (P2 cell) | .8683 ± .0076 | .1066 | .0995 | L_E real 2.309 vs const-WS 2.487 |
| O3 λ=1 hybrid anchor (P2 cell) | .8856 ± .0074 | .1238 | .1141 | anchor (not a selection candidate) |
| O3 λ=1 strict anchor (ref 10717345) | 1.0451 ± .0069 | .2814 | .2741 | anchor (not a selection candidate); +.0591 vs strict NTP |
| O4 λ=1 strict anchor (ref 10717352) | 1.0695 ± .0070 | .3051 | .3070 | anchor (not a selection candidate); +.0835 vs strict NTP |
| O5 λ=1 strict anchor (ref 10717336) | 1.0787 ± .0070 | .3141 | .3126 | anchor (not a selection candidate); R_ls .198 — O5: invalid_O5_loss_deviation (V8-A9) |
| O2 λ=1 strict ref (10717330) | 1.0343 ± .0069 | .2710 | .2715 | λ=1 reference (item 10); KL > strict NTP .2233 |
| O1 λ=1 strict ref (10717325) | .9977 ± .0071 | .2334 | .2242 | λ=1 reference (item 10); training/evals had finished 21:00 Sun, requeue skipped through 06:59 Mon |
| O5 λ=1 hybrid anchor (P2 cell) | .8803 ± .0075 | .1187 | .1096 | anchor (not a selection candidate) — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B strict O3 λ_E 1.4e-4 (λ_F .00496) | .9860 ± .0071 | .2233 | .2315 | Stage B grid point (O3-strict) |
| Stage B strict O3 λ_E 5.601e-4 (λ_F .00496) | .9741 ± .0071 | .2110 | .2149 | Stage B grid point (O3-strict) |
| Stage B strict O3 λ_E 5.048e-3 (λ_F .00496) | .9827 ± .0071 | .2200 | .2235 | L_E real .0362 vs const-WS .1663; O3-strict |
| Stage B strict O3 λ_E .02464 (λ_F .00496) | .9770 ± .0071 | .2142 | .2171 | L_E real .0365 vs const-WS .0895; O3-strict grid 4/4 scored (selection only in Selection B) |
| Stage B strict O4 λ_E 1.4e-4 (λ_F .00496) | .9928 ± .0072 | .2299 | .2360 | L_E real 2.313 vs const-WS 2.424; O4-strict |
| Stage B strict O4 λ_E 5.601e-4 (λ_F .00496) | .9994 ± .0070 | .2369 | .2440 | L_E real 2.313 vs const-WS 2.369; O4-strict 2/4 |
| Stage B strict O4 λ_E 4.108e-3 (λ_F .00496) | .9903 ± .0071 | .2270 | .2324 | L_E real 2.317 vs const-WS 2.521; O4-strict |
| Stage B strict O4 λ_E .01383 (λ_F .00496) | 1.0021 ± .0071 | .2392 | .2471 | L_E real 2.305 vs const-WS 2.409; O4-strict grid 4/4 scored (selection only in Selection B) |
| Stage B strict O5 λ_R 9.92e-4 (λ_F .00496) | .9913 ± .0070 | .2287 | .2376 | O5-strict 1/4 — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B strict O5 λ_R 3.968e-3 (λ_F .00496) | 1.0068 ± .0070 | .2430 | .2545 | O5-strict 2/4 — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B strict O5 λ_R .03463 (λ_F .00496) | 1.0120 ± .0071 | .2480 | .2539 | O5-strict — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B strict O5 λ_R .1052 (λ_F .00496) | 1.0834 ± .0070 | .3193 | .3408 | O5-strict grid 4/4 scored (selection only in Selection B); strict Stage B 12/12 scored — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B hybrid O3 λ_E 5.601e-4 (λ_F .01984) | .8327 ± .0076 | .0717 | .0657 | L_E real .0394 vs const-WS .0580; O3-hybrid 1/3 |
| Stage B hybrid O3 λ_E 8.847e-4 (λ_F .01984) | .8305 ± .0076 | .0690 | .0638 | L_E real .0379 vs const-WS .0463; O3-hybrid 2/3 |
| Stage B hybrid O3 λ_E 1.4e-4 (λ_F .01984) | .8281 ± .0076 | .0678 | .0621 | L_E real .0406 vs const-WS .0772; O3-hybrid grid 3/3 scored (selection only in Selection B); evals rerun after node GPU fault |
| Stage B hybrid O4 λ_E 1.4e-4 (λ_F .01984) | .8324 ± .0076 | .0714 | .0657 | L_E real 2.336 vs const-WS 2.338; O4-hybrid 1/3 |
| Stage B hybrid O4 λ_E 5.601e-4 (λ_F .01984) | .8321 ± .0076 | .0711 | .0653 | L_E real 2.333 vs const-WS 2.337; O4-hybrid 2/3 |
| Stage B hybrid O4 λ_E 8.797e-4 (λ_F .01984) | .8329 ± .0076 | .0719 | .0663 | L_E real 2.313 vs const-WS 2.327; grid 3/3 |
| Stage B hybrid O5 λ_R 9.92e-4 (λ_F .01984) | .8323 ± .0076 | .0713 | .0654 | r_ls .1470 / r_own .1426; O5-hybrid 1/3 — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B hybrid O5 λ_R 3.968e-3 (λ_F .01984) | .8336 ± .0076 | .0721 | .0665 | r_ls .1299 / r_own .1264; O5-hybrid 2/3 — O5: invalid_O5_loss_deviation (V8-A9) |
| Stage B hybrid O5 λ_R .03181 (λ_F .01984) | .8421 ± .0075 | .0803 | .0742 | r_ls .1082 / r_own .1061; grid 3/3; Stage B 21/21 -> Selection B 19:14 (PROJECT.md) — O5: invalid_O5_loss_deviation (V8-A9) |
| O1 λ=1 hybrid (P2 cell) | .8566 ± .0075 | .0964 | .0896 | λ=1 reference; KL > NTP (ineligible) |
| O2 λ=1 hybrid (P2 cell) | .8670 ± .0075 | .1066 | .0996 | λ=1 reference; KL > NTP (ineligible) |

**V8-A9 O5 v2 Stage B grid (o5_loss_version 2; submitted 16:4x Wed 14 Oct).** v2 gradient ratios (backbone, median over
updates with the term present; NTP final ckpt / step-0 init): hybrid ρ_R 2.695 / 0.8304, strict 2.58 / 0.9381. λ_par(R) v2 =
λ_par(F) = 0.0198381 (b80). Grid rule unchanged (V8-A4 item 15, V8-A5 item 2): λ_par×{1,4} + λ at ρ 0.1 / 1.0 under both
measurements, merge within 1.5× of a λ_par point (strict step0 ρ=0.1 0.1066 -> 0.07935). No cuts. Anchors = the v2 λ=1 runs
(hybrid P2 b80-indep-d02-O5-o5v2, strict ref b80-indep-d0-O5-o5v2). File: assets/aux-weight-stageB-grid-o5v2.json.
NOTE: the job ids in the rows below are the FIRST attempts (cancelled 17:1x: config allow-list bug); every run was
resubmitted at the fixed SHA 18:2x Wed (`--replace`); LEDGER.jsonl / `ae status` hold the current job ids.

| stage | obj | access | run | train job | devmetrics job | status |
|---|---|---|---|---|---|---|
| B v2 | O5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.01984-o5v2 | 10805056 | 10805058 | submitted 16:4x Wed |
| B v2 | O5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2 | 10805061 | 10805069 | trained + dev-scored 03:xx Thu; dev NLL .8329 ± .0076; KL_bal .0661; R ls .0984 / own .0966 |
| B v2 | O5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.07935-o5v2 | 10805070 | 10805079 | submitted 16:4x Wed |
| B v2 | O5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.1204-o5v2 | 10805080 | 10805081 | trained + dev-scored 03:xx Thu; dev NLL .8441 ± .0076; KL_bal .0754; R ls .0928 / own .0917 |
| B v2 | O5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.3711-o5v2 | 10805127 | 10805129 | trained + dev-scored 03:xx Thu; dev NLL .8610 ± .0075; KL_bal .0906; R ls .0904 / own .0905 |
| B v2 | O5 | hybrid | K4-b80-hybrid-indep-d02-O5-lf0.01984-lr1.204-o5v2 | 10805088 | 10805091 | submitted 16:4x Wed |
| B v2 | O5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr0.01984-o5v2 | 10805095 | 10805096 | trained + dev-scored 02:xx Thu; dev NLL .9991 ± .0071; KL_bal .2444; R ls .1750 / own .1735 (strict NTP v2 ref: NLL .9860, R ls ≈ .272) |
| B v2 | O5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr0.03876-o5v2 | 10805099 | 10805105 | trained + dev-scored 03:xx Thu; dev NLL .9958 ± .0071; KL_bal .2377; R ls .1703 / own .1686 |
| B v2 | O5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr0.07935-o5v2 | 10805108 | 10805111 | trained + dev-scored 02:xx Thu; dev NLL 1.0072 ± .0071; KL_bal .2497; R ls .1685 / own .1672 (strict NTP v2 ref: NLL .9860, R ls ≈ .272) |
| B v2 | O5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr0.3876-o5v2 | 10805112 | 10805113 | trained + dev-scored 07:xx Thu; dev NLL 1.1380 ± .0069; KL_bal .3941; R ls .2192 / own .2196 |
| B v2 | O5 | strict | K4-b80-strict-indep-d0-O5-lf0.00496-lr1.066-o5v2 | 10805116 | 10805121 | trained + dev-scored 03:xx Thu; dev NLL 1.1638 ± .0068; KL_bal .4073; R ls .2163 / own .2176 |
| anchor v2 | O5 | strict | K4-b80-strict-indep-d0-O5-o5v2 (λ_F = λ_R = 1) | 10805885 | 10810891 | reference, not a candidate; dev NLL 1.0436 ± .0070; KL_bal .2732; R ls .1806 / own .1782 |
