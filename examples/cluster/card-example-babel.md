# Babel cluster card
Everything you need in normal operation. Full reference: `cluster/BABEL.md`
(853 lines — grep it, never load it).

## What we can use
| | value |
|---|---|
| Partition | `preempt` — 128 nodes, 980 GPUs, `PriorityTier=1` (lowest) |
| GPU QOS | `preempt_qos` — **24 GPUs/user**, 256 CPU/job, 24 running, 100 submitted |
| CPU QOS | `preempt_cpu_qos` — **0 GPUs**, 32 CPU/job, 64 CPU total, **separate quota** |
| Max walltime | 31 days (no QOS `MaxWall`) |
| Default walltime | **30 minutes** — never omit `-t` |
| `general` partition | **AVAILABLE since 2026-09-21** — `normal` QOS granted. See the two-pool table below. |
| `maxlab*` QOS | `ae doctor` also prints `maxlab_qos`/`maxlab_cpu_qos`. We hold them and they pass a dry run, but they are **not usable in practice** — see `BABEL.md` "Addendum A". Ignore them. |

## Two pools — choose with `#EXP part=preempt|general`
| | `preempt` (default) | `general` |
|---|---|---|
| QOS | `preempt_qos` / `preempt_cpu_qos` | `normal` |
| GPUs per user | **24** | **8** |
| CPUs per job | 256 | 128 |
| Running / submitted | 24 / 100 | 10 / 50 |
| Max walltime | **31 days** | **2 days** |
| Priority / tier | 1 000 / **1** | 10 000 / **4** |
| **Preemptible** | yes, by everyone | **NO** (verified: no QOS lists `normal` as preemptable) |
| GPU billing weight | 16.0 | **8.0** — half the fairshare cost |
| 0-GPU jobs | `preempt_cpu_qos` | **impossible** — `normal` also has `MinTRES=gres/gpu=1` |

### How to use both — the operating strategy
**Hold standby on BOTH pools and use whichever comes up first.** Neither pool is
reliably faster; which one wins varies hour to hour. Measured 2026-09-21 for the
same 1-GPU/1-hour job: general `2026-09-22T08:13`, preempt `2026-10-03T07:05` —
**general 11 days sooner**. The week before it was the other way round. Do not
assume; ask.

```
ae pool                 # cpu + preempt-gpu + general-gpu (default: all three)
ae pool cpu             # just the fast CPU tier
ae pool gpu             # just preempt GPU standby
ae pool gen             # just general (non-preemptible) GPU standby
```

`ae attach --gpu` and `ae tinker <id> --gpu` take the **oldest RUNNING GPU
standby in either pool** — you latch onto whichever won the race and do not care
which. `--preempt` / `--gen` force a specific pool when you need one.

### Choosing a pool per experiment
```
#EXP part=auto        # ask both pools for a start estimate, take the earlier
#EXP part=preempt     # force preemptible pool
#EXP part=general     # force non-preemptible pool
```
`part=auto` runs `sbatch --test-only` against both and picks the earlier ISO
start time. It **forces preempt automatically** when `time > 2 days`, since
general cannot hold the job.

**Caveat, measured:** `--test-only` estimates are worst-case and can be very
wrong. On 2026-09-21 it predicted general would start `2026-09-22T08:13` (a day
out) while an actual 1-GPU general standby submitted a minute later was **RUNNING
in ~60 seconds**. Treat `auto` as a tie-breaker that is better than guessing, not
as a scheduler oracle. If you need something started *now*, the reliable move is
a warm standby in both pools — which is why `ae pool` defaults to all three
tiers.

Slurm cannot race a job across both pools itself: the QOSes are
partition-specific and `--test-only` does **not** validate the pairing (it will
cheerfully report "in partition general" for `-q preempt_qos`). So `ae` asks each
pool separately rather than submitting `-p preempt,general`.

