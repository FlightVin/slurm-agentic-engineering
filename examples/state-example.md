# STATE — final (2026-10-16 05:0x EDT): study complete; FINAL v16 written, audited, published, committed

## STATUS: STUDY COMPLETE — FINAL written, audited, published and committed (2026-10-16 05:0x EDT)
- Final analysis: intermediate-analyses/2026-10-09-workspace-final-analysis.md, header "FINAL, frozen 2026-10-16 04:53
  EDT", version 16 (v8ws-aggregate-final 10823820), byte-identical to the build (sha256 19141407e82f…); 69/69 links.
- Closeout audit: audits/audit-20261016-0450-final.md (clean after 1 status-label fix, v8a9cancel); STE 88.5%.
- Timers disarmed: crons 325b4e64 (audits) + df36eb57 (hourly) deleted; Slurm backstop 10715530 CANCELLED; watchers
  stopped; CPU standbys released. No study job remains.

## Final verified state
- 152 in-scope rows (128 non-O5 + 24 O5 v2) PASS every gate on both splits; 24 old-loss O5 rows invalid (kept,
  appendix only); selection rule ea0b49e9 frozen; O5 re-selected on dev only (V8-A9); V8-A8 record-only points:
  hybrid O3 λ_E .02502 and hybrid O4 λ_E .1406 would have won (stated as limitations; no re-selection).
- Earlier audits: audits/audit-20261012-2345 … audit-20261016-0045 (#1–#8).

## Documents
- 2026-10-16: owner asked for one document. Deleted the superseded draft (2026-10-09-workspace-final-analysis-draft.md) and the
  living log (2026-10-09-workspace-intermediate-analyses.md); both are recoverable with `git show 283e0487:intermediate-analyses/<file>`.
  The single deliverable is intermediate-analyses/2026-10-09-workspace-final-analysis.md (FINAL v16).

## Next actions
None required. Any further work needs a new owner instruction.
