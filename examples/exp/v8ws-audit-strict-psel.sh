#!/usr/bin/env bash
#EXP gpus=1 cpus=8 mem=48G time=0:45:00 part=auto exclude=babel-l5-[16,20,28,32],babel-l9-[16,20,28,32],babel-m9-[16,20,28,32],babel-n9-20,babel-z5-[16,20,28,32],babel-z9-16,babel-p9-32,babel-s5-24,babel-v9-28,babel-p9-16,babel-m5-32,babel-o9-32,babel-v9-20
# (RTX PRO 6000 Blackwell excluded: flex-attention Triton kernel exceeds its shared memory; v7f-bwtest)
# HYPOTHESIS: none -- V8 gate C3 production strict audit (every completed 5M run): on 32 real val_seen sessions with an inserted
# workspace, pin every layer's WS input states, replace all prefix tokens by another real session's prefix and
# compare suffix logits: STRICT max |d| <= 1e-5 (fp32) / 1e-3 (bf16); HYBRID must change (> 1e-2). Results ->
# $PROJ_DATA/v8ws/audit/strict/<cell>.json (read by scripts/v8/audit.py), copies -> $AE_RESULTS.
# Phases run under bash -euo pipefail: a failing cell must not stop the phase, so exit codes are captured with
# `st=0; cmd || st=$?` and the phase exits with that status after the copies.
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra

phase strict "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.strict_audit --all --n-sessions 32 > \$AE_RESULTS/strict.log 2>&1 || st=\$?; }
    cat \$AE_RESULTS/strict.log | tail -40
    mkdir -p \$AE_RESULTS/strict && cp \$PROJ_DATA/v8ws/audit/strict/*.json \$AE_RESULTS/strict/ 2>/dev/null || true
    exit \$st
"
phase slots "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.slot_redundancy --all --n-sessions 512 > \$AE_RESULTS/slots.log 2>&1 || st=\$?; }
    tail -20 \$AE_RESULTS/slots.log
    mkdir -p \$AE_RESULTS/slots && cp \$PROJ_DATA/v8ws/reports/slot-redundancy/*.json \$AE_RESULTS/slots/ 2>/dev/null || true
    exit \$st
"
