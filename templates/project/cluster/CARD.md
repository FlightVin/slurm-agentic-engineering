# Babel cluster card
Everything you need in normal operation. Full reference: `cluster/BABEL.md` (850+ lines —
grep it, never load it). Facts verified 2026-09/10; re-check quotas with `ae doctor`, which
prints Slurm's live QOS values next to `config.sh`.

## Two pools — choose per experiment with `#EXP part=preempt|general|auto`
| | `preempt` (default) | `general` |
|---|---|---|
| GPU QOS | `preempt_qos` | `normal` |
| CPU-only QOS | `preempt_cpu_qos` (0 GPUs, 32 CPU/job, 64 total, 20 running / 50 submitted, separate quota) | — impossible |
| GPUs per user | **24** | **8** |
| CPUs per job | 256 | 128 |
| Running / submitted | 24 / 100 | 10 / 50 |
| Max walltime | **31 days** | **2 days** |
| Priority / tier | 1 000 / **1** (lowest) | 10 000 / **4** |
| **Preemptible** | yes, by everyone | **NO** (verified: no QOS lists `normal` as preemptable) |
| GPU billing weight | 16.0 (fairshare costs 2×) | **8.0** |
| Default walltime | **30 minutes** — never omit `-t` (`ae` defaults to `AE_DEFAULT_TIME`) | |

`maxlab_qos` / `maxlab_cpu_qos` may show up as held and pass a dry run, but they are **not usable
in practice** (`BABEL.md` Addendum A). Ignore them.

### Operating strategy
- **Hold standby on both GPU pools and use whichever comes up first** (`ae pool` = cpu + preempt
  + general). Neither pool is reliably faster; measured 2026-09-21 for the same 1-GPU/1-h job,
  general was 11 days sooner — the week before it was the other way round.
- `ae attach --gpu` / `ae tinker <id> --gpu` take the oldest RUNNING GPU standby in either pool;
  `--preempt` / `--gen` force one.
- `part=auto` asks both pools with `sbatch --test-only` and takes the earlier estimate; it forces
  preempt when `time > 2 days`. Estimates are worst-case and can be very wrong (predicted a day,
  started in 60 s): a tie-breaker, not an oracle. Warm standby is the reliable way to start *now*.
- Slurm cannot race one job across both pools (QOSes are partition-specific and `--test-only`
  does not validate the pairing), which is why `ae` asks each pool separately.
- **Long jobs:** develop and smoke-test on general (uninterrupted, half the fairshare), then run
  the full job on preempt with `--requeue`. `ae submit` refuses a > 2-day general job.
- Preempt-safety (`--requeue`, `--signal=B:USR1@120`, the USR1 discriminator, phase skipping)
  is unconditional, on both pools. On general it covers node failure and walltime chaining.

## Traps that have bitten (handled by `ae`)
- **`MinTRES=gres/gpu=1`** on `preempt_qos` *and* `normal`: a 0-GPU job pends on `QOSMinGRES`
  forever. `ae` routes `gpus=0` to `preempt_cpu_qos` whatever `part=` says.
- **GRES type names are case-sensitive**: `gpu:A6000` works, `gpu:a6000` fails. Valid:
  `6000Ada A100_40GB A100_80G A100_80GB A6000 H100 H200 L40 L40S RTX_PRO_6000`.
- **`sbatch --test-only` does not check `MinTRES`/`MaxTRESPU`** — those pend rather than reject.
- **`sacct` drops `Comment`** (`AccountingStoreFlags` unset): the commit sha cannot be recovered
  from Slurm. That is why `state/LEDGER.jsonl` exists.
- **`scp` does not expand `$HOME`** (SFTP); `ssh` does. **`ssh` eats stdin** in `while read`
  loops — use `ssh -n`.
- A held job with reason `launch_failed_requeued_held` pends forever; `ae pool` releases it.

## Preemption
`PreemptType=preempt/qos`, `PreemptMode=REQUEUE`,
`PreemptParameters=youngest_first,send_user_signal`, GraceTime **2 min**.
- **`youngest_first`**: the most recently *started* job dies first — old allocations are safer.
- **`send_user_signal`**: USR1 arrives on preemption, not only near walltime; the preamble tells
  them apart by the time left.
