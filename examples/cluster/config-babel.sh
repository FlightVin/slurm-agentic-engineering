# ==========================================================================
# SITE CONFIG — the ONLY file with cluster-specific values.
# Generic logic in bin/ae and lib/preamble.sh reads these; nothing else
# hard-codes a hostname, partition, QOS, or path. Porting to another
# cluster should mean editing this file and nothing else.
# ==========================================================================

# --- connection ---------------------------------------------------------
AE_HOST="babel"                      # ssh alias (must have ControlMaster; see OPERATOR.md)

# --- remote layout ------------------------------------------------------
AE_REMOTE_ROOT='$HOME/ae'            # single-quoted: expanded REMOTELY, not locally
AE_REMOTE_REPO='$HOME/projects/wllms'  # compute-side clone; source for worktrees

# --- git ----------------------------------------------------------------
AE_BRANCH="v8-ws"               # laptop's authoritative branch
AE_REMOTE="origin"

# --- slurm: experiments -------------------------------------------------
# Two pools. Experiments pick one with `#EXP part=preempt|general`.
#   preempt : 24 GPUs, 31-day wall, tier 1, PREEMPTIBLE, 2x fairshare cost
#   general : 8 GPUs, 2-day wall, tier 4, NOT preemptible, half fairshare cost
# Verified 2026-09-21: nothing lists `normal` in its Preempt set.
AE_PARTITION="preempt"                 # default pool when part= is unset
AE_QOS_GPU="preempt_qos"             # MinTRES=gres/gpu=1 -> cannot run 0-GPU jobs
AE_QOS_CPU="preempt_cpu_qos"         # 0 GPUs, separate quota pool, max 32 cpu/job
AE_DEFAULT_TIME="08:00:00"           # partition default is 30min; never rely on it

# --- general (non-preemptible) pool -------------------------------------
AE_PARTITION_GEN="general"
AE_QOS_GEN="normal"
AE_GEN_MAX_GPUS=8                    # MaxTRESPU gres/gpu=8
AE_GEN_MAX_RUNNING=10                # MaxJobsPU
AE_GEN_MAX_SUBMIT=50                 # MaxSubmitPU
AE_GEN_MAX_SECONDS=172800            # partition MaxTime 2-00:00:00
# `normal` carries MinTRES=gres/gpu=1 exactly like preempt_qos, so a 0-GPU job
# submitted here pends on QOSMinGRES forever. ae routes gpus=0 back to the CPU
# pool automatically -- do not "fix" that by adding a 0-GPU general path.
AE_DEFAULT_CPUS=4
AE_SIGNAL="B:USR1@120"

# --- slurm: standby (debug/tinkering) capacity --------------------------
AE_DBG_NAME="ae-dbg"
AE_DBG_GPUS=1                        # MinTRES forces >=1 on the GPU qos
AE_DBG_CPUS=4
AE_DBG_TIME="24:00:00"
AE_DBG_POOL=2                        # GPU standby: SLOW to schedule (tier-1 queue,
                                     # hours). Keep few; only for GPU tinkering.

# CPU standby: schedules in SECONDS and uses a SEPARATE quota pool (0 GPUs), so
# it costs nothing against the 24-GPU budget. This is the default tinkering
# substrate -- most code/data work needs no GPU.
AE_DBG_CPU_NAME="ae-dbg-cpu"
AE_DBG_CPU_CPUS=4
AE_DBG_CPU_TIME="12:00:00"
AE_DBG_CPU_POOL=2

# GPU standby on the NON-PREEMPTIBLE pool. Same cost model as ae-dbg (1 of a
# small GPU quota) but it cannot be taken away once running, so it is the better
# home for a long debugging session. Counts against general's 8-GPU budget.
AE_DBG_GEN_NAME="ae-dbg-gen"
AE_DBG_GEN_GPUS=1
AE_DBG_GEN_CPUS=4
AE_DBG_GEN_TIME="2-00:00:00"          # general MaxTime; standby is worth the full wall
AE_DBG_GEN_POOL=2

# --- quota guards (from `sacctmgr show qos`) ----------------------------
AE_MAX_GPUS_PER_USER=24
AE_MAX_SUBMIT=100

# --- harvest ------------------------------------------------------------
AE_HARVEST_MAX_KB=5120               # owner raised 2 MB -> 5 MB (2026-10-14); keeps laptop small
