# Log 2026-10

## 2026-10-09 18:50 EDT — V8 workspace study start
- Bootstrap: state files reset for new PROJECT (V8 workspace). ~18 h to 13:00 EDT 10-10 deadline.
- Feasibility from V7 records: 5M std 13 GPU-h (1 GPU), 200M std 91 GPU-h (4 GPUs, ~23 h wall).
  200M from-scratch 4-epoch runs cannot finish in time on any plausible allocation; plan to focus P1 5M
  and be explicit about everything else. Re-measure with real WS masks before final allocation.
- Warmed all standby tiers; set session cron milestones (10:00/12:00/12:30/12:45, hourly forecast).

## 2026-10-09 18:58 EDT — discovery + implementation launch
- Exploration (4 read-only agents) established:
  - A5 one-time-workspace implementation exists at `ae695d4` / tag archive/v7-pre-cleanup-2026-10-06
    (data/a4.py once, a4_loader, model._forward_a4, score.py a4 spec, tests/v7/test_a5.py, flex==dense
    parity). Differences vs V8 spec: A5 `mand` kept header visible (V8 strict must not), causal WS only,
    A5 dropout differs; no validation target mask. Port + extend.
  - Marker: PAUSE=141 is never emitted by the generator (tokens.py:18-21); verify 0 occurrences (v8base).
  - RoPE by row index (no per-session reset) is V7's positional convention -> preserved.
  - Std per-decision arrays `$PROJ_DATA/evals/v7f-a3/{5M,200M}/std/decisions-<split>.npz` align with
    v7f-labels (`h` = completed hands); suffix query set for boundary b = decisions with h >= b.
    Oracles 1-3 per-decision over full val; oracle 4 approximate, A2 279-session sample only.
  - 5M std: rows 16/update, accum 16 on 1 GPU, T=9216, LR 1.125e-3; 200M: 4 GPUs, LR 1.607e-4. Seed 6.
    Resume requires the same world size.
- Branching: ae's AE_BRANCH was `v7-fresh`; PROJECT §2 requires a new branch from current main ->
  created `v8-ws` from main (b1d21ab) and set AE_BRANCH=v8-ws.
- Launched tinkers: v8impl (GPU 6000Ada; WS training path, tests gates 2-9, benchmark, exp generator,
  suffix eval) and v8base (CPU; resolved inputs, id-141 scan, 224 manifest, cached baseline/oracle suffix
  tables, aggregator).
- Scope reasoning (to confirm with benchmark): 200M from scratch = ~23 h wall on 4 GPUs (V7) -> cannot
  finish by 13:00. P2/P3 need a 200M teacher cache + O1-O5 heads + 4 full epochs -> cannot finish.
  P1 5M (16 runs) is the realistic deliverable; at 1 GPU each (~11-13 h) it is too late if launched
  after ~23:30, so plan 2-GPU DDP per run (16x2 = 32 = full quota across both pools).

## 2026-10-09 19:35 EDT — incident + owner direction
- Both tinkers died at launch (18:57): cluster Claude OAuth expired. Owner re-authenticated 19:26.
- `ae launch` re-copies the LOCAL brief (agentic-engineering/inv/<id>/brief.md) over the remote one;
  scp'ing a new brief to the cluster is not enough. Fixed by editing the local copy and relaunching.
- Owner: start P1, finish P2, progress on P3. Added inv/v8aux (teacher cache, O1–O5). Added `micro_rows`
  speed lever to v8impl (same global batch, fewer micro-steps) — the only plausible way 5M P2 fits.
- Frozen aux hyperparameters (not tuned; no time for dev selection, recorded as limitation):
  tau=1, lambda_K=lambda_F=lambda_R=1.0, lambda_E=0.1.

## 2026-10-09 20:25 EDT — owner scope decision
- Owner: only 5M models are trained; the pretrained std 200M is used as the auxiliary teacher (and comparator)
  only. 112 5M training cells; the 112 200M rows stay in the manifest as out-of-scope-by-owner.