- Requeue keeps the **same JobID**, `SLURM_RESTART_COUNT` +1, usually back on a node in 2–5 min.
  No practical requeue cap (jobs reach 95 restarts). A requeued job is non-terminal, so
  `afterany` dependents correctly sleep through every preemption of their parent.

## Standby latency (measured)
| tier | time to RUNNING | cost |
|---|---|---|
| `preempt_cpu_qos` (CPU) | **~5 s** when the CPU queue is quiet (2026-09); **41 s – 70+ min** on 2026-10-20 with 100+ CPU jobs pending | 0 GPUs, separate quota |
| `preempt_qos` (GPU) | **2.5–3.5 h** typical | 1 of 24 GPUs |
| `normal` (general GPU) | seconds to days — varies hour to hour (1 GPU started at once on 2026-10-20) | 1 of 8 GPUs |

CPU latency depends on how busy `preempt_cpu_qos` is: check `squeue -q preempt_cpu_qos -t PD | wc -l`.
Keep CPU standby **warm** rather than requesting it when needed — that is what hides the wait.

## Storage (verified)
| path | quota | shared between nodes | on the LOGIN node |
|---|---|---|---|
| `/home/<user>` (repo clone, `~/ae/`, `$AE_RESULTS`) | **100 GB** | yes (NFS) | **yes** |
| `/data/user_data/<user>` (datasets, runs, checkpoints) | **500 GB** | yes (NFS) | **NO** |
| `/data/hf_cache`, `/data/datasets` | shared, cluster-wide | yes | no |
| `/tmp` on a node | node-local | no | no |
- The login node cannot read `/data/user_data`: distillates go to `$AE_RESULTS` (under /home) to
  be harvestable, and disk audits of `/data/user_data` must run as a CPU job.
- **Never write checkpoints under `$AE_RUNDIR`** (/home): on 2026-10-01 smoke checkpoints filled
  the 100 GB quota and killed every job at its next write. Large outputs go to `/data/user_data`.

## GPU nodes (dated observations — re-verify; nodes get fixed)
- **RTX PRO 6000 (Blackwell)**: torch 2.7.1+cu128 flex-attention SWA kernels need 124,928 B shared
  memory; the card allows 101,376 B. Exclude these 18 nodes for flex-attention jobs:
  `babel-l5-[16,20,28,32],babel-l9-[16,20,28,32],babel-m9-[16,20,28,32],babel-n9-20,babel-z5-[16,20,28,32],babel-z9-16`.
- **Foreign process on an allocated GPU** (NCCL `Cuda failure 2 'out of memory'` at init, rank N
  "unhandled cuda error"): seen 2026-09-30..10-01 on babel-p9-32, babel-v9-28, babel-p9-16,
  babel-s5-24, babel-o9-32. Fail fast in a precheck when any allocated GPU has > 2 GB in use.
- **babel-m5-32**: 4-GPU job crawled in collectives (2026-10-01). **babel-v9-20**: "CUDA unknown
  error" for every process from 2026-10-09.
- Health-check a fresh standby with `torch.zeros(1).cuda()` before launching an agent on it.
- Pending jobs take `scontrol update JobId=X ExcNodeList=...`; running jobs cannot.

## Connection
`ssh babel` → `login.babel.cs.cmu.edu`. Multiplexing is mandatory: unmultiplexed auth measured
**5–31 s** and highly variable; with `ControlMaster` ~0.9 s (the login-node shell floor at load
~18). A stale master hangs rather than fails — `ae` re-establishes it on every command.
Never run work on the login node. Help: `#babel-babble` Slack.

## Compute-side git
The compute clone may sit on any branch (`ae doctor` often shows `main`). That is not a
mismatch: experiments run in detached worktrees cut from freshly fetched refs.

## Project-specific notes
<!-- Add facts this project has verified about Babel (bad nodes for its workload, data paths,
     measured throughput), each with a date. -->
