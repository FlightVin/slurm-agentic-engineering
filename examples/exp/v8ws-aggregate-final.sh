#!/usr/bin/env bash
#EXP gpus=0 cpus=8 mem=32G time=6:00:00
# HYPOTHESIS: none -- V8 analysis pipeline (CPU; idempotent, safe to rerun every hour): audit -> aggregate -> paired ->
# plots -> living report. audit / aggregate / paired are incremental: per-run (per-pair) results are cached under
# $PROJ_DATA/v8ws/{audit/cache, metrics/runs, paired/cache} keyed by code sha + input fingerprints / sha256s and written
# as each unit finishes, so unchanged runs are skipped and a requeue resumes instead of restarting. audit exits 1 when
# some run FAILs a gate: expected, those runs are excluded and ledgered, so the pipeline continues. Report: V8-A6 living
# FINAL version $V8_LIVING_VERSION (default 14; --final: "FINAL, frozen <build time>", V8-A8 item 5) -> $AE_RESULTS/final-analysis.md (+ assets next to it); the orchestrator
# publishes versions into intermediate-analyses (this job never writes the report there; the frozen draft is not
# touched). Writes $PROJ_DATA/v8ws/{audit,metrics,paired,plots,reports}, $PROJ_DATA/v8-scratch/analysis and the
# aggregate's small CSV/MD assets; full logs -> $LOGS (scratch), the last 200 lines of each -> $AE_RESULTS (harvest
# cap 2 MB). Reads run dirs / eval outputs read-only.
# Phases run under bash -eu: exit codes are captured with `|| st=$?`.
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=8 OPENBLAS_NUM_THREADS=8 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
export LOGS=$PROJ_DATA/v8-scratch/logs/$AE_EXPID/$AE_SHA
mkdir -p "$LOGS"
export V8_LIVING_VERSION=${V8_LIVING_VERSION:-16}   # v1-v13 published; v14, v15 = closeout audit builds; FINAL = v16

phase audit "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.audit > \$LOGS/audit.log 2>&1 || st=\$?; }
    tail -200 \$LOGS/audit.log > \$AE_RESULTS/audit.log
    tail -5 \$AE_RESULTS/audit.log
    echo \"audit exit \$st (1 = some run FAILs a gate: excluded + ledgered; >1 = crash)\"
    [ \$st -le 1 ]
"
phase aggregate "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.aggregate > \$LOGS/aggregate.log 2>&1 || st=\$?; }
    tail -200 \$LOGS/aggregate.log > \$AE_RESULTS/aggregate.log
    tail -5 \$AE_RESULTS/aggregate.log; exit \$st
"
phase paired "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.paired > \$LOGS/paired.log 2>&1 || st=\$?; }
    tail -200 \$LOGS/paired.log > \$AE_RESULTS/paired.log
    tail -5 \$AE_RESULTS/paired.log; exit \$st
"
phase plots "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.plots > \$LOGS/plots.log 2>&1 || st=\$?; }
    tail -200 \$LOGS/plots.log > \$AE_RESULTS/plots.log
    tail -5 \$AE_RESULTS/plots.log; exit \$st
"
phase report "false" "
    cd \$AE_CODE && st=0 && { \$PY -m scripts.v8.final_report --mode living --final --version \$V8_LIVING_VERSION --out \$AE_RESULTS/final-analysis.md --scratch \$PROJ_DATA/v8-scratch/analysis > \$LOGS/report-living.log 2>&1 || st=\$?; }
    tail -200 \$LOGS/report-living.log > \$AE_RESULTS/report-living.log
    tail -5 \$AE_RESULTS/report-living.log; exit \$st
"