- v8base accepted (a16d165). Std suffix legal top-1 (focal/opp) val_seen b40: 5M .836/.568, 200M .863/.600.

## 2026-10-09 20:50 EDT — P1 launched; owner audit questions
- v8impl accepted (163aa21): 5M mr4 6.3–7.4 h / 4 epochs on 6000Ada (V7 ~13 h). 1 GPU/run (NCCL WS untested).
- P1 16 scripts = orchestrator text-templating of the accepted sample + eval_ws phases + full exclude list + 15 h wall.
- `part=auto` sent all 16 to general (cap 8 GPUs) -> 10 pending on QOSMaxGRESPerUser; moved the 10 pending to
  preempt via `scontrol update Partition=preempt QOS=preempt_qos` (identical preamble on both pools).
  Lesson: for batches larger than general's free capacity, set part explicitly.
- Owner audit: no 200M training anywhere (sacct, exp scripts, run dirs). Fixed manifest (200M rows ->
  out_of_scope_owner_A1). Quarantined v8impl's 30-update 200M throughput benchmark log (no weights).
- Acceptance checklist with concrete pass/fail gates: assets/acceptance-checklist.md; gaps G3–G6, C3, D2/D3,
  E2/E3, F1/F2 -> v8analysis tinker; aux hook rebase + P2/P3 scripts + GPU-sharing benchmark -> v8aux2.

## 2026-10-09 21:10 EDT — Amendment V8-A2 (final owner text) reconciled
- Owner sent several revisions; the 21:05 message supersedes all. PROJECT.md V8-A2 = that verbatim text only.
- Found real bug: floor budget dropped 12 epoch-4 bins in b40 K4 cells -> 8 runs cancelled+quarantined, inv/v8tail fix.
- Seeds recovered from originals (6/6 everywhere); no seed changes needed; S-gates added.
- Old 12:45 guard 10714526 cancelled; runaway backstop 10715530 (2026-10-12 18:00). Session timers: hourly :07 +
  11:50 and 12:40 draft wake-ups; old 10:00/12:00/12:30/12:45 deadline timers deleted.
- v8analysis relaunched with draft/final builder brief; v8aux2 brief updated (not relaunched mid-rebase).

## 2026-10-09 22:15 EDT — epoch plans differ: b80 runs also violate exact-4-epochs
- v8tail (TAIL-READY aeae3d5): per-epoch repacked plans have DIFFERENT bin counts (K4-b40: 435,131/435,127/435,118/
  435,124 = 1,740,500). So the old floor(4*bpe) budget: b40 trained all 4 plans + 12 bins of a 5th pass (duplication,
  not a drop); b80 (4*434,896 = 1,739,584 > sum 1,739,563) trains 21 bins of a 5th pass; K16-b40 (later epochs larger
  than epoch 0) would have DROPPED bins under the old A4 rule.
- My brief had told v8tail to keep b80 byte-identical — wrong premise. Decision: every cell uses budget = sum of the 4
  plans with a partial final update; nothing beyond plan epoch 3. All 20 running b80 runs (8 P1 NTP + 12 P2 O1/O2/O5)
  are invalid under gate B1 and will be cancelled + quarantined at resubmission (kept running only until the fixed code
  is ready because no other work can use those GPUs). Revision relaunched as v8tail (TAIL2-READY).

## 2026-10-09 22:25 EDT — aux runs NFS-bound; cancelled
- Steady-state P2 throughput ~51k tok/s (2.9 s/update) on L40/A6000/6000Ada alike: TeacherStore memmaps the 34 GB
  flat/ cache over NFS (random reads). v8aux2's 4–6% overhead was measured on a 1.1 GB scratch cache in page cache.
