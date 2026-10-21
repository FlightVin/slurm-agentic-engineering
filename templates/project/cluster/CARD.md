# Babel cluster card
Everything you need in normal operation. Full reference: `cluster/BABEL.md` (850+ lines —
grep it, never load it). The limits below are the values configured in `config.sh` (recorded
2026-09/10). **They are claims until verified:** the first run verifies them and records the
result in "Verified on this account" below. This card makes no statement about queue wait
times; measure them (agent.md "First run").

## Two pools — choose per experiment with `#EXP part=preempt|general|auto`
| | `preempt` (`AE_PARTITION`) | `general` (`AE_PARTITION_GEN`) |
|---|---|---|
| GPU QOS | `preempt_qos` | `normal` |
| CPU-only QOS | `preempt_cpu_qos` (0 GPUs, 32 CPU/job, 64 total, 20 running / 50 submitted, separate quota) | none |
| GPUs per user | 24 | 8 |
| CPUs per job | 256 | 128 |
| Running / submitted | 24 / 100 | 10 / 50 |
| Max walltime | 31 days | 2 days |
| Preemptible | yes | no (no QOS lists `normal` as preemptable, 2026-09-21) |
| GPU billing weight | 16.0 | 8.0 |
| Default walltime | 30 minutes — never omit `-t` (`ae` uses `AE_DEFAULT_TIME`) | 6 hours (`scontrol show partition general`, 2026-10-20) |

`maxlab_qos` / `maxlab_cpu_qos` may show up as held and pass a dry run, but they are not usable
in practice (`BABEL.md` Addendum A). Ignore them.

## Choosing a pool
The harness does not prescribe a pool. For each experiment, choose by one of these:
1. **The owner's stated preference** (record it in `PROJECT.md` as an amendment), or
2. **The fastest result**, from the measurements in "Verified on this account" and current
   queue state (`part=auto`, `bin/ae-capacity`, `squeue` pending counts).

State the choice and its reason in `state/DECISIONS.md`.

Suggestions (current owner preferences — not rules; the owner or the measurements override them):
- Prototype and smoke-test on `general` (not preemptible); run jobs longer than 2 days on `preempt`.
- Keep CPU standby (`ae pool cpu`) for tinkers; hold GPU standby only when GPU work is expected.

Mechanics (facts, not advice):
- `part=auto` asks both pools with `sbatch --test-only` and takes the earlier estimate. It uses
  `preempt` when `time` > 2 days. `--test-only` estimates are not guarantees.
- Slurm cannot race one job across both pools (QOSes are partition-specific and `--test-only`
  does not validate the pairing), so `ae` asks each pool separately.
- `ae attach gpu` / `ae tinker <id> --gpu` take the oldest RUNNING GPU standby in either pool;
  `--preempt` / `--gen` force one.
- `ae submit` refuses a `general` job longer than 2 days.
- Preempt-safety (`--requeue`, `--signal=B:USR1@120`, the USR1 discriminator, phase skipping)
  applies on both pools. On `general` it covers node failure and walltime chaining.

## Verified on this account
<!-- Filled by the first run (agent.md "First run", step 8); re-measure when conditions change.
     Record the date and the command for each value. -->
| item | `preempt` | `general` | `preempt_cpu_qos` | how / date |
|---|---|---|---|---|
| GPU limit per user (MaxTRESPU) | | | — | `sacctmgr show qos` |
| CPU limit per job / per user | | | | `sacctmgr show qos`, `scontrol show partition` |
| Running / submitted limit | | | | `sacctmgr show qos` |
| Max / default walltime | | | — | `scontrol show partition` |
| Pending jobs ahead (all users) | | | | `squeue -p <part> -t PD` |
| `--test-only` start estimate, 1 GPU / 1 h | | | — | `sbatch --test-only` |
| Self-test time to RUNNING | | | | ledger submit time vs `sacct` Start |
| Recent median / p90 wait (own jobs) | | | — | `bin/ae-capacity` |

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

## Traps NOT handled by `ae` (verified 2026-10-20/21 — re-verify)
- **`srun` is refused on `preempt`** ("Only `sbatch` jobs are allowed"). On `general`,
  `srun --jobid=<running job> --overlap -n1 <cmd>` works for quick checks inside a held allocation.
- **The login node's view of `/home` lags compute-node writes** (minutes). To read fresh compute
  output, read it from a compute node: `srun --jobid=<j> --overlap -n1 tar -C <dir> -cf - . | tar -xf -`.
- **`squeue %m` shows `MinMemoryTRES`, not the requested memory**; check `scontrol show job` `ReqTRES`.
- **`sbatch --test-only` estimates can be far too pessimistic** on `general` (+34 h shown while
  jobs started within minutes). Treat them as an upper bound.
- **Shared nodes:** `pgrep`/`pkill -f` see other users' processes; add `-u $USER`. A `pkill -f
  PATTERN` inside `bash -c "..."` also matches its own command line; write `[p]attern`.

## Preemption
`PreemptType=preempt/qos`, `PreemptMode=REQUEUE`,
`PreemptParameters=youngest_first,send_user_signal`, GraceTime **2 min**.
- **`youngest_first`**: the most recently *started* job is preempted first.
- **`send_user_signal`**: USR1 arrives on preemption, not only near walltime; the preamble tells
  them apart by the time left.
- Requeue keeps the **same JobID** and increments `SLURM_RESTART_COUNT`. No practical requeue cap
  (jobs reached 95 restarts). A requeued job is non-terminal, so `afterany` dependents correctly
  sleep through every preemption of their parent.

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
