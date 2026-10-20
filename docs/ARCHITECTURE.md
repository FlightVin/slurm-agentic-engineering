# Architecture

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

Only **code** crosses via git. Only **small distillates** come home. Job status
is never transported — it is queried.

## Why there is no daemon

A previous attempt put a monitor and an agent-host job on the cluster so they
could survive preemption. They could not: nothing that executes on `preempt` is
durable, and the monitor died exactly when monitoring mattered.

The persistent-laptop invariant dissolves that whole layer. The laptop is the
supervisor, so there is nothing to self-heal. **No handler jobs, no monitor, no
self-resubmitting chains.** This also halves queue usage against the per-user submit cap.

## The durability split

| Concern | Strategy | Because |
|---|---|---|
| Experiments | **resilience** — `--requeue` + phase skipping | they are long and restartable |
| Standby/dev | **redundancy** — keep N warm, replace the dead one | a session cannot be checkpointed |
| Orchestration | **statelessness** — nothing to lose | the laptop holds it |

Applying the wrong one is what makes preemption feel intractable.

## What is written vs derived

Written, because it cannot be derived:
- `exp/*.sh`, `inv/*/brief.md` — intent
- `state/LEDGER.jsonl` — expid → jobid → **sha** (project code) → **expsha**
  (the experiment recipe). Slurm drops `Comment`, so neither is recoverable from
  it. `expsha` exists because the workspace is outside the project's git tracking: editing an
  `exp/*.sh` does not dirty the tree and would otherwise silently change what
  runs at the "same" sha.
- `state/FINDINGS.md`, `state/DECISIONS.md`, `state/STATE.md` — conclusions
- `results/<expid>/` — distillates

Derived, never stored: job state, exit codes, restart counts, node, queue
position, elapsed/remaining, what code is on compute (`git describe`).

Everything written is either git or **append-only**. That is the whole
concurrency story.

## Code identity

`ae submit` refuses a dirty tree, pushes, resolves HEAD to a sha, and creates a
**detached worktree** `~/ae/code/<expid>-<sha>`. The generated job script `cd`s
there on every attempt.

Two identities are pinned: the **project sha** (a detached worktree) and the
**recipe sha** (`expsha`, hashing the `exp/*.sh`). The generated job script is
archived per `(sha, expsha)` on the cluster and copied into
`results/<expid>/job.sh` on harvest, so a result folder fully describes what
produced it.

Consequence: you cannot launch an experiment against unpushed code — the
worktree simply cannot be materialised. The invariant is arithmetic, not
discipline. And a requeue 20 hours later runs byte-identical code.

## The tinkering loop

```
laptop:  ae tinker <id> < brief.md
           ├─ branch inv/<id> off the authoritative branch, pushed
           ├─ dev worktree ~/ae/work/<id>, hard-reset to origin/inv/<id>
           └─ agent as a tmux WINDOW on the standby job's server
compute: agent reads brief → edits → verifies → commits → pushes → .ae-report.md
laptop:  ae report <id>   → ae accept <id>  (squash-merge, branch kept as archive)
         ae submit <expid>                  (pinned to the merged sha)
```

Three details that are load-bearing:
- The agent is **relaunchable, not durable**. `ae launch` again and it re-orients
  from the brief and its own `git log` — never from a conversation.
- The tmux **server belongs to the standby batch job**, not to the `srun` step.
  A session created by the step is killed when the step exits (verified).
- The standby job's USR1/TERM handler **commits and pushes every dirty dev
  worktree** before the allocation dies. Preemption costs the current thought.

## Standby capacity — the tradeoff, stated

Warm capacity removes queue latency but consumes quota. Measured on one site (see
examples/cluster/): CPU standby reached RUNNING in **~5 s**; GPU standby in **2.5–3.5 h**.

So: keep **2 CPU standby** (0 GPUs, separate quota pool — effectively free) and
**GPU standby only when needed** (it counts against the GPU quota). Tinkering defaults to CPU because most code and data
work needs no GPU; `ae tinker <id> --gpu` opts in and expects to wait.

Standby self-heals: `--requeue` means a preempted standby returns to PENDING
under the same JobID and comes back on a new node by itself. `ae pool` only tops
up after a *terminal* end (the walltime: 12 h for the CPU tier, 24 h for GPU),
and `ae launch` tops the pool up automatically if it finds none running.