- Cancelled + quarantined the 12 P2 b80 runs (also invalid: 5th-pass bins). Aux exp scripts now stage the needed
  cache files (13.5 GB; +22.8 GB hidden for O5) under a per-node flock to a fixed node-local path and point
  V8_TEACHER_DIR there; tested 15 GB / 7 min on babel-w9-22. Verify speed on the first resubmitted aux runs.

## 2026-10-09 22:40 EDT — Amendment V8-A3 (owner): 1–2% epoch tolerance
- Owner: within 1–2% of four epochs is fine. Deviations of the accepted rule are <= 0.0012%. Keep ONE budget rule for all
  cells; the exact-budget candidate (v8-ws-tail2-merge) is archived. 8 P1 b80 runs valid; 8 P1 b40 resubmitted.
- My 40-cell P2 submission failed at precheck: the staging block's `find | awk` on a not-yet-staged path exits 1 under
  the preamble's `bash -euo pipefail` (my test harness used only `bash -u`). Fixed with `|| true`; harness now mirrors
  the preamble exactly. Lesson: test phase code under the preamble's real shell options.

## 2026-10-09 23:35 EDT — hourly
- P1 16/16 training, ETAs 03:48–11:02. P2 13 running at ~NTP speed after staging, 27 pending.
- babel-n5-20: two P2 O1 runs degraded 340k -> 81k tok/s; processes in D state (folio_wait_bit_common) on mmap'd NFS
  TRAIN shards (teacher cache was correctly local); node heavily shared (load ~12). Requeued both with n5-20 excluded
  (scontrol requeue + ExcNodeList); not a code fault, so not added to the global exclude list.

## 2026-10-10 09:40 — aux weighting decision (owner-delegated)
v8auxdiag showed the specified aux loss (λ_K=1, per-site mean ≈ 50x token weight) makes the student worse by an
optimisation effect (aux grads dominate Adam; O1 student ends farther from the teacher). Owner: "choose your best
judgement". Chose: dev sweep λ_K {0.02, 0.1, 0.3} on one O1 cell with a pre-declared selection rule; let λ=1 P2 finish
(as-specified record + ablation); hold P3 (~320 GPU-h) until selection; submit P4 now (λ-independent) to keep GPUs busy;
P2 re-runs at selected λ as additional rows. Rationale: PROJECT §6 requires dev-selected aux weights; running 40 more
cells at a weight known to defeat its own objective would not test the hypothesis.

## 2026-10-10 14:40–15:20 — resume after pause; Amendment V8-A4
Part 1: reconciliation clean (68 completed / 32 running / 48 pending of 148 ledger expids; nothing failed or preempted
except CPU standby). Part 2: V8-A4 added verbatim to PROJECT.md (A4 free). Part 3: λ_par from all finished-run logs
(b80: K/F .01984, E 1.400e-4, R 9.920e-4); dev split v7f/prod/dev proven seed-disjoint; val_seen sweep rule superseded
(never applied); O4 η from a train-data rule (deviation from §6.6, not validation). Stage A O1 submitted (5 new) +
5 strict λ=1 references released from held P3 (identical configs). Agents: v8lambda2 (λ_F/E/R overrides), v8devsel (dev
selection pipeline). Hourly timer recreated (fd351725) with sweep-ledger + gate tracking. Runaway backstop 10715530 moved
from 2026-10-12 18:00 to 2026-10-14 18:00 (V8-A4 production extends past Oct 12); backstop.sh contents not re-checked
(read was denied by the permission classifier) — if it hard-codes the old date it fires at its begin time only, i.e. now
Oct 14.

