# Babel SLURM Reference

**Cluster:** `babel` — CMU, SLURM **26.05.1**
**User:** `vineethb` (uid 6010497) · **Account:** `msimchow` · lineage `/mld/msimchow/0-vineethb/`
**Analysis date:** 2026-09-17

**Scope note.** This document covers only the two submission paths that actually work:
`~/scripts/interactive_job.sh` and the single-GPU training submit script
(`~/scripts/submit_naivepoker_1gpu.sh`). The monitoring daemon and the Claude-session host
scripts (`v3_monitor_daemon.sh`, `submit_v3_monitor_job.sh`, `v3_status.sh`,
`v3_session_resume.sh`, `submit_claude_host.sh`, `claude_attach.sh`) are **non-functional** and are
deliberately excluded — any conclusions that depended on them have been removed, and §7 records
what that costs us.

**Method.** All findings were taken live from the cluster. Nothing was submitted for real — every
submission test used `sbatch --test-only`. Scripts were copied down with `scp -r babel:~/scripts`
and read locally.

---

## Contents

1. [Quick reference card](#1-quick-reference-card)
2. [Connecting to the cluster](#2-connecting-to-the-cluster)
3. [What we can use, and why only preempt](#3-what-we-can-use-and-why-only-preempt)
4. [Our limits: what we can actually request](#4-our-limits-what-we-can-actually-request)
5. [GPUs available on preempt](#5-gpus-available-on-preempt)
6. [How we submit jobs](#6-how-we-submit-jobs)
7. [How preemption works](#7-how-preemption-works)
8. [Priority: why we wait](#8-priority-why-we-wait)
9. [Known bugs and gaps](#9-known-bugs-and-gaps)
10. [Command cookbook](#10-command-cookbook)
- [Addendum A — maxlab / maxlab-cpu](#addendum-a--maxlab--maxlab-cpu-not-available-to-us-in-practice)
- [Addendum B — restoring `general` access](#addendum-b--restoring-general-access)

---

## 1. Quick reference card

| | |
|---|---|
| **Login** | `ssh babel` → `login.babel.cs.cmu.edu`, user `vineethb`, key `~/.ssh/id_ed25519` |
| **Partition we use** | `preempt` (the cluster default — 128 nodes, 980 GPUs) |
| **QOS we use** | `preempt_qos` (GPU jobs) · `preempt_cpu_qos` (CPU-only jobs) |
| **Account** | `msimchow` |
| **GPU quota** | **24 GPUs** concurrently (`preempt_qos`) |
| **CPU quota** | 256 CPUs/job (`preempt_qos`) · 32 CPUs/job, 64 total (`preempt_cpu_qos`) |
| **Job quota** | 24 running / 100 submitted (`preempt_qos`) |
| **Max walltime** | **31 days** (partition cap; no QOS `MaxWall`) |
| **Default walltime** | 30 minutes — **always pass `--time`** |
| **Minimum request** | **≥ 1 GPU** on `preempt_qos` (`MinTRES=gres/gpu=1`) |
| **Preemptible?** | **Yes — by every other QOS on the cluster** |
| **Grace period** | 2 minutes, then SIGKILL, then automatic requeue under the same JobID |
| **Requeue cap** | None in practice (jobs on this cluster reach 95 restarts) |
| **Help** | `#babel-babble` Slack channel |

**Never run work on the login node.** `login3` carries a load average of ~18 with 39 users.

---

## 2. Connecting to the cluster

### SSH configuration

From `~/.ssh/config` on the local machine:

```sshconfig
Host babel
    HostName login.babel.cs.cmu.edu
    User vineethb
    IdentityFile ~/.ssh/id_ed25519
    Compression no
    ForwardAgent yes
    ForwardX11 no

Host babel-compute-node
    HostName babel-y9-16
    User vineethb
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump babel
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
```

```bash
ssh babel          # lands on a login node (login1/login2/login3 — round-robin)
```

The `babel-compute-node` entry proxies through the login node to a **hardcoded** compute node.
It only works when we actually hold an allocation on `babel-y9-16`, so it needs editing per
session. The reliable way into a running job is `srun` (§6.1), not SSH.

### Identity and group membership

```
$ id
uid=6010497(vineethb) gid=6010497(vineethb)
groups=6010497(vineethb),500(hpcuser),60057(mld),60113(msimchow_group),
       60164(maxlab),60171(nas5_home),60185(nas5_usrdata)
```

`hpcuser` (gid 500) is the group every partition requires via `AllowGroups=hpcuser`. We have it,
so **group membership is never the thing blocking a submission** — QOS is (§3).

### Filesystems

| Path | What | Shared across nodes? |
|---|---|---|
| `/home/vineethb` | home, scripts, job logs (`~/job_outs`) | **Yes** |
| `/data/user_data/vineethb` | datasets, runs, checkpoints, conda envs | **Yes** |
| `/tmp` on a compute node | scratch | **No — node-local** |

This matters directly for preemption: a requeued job lands on a **different node**, so anything it
needs to resume from must be on shared storage. The v3 pipeline script checks this explicitly and
warns if the dataset filesystem is not one of `nfs*|lustre|gpfs|beegfs|panfs`.

---

## 3. What we can use, and why only preempt

### The partition table

The cluster has 33 partitions. Three are general-access; the rest are lab-private. What matters
for us:

| Partition | Accepts QOS | Nodes / GPUs | Walltime (dflt / max) | `PriorityTier` | Preemptible |
|---|---|---|---|---|---|
| **`preempt`** *(cluster default)* | `preempt_qos`, `preempt_cpu_qos` | **128 nodes, 980 GPUs** | 30 min / **31 days** | **1** (lowest) | **Yes** |
| `general` | `normal` — ✗ we lack it | 66 nodes, 522 GPUs | 6 h / 2 days | 4 | No |
| ~28 lab partitions | their own lab QOS | 1–7 nodes each | varies | 5 | No |

`preempt` is the largest partition on the cluster by a wide margin — it overlaps almost every
node, including the lab-private ones. That is the whole point: idle lab hardware is lent out as
preemptible capacity and reclaimed the instant its owner wants it.

### Why we cannot use `general`

**We are missing the `normal` QOS, and `normal` is the only QOS `general` accepts.**

```
$ scontrol show partition general
PartitionName=general
   AllowGroups=hpcuser AllowAccounts=ALL AllowQos=normal
   ...

$ sacctmgr -s show user vineethb format=User,Account,QOS,DefaultQOS
User     |Account |QOS                                                        |Def QOS
vineethb |msimchow|maxlab_cpu_qos,maxlab_qos,preempt_cpu_qos,preempt_qos      |preempt_qos
```

Confirmed by dry run — this is a hard association rejection, not a queueing problem:

```
$ sbatch --test-only -p general -q normal -A msimchow --gres=gpu:1 -t 1:00:00 --wrap=hostname
allocation failure: Invalid qos specification

$ sbatch --test-only -p general -A msimchow --gres=gpu:1 -t 1:00:00 --wrap=hostname
allocation failure: Invalid qos specification
```

`general` has `AllowAccounts=ALL` and `AllowGroups=hpcuser`, both of which we satisfy. The QOS
list is the only blocker.

The accounting transaction log shows this was a **provisioning choice at account-creation time**,
not a limit we tripped:

```
$ sacctmgr show transaction where accounts=msimchow format=Time,Action,Actor,Where,Info
2026-08-28T14:13:11|Add Associations|root|id_assoc=1352| acct='msimchow', user='vineethb',
    lineage='/mld/msimchow/0-vineethb/', def_qos_id=2, qos=',63,41,71,2,'
```

QOS IDs (`sacctmgr show qos format=ID,Name`): `2=preempt_qos`, `41=maxlab_qos`,
`63=maxlab_cpu_qos`, `71=preempt_cpu_qos`. **ID `1` (`normal`) is absent.**

By contrast `ndelara`, added to the same account on 2026-09-03, got `qos=',63,41,1,71,2,42,'` —
including `1`. Two other msimchow members (`awu5`, `ataracha`) are in the same position as us.

See [Addendum B](#addendum-b--restoring-general-access) for the fix.

---

## 4. Our limits: what we can actually request

### QOS limits

```
$ sacctmgr show qos where name=preempt_qos,preempt_cpu_qos \
    format=Name,Priority,Preempt,GraceTime,MaxTRESPU,MaxJobsPU,MaxSubmitPU,MaxTRES,MinTRES,UsageFactor,Flags
```

| | `preempt_qos` | `preempt_cpu_qos` |
|---|---|---|
| Use for | any GPU job | CPU-only jobs |
| Priority | 1000 | 100 |
| **GPUs per user** | **24** | **0** (GPUs forbidden) |
| **Max CPUs per job** | **256** | **32** |
| **Max CPUs per user** | — | **64** |
| **Minimum per job** | **≥ 1 GPU** | — |
| Running jobs / user | **24** | 20 |
| Submitted jobs / user | **100** | 50 |
| `MaxWall` | none (partition caps at 31 days) | none |
| GraceTime on preemption | 2 min | 2 min |
| Fairshare `UsageFactor` | 1.0 | **1.5** |
| Flags | — | `OverPartQOS` |
| Preempts | `preempt_cpu_qos` | nothing |

**No association-level caps at all.** Every per-user override is empty:

```
$ scontrol show assoc_mgr users=vineethb flags=assoc
ClusterName=babel Account=msimchow UserName=vineethb(6010497) Partition= Priority=0 ID=1352
    SharesRaw/Norm/Level/Factor=1/0.02/55/0.07
    UsageRaw/Norm/Efctv=9864948.16/0.00/0.00
    ParentAccount= Lineage=/mld/msimchow/0-vineethb/ DefAssoc=Yes
    MaxJobs= MaxJobsAccrue= MaxSubmitJobs= MaxWallPJ=
    MaxTRESPJ=
    MaxTRESPN=
    MaxTRESMinsPJ=
```

So the QOS table above is the complete set of limits.

### Partition defaults that apply to every job

```
$ scontrol show partition preempt
   DefaultTime=00:30:00   MaxTime=31-00:00:00
   JobDefaults=DefCpuPerGPU=4,DefMemPerGPU=32000
   DefMemPerCPU=1000      MaxMemPerNode=UNLIMITED
   TRESBillingWeights=CPU=1.0,Mem=0.25G,Energy=0,GRES/gpu=16.0
```

- **`DefaultTime=30 minutes`.** Forgetting `--time` gets a 30-minute job. Always pass it.
- **`DefCpuPerGPU=4`, `DefMemPerGPU=32000`.** Asking for `--gres=gpu:1` and nothing else yields
  4 CPUs and 32 GB — which is exactly what our interactive jobs allocate
  (`billing=27,cpu=4,gres/gpu=1,mem=32000M`).

### Three limits that bite

**1. `MinTRES=gres/gpu=1` — a 0-GPU job on `preempt_qos` is unschedulable.**
It is not merely wasteful; it pends on `Reason=QOSMinGRES` **forever**. Observed on JobID
10474520. For genuinely CPU-only work, use `preempt_cpu_qos` (which forbids GPUs and caps you at
32 CPUs/job).

**2. Billing weight — `preempt` charges 2× for GPUs.**
`GRES/gpu=16.0` on `preempt` versus `8.0` on every other partition. Fairshare usage is computed
from the `billing` TRES, so **every GPU-hour on `preempt` costs double the fairshare of the same
hour anywhere else**, and `preempt_cpu_qos` layers a further 1.5× `UsageFactor` on top. We pay a
premium for the privilege of being preempted.

**3. `--test-only` does not evaluate every limit.**
It catches configuration rejections (a bad QOS, an impossible node spec) but **not** limits that
produce a PENDING reason rather than a rejection. Both of these pass `--test-only` and then sit
pending forever / partially:

```
$ sbatch --test-only -p preempt -q preempt_qos -n 1 -t 1:00:00 --wrap=hostname
sbatch: Job 10479998 to start at 2026-09-27T07:37:11 ...   # but MinTRES → QOSMinGRES pending

$ sbatch --test-only -p preempt -q preempt_qos --gres=gpu:8 -N4 -t 1:00:00 --wrap=hostname
sbatch: Job 10479996 to start ... on 4 nodes ...           # 32 GPUs > our 24 → QOSMaxGRESPerUser
```

Treat `--test-only` as a syntax and permissions check, not a quota check.

### Current fairshare

```
$ sshare -U -l
Account    User      RawShares  NormShares  RawUsage  NormUsage  EffectvUsage  FairShare  LevelFS
msimchow   vineethb          1    0.018182   9868339   0.000355      0.004235   0.068548  4.293474
```

`PriorityDecayHalfLife = 7 days`, `PriorityUsageResetPeriod = NONE`,
`FairShareDampeningFactor = 3`. Usage decays with a one-week half-life; there is no hard reset.

---

## 5. GPUs available on preempt

980 GPUs across 128 nodes. Every node is 8 GPUs unless noted.

```
$ sinfo -p preempt -h -N -o "%N %G" | sort -u | awk '{split($2,a,":"); ...}'
```

| GRES type | Nodes | **GPUs** | VRAM | Interconnect | Notes |
|---|---:|---:|---|---|---|
| `L40S` | 51 | **410** | 48 GB | — | The bulk of the partition — most likely draw |
| `A6000` | 29 | **208** | 48 GB | `nvlink` | Second most common; some 4- and 10-GPU nodes |
| `RTX_PRO_6000` | 18 | **144** | **96 GB** | — | Blackwell. **Fastest**, and the most VRAM per card |
| `6000Ada` | 7 | 58 | 48 GB | — | 6-, 8- and 10-GPU nodes |
| `L40` | 7 | 56 | 48 GB | — | |
| `A100_80GB` | 6 | 48 | 80 GB | `nvlink` | |
| `H100` | 3 | 24 | 80 GB | `nvlink` | Scarce — longest queue wait of any type |
| `A100_40GB` | 3 | 24 | 40 GB | `nvlink` | |
| `H200` | 1 | 4 | **141 GB** | — | Single node, 4 GPUs |
| `A100_80G` | 1 | 4 | 80 GB | — | Note the spelling: **no trailing `B`** |

Node features also include `avx512f` on most nodes and `nvlink` on the A6000/A100/H100 fleet.

### GPU model is the single biggest factor in runtime

Measured in our own training runs at `microbatch_size=42`:

| GPU | ms / step | Relative |
|---|---:|---:|
| RTX PRO 6000 | ~417 ms | **1.0×** |
| A6000 | ~1163 ms | **2.8× slower** |

An untyped `--gres=gpu:1` is a lottery. What we have actually drawn across our interactive jobs
since 2026-09-01:

```
$ sacct -u vineethb -S 2026-09-01 -X -P -n -o JobName,AllocTRES | grep ^interactive_setup \
    | grep -oP "gres/gpu:[a-z0-9_]+" | sort | uniq -c | sort -rn
     15 gres/gpu:a6000
      8 gres/gpu:l40s
      2 gres/gpu:a100_80gb
      2 gres/gpu:a100_40gb
      1 gres/gpu:rtx_pro_6000
      1 gres/gpu:l40
```

15 of 29 draws were the slowest card in the fleet, and exactly one was the fastest.

### Requesting a specific GPU

Two mechanisms, both verified by dry run:

**By GRES type** — `--gres=gpu:<TYPE>:<count>`. **The type name is case-sensitive and must match
the node's registered GRES string exactly:**

```bash
--gres=gpu:L40S:1           # ✓
--gres=gpu:RTX_PRO_6000:1   # ✓
--gres=gpu:A6000:2          # ✓
--gres=gpu:6000Ada:1        # ✓
--gres=gpu:a6000:2          # ✗ allocation failure: Requested node configuration is not available
```

Valid strings, verbatim from `sinfo -p preempt -h -N -o "%G" | sort -u`:

```
6000Ada   A100_40GB   A100_80G   A100_80GB   A6000   H100   H200   L40   L40S   RTX_PRO_6000
```

**By feature constraint** — `-C` / `--constraint`, which is more forgiving when several models
would do:

```bash
-C VRAM_80GB                # A100_80GB or H100
-C VRAM_96GB                # RTX_PRO_6000 only
-C "VRAM_80GB|VRAM_96GB"    # either
-C nvlink                   # A6000 / A100 / H100 fleet
```

Available features: `VRAM_40GB`, `VRAM_48GB`, `VRAM_80GB`, `VRAM_96GB`, `VRAM_141GB`, `nvlink`,
`avx512f`, plus a feature per GPU model name.

**The trade-off.** Constraining narrows the node pool, which raises queue wait *and* raises
preemption exposure — a smaller pool means fewer places to land on requeue. Our current scripts
deliberately leave `--gres=gpu:N` untyped and record what they got instead. For a long run where
a 2.8× speed difference dominates, `-C VRAM_96GB` is usually worth the wait; for short jobs it is
not.

---

## 6. How we submit jobs

Two working paths.

### 6.1 Interactive allocation — `~/scripts/interactive_job.sh`

```bash
~/scripts/interactive_job.sh [-g GPUS] [-c CPUS] [-t TIME] [-n NAME]
# defaults: 1 GPU, 4 CPUs, 04:00:00, name "interactive_setup"
```

It submits a batch job whose entire payload is a header dump plus `sleep infinity`:

```bash
#SBATCH --partition=preempt
#SBATCH --qos=preempt_qos
#SBATCH --gres=gpu:${GPUS}
#SBATCH --cpus-per-task=${CPUS}
#SBATCH --time=${TIME}
#SBATCH --job-name=${JOB_NAME}
#SBATCH --output=${HOME}/job_outs/%j_${JOB_NAME}.out
...
sleep infinity
```

Then attach a shell to the running allocation:

```bash
squeue -u $USER                                  # find the JobID and node
srun --jobid=<JOBID> --overlap --pty bash        # get a shell inside it
```

`--overlap` is what lets a second step share resources already allocated to the job step; without
it the `srun` blocks waiting for resources the job itself is holding.

**Properties to know:**

- **It has no `--requeue` and no `--signal`.** A preempted interactive allocation is simply
  **gone** — it does not come back, and the shell dies with it. This is the single biggest
  difference from the training path (§6.2).
- **It holds a GPU to do nothing.** One of our 24, for the duration, just to own a shell. That is
  forced by `MinTRES=gres/gpu=1` on `preempt_qos` — a 0-GPU allocation would never schedule.
- **The 4-hour default is the dominant failure mode in our history.** 12 of our jobs since
  2026-09-09 ended `TIMEOUT`, almost all `interactive_setup` hitting exactly `04:00:00`. The
  partition allows 31 days; `-t 24:00:00` would remove most of this churn at no extra cost.
- **Anything started inside it dies with it.** A process cannot outlive its job step. This is
  precisely why real work belongs in §6.2, not in an interactive shell.

### 6.2 Single-GPU training job — `~/scripts/submit_naivepoker_1gpu.sh`

This is the preemption-safe pattern, and the one worth copying for any long run.

```bash
~/scripts/submit_naivepoker_1gpu.sh [-c CONFIG] [-t TIME] [-n NAME] [-p CPUS] [-d]
# defaults: 12h walltime, 4 CPUs, 1 GPU
```

*(`submit_naivepoker_4gpu.sh` is machine-generated from this file by `gen_submit_4gpu.py`, and
`submit_naivepoker_v3_pipeline.sh` is modelled on it step for step. Same pattern throughout.)*

**The four directives that make it survive preemption:**

```bash
#SBATCH --partition=preempt
#SBATCH --qos=preempt_qos
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=${CPUS}
#SBATCH --time=${TIME}
#SBATCH --output=${HOME}/job_outs/%j_${JOB_NAME}.out
#SBATCH --open-mode=append     # one .out across every attempt
#SBATCH --requeue              # opt into automatic restart
#SBATCH --signal=B:USR1@120    # B: = signal the batch shell, not the job step
```

**The five mechanisms inside it:**

**(a) Self-requeue to chain past the walltime.**
A USR1 trap calls `scontrol requeue` on the job itself, so hitting `--time` returns the job to
PENDING instead of ending `TIMEOUT`. That is how a 12-hour allocation runs a multi-day job:

```bash
on_time_limit_warning() {
    log "*** caught USR1 (approaching --time=${TIME} limit) ***"
    scontrol requeue "$SLURM_JOB_ID"
}
trap on_time_limit_warning USR1
trap on_term TERM
```

**(b) Background the child, then `wait` — and re-`wait`.**
`set -uo pipefail` deliberately *without* `-e`, plus:

```bash
"${PY}" train.py --config "$CONFIG" $WANDB_OVERRIDE &
TRAIN_PID=$!
wait $TRAIN_PID; STATUS=$?
while [ $STATUS -gt 128 ] && kill -0 $TRAIN_PID 2>/dev/null; do
    log "wait returned $STATUS (trapped signal) but PID $TRAIN_PID is alive -- resuming wait"
    wait $TRAIN_PID; STATUS=$?
done
```

`wait` returns `128+N` the instant a **trapped** signal is delivered, even though the child is
still alive. Without the re-wait loop the script falls through to teardown mid-training. This
fires in practice — from a real log: `wait returned 138 (trapped signal) but PID 647642 is alive`.

**(c) Checkpoint-bounded loss plus `runtime.resume: auto`.**
`train.py` has **no SIGTERM handler**, so a preemption discards everything since the last
checkpoint. `checkpoint_interval` is therefore the knob that bounds the damage — the 1-GPU config
uses 4% of total steps (1071 steps: ~20 min on an A6000, ~7 min on an RTX PRO 6000). On restart,
`resume: auto` finds the newest checksum-valid checkpoint and restores model, optimizer,
scheduler, per-rank RNG and data-loader cursor.

**(d) Checkpoint triage before launching.**
A preemption can kill the job at any point inside `save_checkpoint`, which writes in three steps
(atomic-replace the `.pt`, then its `.sha256.json` receipt, then `latest.json`). STEP 5
classifies the debris into three kinds that need **opposite** responses:

| Kind | What it is | Action |
|---|---|---|
| `TMP` | `.pt.tmp-<uuid>` from a save killed mid-write; the cleanup `finally:` is skipped by SIGKILL, so it leaks ~255 MB permanently | **Always delete** |
| `ORPHAN` | a `.pt` whose `.sha256.json` receipt never got written; every read path goes through `_read_validated()`, so it is permanently unusable | **Always delete** |
| `CORRUPT` | a `.pt` *with* a receipt that **fails** its checksum — real bit-rot or a truncated NFS write | **Never auto-delete**; exit 1 for inspection |

The probe's last act is to print a `PROBE_OK` sentinel, and its **absence is treated as "refuse to
classify"** rather than "nothing here" — specifically so an NFS stall on `/data/user_data` cannot
trigger an `rm -rf` of an output_dir holding every checkpoint of a multi-day run. Absence of
evidence is not evidence of absence.

**(e) Honest exit status.**
The script propagates the child's real exit code rather than exiting 0, so `sacct` shows `FAILED`
for a genuine crash instead of `COMPLETED 0:0`, and any `--dependency=afterok:` chain behaves
correctly. A *requeued* job returns to PENDING (non-terminal), so a dependency is simply not
evaluated yet and the follow-on survives its parent's preemption for free.

There is also a **W&B preflight** (STEP 6) worth keeping in any copy of this script: with
credentials present but the API unreachable, `wandb.init(mode='online')` blocks **indefinitely**
(measured still blocked after 300 s; `WANDB_INIT_TIMEOUT` does not bound it and `WANDB_MODE` does
not override an explicit `mode='online'` kwarg). Unmitigated, that burns an entire allocation
having trained zero steps, then requeues and repeats forever. The script probes reachability with
a hard 20-second bound and falls back to `--wandb-mode offline`.

### 6.3 Submission checklist

```bash
#SBATCH --partition=preempt
#SBATCH --qos=preempt_qos      # or preempt_cpu_qos for CPU-only
#SBATCH --gres=gpu:1           # ≥1 is mandatory on preempt_qos
#SBATCH --time=12:00:00        # NEVER omit — the default is 30 minutes
#SBATCH --requeue              # opt into restart-on-preemption
#SBATCH --open-mode=append     # keep one log across attempts
#SBATCH --signal=B:USR1@120    # get a warning before the walltime
```

Plus, in the payload: resume from checkpoints on shared storage, background children and `wait`,
and make every stage idempotent so a restart from the top is cheap.

---

## 7. How preemption works

### Cluster configuration

```
$ scontrol show config
PreemptType             = preempt/qos
PreemptMode             = REQUEUE          # and PreemptMode=REQUEUE on every partition
PreemptParameters       = youngest_first,send_user_signal
PreemptExemptTime       = 00:00:00
KillWait                = 120 sec
JobRequeue              = 1
MaxBatchRequeue         = 5
MinJobAge               = 300 sec
SchedulerType           = sched/backfill   SchedulerParameters = bf_continue
SelectType              = select/cons_tres SelectTypeParameters = CR_CORE_MEMORY,CR_PACK_NODES
AccountingStorageEnforce = associations,limits,qos
EnforcePartLimits       = NO
```

### The mechanism, step by step

1. **Everyone can preempt us.** Every lab QOS (priority 20000), `normal` (10000) and the `katef_*`
   family list `preempt_cpu_qos,preempt_qos` in their `Preempt=` field. `preempt_qos` in turn
   preempts `preempt_cpu_qos`. We sit at the bottom but one of the entire cluster.
2. **`youngest_first`** — among preemptable candidates, the most recently **started** job is
   killed first. A job that has just restarted is the first target for the next preemption.
3. **`send_user_signal`** — SLURM delivers our `--signal=B:USR1@120` signal at the **start of the
   grace window**, not only before the walltime. (See §9a — our script misreads this.)
4. **2-minute `GraceTime`** (from the QOS) → SIGTERM → SIGKILL.
5. **Requeue to PENDING under the same JobID**, with `SLURM_RESTART_COUNT` incremented. Because
   `--open-mode=append` is set, the new attempt appends to the same `.out` file.

### Verified end to end — job 10475844, 2026-09-17

```
$ sacct -j 10475844 -D -X -o JobID,JobName,State,Start,End,Elapsed,NodeList
10475844 naivepoker_v3_pipeline REQUEUED  05:42:43→05:43:34  00:00:51  babel-u5-28
10475844 naivepoker_v3_pipeline PREEMPTED 05:46:16→07:31:10  01:44:54  babel-v9-24
10475844 naivepoker_v3_pipeline PREEMPTED 07:33:54→07:36:58  00:03:04  babel-q5-24
10475844 naivepoker_v3_pipeline REQUEUED  07:39:28→08:17:28  00:38:00  babel-p5-32
10475844 naivepoker_v3_pipeline PREEMPTED 08:21:52→09:02:58  00:41:06  babel-w9-26
10475844 naivepoker_v3_pipeline COMPLETED 09:05:19→09:46:46  00:41:27  babel-x9-24
```

**Six allocations, five different nodes, one JobID, finished successfully.** Requeue turnaround
was **2–5 minutes** each time. `SLURM_RESTART_COUNT` reached 5.

Note the shape of it: allocations of 1 h 45 m, 3 min, 38 min, 41 min, 41 min. **Preemption is
bursty and unpredictable** — a 3-minute allocation is a real occurrence, which is why work that
cannot checkpoint more often than every ~20 minutes will struggle here.

### There is no requeue cap in practice

`slurm.conf` sets `MaxBatchRequeue=5`, which `man 5 slurm.conf` defines as:

> Maximum number of times a batch job may be automatically requeued before being marked as
> JobHeldAdmin. (Mainly useful when the SchedulerParameters option `nohold_on_prolog_fail` is
> enabled.) The default value is 5.

Empirically it does **not** gate preemption requeues. Sampling every live job on the cluster:

```
$ scontrol show job -a -o | grep -oP "QOS=\S+.*?Restarts=[0-9]+" | ...
QOS=preempt_qos      Restarts=95
QOS=preempt_qos      Restarts=51
QOS=preempt_qos      Restarts=37
QOS=preempt_qos      Restarts=35
QOS=preempt_cpu_qos  Restarts=22
```

No job on the cluster is currently in `JobHeldAdmin`. A well-behaved requeueing job can restart
indefinitely.

### What preemption does *not* cover

`--requeue` handles preemption and node failure. It does **not** handle a genuine crash: a
non-signal nonzero exit is recorded `FAILED` and the job **stops**. Recovery is manual (§9c).

---

## 8. Priority: why we wait

`PriorityType = priority/multifactor`:

```
PriorityWeightAge       = 1000        PriorityWeightAssoc     = 500
PriorityWeightFairShare = 5000        PriorityWeightJobSize   = 500
PriorityWeightPartition = 10000       PriorityWeightQOS       = 1000
PriorityWeightTRES      = CPU=1000,Mem=500,GRES/gpu=1000
PriorityFavorSmall      = yes         PriorityMaxAge          = 12-00:00:00
PriorityCalcPeriod      = 00:05:00    PriorityDecayHalfLife   = 7-00:00:00
```

A representative pending job of ours scores **2876**:

```
$ sprio -j 10479795 -l
JOBID     PARTITION  USER      ACCOUNT   PRIORITY  AGE  ASSOC  FAIRSHARE  JOBSIZE  PARTITION  QOS  TRES
10479795  preempt    vineethb  msimchow      2876    1      0        342      498       2000   33     2
```

Fairshare contributes 342 of a possible 5000; QOS contributes 33 of 1000.

**The real constraint is not the score.** `preempt` has `PriorityTier=1`, against `general`'s 4
and every lab partition's 5. **`PriorityTier` is a hard ordering, not a weight** — tier-1 jobs are
only considered after every higher-tier job has been scheduled. No amount of fairshare recovery
or job-shaping changes that while we are confined to `preempt`. It is why the answer to "why am I
waiting" is structural, and why [Addendum B](#addendum-b--restoring-general-access) is the highest-
leverage change available.

**What *does* help within `preempt`:**

- **Shorter walltime requests backfill better.** `sched/backfill` will start a short job in a gap
  ahead of a higher-priority long job. A 4-hour request finds gaps a 31-day request never will.
- **Smaller jobs win twice** — `PriorityFavorSmall=yes`, and a 1-GPU job has vastly more
  candidate nodes than an 8-GPU one.
- **Age accrues to a 12-day cap**, so leaving a job queued is not wasted.
- **Don't over-constrain GPU type** unless the speed difference justifies it (§5).

---

## 9. Known bugs and gaps

### (a) The USR1 handler mislabels preemption as the walltime

Because `PreemptParameters=send_user_signal`, USR1 arrives on **preemption** too — not just 120 s
before `--time`. From job 10475844's log:

```
[2026-09-17 05:42:48] [+0s]  ===================== STEP 0: JOB STARTED =====================
[2026-09-17 05:43:34] [+46s] *** caught USR1 (approaching --time=06:08:00) ***
[2026-09-17 05:43:34] [+46s] requesting SLURM requeue of job 10475844
[2026-09-17 05:43:34] [+46s] NOT exiting: the current child keeps running for the remaining ~120s
[2026-09-17T05:43:34.835] error: *** JOB 10475844 ON babel-u5-28 CANCELLED AT 05:43:34 DUE TO JOB REQUEUE ***
```

**46 seconds into a 6 h 08 m allocation** — that was not the walltime. Two consequences:

1. `sacct` records **REQUEUED instead of PREEMPTED**, which hides our true preemption rate.
2. The handler's comment *"NOT exiting: the current child keeps running for the remaining ~120s
   and may still commit another shard or checkpoint"* is **false on this path** — the self-requeue
   killed the step **0.8 seconds later**, discarding the entire 2-minute grace window that could
   have reached a checkpoint boundary.

**Fix:** distinguish the two causes inside the handler, e.g. check remaining walltime with
`squeue -h -j "$SLURM_JOB_ID" -o %L`. If plenty of time remains it is a preemption: log it as such
and **fall through**, letting SLURM requeue after the grace period so the child gets its full two
minutes to checkpoint.

### (b) The TERM trap produces no evidence

On the genuinely `PREEMPTED` segments (ending 07:31:10, 07:36:58, 09:02:58) neither
`caught SIGTERM` nor `caught USR1` appears anywhere in the log. The likeliest cause is the
`exec > >(while IFS= read -r line; ...)` timestamping subshell being torn down before it flushes.

**This was not proven.** But the diagnostic trap is currently producing nothing at exactly the
moment it matters most. Worth testing by writing directly to a separate unbuffered file descriptor
inside `on_term`.

### (c) Nothing recovers from a genuine failure

With the monitor and session scripts out of scope, there is **no automation left** that resubmits
a job SLURM has given up on. The coverage is:

| Failure | Handled? | By what |
|---|---|---|
| Preemption | ✅ | `--requeue` + `resume: auto` |
| Node failure | ✅ | `--requeue` |
| Walltime reached | ✅ | USR1 trap → `scontrol requeue` |
| **Genuine crash (nonzero exit)** | ❌ | Nothing — job ends `FAILED`, needs manual resubmit |
| **Interactive allocation preempted** | ❌ | Nothing — the shell is gone (§6.1) |
| **Interactive allocation times out** | ❌ | Nothing — 12 `TIMEOUT` states in our history |

The batch path is genuinely robust against preemption, which is the common case. It is **not**
unattended: a crash at hour 3 of a multi-day run sits idle until someone looks. Checking
`squeue -u $USER` and `sacct -u $USER -S today` on a routine is currently a manual habit, not a
system.

### (d) GPU type is left to chance

Untyped `--gres=gpu:1` drew the slowest card in the fleet on 15 of 29 interactive allocations and
the fastest on 1 (§5). For anything long-running, `-C VRAM_96GB` or `--gres=gpu:RTX_PRO_6000:1`
is likely worth the extra queue time — roughly a 2.8× difference in wall-clock.

### (e) Interactive defaults cause avoidable churn

The 4-hour default against a 31-day partition cap is the direct cause of most of our `TIMEOUT`
records. `-t 24:00:00` costs nothing extra and removes most of the restart cycle.

---

## 10. Command cookbook

### Connect and orient

```bash
ssh babel                                  # → a login node
id                                         # group membership (need hpcuser)
sinfo -s                                   # partition summary
sinfo -p preempt -N -o "%N %G %t %C %m"    # node-by-node GPU/state/CPU/mem
```

### What am I allowed to do?

```bash
sacctmgr -s show user vineethb format=User,Account,QOS,DefaultQOS
sacctmgr show qos where name=preempt_qos,preempt_cpu_qos \
    format=Name,Priority,Preempt,GraceTime,MaxTRESPU,MaxJobsPU,MaxSubmitPU,MaxTRES,MinTRES,UsageFactor
scontrol show partition preempt
scontrol show assoc_mgr users=vineethb flags=assoc    # live limits + usage
sshare -U -l                                          # fairshare standing
```

### Submit and attach

```bash
~/scripts/interactive_job.sh -g 1 -c 4 -t 24:00:00     # interactive allocation
squeue -u $USER
srun --jobid=<JOBID> --overlap --pty bash              # shell inside it

~/scripts/submit_naivepoker_1gpu.sh -t 12:00:00        # preemption-safe training job
```

### Watch a job

```bash
squeue -u $USER -o "%.10i %.12P %.28j %.9T %.11M %.11L %.4D %.22R %.14b %.13q %.7r"
scontrol show job <JOBID>                              # full detail incl. Restarts, Reason
sprio -j <JOBID> -l                                    # priority breakdown
tail -f ~/job_outs/<JOBID>_<name>.out                  # live log (appends across requeues)
```

### After the fact

```bash
sacct -j <JOBID> -D -X -o JobID,JobName,State,ExitCode,Start,End,Elapsed,NodeList
    # -D shows EVERY allocation of a requeued job, one row per attempt — this is how
    #    you see the preemption history. Without -D you see only the final row.

sacct -u $USER -S 2026-09-01 -X -o JobID,JobName%28,Partition,QOS,AllocTRES%50,\
Elapsed,Timelimit,State%22,ExitCode,Start,End -P

sacct -u $USER -S today -X -P -o State | sort | uniq -c    # today's outcome histogram
```

### Dry-run before committing

```bash
sbatch --test-only -p preempt -q preempt_qos --gres=gpu:1 -t 12:00:00 --wrap=hostname
# Catches: bad QOS, impossible node spec, bad GRES type name.
# Does NOT catch: MinTRES, MaxTRESPU — those pend rather than reject (§4).
```

### Cancel

```bash
scancel <JOBID>
scancel -u $USER -n interactive_setup      # all jobs with a given name
scancel -u $USER -t PENDING                # just the queue, leave running work alone
```

---

## Addendum A — `maxlab` / `maxlab-cpu` (not available to us in practice)

Recorded for completeness. **We cannot use these presently; `preempt` is all we have.**

Our association does carry `maxlab_qos` and `maxlab_cpu_qos`, and dry runs pass SLURM's
validation:

```
$ sbatch --test-only -p maxlab -q maxlab_qos -A msimchow --gres=gpu:1 -t 1:00:00 --wrap=hostname
sbatch: Job 10479876 to start at 2026-09-19T23:38:23 using 4 processors on babel-m9-16 in partition maxlab

$ sbatch --test-only -p maxlab-cpu -q maxlab_cpu_qos -n 8 -t 1:00:00 --wrap=hostname
sbatch: Job 10479880 to start at 2026-09-17T15:38:23 using 8 processors on babel-m9-[16,20,28]
```

So the block is **not** a SLURM association restriction — it is a practical or policy constraint
outside what the scheduler records. The technical details, if that ever changes:

| | `maxlab` | `maxlab-cpu` |
|---|---|---|
| Nodes | `babel-m9-[16,20,28]` | same 3 nodes |
| Hardware | 24× RTX PRO 6000, 96 GB VRAM, 704 CPUs | 704 CPUs, no GPU |
| Walltime (dflt / max) | 8 h / 3 days | 3 h / 6 h |
| QOS priority | 20000 | 20000 |
| GPUs per user | 16 | 0 |
| Max CPUs per job | 512 | 128 |
| Jobs (running / submitted) | 10 / 50 | 10 / 50 |
| `PriorityTier` | 5 | 5 |
| Preemptible | **No** | **No** |
| GPU billing weight | 8.0 (half of `preempt`'s 16.0) | 1.0 |

It is also heavily contended — at time of analysis all 24 GPUs were allocated to `yifeizh3`,
`naichieh`, `ndelara`, `pchellap` and `siqiaoh`, with a long pending queue, which is why the dry
run estimated a two-day wait.

---

## Addendum B — restoring `general` access

The single highest-leverage change available. `general` is 66 nodes / 522 GPUs at
`PriorityTier=4` and **is not preemptible** — it would move us out of tier 1 entirely (§8).

The blocker is one missing QOS on our association (§3). The fix is one command from an admin:

```
sacctmgr modify user vineethb set qos+=normal
```

Supporting evidence to include in the request (`#babel-babble` Slack):

- `sacctmgr -s show user vineethb` → QOS list has no `normal`
- `sbatch --test-only -p general -q normal ...` → `allocation failure: Invalid qos specification`
- `sacctmgr show transaction where accounts=msimchow` → our association was created
  2026-08-28 with `qos=',63,41,71,2,'`, while `ndelara` (same account, 2026-09-03) got
  `qos=',63,41,1,71,2,42,'` including `1` (`normal`). `awu5` and `ataracha` have the same gap.

`normal`'s limits, for reference: priority 10000, 8 GPUs/user, 128 CPUs/job, `MinTRES=gres/gpu=1`,
10 running / 50 submitted jobs, 2-day partition walltime cap. Note that our `preempt_qos` GPU
quota (24) is **higher** than `normal`'s (8) — the trade is fewer GPUs and a shorter walltime in
exchange for not being preempted and for a hard scheduling-tier advantage.
