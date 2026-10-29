#!/usr/bin/env bash
# Experiment definition. This file is the ONLY thing you author per experiment.
# `ae submit` inlines it into a generated, self-contained job script.
#
# Header (parsed by ae; defaults come from config.sh):
#   gpus=N    0 routes to preempt_cpu_qos automatically (preempt_qos and normal both
#             have MinTRES=gres/gpu=1, so a 0-GPU job there pends forever)
#   cpus=N    time=HH:MM:SS (default 08:00:00; Babel's own default is 30 min)   after=expid[,expid]
#   part=preempt|general|auto   (default preempt)
#             preempt  = 24 GPUs, 31-day wall, preemptible (requeue-safe via phases)
#             general  = 8 GPUs, 2-day wall, NOT preemptible; > 2 days is refused
#             auto     = ask both pools for a start estimate, take the earlier
#             gpus=0 always runs on preempt_cpu_qos regardless of part=
#   exclude=<nodes>  constraint=<features, e.g. VRAM_80GB|VRAM_96GB>  mem=<size>
#   gtype=<GRES type, case-sensitive: A6000 L40S A100_80GB H100 H200 6000Ada ...>
#   For flex-attention jobs, exclude the RTX_PRO_6000 nodes (list in cluster/CARD.md).
#EXP gpus=1 cpus=4 time=02:00:00

# HYPOTHESIS: <what this run is supposed to tell you. One or two lines.>

# Available from the preamble:
#   $AE_RUNDIR   scratch, compute-side, keyed <sha>-<expsha>; survives a requeue
#                of THIS run only -- a different run or experiment cannot find it
#   $AE_RESULTS  write SMALL distillates here -- only this dir is harvested
#
# WHERE TO WRITE WHAT (the cross-experiment contract):
#   consumed by a LATER experiment  -> a PROJECT path (see PROJECT.md), e.g.
#                                      $PROJ_DATA/<name>/ckpt.pt
#   read by you on the laptop       -> $AE_RESULTS (small; harvested; <= AE_HARVEST_MAX_KB)
#   throwaway scratch for this run  -> $AE_RUNDIR
#
# On Babel $PROJ_DATA lives under /data/user_data/$USER (500 GB, shared between compute
# nodes, NOT mounted on the login node) -- which is why distillates go to $AE_RESULTS.
# Never write checkpoints to $AE_RUNDIR: it is under /home (100 GB, shared by every job).
#   $AE_ROOT     the remote harness root; stable across runs (see selftest/)
#
# EXPORT any variable a phase uses. `phase` runs a child shell; a set-but-not-
# exported variable is an ERROR there (the preamble runs phases under `bash -u`).
#   cwd          a git worktree detached at the pinned commit
#
# phase <name> <done-predicate> <command...>
#   The predicate is eval'd; if it succeeds the phase is SKIPPED. A requeue
#   re-runs this whole file from the top, so every phase must be cheap to skip.
#   Phases run under `bash -euo pipefail`: an unset variable is an error, a
#   pipeline reports the failing stage rather than the last one, and the phase
#   fails at the FIRST failing command rather than taking the status of the last.
#   All three exist because each silently turned a failure into a pass in a real
#   run. If a command in your phase is allowed to fail, write `cmd || true`.

# Two traps that each broke a real run:
#   - Inside a DOUBLE-quoted phase string, write \$var, \$? and \${PIPESTATUS[0]}. Unescaped,
#     they expand when the phase is DEFINED (often to empty), not when it runs.
#   - A trainer that saves a checkpoint on $AE_PREEMPT_FLAG and exits makes the job end
#     FAILED, and Slurm never requeues a finished job. Requeue it from the phase:
#       phase train "test -f \$RUN/RUN_COMPLETE" "
#           rc=0; python train.py ... || rc=\$?     # '|| rc=' keeps bash -e from exiting first
#           if [ \$rc -eq 143 ]; then scontrol requeue \$SLURM_JOB_ID; sleep 900; fi
#           [ \$rc -eq 0 ] && touch \$RUN/RUN_COMPLETE
#           exit \$rc
#       "

export PROJ_DATA="${PROJ_DATA:-/data/user_data/$USER/<project>}"   # from PROJECT.md "Data and paths"

phase example "test -f $AE_RESULTS/summary.json" "
    echo 'replace me with real work'
    printf '{\"metric\": 0}\n' > $AE_RESULTS/summary.json
"