## 2026-10-11 08:15 — Selection A and the post-A gates
- Selection A (v8ws-select-A 10730739, DEV only, frozen rule ea0b49e9, selection_sha256 7ca12270): O1 λ_K hybrid 0.1 (m* 5.04),
  strict 0.02 (m* 1.01); O2 λ_F hybrid 0.01984 (m* 1.00), strict 0.00496 (m* 0.25, the grid's lowest point). No ties.
- Observation: hybrid O1 dev NLL vs λ is non-monotone (Δ vs NTP −.0003, +.0048, −.0041, +.0073 at λ .005/.02/.1/.3); the
  swings are ~15× the paired SE, so the paired SE (decision-level, one seed) does not capture run-to-run variance. The rule
  was applied as frozen; item 18 (seed 7 at the selected λ, plus NTP seed 7) is the planned measurement of this variance.
  Strict O1 gains are consistent at λ .005 and .02 (−.0166, −.0175) — the one robust effect so far.
- Ambiguity choices: item 16 "selected m*" -> hybrid m* (a K=0 model attends to the full prefix, i.e. the hybrid access
  pattern). V8-A5 strict trim "to 4 points per term" -> λ_par×1 + the 3 points with log m closest to log m*_F (same rule
  as the hybrid trim). Both trims applied at once because the forecast is far past 09:00 Tue even after them.
- Submitted (all general; preempt GPU ≈ none): Stage B 21 (13 cut, listed in SWEEP-LEDGER), item 18 O1 seed 7 ×2, item 16
  K=0 O1/O2 ×2; K=0 NTP ref + strict λ=1 O5 anchor moved to general. inv/v8psel launched for the manifest/P-sel gate.

## 2026-10-11 16:35 — V8-A6 (living final analysis, Friday cutoff, both partitions); facts evicted from STATE
Owner V8-A6 (16:25) replaces two withdrawn owner messages; of those, only PROJECT/STATE/log edits were made (no jobs touched), all rewritten to V8-A6. Facts moved out of STATE.md verbatim:

- Eligible val counts (h>=b): actions val_seen 19,057,792 / 5,951,378; val_unseen 18,879,445 / 5,881,624 (b40/b80).
- Dev split: datasets/naive_poker_v7/v7f/prod/dev (6,000 sessions, 13.6M tokens, seeds 10,700,000,000–…5,999);
  seed sets of train/dev/val_seen/val_unseen pairwise disjoint (0 overlap, 2,018,000 sessions checked 14:55).
- O4 η: b40 7.853e-4, b80 5.204e-4, rule median_u mean_i d_i(u) over registered TRAIN queries (not val; not dev:
  deviation from §6.6 recorded). τ = 1 default. λ=1 / λ_E=0.1 were frozen untuned (no data) — the V8-A4 trigger.
- Aux staging to node-local /tmp: 350–650k tok/s; ~7–13 h per 5M run by GPU type.
- Strict λ=1 references = the 5 held P3 jobs b80-strict-indep-d0-O1..O5 (identical config) -> released, not duplicated.
- Sweep runs keep their in-job val evals (reporting only); select_aux_weights.py must refuse any non-dev input (W2).
- O5 R for the NTP comparator: least-squares linear head fit on even-seed dev sessions, both models scored on odd-seed
  dev sessions (dev only; documented in the selection JSON).
- λ_par uses b80 (both representative cells are b80); λ_par(F) counted in sites, as specified (O2 normalises per session).
- Stage B grid (19:40): 4 ρ points = λ at ρ 0.1/1 under BOTH measurements (NTP-final, step-0; backbone ρ, active updates)
  + λ_par×{1,4}, merged within 1.5× -> 34 runs. V8-A5 trim 'two points closest to the selected λ_F' read in m = λ/λ_par units
  (keep the 2 points with log m closest to m*_F, plus λ_par×1).
## V8-A4 items 13–18 (rule frozen 17:55 Oct 10, eca6ffa, rule_sha256 ea0b49e9; details in PROJECT.md)
m* units (13); paired SE ties (14); Stage B ρ grids (15); K=0 control (16); learning gap (17); seed 7 (18).


- 2026-10-12 23:45 audit #1 (owner deep-audit rule): CHECKLIST rewritten from the audit; previous plan = git CHECKLIST.md @ 89092da. See intermediate-analyses/2026-10-09-workspace-assets/audits/audit-20261012-2345.md.
