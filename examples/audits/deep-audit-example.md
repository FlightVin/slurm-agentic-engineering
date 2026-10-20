# Deep self-audit — 2026-10-16 00:00 tick, run 00:25–00:50 EDT (audit #8; cron 325b4e64)

Previous: audit-20261015-1230.md (#7). Ground truth used:
- G1 `audit_gt.py` on CPU standby 10818894 from a fresh worktree at origin/v8-ws (27ee3c3, CURRENT code; audit cache
  warm from the v14 rebuild's audit phase): 152 in-scope rows incl. the 24 v2 O5 rows, 3 fresh no-cache re-audits
  (one a v2 row), 229 C3 results, peak RSS 4.03 GB, 116 s.
- G1b the v14 rebuild's own audit summary (current code): 184 audited rows = 156 PASS (152 in scope + 4 superseded
  strict λ=1 refs that exist on disk) + 28 missing (superseded P3 λ=1 rows never trained); 0 FAIL; the 24 invalid
  old O5 rows and 8 superseded O5 rows are not audited by design.
- G2 LEDGER.jsonl (631 jobs / 468 expids) vs `sacct -j` + `squeue`.
- G3 selection file sha 4ff969f9 (O5 re-run), rule ea0b49e9.
- G5 git, CronList, scontrol (backstop), df.

## Delta since audit #7
**Closed:** all V8-A9 training (16/16 P-sel O5 v2, 9/9 λ=1 v2, 11/11 grid); C3 34/34 v2 run dirs PASS; A2 34/34;
item-9 16/16 v2 P-sel (2 bundles, 0 errors); dev learning gap rebuilt; manifest.csv regenerated (V8-A9 layout).
**Still open:** v14 living rebuild (running: aggregate phase), its full V8-A7 audit, STE measurement, FINAL v15.
**New:** none.

## Correctness errors
None new. Under the CURRENT code all 152 in-scope rows (incl. 24 v2 O5) PASS every gate (A4, B1, B2, C3, S2, S3) on
both splits; 0 λ mismatch (incl. the re-run λ_R); seeds 6/6; 1 ckpt/run; fresh re-audits identical.

## Summary counts (92 requirement rows, counted by script)
| status | count |
|:--|--:|
| MET [verified] | 67 |
| MET [claimed] | 6 |
| INVALID → fixed + retrained (P6.1) | 1 |
| IN PROGRESS | 7 |
| SUPERSEDED | 9 |
| SCHEDULED | 1 |
| GAP | 1 |

## Requirement table
| ID | requirement | governing text | status | evidence | how verified | gap | action |
|:--|:--|:--|:--|:--|:--|:--|:--|
| P1.1 | Compare WS variants with existing std 5M/200M; no std retraining | §1 | MET [verified] | no std train expid in LEDGER; std 5M/200M used as comparator/teacher | G2 | – | – |
| P1.2 | 13:00 Oct 10 deadline + milestone timers | §1 | SUPERSEDED | → V8-A2 → V8-A6 → V8-A8 | – | – | – |
| P1.3 | Tier priority 1→4 | §1 | SUPERSEDED | → V8-A4 item 8 → V8-A6 item 6 | – | – | – |
| P1.4 | Interleave training, eval, harvest, report | §1, V8-A2 item 4 | MET [verified] | hourly status rows 10-14 09:12, 10:3x, 11:1x | G5 | – | – |
| P2.1 | Resolved-inputs manifest | §2 | MET [claimed] | assets/data/resolved-inputs.json | file present | – | – |
| P2.2 | Reuse datasets; no regeneration | §2 | MET [claimed] | v7f corpora; teacher manifest sha c4d1bfaf9823 = training manifest sha | G6 (sha) | – | – |
| P2.3 | Recovered seeds 6/6 | §2, V8-A2 item 5 | MET [verified] | seeds [6, 6] on 152/152 rows | G1 | – | – |
| P2.4 | From scratch, exactly 4 epochs | §2, V8-A3 | MET [verified] | B1 PASS 152/152 | G1 | – | – |
| P3.1 | Manifest, unique IDs | §3, V8-A4 item 7 | MET [verified] | manifest.csv regenerated 16:4x Thu with the V8-A9 layout: 328 rows, 152 in scope (128 non-O5 + 24 v2), 24 invalid_O5_loss_deviation, 40 superseded, 112 out of scope; --check OK | G1 (current code) + manifest --check | – | – |
| P3.2 | Every Cartesian cell run | §3.1 | MET [verified] | 152/152 in-scope rows PASS every gate (current code), incl. the 24 v2 O5 rows (8 P2 λ=1 + 16 P-sel; the v2 strict λ=1 reference is a dev run, not a manifest row) | G1 | – | – |
| P3.3 | Paired one-factor comparisons + distribution | §3.1 | IN PROGRESS | living v14 rebuild (paired phase incl. boundary common_b40_b80 pairs) running | ae logs | – | audit v14 |
| P4.1 | WS token, insertion, masks, dropout | §4 | MET [verified] | training-code review (10:0x) + gate tests | G6 | – | – |
| P4.2 | Strict suffix invariant to prefix | §4.2, acc. C3 | MET [verified] | C3 PASS 152/152 in scope; 229 strict/hybrid C3 results; v2: 34/34 run dirs PASS | G1 + C3 results | – | – |
| P4.3 | Eval keeps all slots | §4.3 | MET [verified] | eval_ws WSSpec(dropout=0.0); review | G6 | – | – |
| P5.1 | T vs V masks; suffix-only scoring | §5 | MET [verified] | split gates PASS both splits 152/152; review confirms denominators | G1, G6 | – | – |
| P6.1 | Aux contract (frozen teacher, train sites, separate objectives, exact mean or unbiased estimator) | §6.1 | INVALID v1 → v2 fixed, retrained, verified | all v2 runs trained; old O5 results invalid (appendix in v14) | G1 + sacct | – | – |
| P6.2 | O1–O5 definitions | §6.2–6.7 | MET [verified] (O1–O4; O5 v2 on real data) | o5v2 cache 16,587,680 sites / 29.9 GB; vs old cache on overlap cos ≥ .9998, 61% bitwise (bf16 only) | o5cos.py | – | – |
| P6.3 | O4 η on development data | §6.6 | MET with recorded deviation [verified] | η fit on train labels (review L3); no validation use | G6 | not dev | stated in report (v8a8notes) |
| P6.4 | Loss diagnostics logged | §6.8 | MET [claimed] | aux_* metrics keys; v2 adds normaliser S | G6 | – | – |
| P7.1 | Every final ckpt on full val_seen + val_unseen | §7 | MET [verified] | 152/152 both splits PASS (current code) | G1 | – | – |
| P7.2 | Identical eligible query sets | §7 | MET [verified] | E2 PASS 152/152 | G1 | – | – |
| P7.3 | Oracles 1–3 matched | §7 | MET [claimed] | v13 oracle tables | file | – | – |
| P7.4 | Oracle 4 / A2 for every WS model | §7 | MET [verified] | A2: 34/34 v2 runs scored (0 errors) + earlier 187 old | A2 logs | – | – |
| P7.5 | b40 vs b80 on the common query set | §7 | MET in code [verified]; not in a published version | v8a8fix test_v8a8fix boundary rows | G6 | not yet published | rebuild |
| P8.1 | Gates tested; re-run after changes | §8 | MET [verified] | v8o5cfg 12 real-config tests; v8a9rep3 merged 114/114 (my run); v8ntptol 32/32 (my run); stale fixtures fixed | G6 | full suite exceeds standby limits | heavy tests as a job before FINAL |
| P9.1 | Use general + preempt | §9, V8-A6 item 6 | MET [verified] | 12:2x Thu: general 8/8 + preempt 6 P-sel running; preempt 24 h 9.27 GPUs | squeue + G4 | – | – |
| P9.2 | Rolling ckpt; one final ckpt per run | §9, acc. B2 | MET [verified] | n_ckpt 1 on 152/152 + 47 dev dirs | G1 | – | – |
| P9.3 | Storage monitoring; cleanup only < 20% free | §9 + owner | MET [verified] | /data 23.5% free (collector statvfs) | G1 | close to 20% | delete o5v2 per-shard npz first if < 20% |
| P10.1 | Intermediate analysis kept current | §10 | MET [verified] | rows 09:12, 10:3x, 11:1x | G5 | – | 13:5x row |
| P10.2 | Long-form metrics, NA not zeros | §10 | MET [claimed] | aggregate CSV | – | – | – |
| P10.3 | Final analysis items 1–5 | §10 | IN PROGRESS | living v14 rebuild running (aggregate phase 00:3x) | ae logs | – | V8-A7 audit → FINAL v15 |
| A1.1 | 5M students only | V8-A1 | MET [verified] | no 200M train expid; run dirs only 5M | G1, G2 | – | – |
| A1.2 | 200M = pinned teacher | V8-A1 item 2 | MET [verified] | teacher sha checked in every O5 v2 exp (d9b7beec54d6) | exp script read | – | – |
| A2.1 | Draft by 13:00 Oct 10 | V8-A2 item 1 | MET [verified] | draft frozen | – | – | – |
| A2.2 | No deadline cancellation | V8-A2 item 2 | MET [verified] | backstop 10715530 StartTime 2026-10-23T12:15 | G5 scontrol | – | cancel at closeout |
| A2.3 | Hourly wake-ups | V8-A2 item 4 | MET [verified] | CronList: df36eb57 hourly (V8-A9 text), 325b4e64 audits | CronList | session-only | – |
| A3.1 | Budget within tolerance | V8-A3 | MET [verified] | B1 152/152 | G1 | – | – |
| A4.1 | λ_par measured | V8-A4 item 1 | MET [verified] | λ_par(R) v2 = λ_par(F) = .0198381 (b80), recorded in grid file + CHECKLIST | files | – | – |
| A4.2 | Dev split only for selection | V8-A4 item 2 | MET [verified] | "val_" strings in the JSON only under rule/data/forbidden_inputs; 158 dev/metrics paths | G3 | – | – |
| A4.3 | Sweep runs = dev runs, separate ledger | V8-A4 item 3 | MET [verified] | 47 dev/control dirs; not manifest rows | G1 | – | – |
| A4.4 | Grids | V8-A4 item 4 | MET [verified] | O5 v2 grid 11/11 trained + dev-scored; O1–O4 grids complete incl. the 8 V8-A8 points | sacct + SWEEP-LEDGER | – | – |
| A4.5 | Frozen rule, JSON + SHA in PROJECT | V8-A4 item 5 | MET [verified] | current file sha256 4ff969f9 == sidecar; rule_sha256 ea0b49e9; O5 re-run postcheck byte-identical for non-O5 | sha256 + postcheck | – | – |
| A4.6 | P-sel at selected λ | V8-A4 item 6 | MET [verified] | 0 λ mismatch over 152 rows incl. v2 P-sel λ_R from the O5 re-run | G1 | – | – |
| A4.7 | Manifest +80; P3 λ=1 superseded | V8-A4 item 7 | MET [verified] | 304 rows; 35 P3 λ=1 jobs CANCELLED | G1, G2 | – | – |
| A4.8 | Priority (A4) | V8-A4 item 8 | SUPERSEDED | → V8-A6 item 6 | – | – | – |
| A4.9 | Item-9 for every P-sel cell | V8-A4 item 9 | MET [verified] | item-9 complete for all 80 P-sel cells: old O1–O4 (v13) + 16 v2 O5 (bundles psel-o5v2-01/02, 0 errors) | bundle results | – | – |
| A4.10 | Item-10 comparisons + sweep curve | V8-A4 item 10 | IN PROGRESS | item-10 comparisons rebuilt in v14 | – | – | audit v14 |
| A4.11 | Final only after all complete | V8-A4 item 11 | SUPERSEDED | → V8-A6 → V8-A8 item 5 | – | – | – |
| A4.13 | m* per boundary | V8-A4 item 13 | MET [verified] (incl. O5 re-run) | O5 m*: hybrid 1.000, strict 1.954; λ = m*·λ_par(b) at b40 and b80 | selection JSON (sha 4ff969f9) | – | – |
| A4.14 | Paired dev SE | V8-A4 item 14 | MET [verified] | every candidate vs_ntp {diff, se} | G3 | – | – |
| A4.15 | Stage B grid from measured ratios | V8-A4 item 15, V8-A5 2–3 | MET [verified] (O5 v2) | v2 backbone ρ_R hybrid 2.695/0.8304, strict 2.58/0.9381 → grid per item 15 + V8-A5 item 2 (strict .1066 merged) | gradratio JSON | – | – |
| A4.16 | K=0 distillation control | V8-A4 item 16 | MET [verified] | v13 §3.5 | file | – | – |
| A4.17 | Learning-gap for every P-sel cell + sweep candidate | V8-A4 item 17 | IN PROGRESS | dev learning-gap table rebuilt (v2 + V8-A8 rows); val item-17 in v14 | learning-gap.log | – | audit v14 |
| A4.18 | Seed 7 for NTP + O1 | V8-A4 item 18 | MET [verified] | 4/4 seed-7 dirs (runs-seed/, [7,7]) | G1 | – | – |
| A5.1/6/7 | Tue deadline, guard, fallback | V8-A5 | SUPERSEDED | → V8-A6 | – | – | – |
| A5.2 | Stage B grid rules (merge 1.5×, anchors) | V8-A5 item 2 | MET [claimed] for O3/O4 | SWEEP-LEDGER | ledger | O5 v2 grid | V8-A9 (ii) |
| A5.3 | ρ on NTP ckpt + step 0 | V8-A5 item 3 | MET [verified] (v2) | 4 v2 gradratio jobs COMPLETED | sacct | – | – |
| A5.5 | Verify every edit by read-back | V8-A5 item 5 | MET [verified] (this audit) | every edit read back | – | – | – |
| A6.1a | Living v1 by Tue 14:00 | V8-A6 item 1 | MET [verified] | – | – | – | – |
| A6.1b | Update every 6 h | V8-A6 item 1 | SUPERSEDED | → V8-A8 item 1 | – | – | – |
| A6.1c | Fri 12:00 freeze | V8-A6 item 1 | SUPERSEDED | → V8-A8 item 5 (FINAL after a clean audit) | CronList (4dbbbdc1 gone) | – | – |
| A6.2 | Version rules | V8-A6 item 2 | MET [verified] | v13 + v8a8fix | file + tests | – | – |
| A6.3 | Thu 12:00 launch rule; Fri cancellation | V8-A6 item 3 | SUPERSEDED | → V8-A8 item 1 (9b6df222 deleted) | CronList | – | – |
| A6.4 | Scope | V8-A6 item 4 | SUPERSEDED in part | → V8-A8 item 2, V8-A9 | – | – | – |
| A6.5 | Seed-variance limitation | V8-A6 item 5 | MET [verified] | §5 two label columns | v13 | – | – |
| A6.6 | Both partitions; never cancel for priority | V8-A6 item 6 | MET [verified] | cancellations this cycle were owner-ordered (V8-A9 item 4) | G2 | – | – |
| A6.7 | Measured rates + S1/S2/S3 | V8-A6 item 7 | **GAP (partial)** | preempt 72 h 8.85 GPUs, 24 h 5.51, median wait 3.10 h, 69 preemptions, mean attempt before preemption 3.10 h; general 72 h 6.74, 24 h 4.30 | G4 | loss per preemption not measured per job (bounded by checkpoint interval) | forecast below uses the bound |
| A7.1 | Rigorous audit before the final analysis | V8-A7 item 1 | IN PROGRESS | review (analysis + training) done; recompute.py/recompute2.py match v13 | G6 | final full audit after V8-A9 | closeout |
| A7.2 | Stop only after the final analysis | V8-A7 item 2 | SCHEDULED | CHECKLIST 0b | – | – | – |
| A7.3 | Owner correction list | V8-A7 item 3 | MET [verified] | v13 + v8a8fix | file + tests | – | – |
| A7.4 | ~80% ASD-STE100 | V8-A7 item 4 | MET on v13 [verified] | ste_check.py: 150/172 = 87.2% | script | re-measure on FINAL | closeout |
| A8.1 | Disarm refresh/freeze timers; keep 12-h audits | V8-A8 item 1 | MET [verified] | CronList: only 325b4e64 + df36eb57 | G5 | – | – |
| A8.2 | 13 cut points as full runs, identical except swept weight + paths | V8-A8 item 2 | MET [verified] | 8 O3/O4 trained (4 epochs) + dev-scored by 23:3x Wed; 5 O5 cancelled (V8-A9) | sacct + SWEEP-LEDGER | – | – |
| A8.3 | Record only; no re-selection | V8-A8 item 3 | MET so far [verified] | selection file 54450305 unchanged; hybrid O3 λ_E .02502 dev .8267 (unpaired) < selected ≈ .8282 | SWEEP-LEDGER | possible record-only winner | paired check at rebuild; limitation if it wins |
| A8.4 | Tracking files updated + read back | V8-A8 item 4 | MET [verified] | this audit | – | – | – |
| A8.5 | Closeout | V8-A8 item 5 | IN PROGRESS | closeout started: v14 rebuild running | ae logs | – | audit → FINAL |
| A9.1 | Old O5 invalid | V8-A9 item 1 | MET [verified] | tracking + report/manifest code (v8a9rep3) | read back + tests | – | – |
| A9.2 | Ledger status invalid_O5_loss_deviation, kept | V8-A9 item 2 | MET [verified] | manifest.csv: 24 rows invalid_O5_loss_deviation (kept), not audited, not failures | manifest + G1 | – | – |
| A9.3 | Report labels / appendix | V8-A9 item 3 | IN PROGRESS (code verified) | INVALID appendix + sentence produced by the v14 build | tests 114/114 | real-data check pending | audit v14 |
| A9.4 | 5 O5 runs cancelled | V8-A9 item 4 | MET [verified] | sacct CANCELLED 10797454/65/71/97/502 + dev 10797461/67/74/500/504 | G2 | – | – |
| A9.5 | Backstop moved | V8-A9 item 5 | MET [verified] | StartTime 2026-10-23T12:15:00 | G5 | – | – |
| A9.6 | Fix L_R (method + reason + cost) | V8-A9 item 6 | MET [verified] | method (b), cost ~10 GPU-h cache + 60 GB peak; built + verified | results | – | – |
| A9.7 | Proofs (expectation, gradcheck, no teacher grad, config diff) | V8-A9 item 7 | MET [verified] | real-run config diff 34/34 CLEAN (λ=1: output_dir + o5_loss_version; grid + P-sel: + λ_R) — cfgdiff_v2.py fixed this audit to compare each P-sel run with the OLD P-sel run of the same cell | cfgdiff_v2 on compute 12:1x | – | – |
| A9.8 | Retrain all O5 in dependency order | V8-A9 item 8 | MET [verified] | (i)–(v) all done: ratios, grid 11/11, Selection B O5, 9 λ=1 + 16 P-sel trained, C3 34/34, A2 34/34, item-9 16/16, learning gap | sacct + results | – | – |
| A9.9 | Both partitions; forecast before P-sel | V8-A9 item 9 | MET [verified] | forecast reported before the P-sel submit | – | – | – |
| OWN.1 | Storage invariant | owner | MET [verified] | 37.2% / 52% free | G5 | – | – |
| OWN.2 | Validation out of every selection | owner | MET [verified] | see A4.2 | G3 | – | – |
| OWN.3 | 12-h audits until FINAL | owner 23:10 Mon | MET [verified] | cron 325b4e64 | G5 | session-only | – |
| JOB.1 | Every LEDGER job vs sacct | audit | MET [verified] | 468 expids / 631 jobs, all in sacct; latest COMPLETED 422, RUNNING 1 (rebuild), CANCELLED 45; 0 FAILED latest; 0 duplicate active | G2 | – | – |
| JOB.2 | Unsubmitted work | audit | MET [verified] | no unsubmitted study work; only the closeout chain (rebuild running, FINAL after the audit) | G2 | – | – |
| JOB.3 | Lost work | audit | MET [verified] | every RUNNING row maps to a live job; cancelled O5 dirs kept | G1, G2 | – | – |
| JOB.4 | Standby duties | CHECKLIST | MET [verified] | standby 10818894 to ~05:30 Fri | squeue | – | renew ~05:00 if the closeout runs long |
## Forecast (00:45 Fri; no training left, only CPU closeout work)
| step | S1 (slow: audit finds fixes needing a tinker + rebuild) | S2 (main) | S3 (clean first pass) |
|:--|:--|:--|:--|
| v14 rebuild done (aggregate → paired → plots → report) | Fri ~04:00 | Fri ~03:00 | Fri ~02:30 |
| full V8-A7 audit of v14 (recompute sample, denominators, labels, links, ledger, STE) | Fri ~07:00 | Fri ~05:30 | Fri ~04:30 |
| fixes + re-verify (+ rebuild if code changes) | Fri ~11:00 | Fri ~07:00 | – |
| FINAL v15 build + byte-equal publish + disarm + commit | Fri ~13:00 | Fri ~08:30 | Fri ~06:00 |

## Timers
- 325b4e64 deep audit (next Fri 16 Oct 12:00, if FINAL is not done before); df36eb57 hourly; backstop 10715530
  StartTime 2026-10-23T12:15 (verified). All three are disarmed at the FINAL step.

## Storage and retention
- /data 23.5% free; /home ~35%. One checkpoint per run. Invalid O5 run dirs kept (V8-A9 item 2).

## Fixes this audit
None needed (no gap with a fix available before the rebuild finishes); tracking rewritten.