### Long jobs: prototype on general, run on preempt
If a run needs more than general's 2-day wall: **develop and smoke-test it on
general** (uninterrupted, fast feedback, half the fairshare), then submit the
full run to **preempt** with `--requeue`. `ae submit` refuses a >2-day general
job and says exactly this.

### Preempt-safety is unconditional
Every job gets `--requeue`, `--signal=B:USR1@120`, the USR1
preemption-vs-walltime discriminator, `run_child`, and phase skipping —
**on both pools**. On general these cover node failure and walltime chaining
rather than preemption, and cost nothing. Never strip them for a general job.

Quotas are enforced **per pool** by `ae submit`, and `gpus=0` is routed back to
`preempt_cpu_qos` automatically whatever `part=` says.

## Traps that have actually bitten (all handled by `ae`)
- **`MinTRES=gres/gpu=1`** on `preempt_qos`: a 0-GPU job there pends on
  `QOSMinGRES` *forever*. `ae` routes `gpus=0` to `preempt_cpu_qos` automatically.
- **GRES type names are case-sensitive**: `gpu:A6000` works, `gpu:a6000` fails.
  Valid: `6000Ada A100_40GB A100_80G A100_80GB A6000 H100 H200 L40 L40S RTX_PRO_6000`
- **`sbatch --test-only` does not check `MinTRES`/`MaxTRESPU`** — those pend
  rather than reject. It is a syntax check, not a quota check.
- **`sacct` drops `Comment`** (`AccountingStoreFlags` unset) → the commit sha
  cannot be recovered from Slurm. That is why `state/LEDGER.jsonl` exists.
- **`scp` does not expand `$HOME`** (it is SFTP); `ssh` does.
- **`ssh` consumes stdin** — inside a `while read` loop it eats the input. Use `ssh -n`.
- **Preempt billing is 2x**: `GRES/gpu=16.0` vs `8.0` elsewhere. Fairshare is
  computed from billing, so preempt GPU-hours cost double.

## Preemption
`PreemptType=preempt/qos`, `PreemptMode=REQUEUE`,
`PreemptParameters=youngest_first,send_user_signal`, GraceTime **2 min**.
- Everyone can preempt us; we are second-from-bottom.
- **`youngest_first`**: the most recently *started* job dies first, so an old
  allocation is safer than a fresh one.
- **`send_user_signal`**: USR1 arrives on *preemption*, not only near the
  walltime. The preamble tells them apart via remaining time — self-requeueing on
  a preemption would throw away the 2-minute grace window.
- Requeue returns the **same JobID** to PENDING, `SLURM_RESTART_COUNT` +1,
  typically back on a node in 2–5 min. **No practical requeue cap** (jobs on this
  cluster reach 95 restarts; `MaxBatchRequeue=5` governs prolog failures only).
- A requeued job is **non-terminal**, so `afterany` dependents correctly sleep
  through every preemption of their parent.

## Standby scheduling latency (measured)
| tier | time to RUNNING | cost |
|---|---|---|
| `preempt_cpu_qos` (CPU) | **~5 seconds** | 0 GPUs, separate quota |
| `preempt_qos` (GPU) | **2.5–3.5 hours** | 1 of 24 GPUs |

→ CPU standby is the default tinkering substrate. Ask for GPU standby only when
the work genuinely needs a GPU, and expect to wait.

## Filesystems (verified)
| Path | Shared between compute nodes? | Visible on the LOGIN node? |
|---|---|---|
| `/home/<user>` (repo, `~/ae/`, `$AE_RESULTS`) | yes (NFS) | **yes** |
| `/data/user_data/<user>` (datasets, runs, checkpoints) | yes | **NO** |
| `/tmp` on a node | no | no |

The orchestrator runs on the login node, so it **cannot read `/data/user_data`**.
That is why distillates must be written to `$AE_RESULTS` (under `/home`) to be
harvestable, and why cross-experiment artifacts live under `/data/user_data`.

