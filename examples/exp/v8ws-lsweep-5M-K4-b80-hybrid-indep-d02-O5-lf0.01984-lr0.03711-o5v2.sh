#!/usr/bin/env bash
#EXP gpus=1 cpus=8 mem=48G time=15:00:00 part=preempt exclude=babel-l5-[16,20,28,32],babel-l9-[16,20,28,32],babel-m9-[16,20,28,32],babel-n9-20,babel-z5-[16,20,28,32],babel-z9-16,babel-p9-32,babel-s5-24,babel-v9-28,babel-p9-16,babel-m5-32,babel-o9-32,babel-x9-16,babel-y9-08,babel-v9-20,babel-m5-28
# (RTX PRO 6000 Blackwell excluded: flex-attention Triton kernel exceeds its shared memory; v7f-bwtest)
# HYPOTHESIS: [owner V8-A9 O5 v2: training.aux.o5_loss_version 2, IPW L_R on the <teacher>/o5v2 subset; otherwise identical to v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711.sh except output paths] V8-A4 Stage sweep (development run, NOT a production cell; sweep ledger): O5 on 5M K4-b80-hybrid-indep-d02 with V8_LAMBDA_F=0.01984 V8_LAMBDA_R=0.03711; identical to the production K4-b80-hybrid-indep-d02-O5 script except this weight and run/work/eval paths. Selected on the DEV split only (V8-A4 item 5).
# after b=80 completed hands, hybrid suffix access, independent construction, WS key dropout 0.2;
# from scratch, 4 epochs (original data passes) over the frozen train manifest, V7 std 5M recipe (L5 d256 H4 i960,
# lr 0.001125, seed 6, 16 x 9,216 positions per update; 1 GPU(s), micro_rows 4). One rolling verified checkpoint.
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=4 OPENBLAS_NUM_THREADS=4 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
export CORPUS=$PROJ_DATA/datasets/naive_poker_v7/v7f/prod
export TRAIN_MANIFEST=$CORPUS/train/train.json DEV_MANIFEST=$CORPUS/dev/dev.json
export VAL_MANIFESTS=$CORPUS/val_seen/val_seen.json,$CORPUS/val_unseen/val_unseen.json
export TRAIN_MANIFEST_SHA256=c4d1bfaf98235cf7c05e5453ee5f05b60924d2ed7f12b0338c9a3b59fa095436
export SEED=6 RUNS=$PROJ_DATA/runs WORK=$PROJ_DATA/v8-work/cfg/v8ws-lsweep-5M-K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2
export V8_LAMBDA_F=0.01984 V8_LAMBDA_R=0.03711 V8_O5_LOSS_VERSION=2 V8_AUX=O5 V8_TEACHER_SRC=$PROJ_DATA/v8ws/teacher V8_TEACHER_DIR=/tmp/v8ws-teacher-d9b7beec54d6
export V8_MICRO_ROWS=4
export V8_MC_ARGS="--train-manifest $TRAIN_MANIFEST --dev-manifest $DEV_MANIFEST --length-manifests $VAL_MANIFESTS --rows 16 --lr 0.001125"
phase precheck "false" "
    # --- stage teacher cache to node-local disk (identical bytes; avoids NFS random reads) ---
    mkdir -p \$V8_TEACHER_DIR/flat \$V8_TEACHER_DIR/o5v2
    need=\$({ du -sbL \$V8_TEACHER_SRC/flat/{DONE.json,sessions.npz,tokl.npy,h.npy,role.npy,legal.npy,o5row.npy,logits.npy} \$V8_TEACHER_SRC/o5v2/flat/{DONE.json,sessions.npz,site.npy,q.npy,hidden.npy} 2>/dev/null || true; } | awk '{s+=\$1} END {print s}')
    avail=\$(df --output=avail -B1 /tmp | tail -1)
    exec 9>/tmp/v8ws-teacher.lock; flock -w 5400 9 || { echo PRECONDITION FAILED: teacher staging lock timeout; exit 1; }
    for f in meta.json flat/DONE.json flat/sessions.npz flat/tokl.npy flat/h.npy flat/role.npy flat/legal.npy flat/o5row.npy flat/logits.npy o5v2/meta.json o5v2/flat flat34; do
      s=\$(find \$V8_TEACHER_SRC/\$f -type f -printf '%s\n' | awk '{t+=\$1} END {print t+0}')
      d=\$({ find \$V8_TEACHER_DIR/\$f -type f -printf '%s\n' 2>/dev/null || true; } | awk '{t+=\$1} END {print t+0}')
      if [ \"\$s\" != \"\$d\" ]; then
        if [ \$avail -lt \$((need + 10000000000)) ]; then echo PRECONDITION FAILED: /tmp too small on \$(hostname): avail \$avail need \$need; exit 1; fi
        rm -rf \$V8_TEACHER_DIR/\$f.tmp && cp -r \$V8_TEACHER_SRC/\$f \$V8_TEACHER_DIR/\$f.tmp && rm -rf \$V8_TEACHER_DIR/\$f && mv \$V8_TEACHER_DIR/\$f.tmp \$V8_TEACHER_DIR/\$f || { echo PRECONDITION FAILED: staging \$f; exit 1; }
      fi
    done
    flock -u 9; exec 9>&-
    echo staged teacher cache on \$(hostname) at \$V8_TEACHER_DIR: \$(du -sh \$V8_TEACHER_DIR | cut -f1)
    got=\$(sha256sum \$TRAIN_MANIFEST | cut -d' ' -f1)
    if [ \$got != \$TRAIN_MANIFEST_SHA256 ]; then echo PRECONDITION FAILED: train manifest sha256 \$got differs; exit 1; fi
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    df -h \$PROJ_DATA | tail -1
    for f in flat o5v2/flat; do test -f \$V8_TEACHER_DIR/\$f/DONE.json || { echo PRECONDITION FAILED: teacher cache \$f/DONE.json missing; exit 1; }; done
    \$PY -c \"import json,sys; t='\$V8_TEACHER_DIR'; s=[json.load(open(t+'/meta.json'))['teacher_sha256'], json.load(open(t+'/flat/DONE.json'))['meta']['teacher_sha256'], json.load(open(t+'/o5v2/flat/DONE.json'))['teacher_sha256']]; print('teacher sha256', s[0]); sys.exit(0 if all(x.startswith('d9b7beec54d6') for x in s) else 'PRECONDITION FAILED: teacher sha256 '+str(s))\" || exit 1
"
phase train "d=\$(ls -d $RUNS/v8ws/5M/K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2/seed-6-*/ 2>/dev/null | grep -v nockpt | tail -1); test -n \"\$d\" && cd \$AE_CODE && \$PY -m scripts.v7.final_ckpt \$d > /dev/null 2>&1" "
    mkdir -p \$WORK
    cd \$AE_CODE && bash scripts/v8/train_one.sh 5M 4 80 hybrid independent 0.2 \$RUNS \$WORK 1 \$SEED
    d=\$(cat \$WORK/run_dir-5M-K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2.txt)
    \$PY -m scripts.v7.final_ckpt \$d
"
phase distil "test -f \$AE_RESULTS/DONE.json" "
    d=\$(ls -d $RUNS/v8ws/5M/K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2/seed-6-*/ | grep -v nockpt | tail -1)
    cd \$AE_CODE && \$PY -m scripts.v7.final_ckpt \$d > \$AE_RESULTS/final_ckpt.txt 2> \$AE_RESULTS/final_ckpt.json
    grep '^#' \$d/config.yaml.used > \$AE_RESULTS/config_header.txt
    cp \$d/DONE.json \$AE_RESULTS/DONE.json
"

export EVAL_DIR=$PROJ_DATA/v8ws/evals-lsweep/5M/K4-b80-hybrid-indep-d02-O5-lf0.01984-lr0.03711-o5v2 LABELS=$PROJ_DATA/evals/v7f-labels ORACLE=$PROJ_DATA/datasets/naive_poker_v7/v7f/oracle-corpus
for s in val_seen val_unseen; do
  phase eval_$s "test -f \$EVAL_DIR/decisions-$s-b80.npz && test -s \$AE_RESULTS/eval-$s-b80.json" "
    mkdir -p \$EVAL_DIR
    ck=\$(cat \$AE_RESULTS/final_ckpt.txt)
    cd \$AE_CODE && \$PY -m scripts.v8.eval_ws --ckpt \$ck --manifest \$CORPUS/$s/$s.json --labels \$LABELS/$s.npz --name $s-b80 --out-dir \$EVAL_DIR --oracle-dir \$ORACLE/$s > \$AE_RESULTS/eval-$s-b80.log 2>&1 || { tail -20 \$AE_RESULTS/eval-$s-b80.log; exit 1; }
    grep '^{' \$AE_RESULTS/eval-$s-b80.log | tail -1 > \$AE_RESULTS/eval-$s-b80.json; cat \$AE_RESULTS/eval-$s-b80.json
  "
done
