#!/usr/bin/env bash
# Experiment definition. This file is the ONLY thing you author per experiment.
# `ae submit` inlines it into a generated, self-contained job script.
#
# Header (parsed by ae; defaults come from config.sh):
#   gpus=N    0 routes to the CPU-only QOS automatically (the GPU QOS has
#             MinTRES=gres/gpu=1 and a 0-GPU job there pends forever)
#   cpus=N    time=HH:MM:SS   after=expid[,expid]
#   part=auto|general|<partition>   (default AE_PARTITION from config.sh)
#             general  = the optional second pool, AE_PARTITION_GEN (e.g. non-preemptible)
#             auto     = ask both pools for a start estimate, take the earlier
#             gpus=0 always runs on the CPU-only QOS (AE_QOS_CPU) regardless of part=
#             With no second pool configured, general/auto fall back to AE_PARTITION.
#   exclude=<nodes>  constraint=<features>  mem=<size>  gtype=<GRES type>
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
# $PROJ_DATA is compute storage shared between compute nodes. It may not be mounted
# on the login node or the laptop -- which is why distillates go to $AE_RESULTS.
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

export PROJ_DATA="${PROJ_DATA:-/path/on/compute/to/project-data}"   # from PROJECT.md "Data and paths"

phase example "test -f $AE_RESULTS/summary.json" "
    echo 'replace me with real work'
    printf '{\"metric\": 0}\n' > $AE_RESULTS/summary.json
"
