# ==========================================================================
# SITE CONFIG -- the ONLY file with cluster-specific values.
#
# `ae init` copies this to <workspace>/config.sh (the workspace defaults to the
# slurm-agentic-engineering/ directory itself). Fill in the REQUIRED block; `ae`
# refuses to run while any required value is empty. A filled-in example for a
# real two-pool cluster is in examples/cluster/config-babel.sh.
# ==========================================================================

# --- REQUIRED -------------------------------------------------------------
AE_HOST=""                           # ssh alias of the login node (needs ControlMaster; see README)
AE_REMOTE_REPO=''                    # compute-side clone of THIS project, single-quoted so
                                     # $HOME expands REMOTELY, e.g. '$HOME/projects/myproject'
AE_BRANCH=""                         # the laptop's authoritative branch (what ae submit pins)
AE_PARTITION=""                      # default (usually preemptible) GPU partition
AE_QOS_GPU=""                        # GPU QOS on AE_PARTITION
AE_QOS_CPU=""                        # CPU-only QOS (0 GPUs). If your site has no separate one,
                                     # use the same QOS as AE_QOS_GPU only if it allows 0-GPU jobs.

# --- remote layout --------------------------------------------------------
AE_REMOTE="origin"                   # git remote shared by laptop and cluster
AE_REMOTE_ROOT='$HOME/ae'            # single-quoted: expanded REMOTELY, not locally

# --- experiments ----------------------------------------------------------
AE_DEFAULT_TIME="08:00:00"           # never rely on a partition's default walltime
AE_DEFAULT_CPUS=4
AE_SIGNAL="B:USR1@120"               # pre-kill signal; lib/preamble.sh discriminates
                                     # preemption vs walltime from the time left

# --- optional second pool (e.g. a NON-preemptible partition) --------------
# Leave AE_PARTITION_GEN empty if there is only one pool. With it set:
#   #EXP part=general  -> this pool;   #EXP part=auto -> whichever starts earlier.
AE_PARTITION_GEN=""
AE_QOS_GEN=""
AE_GEN_MAX_GPUS=0                    # per-user GPU cap on that pool (0 = unknown, no note)
AE_GEN_MAX_SUBMIT=0                  # per-user submit cap (0 = no guard)
AE_GEN_MAX_SECONDS=0                 # its MaxTime in seconds (0 = no guard)

# --- standby (debug/tinkering) capacity -----------------------------------
# CPU standby is the default tinkering substrate: fast to schedule, no GPU quota.
AE_DBG_CPU_NAME="ae-dbg-cpu"
AE_DBG_CPU_CPUS=4
AE_DBG_CPU_TIME="12:00:00"
AE_DBG_CPU_POOL=2
# GPU standby on AE_PARTITION (only for tinkering that truly needs a GPU).
AE_DBG_NAME="ae-dbg"
AE_DBG_GPUS=1
AE_DBG_CPUS=4
AE_DBG_TIME="24:00:00"
AE_DBG_POOL=0
# GPU standby on AE_PARTITION_GEN (ignored when no second pool is configured).
AE_DBG_GEN_NAME="ae-dbg-gen"
AE_DBG_GEN_GPUS=1
AE_DBG_GEN_CPUS=4
AE_DBG_GEN_TIME="24:00:00"
AE_DBG_GEN_POOL=0

# --- quota guards (from `sacctmgr show qos`) ------------------------------
AE_MAX_GPUS_PER_USER=0               # GPU cap on AE_PARTITION (0 = unknown, no note)
AE_MAX_SUBMIT=100                    # MaxSubmitPU on AE_PARTITION (refused beyond it)

# --- harvest --------------------------------------------------------------
AE_HARVEST_MAX_KB=2048               # per-experiment cap on what comes back to the laptop.
                                     # If a job wants more, fix the job to emit a summary.

# --- tinkering agent ------------------------------------------------------
# Command that runs the compute-side agent; the prompt is passed as its last argument.
AE_AGENT_CMD="claude --permission-mode acceptEdits"
