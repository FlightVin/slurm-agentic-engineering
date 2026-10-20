# Operator guide

## 1. What do I fill in manually?
Only two things:
- **`PROJECT.md`** — the science: question, hypothesis, how a run executes, where
  data lives, what a finished experiment must emit. This is the plug-in point.
- **`exp/<expid>.sh`** — one per experiment, ~15 lines, from `templates/exp.sh`.

Plus two values in `config.sh` (`AE_REMOTE_REPO`, `AE_BRANCH`); the rest of it is Babel's
measured configuration. Edit more only if Babel's quotas change (`ae doctor` shows live values)
or you port to another cluster. Nothing else.

## 2. One-time setup
Once per project and laptop:
1. `~/.ssh/config` — `ControlMaster auto`, `ControlPath ~/.ssh/cm-%r@%h:%p`,
   `ControlPersist 10m`, `ServerAliveInterval 15`, plus a `Host babel-*` wildcard for compute nodes.
   **Mandatory**: unmultiplexed auth measured 5–31 s per command.
2. Keep the harness out of the project's history: add `slurm-agentic-engineering/` and
   `.claude/settings.local.json` to the project's `.git/info/exclude` (or `.gitignore`).
3. `ae init` — creates the workspace documents (incl. the Babel `cluster/CARD.md` and
   `cluster/BABEL.md`) and `config.sh` from templates; set `AE_REMOTE_REPO` and `AE_BRANCH`.
4. `ae setup` — creates `~/ae/{jobs,code,work,out,results,inv}` on the cluster and
   verifies ssh, git remote access, the QOSes you hold, live quotas vs `config.sh`, and /home space.
5. `ae pool cpu` — brings up standby capacity.
6. Self-tests: `ae submit ae-smoke && ae submit ae-smoke-dep --after ae-smoke`, and
   `ae submit ae-smoke-gen` for the general pool.

## 3. What command starts the orchestrator?
```
cd <repo> && claude
```
There is no server. The project's `CLAUDE.md` (created by `ae init`) loads `agent.md`; the
session reads `STATE.md`,
`cluster/CARD.md`, `PROJECT.md`, runs `ae status`, and is oriented.
Add `slurm-agentic-engineering/bin` to `PATH`, or call `./slurm-agentic-engineering/bin/ae`.

## 4. How do I specify a hypothesis/experiment?
Tell Claude in plain words. It writes `exp/<expid>.sh`:
```bash
#EXP gpus=1 cpus=4 time=08:00:00 after=<other-expid>
# HYPOTHESIS: <one or two lines>
phase <name> "<done-predicate>" "<command>"
```
`gpus=0` is routed to the CPU QOS automatically. The done-predicate is what makes
a requeue cheap — a finished phase must be skippable in seconds.

## 5. How does it start and condition a tinkering agent?
```
ae tinker <id> < brief.md          # branch + brief + launch, one step
ae tinker <id> --gpu < brief.md    # only if the work truly needs a GPU
```
The brief (from `templates/inv.md`) states Objective, Scope, **Do NOT**, a
Success criterion as an exact command, and the report format. The agent gets that
plus `lib/tinker-bootstrap.md` and a least-privilege allowlist. It can run git and
tests; it **cannot** submit jobs, push to the authoritative branch, force-push,
`rm -rf`, or ssh out.

## 6. How does validated code get promoted?
```
ae report <id>     # its report + the commits on inv/<id>
ae accept <id>     # squash-merge into the authoritative branch, push
```
You review before accepting. The `inv/<id>` branch is kept as the WIP archive.
A failed investigation is simply never accepted; nothing is deleted.

## 7. How does it launch an experiment?
```
ae submit <expid> [--after a,b] [--replace]
```
Refuses a dirty tree → checks GPU/submit quota → pushes → resolves the sha →
creates a **detached worktree** at that sha → generates a self-contained job
script → `sbatch` → writes the ledger line (recording both the project `sha` and
the recipe `expsha`). Dependencies use `afterany` plus each job's own precondition
check. Other commands: `ae cancel <expid>`, `ae attach [tier]`,
`ae investigate <id>` / `ae launch <id>` (the two halves of `ae tinker`).

## 8. How do results return?
The job writes small distillates to `$AE_RESULTS`. Then:
```
ae harvest          # anything finished and not yet harvested
```
rsyncs `results/<expid>/`, appends one line to `state/FINDINGS.md`, saves a 40-line
log tail, and copies the generated job script to `results/<expid>/job.sh` so the
folder fully describes what produced it. It refuses to mark an experiment
harvested if the remote had artefacts and none were copied. Capped at `AE_HARVEST_MAX_KB` per experiment (default 2 MB) — if a job wants to return more,
fix the job; raise the cap only deliberately. Checkpoints and datasets never come home.

## 9. How does it decide the next experiment?
You and Claude read `results/` and `FINDINGS.md`, update `STATE.md`, and write the
next `exp/*.sh`. Pre-declared chains are submitted up front with `--after`, so
they need no babysitting. Judgement calls go to `state/DECISIONS.md`.

**Automatic harvest:** run the poll on an interval, e.g. Claude Code's
`/loop 20m` with `ae status --changed && ae harvest`. `--changed` prints
`no change` when nothing is new, so idle wakes are cheap.

## 10. How does standby work?
Three tiers on Babel: **CPU** (`preempt_cpu_qos`, 0 GPUs, separate quota), **preempt GPU** (1 of
the preempt GPU quota each) and **general GPU** (1 of the general GPU quota each, not preemptible).
Start times are not fixed; the agent measures them on first run (`cluster/CARD.md`).
`ae pool cpu` holds CPU standby only; plain `ae pool` also holds GPU standby in both pools (4 GPUs
of quota with the default sizes), and `--gpu` takes whichever is running. Which tiers to hold is
the owner's preference or the agent's measured choice. Tinkering defaults to CPU. Each holds a long-lived tmux server that agents attach to as
windows. `--requeue` means a preempted standby returns under the same JobID by
itself; `ae pool` only tops up after a terminal end (12 h CPU / 24 h preempt GPU / 2 days general),
and `ae launch` tops up automatically if no standby is running.

## 11. What happens after preemption/reboot?
- **Experiment preempted** → Slurm requeues the same JobID, the pinned worktree is
  unchanged, finished phases skip in seconds. You do nothing.
- **Standby preempted** → returns by itself in 2–5 min; before dying it
  **commits and pushes every dirty dev worktree**.
- **Tinkering agent lost** → `ae launch <id>` again; it re-orients from the brief
  and its own `git log`.
- **Laptop restarted** → `cd <repo> && claude`. Nothing was in the session.
- **A job genuinely FAILED** → `ae logs <expid>` for a bounded slice, `LEDGER.jsonl`
  for the exact sha. Never auto-retried, by design.

## 12. What does a fresh session read first?
`CLAUDE.md` → `agent.md` (auto-loaded) → `state/STATE.md` → `cluster/CARD.md` →
`PROJECT.md` → `ae status`. About 250 lines. Everything else is grep-on-demand.
