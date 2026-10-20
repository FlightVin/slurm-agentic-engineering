# ==========================================================================
# SITE CONFIG -- tuned for CMU Babel. The ONLY file with cluster-specific values.
#
# `ae init` copies this to <workspace>/config.sh (the workspace defaults to the
# slurm-agentic-engineering/ directory itself). Fill in the two PER-PROJECT values;
# `ae` refuses to run while any required value is empty. Everything else is Babel's
# measured configuration (cluster/BABEL.md, cluster/CARD.md) and works as-is.
# Re-check the quota numbers with `ae doctor` if Babel changes them.
# Porting to another cluster means editing this file (and the cluster card) only.
# ==========================================================================

# --- PER-PROJECT (required) -----------------------------------------------
AE_REMOTE_REPO=''                    # compute-side clone of THIS project, single-quoted so
                                     # $HOME expands REMOTELY, e.g. '$HOME/projects/myproject'
AE_BRANCH=""                         # the laptop's authoritative branch (what ae submit pins)

# --- connection -----------------------------------------------------------
AE_HOST="babel"                      # ssh alias for login.babel.cs.cmu.edu; MUST use
                                     # ControlMaster (README "ssh"): unmultiplexed auth 5-31 s

# --- remote layout --------------------------------------------------------
AE_REMOTE="origin"                   # git remote shared by laptop and cluster
AE_REMOTE_ROOT='$HOME/ae'            # single-quoted: expanded REMOTELY, not locally.
                                     # Under /home (100 GB quota): never write checkpoints here.

# --- pool 1: preempt (default) --------------------------------------------
#   24 GPUs/user, 31-day wall, priority tier 1, PREEMPTIBLE by everyone, 2x fairshare cost.
AE_PARTITION="preempt"
AE_QOS_GPU="preempt_qos"             # MinTRES=gres/gpu=1 -> a 0-GPU job pends forever here
AE_QOS_CPU="preempt_cpu_qos"         # 0 GPUs, SEPARATE quota: 32 cpu/job, 64 cpu total;
                                     # ae routes every gpus=0 job here automatically
AE_DEFAULT_TIME="08:00:00"           # partition default is 30 min; never rely on it
AE_DEFAULT_CPUS=4
AE_SIGNAL="B:USR1@120"               # Babel GraceTime is 2 min; preamble.sh tells
                                     # preemption from walltime by the time left

# --- pool 2: general (NOT preemptible) ------------------------------------
#   8 GPUs/user, 2-day wall, tier 4, not preemptible (verified 2026-09-21), half fairshare cost.
#   `normal` ALSO carries MinTRES=gres/gpu=1: CPU-only work can never run here.
#   #EXP part=general -> here;  part=auto -> whichever pool estimates the earlier start.
AE_PARTITION_GEN="general"
AE_QOS_GEN="normal"
AE_GEN_MAX_GPUS=8                    # MaxTRESPU gres/gpu=8
AE_GEN_MAX_RUNNING=10                # MaxJobsPU
AE_GEN_MAX_SUBMIT=50                 # MaxSubmitPU
AE_GEN_MAX_SECONDS=172800            # partition MaxTime 2-00:00:00; ae refuses longer jobs

# --- standby (debug/tinkering) capacity -----------------------------------
# CPU standby: ~5 s to RUNNING on a quiet queue, over an hour when 100+ CPU jobs pend; separate
# quota, 0 GPUs. The default tinkering substrate -- keep it warm so the wait is already paid.
AE_DBG_CPU_NAME="ae-dbg-cpu"
AE_DBG_CPU_CPUS=4
AE_DBG_CPU_TIME="12:00:00"
AE_DBG_CPU_POOL=2
# GPU standby on preempt: measured 2.5-3.5 h to RUNNING; 1 of the 24-GPU quota each.
AE_DBG_NAME="ae-dbg"
AE_DBG_GPUS=1                        # MinTRES forces >= 1
AE_DBG_CPUS=4
AE_DBG_TIME="24:00:00"
AE_DBG_POOL=2
# GPU standby on general: cannot be preempted once running; 1 of the 8-GPU quota each.
# Which GPU pool starts first varies hour to hour, so `ae pool` holds both.
AE_DBG_GEN_NAME="ae-dbg-gen"
AE_DBG_GEN_GPUS=1
AE_DBG_GEN_CPUS=4
AE_DBG_GEN_TIME="2-00:00:00"         # general MaxTime: a standby is worth the full wall
AE_DBG_GEN_POOL=2

# --- quota guards (sacctmgr show qos preempt_qos) -------------------------
AE_MAX_GPUS_PER_USER=24              # MaxTRESPU gres/gpu on preempt_qos
AE_MAX_SUBMIT=100                    # MaxSubmitPU on preempt_qos (refused beyond it)

# --- harvest --------------------------------------------------------------
AE_HARVEST_MAX_KB=2048               # per-experiment cap on what comes back to the laptop.
                                     # If a job wants more, fix the job to emit a summary.

# --- tinkering agent ------------------------------------------------------
# Command that runs the compute-side agent; the prompt is passed as its last argument.
AE_AGENT_CMD="claude --permission-mode acceptEdits"
