#!/usr/bin/env bash
#EXP gpus=0 cpus=8 mem=48G time=2:00:00
# HYPOTHESIS: none -- owner V8-A9: consolidate the 881 o5v2 shards (v8ws-teacher-o5v2-00..15) -> $T/o5v2/flat (site rows
# of $T/flat, q, hidden; per-session o5_40 / o5_80) read by model/aux.py TeacherStore(o5_version=2). Run after ALL 16
# o5v2 jobs completed. Writes ~30 GB under $T/o5v2/flat (the per-shard o5v2/*.npz may be deleted after DONE.json).
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=1 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
T=$PROJ_DATA/v8ws/teacher
phase precheck "false" "cd $AE_CODE && $PY -m scripts.v8.teacher_cache --o5v2 --shards 0:881 --out $T --status"
phase flat "test -f $T/o5v2/flat/DONE.json" "cd $AE_CODE && $PY -m scripts.v8.teacher_cache --o5v2 --shards 0:881 --out $T --consolidate --workers 8 > $AE_RESULTS/flat.txt 2>&1 || { tail -20 $AE_RESULTS/flat.txt; exit 1; }; cat $AE_RESULTS/flat.txt"