## Compute-side git
The compute clone (`~/projects/wllms`) may sit on any branch — `ae doctor` often
shows `main`. That is **not** a mismatch: experiments run in detached worktrees cut
from freshly fetched refs, so the clone's checked-out branch is irrelevant.

## Connection
Multiplexing is mandatory: unmultiplexed auth measured **5–31 s** and highly
variable. With `ControlMaster`, ~0.9 s (that floor is login-node shell startup at
load ~18, not the connection). A stale master **hangs** rather than fails —
`ae` re-establishes it on every command.

## RTX PRO 6000 (Blackwell) is unusable for v7 training/eval (2026-09-30)
torch 2.7.1+cu128 flex attention: the SWA Triton kernel needs 124,928 B shared memory, the card allows 101,376 B
(v7f-bwtest: test_resume_equals_uninterrupted[swa10] fails; a std resume crashed with a CUDA illegal memory access).
Exclude the 18 RTX_PRO_6000 nodes (`#EXP exclude=babel-l5-[16,20,28,32],babel-l9-[16,20,28,32],babel-m9-[16,20,28,32],babel-n9-20,babel-z5-[16,20,28,32],babel-z9-16`)
for any flex-attention job. Pending jobs can take `scontrol update JobId=X ExcNodeList=...`; running jobs cannot.
The opponent-oracle jobs (no flex attention) run fine there. Node babel-l9-32 also showed "CUDA devices busy/unavailable".
Node **babel-p9-32** (L40S) fails every multi-GPU job at NCCL init on rank 3 ("unhandled cuda error", 3 jobs in 3 min,
2026-09-30 16:20): exclude it too (v7f exps: appended to the Blackwell exclude list).
Node **babel-s5-24** (L40S): a 2-GPU job hung on its FIRST NCCL collective (all-gather, 600 s watchdog, SIGABRT;
2026-09-30 19:50) while both GPUs read 100% busy before model load -> excluded too.
Node **babel-v9-28** (L40S): three 4-GPU jobs in a row failed at DDP init on rank 3 with the babel-p9-32 signature
(NCCL "unhandled cuda error", 2026-09-30 22:30-22:33) -> excluded. (4-GPU jobs ran fine on babel-s9-16 / s9-20.)
**/home quota is 100 GB** and holds `~/ae/run` (job working dirs) + results/logs. 2026-10-01 00:00 it FILLED (200M/50M
smoke checkpoints in $AE_RUNDIR, 70 GB) and killed three eval jobs + a smoke at their next write. Never write
checkpoints under $AE_RUNDIR: smoke/test runs go to $PROJ_DATA (A3 smoke now does); old smoke dirs moved to
$PROJ_DATA/v7f-smoke-archive/.
ROOT CAUSE of the rank-3 "unhandled cuda error" (2026-10-01, NCCL_DEBUG=WARN): `NCCL WARN Cuda failure 2 'out of
memory'` at init -- one of the GPUs Slurm allocated was ALREADY FULL (foreign process outside our cgroup). Nodes seen:
babel-p9-32, babel-v9-28 (4/4), babel-p9-16, likely babel-s5-24 (GPUs 100% busy before model load). All excluded. A3
exps now fail fast in precheck if any allocated GPU has > 2 GB in use (names the node).
Node **babel-m5-32** (L40S): a 4-GPU 200M run crawled (no 271 updates in 37 min; GPU0 216 W, GPUs 1-3 ~100 W spinning
in collectives) -> excluded; the same 4-GPU code runs normally on other nodes.
Node **babel-o9-32**: 4-GPU job, allocated GPU already full at NCCL init (2026-10-01 07:38) -> excluded.
Node **babel-v9-20** (A6000): from 2026-10-09 21:08 every process gets "CUDA unknown error" (nvidia-smi healthy) -> killed a standby and one P2 job; excluded in all v8ws scripts. Health-check a fresh standby with `torch.zeros(1).cuda()` before launching an agent on it.
