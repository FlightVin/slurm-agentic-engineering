# inv/v8a8fix — final-audit fixes (report / analysis / orchestration side), owner amendment V8-A8 + V8-A7

Read PROJECT.md Amendments V8-A7 and V8-A8 first. Start from origin/v8-ws HEAD. Findings were confirmed by the
orchestrator where marked [confirmed]; verify each before changing; fix minimally; test each.

1. [confirmed] FINAL header / cutoff text: scripts/v8/living.py:42-44 hard-code FINAL = "FINAL, frozen Fri 16 Oct 12:00",
   LIVING = "...updated until Fri 16 Oct 12:00", CUTOFF = "not completed by Fri 12:00 cutoff" (used ~:185, :206, :244).
   V8-A8 superseded that schedule. Make the FINAL header f"FINAL, frozen {stamp}" (stamp = the build time, EDT, same
   format as the existing 'generated' stamp) and LIVING = "LIVING VERSION" (no date). In --final mode do NOT relabel
   unaudited rows with the cutoff text: use "not complete at the FINAL build" instead. Update previous_version (~:1380)
   so the FINAL overwrite guard (exit 4) detects the new prefix "FINAL, frozen". Fix the same stale text in living.py
   docstring (:5, :20), final_report.py --final help (~:668), comment line 8 of agentic-engineering/exp/
   v8ws-aggregate-final.sh and -final-g.sh, and set their default version to 14 (v1–v13 were published; v14–v21 were
   never published because V8-A8 superseded the refresh schedule).
2. [confirmed] Boundary pairs missing: paired.py:225 writes boundary pairs with coverage_kind "common_b40_b80"
   (paired) and "full_eligible_b40/b80" (unpaired); living.read_pairs (living.py:336) keeps only "full_eligible", so
   §4 and the §3.1 comparisons have ZERO boundary rows with no NA. Accept "common_b40_b80" for factor == boundary
   (label the rows "common h ≥ 80 query set"), so §4 shows boundary rows per tier like the other factors; anything not
   computable -> NA + reason.
3. Strict-audit exps stop at the first C3 failure: lines 11 and 17 of agentic-engineering/exp/v8ws-audit-strict.sh and
   v8ws-audit-strict-psel.sh use `cmd > log 2>&1; st=$?` under `bash -euo pipefail` (lib/preamble.sh:135). Use
   `st=0; cmd > log 2>&1 || st=$?` as the aggregate exps do.
4. C3-pending cells leak into aggregate/paired/plots: audit.gate_c3 returns SKIP when C3 has not run and finish()
   treats SKIP as PASS (audit.py ~354-357, ~556-563); aggregate.py ~494-499, paired.py ~368-371, plots.py ~333/629 gate
   on that status. For STRICT and HYBRID cells (C3 required for both, per the living completion criterion) treat C3 not
   PASS as not audited in the gate those use (or filter plots/pairs on living's 'audited'). Do not change the C3 rule.
5. Item-17 tables: val_gap_rows / val_excess_rows (living.py ~600 / ~690) print bare k/N; use k_of_n so partial sets are
   labelled (and by-design sets get the by-design label).
6. [confirmed] History plots: plots.py ~192-200 count superseded_owner_A4 rows in the λ=1 tier denominators (k/32,
   empty strict panels). Exclude superseded / out-of-scope rows like oracle_groups does.
7. Harvest cap: aggregate exps and v8ws-a2-ws-all.sh write full logs into $AE_RESULTS (cap 2 MB; ae refuses the whole
   harvest above it). Write full logs under $PROJ_DATA/v8-scratch/... and copy only a tail (≤ 200 lines) to $AE_RESULTS.
8. Item-16 dev rows: living.item16_runs (~:1075) labels the K4 aux dev arm "K4 hybrid aux (P2-sel)" but uses the
   Stage A sweep dev JSON (same checkpoint as the P2-sel b80 representative cell, which reuses that run dir). Label
   it with the real run id and add "(same checkpoint as the P2-sel b80 representative cell)".
9. §5 seed-spread sentence (~:1268) says the Stage A sweep eval is never used as the seed-6 value: true for validation
   only; dev_seed_spread (:473) uses the selected-λ sweep dev JSON (the same checkpoint as the P2-sel/P3-sel b80
   representative cell). Restrict the sentence to validation and name the dev seed-6 source with that clarification.
10. Minor: final_report.py:489 cites scripts/v8/final_ckpt.py -> scripts/v7/final_ckpt.py; record_only_check: catch
    Exception per group -> NA + reason (one bad input must not stop the build); item-9 table: explicit "NA — dev
    evidence is scored at b80 only (V8-A4 item 9)" for b40 cells; v8-topup.sh: count a move only if scontrol succeeds.
11. Tests for 1, 2, 4, 5, 6, 8 (fixtures; CPU, CUDA hidden, compute node — if the env python is refused, say so;
    the orchestrator runs them). Known stale failures: test_living ×2 (pending_selection_B), test_select_b A-only bytes.
12. Commit; push HEAD:inv/v8a8fix (say if blocked). Final line `V8A8FIX-READY <sha>`.

## Do NOT
- Do NOT change metric values, pairing logic (other than accepting the existing boundary rows), the C3 rule itself,
  selection, the frozen JSON, training/eval code; do NOT touch agentic-engineering/state or intermediate-analyses/.
- Do NOT submit Slurm jobs, run the aggregate, push to v8-ws, edit LEDGER.jsonl, or write $PROJ_DATA. No login node.
