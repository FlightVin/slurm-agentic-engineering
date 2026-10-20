#!/usr/bin/env bash
#EXP gpus=1 cpus=6 mem=64G time=3:00:00 part=preempt exclude=babel-l5-[16,20,28,32],babel-l9-[16,20,28,32],babel-m9-[16,20,28,32],babel-n9-20,babel-z5-[16,20,28,32],babel-z9-16,babel-p9-32,babel-s5-24,babel-v9-28,babel-p9-16,babel-m5-32,babel-o9-32,babel-x9-16,babel-y9-08
# HYPOTHESIS: none -- owner V8-A9 O5 v2 teacher subset, shards 0..54 (55 shards): frozen V7 std 200M teacher (sha
# d9b7beec54d6) final-norm hidden (896-d, fp16) + inclusion probability q (fp32) at the pre-declared stratified IPW
# subset (scripts/v8/o5v2.py: q_u = min(1, max(Q0 0.01, K 2 / min_b |U_s,c_b(u)|)), new salt 0x5EED0052; ~6.5% of
# h >= 40 sites, ~1.9 GB per 55 shards). Same packing / precision as the O1/O2 cache; writes ONLY $T/o5v2/ (o12/ o5/
# o34/ flat* untouched). Idempotent per-shard done markers. Expected ~37 min per job (as v8ws-teacher-o12-*).
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=6 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
T=$PROJ_DATA/v8ws/teacher
TC="$PY -m scripts.v8.teacher_cache --o5v2 --shards 0:55 --out $T"
phase o5v2 "cd $AE_CODE && $TC --status" "cd $AE_CODE && $TC > $AE_RESULTS/o5v2.txt 2>&1 || { tail -20 $AE_RESULTS/o5v2.txt; exit 1; }; tail -2 $AE_RESULTS/o5v2.txt"
phase verify "test -f $AE_RESULTS/verify.txt" "cd $AE_CODE && $TC --status > $AE_RESULTS/verify.tmp && mv $AE_RESULTS/verify.tmp $AE_RESULTS/verify.txt && cat $AE_RESULTS/verify.txt"
