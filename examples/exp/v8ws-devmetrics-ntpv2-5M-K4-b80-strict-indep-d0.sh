#!/usr/bin/env bash
#EXP gpus=1 cpus=4 mem=48G time=0:40:00 part=preempt exclude=babel-l5-[16,20,28,32],babel-l9-[16,20,28,32],babel-m9-[16,20,28,32],babel-n9-20,babel-z5-[16,20,28,32],babel-z9-16,babel-p9-32,babel-s5-24,babel-v9-28,babel-p9-16,babel-m5-32,babel-o9-32,babel-x9-16,babel-y9-08,babel-v9-20
# HYPOTHESIS: none -- V8-A9 (precondition of v8ws-select-B-o5v2): re-score the matched NTP checkpoint of $CELL (the
# SAME checkpoint and cell as v8ws-devmetrics-5M-$CELL.sh) with the CURRENT (v2) dev_metrics, so the JSON carries
# r.design (exact-mean R). Output $CELL-ntpv2.json; the old $CELL.json is never overwritten (Selection A/B and the V8-A8
# record-only check read it). Final phase: per-field max |new - old| for nll / kl / r (every form) and the new
# r.design; exit 1 if nll or kl differ by more than 1e-6 (same checkpoint, same dev data). Estimate: <= 15 min, 1 GPU.
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=4 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
CELL=K4-b80-strict-indep-d0
OLD=$PROJ_DATA/v8ws/dev/metrics/$CELL.json
OUT=$PROJ_DATA/v8ws/dev/metrics/$CELL-ntpv2.json
phase precheck "false" "test -f $PROJ_DATA/v8ws/dev/labels/dev.npz && test -f $PROJ_DATA/v8ws/dev/teacher/flat/DONE.json && test -s $OLD || { echo PRECONDITION FAILED: dev labels / dev teacher cache / old NTP JSON missing; exit 1; }"
phase devmetrics "test -s $OUT.sessions.npz" "
    d=\$(ls -d $PROJ_DATA/runs/v8ws/5M/$CELL/seed-6-*/ | grep -v nockpt | tail -1)
    test -f \$d/DONE.json || { echo PRECONDITION FAILED: \$d not finished; exit 1; }
    cd $AE_CODE && ck=\$($PY -m scripts.v7.final_ckpt \$d)
    $PY -m scripts.v8.dev_metrics --ckpt \$ck --cell $CELL --out $OUT > $AE_RESULTS/devmetrics.log 2>&1 || { tail -20 $AE_RESULTS/devmetrics.log; exit 1; }
    tail -1 $AE_RESULTS/devmetrics.log
"
phase compare "false" "
    cd $AE_CODE && rc=0 && { $PY -m scripts.v8.ntpv2_compare $OUT $OLD > $AE_RESULTS/compare.log 2>&1 || rc=\$?; }
    cat $AE_RESULTS/compare.log; exit \$rc
"
