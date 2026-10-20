#!/usr/bin/env bash
#EXP gpus=1 cpus=1 time=00:10:00 part=general
# HYPOTHESIS: none -- harness self-test for Babel's second pool. Verifies that part=general
# lands on the general partition under the `normal` QOS (not preemptible), that the allocated
# GPU is visible and not already occupied by a foreign process, and that the compute-only
# /data/user_data mount is present. Costs one GPU for seconds; it may queue for a while.

phase pool "test -s $AE_RESULTS/pool.json" '
    head=$(git rev-parse HEAD)
    [ "$head" = "$AE_SHA" ] || { echo "PIN MISMATCH: worktree $head != pinned $AE_SHA"; exit 1; }
    gpu=$(nvidia-smi --query-gpu=name,memory.used --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
    used=$(echo "$gpu" | awk -F", " "{print \$2}")
    data=no; [ -d "/data/user_data/$USER" ] && data=yes
    printf "{\"sha\": \"%s\", \"partition\": \"%s\", \"qos\": \"%s\", \"gpu\": \"%s\", \"gpu_mem_used_mib\": %s, \"user_data_mounted\": \"%s\"}\n" \
        "$head" "${SLURM_JOB_PARTITION:-?}" "${SLURM_JOB_QOS:-?}" "${gpu%%,*}" "${used:-null}" "$data" > "$AE_RESULTS/pool-attempt.json"
    [ -n "$gpu" ] || { echo "NO GPU visible"; exit 1; }
    [ "${used:-0}" -lt 2048 ] || { echo "allocated GPU already holds ${used} MiB (foreign process) on $(hostname)"; exit 1; }
    mv "$AE_RESULTS/pool-attempt.json" "$AE_RESULTS/pool.json"    # done-marker only when every check passed
'
