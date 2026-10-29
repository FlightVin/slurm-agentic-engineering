# Architecture

This document explains how the harness is built and why. It covers where each kind of state
lives, how runs survive preemption, how code is pinned, and how tinkers and standby work.

## Three places, three jobs

```
  LAPTOP                     GIT REMOTE              CLUSTER
  ──────                     ──────                  ─────
  Claude = orchestrator  ◄─► code only          ◄─►  execution + data
  slurm-agentic-engineering/ <authoritative branch>  ~/ae/code/   pinned worktrees
    exp/ inv/ state/         inv/* branches          ~/ae/work/   dev worktrees
    results/ (distillates)   (no orchestration)      ~/ae/results/ distillates
                                                     $PROJ_DATA   never leaves
```

Only **code** crosses between the places, and only through git. Only **small distillates** come
home. Job status is never copied anywhere: the harness asks Slurm for it each time.

## Why there is no daemon

An earlier design put a monitor and an agent-host job on the cluster, so that they could survive
preemption. They could not. Nothing that runs on `preempt` is durable, so the monitor died exactly
when monitoring mattered.

This harness removes that layer. The laptop is persistent and is the supervisor, so there is
nothing to self-heal. **No handler jobs, no monitor, no self-resubmitting chains.** This also
uses fewer submit slots against the per-user submit cap, because there are no handler jobs.

## The durability split

Each part of the system needs a different strategy against preemption:

| Concern | Strategy | Because |
|---|---|---|
| Experiments | **resilience** — `--requeue` + phase skipping | they are long and restartable |
| Standby/dev | **redundancy** — keep N warm, replace the dead one | a session cannot be checkpointed |
| Orchestration | **statelessness** — nothing to lose | the laptop holds it |

When a part uses the wrong strategy, preemption causes failures in that part.

## What is written vs derived

The harness writes down only what it cannot derive:
- `exp/*.sh`, `inv/*/brief.md` — intent.
- `state/LEDGER.jsonl` — expid → jobid → **sha** (project code) → **expsha** (the experiment
  recipe). Slurm does not keep the job `Comment` field, so the ledger stores the commit and recipe
  hash; neither value can be recovered from Slurm. `expsha` exists
  because the workspace is outside the project's git tracking. An edit to an `exp/*.sh` does not
  dirty the tree, so without `expsha` it would silently change what runs at the "same" sha.
- `state/FINDINGS.md`, `state/DECISIONS.md`, `state/STATE.md` — conclusions.
- `results/<expid>/` — distillates.

The harness never stores what it can derive: job state, exit codes, restart counts, node, queue
position, elapsed/remaining time, and which code is on compute (`git describe`).

Everything written is either in git or **append-only**. So concurrent writers cannot conflict.

## Code identity

`ae submit` refuses a dirty tree, pushes, resolves HEAD to a sha, and creates a **detached
worktree** `~/ae/code/<expid>-<sha7>` (the 7-character short sha). The generated job script `cd`s there on every attempt.

Two identities are pinned:
- the **project sha**, through the detached worktree;
- the **recipe sha** (`expsha`, a hash of the `exp/*.sh`).

The cluster archives the generated job script per `(sha, expsha)`. `ae harvest` copies it into
`results/<expid>/job.sh`, so a result folder fully describes what produced it.

Two consequences follow. First, you cannot launch an experiment against unpushed code, because the
worktree cannot be created. The rule is enforced by the mechanism, not by discipline. Second, a
requeue 20 hours later runs byte-identical code.

## The tinkering loop

```
laptop:  ae tinker <id> < brief.md
           ├─ branch inv/<id> off the authoritative branch, pushed
           ├─ dev worktree ~/ae/work/<id>, hard-reset to origin/inv/<id>
           └─ tinker as a tmux WINDOW on the standby job's server
compute: tinker reads brief → edits → verifies → commits → pushes → .ae-report.md
laptop:  ae report <id>   → ae accept <id>  (squash-merge, branch kept as archive)
         ae submit <expid>                  (pinned to the merged sha)
```

Three details make this loop work:
- The tinker is **relaunchable, not durable**. Run `ae launch` again, and the tinker re-orients from
  the brief and its own `git log`, never from a conversation.
- The tinker runs in the standby batch job's tmux server, because a tmux session that an `srun`
  step creates dies when that step exits (verified).
- The standby job's USR1/TERM handler **commits and pushes every dirty dev worktree** before the
  allocation ends. A preemption loses only the tinker's uncommitted work.

## Standby capacity — the tradeoff, stated

Warm standby removes queue latency but consumes quota. The time each tier takes to start is not
fixed. The agent measures it on the first run and records it in `cluster/CARD.md` ("Verified on
this account").

CPU standby uses a separate quota (0 GPUs). GPU standby counts against a pool's GPU quota. Which
tiers to hold, and in which pool, is a per-project choice: the owner's preference, or the fastest
option by the agent's measurements (`cluster/CARD.md`, "Choosing a pool"). Tinkering defaults to
CPU, because most code and data work needs no GPU; `ae tinker <id> --gpu` opts in.

**How standby recovers:**
- A preempted standby heals itself. Because of `--requeue`, it returns to PENDING under the same
  JobID and comes back on a new node.
- `ae pool` replaces a standby only when it ends for good, normally at its wall-time limit (12 h
  CPU, 24 h preempt GPU, 2 days general GPU).
- `ae launch` never submits a standby on its own, because a standby uses the project's GPU budget.
  With no standby running, it stops. `--topup` fills the requested tier only, up to its pool size.
- `AE_DBG_EXCLUDE` (config.sh) keeps standbys off known-bad nodes.
