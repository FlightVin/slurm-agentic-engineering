#!/usr/bin/env bash
#EXP gpus=0 cpus=1 time=00:05:00 after=sim-mid-a,sim-mid-b
# HYPOTHESIS: fan-in. Runs only after BOTH midtraining variants terminate.
phase collect "test -f \$AE_RESULTS/report.json" "
    printf '{\"collected\": true, \"host\": \"%s\"}\n' \"\$(hostname)\" > \$AE_RESULTS/report.json
    cat \$AE_RESULTS/report.json
"
