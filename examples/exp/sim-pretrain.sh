#!/usr/bin/env bash
#EXP gpus=0 cpus=2 time=00:12:00
# HYPOTHESIS: a realistic multi-phase "pretrain" runs, writes a durable artefact
# to a PROJECT path (not $AE_RUNDIR), and emits a small distillate. Downstream
# experiments chained on it must be able to find that artefact.

export PROJ_DATA=/data/user_data/$USER/ae-sim
export CKPT=$PROJ_DATA/pretrain/ckpt.txt

phase prep_data "test -f $PROJ_DATA/corpus.txt" "
    mkdir -p $PROJ_DATA
    seq 1 20000 > $PROJ_DATA/corpus.txt
    echo \"corpus: \$(wc -l < $PROJ_DATA/corpus.txt) lines\"
"
phase train "test -f $CKPT" "
    mkdir -p $PROJ_DATA/pretrain
    echo 'training (simulated, 100s)'
    for i in 1 2 3 4 5; do echo \"  step \$((i*20)) loss \$(echo \"scale=4; 2.0/\$i\" | bc)\"; sleep 20; done
    { echo \"sha=\$AE_SHA\"; echo \"host=\$(hostname)\"; echo \"final_loss=0.4000\"; } > $CKPT
    echo \"checkpoint written: $CKPT\"
"
phase summarize "test -f \$AE_RESULTS/summary.json" "
    printf '{\"final_loss\": 0.4000, \"ckpt\": \"%s\", \"sha\": \"%s\"}\n' \"$CKPT\" \"\$AE_SHA\" > \$AE_RESULTS/summary.json
    cat \$AE_RESULTS/summary.json
"
