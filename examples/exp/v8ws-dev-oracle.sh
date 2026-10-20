#!/usr/bin/env bash
#EXP gpus=0 cpus=32 mem=64G time=2:00:00
# HYPOTHESIS: none -- V8-A4 item 17 (dev): oracles 2 (focal unknown-strategy, exact Bayes over the declared prior; the
# dev split is drawn from the training mixture -> prior "training", as scripts/v7/oracle_corpus PRIOR["dev"]) and 3
# (opponent known-strategy, hidden cards integrated out) on the dev split's OWN decisions, computed by the same code
# that produced the val oracle corpus (scripts/v7/oracle_corpus; parses the dev shards' tokens + side records, no data
# generation). Output under $PROJ_DATA/v8ws/dev/ (dev-only guard). Smoke (stride 200, 30 sessions, 3 workers): 160 s
# wall, ~11 CPU-s / session -> 6,000 sessions ~66k CPU-s ~ 35-40 min on 32 workers (one shard per step; resumable).
# Phase 2: oracle excess (+ gap closed when std 5M / 200M and both NTP references have sessions npz) for every dev
# metrics JSON that has a sessions npz -> $PROJ_DATA/v8ws/dev/metrics/learning-gap.json.
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=1 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
DEV=$PROJ_DATA/datasets/naive_poker_v7/v7f/prod/dev/dev.json
O=$PROJ_DATA/v8ws/dev/oracle-corpus
M=$PROJ_DATA/v8ws/dev/metrics
phase oracle "test -f $O/oracle-dev-00000.npz && test -f $O/oracle-dev-00001.npz && test -f $O/oracle-dev-00002.npz" "
    mkdir -p $O && cd $AE_CODE && $PY -m scripts.v7.oracle_corpus --manifest $DEV --split dev --out $O --workers 32 2>&1 | tee $AE_RESULTS/oracle.log
"
phase table "false" "
    cd $AE_CODE
    js=\$(for f in $M/*.json; do test -s \$f.sessions.npz && echo \$f; done)
    test -n \"\$js\" || { echo 'no dev metrics with sessions npz yet; oracle corpus done'; exit 0; }
    extra=''
    test -s $M/std-5M.json.sessions.npz && test -s $M/std-200M.json.sessions.npz && extra=\"--std $M/std-5M.json $M/std-200M.json\"
    ntp=''
    for c in K4-b80-hybrid-indep-d02 K4-b80-strict-indep-d0; do test -s $M/\$c.json.sessions.npz && ntp=\"\$ntp $M/\$c.json\"; done
    test -n \"\$ntp\" && extra=\"\$extra --ntp \$ntp\"
    $PY -m scripts.v8.dev_learning_gap --metrics \$js \$extra --oracle-dir $O --out $M/learning-gap.json | tee $AE_RESULTS/learning-gap.log
"
