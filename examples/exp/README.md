# Worked examples

These are the experiments used to validate the system end to end. They are NOT
project science — they are the reference for how to write an `exp/*.sh`.

`sim-pretrain.sh` → `sim-mid-a.sh` / `sim-mid-b.sh` → `sim-report.sh` is a real
diamond DAG that ran on Babel, survived a genuine preemption, and passed a
checkpoint between experiments.

Copy the **pattern**, especially:
- `export PROJ_DATA=...` and `export CKPT=...` — phases run a child shell under
  `bash -u`, so an unexported variable is a hard error (this caught a real bug
  where a precondition check passed with its input absent).
- artifacts a LATER experiment reads go under `$PROJ_DATA`, never `$AE_RESULTS`.
- each downstream experiment re-checks its own precondition, because `afterany`
  does not mean the parent succeeded.

To run one: `ae submit sim-pretrain` after copying it into `exp/`.
