#!/usr/bin/env bash
#EXP gpus=0 cpus=1 time=00:10:00
# HYPOTHESIS: none -- harness self-test (parent). Verifies commit pinning (the checked-out HEAD
# equals $AE_SHA), CPU-QOS routing (gpus=0), phase skipping on re-entry, and leaves a marker on
# a PROJECT-style path for ae-smoke-dep. Costs seconds of CPU.
export SMOKE_DIR="$AE_ROOT/selftest"

phase pin "test -s $AE_RESULTS/pin.json" '
    head=$(git rev-parse HEAD)
    [ "$head" = "$AE_SHA" ] || { echo "PIN MISMATCH: worktree $head != pinned $AE_SHA"; exit 1; }
    printf "{\"sha\": \"%s\", \"pinned\": true, \"qos\": \"%s\", \"partition\": \"%s\"}\n" \
        "$head" "${SLURM_JOB_QOS:-?}" "${SLURM_JOB_PARTITION:-?}" > "$AE_RESULTS/pin.json"
'
phase skipcheck "test -s $AE_RESULTS/pin.json && test -s $AE_RESULTS/skip.txt" '
    echo "phase pin was skippable on re-entry: $(test -s $AE_RESULTS/pin.json && echo yes)" > "$AE_RESULTS/skip.txt"
'
phase marker "test -s $SMOKE_DIR/$AE_SHA.parent" '
    mkdir -p "$SMOKE_DIR"
    date -u +%s > "$SMOKE_DIR/$AE_SHA.parent"
'
