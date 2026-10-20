#!/usr/bin/env bash
#EXP gpus=0 cpus=1 time=00:05:00 after=sim-pretrain
# HYPOTHESIS: midtrain variant b warm-starts from the pretrain checkpoint at the
# PROJECT path. Demonstrates the cross-experiment contract: export the variable,
# read from $PROJ_DATA, and verify the precondition (afterany does not imply the
# parent succeeded).
export PROJ_DATA=/data/user_data/$USER/ae-sim
export CKPT=$PROJ_DATA/pretrain/ckpt.txt

phase precheck "false" "
    if [ ! -f \$CKPT ]; then echo \"PRECONDITION FAILED: no checkpoint at \$CKPT\"; exit 1; fi
    echo \"found checkpoint from sha \$(grep ^sha= \$CKPT | cut -d= -f2)\"
"
phase midtrain "test -f \$AE_RESULTS/mid.json" "
    base=\$(grep ^final_loss= \$CKPT | cut -d= -f2)
    printf '{\"variant\":\"b\",\"base_loss\":%s,\"mid_loss\":0.3%s}\n' \"\$base\" \"5\" > \$AE_RESULTS/mid.json
    cat \$AE_RESULTS/mid.json
"
