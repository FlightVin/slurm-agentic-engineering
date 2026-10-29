# Operator guide

This guide answers the questions an operator asks most often, in the order they come up: what to
fill in, how to set up, how work runs, and what happens when something breaks.

## 1. What do I fill in manually?
You own two documents, which the agent drafts with you, and two config values:
- **`PROJECT.md`** — the science: question, hypothesis, how a run executes, where data lives, and
  what a finished experiment must emit. This is where your project plugs in.
- **`exp/<expid>.sh`** — one per experiment, about 15 lines, from `templates/exp.sh`.

The two config values are `AE_REMOTE_REPO` and `AE_BRANCH` in `config.sh`. The rest of `config.sh` is
Babel's measured configuration. Edit more only if Babel's quotas change (`ae doctor` shows the
live values) or you port the harness to another cluster. Nothing else needs editing.

## 2. One-time setup
Do these steps once per project and laptop. On a new project the agent's first run does steps 2–6
for you (agent.md, "First run").
1. **`~/.ssh/config`** (once per laptop). Set `ControlMaster auto`, `ControlPath ~/.ssh/cm-%r@%h:%p`,
   `ControlPersist 10m`, `ServerAliveInterval 15`, and add a `Host babel-*` wildcard for compute
   nodes. This is **mandatory**: without multiplexing, authentication took 5–31 s per command.
2. **Keep the harness out of the project's history.** Add `slurm-agentic-engineering/` to the
   project's `.git/info/exclude`.
3. **`ae init`** creates the workspace documents (including the Babel `cluster/CARD.md` and
   `cluster/BABEL.md`) and `config.sh` from templates. Then set `AE_REMOTE_REPO` and `AE_BRANCH`.
4. **`ae setup`** creates `~/ae/{jobs,code,work,out,results,inv,run}` on the cluster. It verifies ssh,
   git remote access, the QOSes you hold, live quotas against `config.sh`, and /home space.
5. **`ae pool cpu`** (optional, when tinkers will run) starts CPU standby capacity.
6. **Self-tests:** `ae submit ae-smoke && ae submit ae-smoke-dep --after ae-smoke`, and
   `ae submit ae-smoke-gen` for the general pool.

## 3. What command starts the orchestrator?
```
cd <repo>/slurm-agentic-engineering && claude
```
There is no server. The harness's `CLAUDE.md` loads `agent.md`. (If you start Claude in the project
root instead, the project needs a `CLAUDE.md` that imports `agent.md`: `ae init` without
`--no-claude-md` writes one.) The session then reads `state/STATE.md`, `state/CHECKLIST.md`,
`cluster/CARD.md` and `PROJECT.md`, runs `ae status`, and is ready to work.
Add `slurm-agentic-engineering/bin` to `PATH`, or call `./slurm-agentic-engineering/bin/ae`.

## 4. How do I specify a hypothesis/experiment?
Tell Claude in plain words. It writes `exp/<expid>.sh`:
```bash
#EXP gpus=1 cpus=4 time=08:00:00 after=<other-expid>
# HYPOTHESIS: <one or two lines>
phase <name> "<done-predicate>" "<command>"
```
`after=<other-expid>` is the same as `ae submit --after`.
`ae` routes `gpus=0` to the CPU QOS automatically. The done-predicate makes a requeue cheap: a
finished phase must be skippable in seconds.

## 5. How does it start and brief a tinker?
```
ae tinker <id> < brief.md          # branch + brief + launch, one step
ae tinker <id> --gpu < brief.md    # only if the work truly needs a GPU
```
The brief (from `templates/inv.md`) states the Objective, the Scope, a **Do NOT** section, a
Success criterion as an exact command, and the report format. The tinker receives the brief,
`lib/tinker-bootstrap.md`, and a least-privilege allowlist. It can run tests and the git
commands its allowlist names (commit, push to `inv/<id>`; not `fetch`, `merge` or `reset --hard`). It
**cannot** submit jobs, push to the authoritative branch, force-push, run `rm -rf`, or ssh out.

## 6. How does validated code get promoted?
```
ae report <id>     # its report + the commits on inv/<id>
ae accept <id>     # squash-merge into the authoritative branch, push
```
You review before you accept. The `inv/<id>` branch stays as the archive of work in progress.
A failed investigation is simply never accepted; nothing is deleted.

## 7. How does it launch an experiment?
```
ae submit <expid> [--after a,b] [--replace]
```
The steps, in order:
1. Check that the laptop is on `AE_BRANCH`.
2. Refuse if the expid is already queued or running (`--replace` cancels it first).
3. Check the submit quota: refuse when it is full. Over the GPU quota, only print a note: the job pends.
4. Refuse a dirty tree, push, and resolve the sha.
5. Generate a self-contained job script, check its syntax, and copy it to the cluster.
6. Create a **detached worktree** at that sha (once per expid and sha).
7. `sbatch`, then write the ledger line, which records the project `sha` and the recipe `expsha`.

Dependencies use `afterany`, and each job checks its own precondition. Related commands:
`ae cancel <expid>`, `ae slurm ...` (quoted Slurm queries; job control on this project's jobs only), `ae attach [tier]`, and `ae investigate <id>` / `ae launch <id>` (the two
halves of `ae tinker`).

## 8. How do results return?
The job writes small distillates to `$AE_RESULTS`. Then run:
```
ae harvest          # anything finished and not yet harvested
```
For each finished experiment, `ae harvest`:
- rsyncs `results/<expid>/` and appends one line to `state/FINDINGS.md`;
- saves a 40-line log tail;
- copies the generated job script to `results/<expid>/job.sh`, so the folder fully describes what
  produced it.

It refuses to mark an experiment harvested if the remote had artifacts and none were copied. The
marker `results/<expid>/.harvested` holds the commit, the recipe hash and the job id, so a
resubmission with the same commit and recipe is harvested again. The previous harvest moves to
`results/<expid>/.prev-<oldjob>-<time>/`. Such a resubmission writes to the same `$AE_RESULTS` directory
on the cluster, so phases whose done-check already passes are skipped. To recompute them, change the
recipe (a new `expsha`) or remove the old outputs first.

The harvest is capped at `AE_HARVEST_MAX_KB` per experiment (default 2 MB). If a job wants to
return more, fix the job; raise the cap only as a deliberate decision. Checkpoints and datasets
never come home.

## 9. How does it decide the next experiment?
You and Claude read `results/` and `FINDINGS.md`, update `STATE.md`, and write the next
`exp/*.sh`. Submit pre-declared chains up front with `--after`, so they need no supervision.
Record judgement calls in `state/DECISIONS.md`.

**Automatic harvest:** run `bin/ae-watch` as a background task. It wakes the agent only when a job
ends, and the agent then runs `ae harvest`. Do not build an agent polling loop (`agent.md`). A
scheduled check-in (for example Claude Code's `/loop`) is fine when the owner asks for one.

## 10. How does standby work?
Babel has three standby tiers:
- **CPU** — `preempt_cpu_qos`, 0 GPUs, separate quota.
- **preempt GPU** — each uses 1 of the preempt GPU quota.
- **general GPU** — each uses 1 of the general GPU quota; not preemptible.

Start times are not fixed; the agent measures them on the first run (`cluster/CARD.md`).
`ae pool cpu` holds CPU standby only. Plain `ae pool` also holds GPU standby in both pools (4 GPUs
of quota with the default sizes), and `--gpu` takes whichever GPU standby is running. Which tiers to
hold is the owner's preference or the agent's measured choice. Tinkering defaults to CPU.

Each standby holds a long-lived tmux server, and tinkers attach to it as windows. Recovery works
as follows:
- Because of `--requeue`, a preempted standby returns under the same JobID by itself.
- `ae pool` replaces a standby only when it ends for good, normally at its wall-time limit (12 h
  CPU / 24 h preempt GPU / 2 days general GPU).
- `ae launch` stops if no standby is running. `ae launch <id> --topup` fills that tier only, up to its pool size.
- `AE_DBG_EXCLUDE` in config.sh keeps standbys off known-bad nodes.

## 11. What happens after preemption/reboot?
- **Experiment preempted** → Slurm requeues the same JobID. The pinned worktree is unchanged, and
  finished phases skip in seconds. You do nothing.
- **Standby preempted** → it returns by itself under the same JobID. Before it ends, it **commits and pushes
  every dirty dev worktree**.
- **Tinker lost** → run `ae launch <id>` again. The tinker re-orients from the brief and
  its own `git log`.
- **Laptop restarted** → `cd <repo>/slurm-agentic-engineering && claude`. The session held no state.
- **A job genuinely FAILED** → read `ae logs <expid>` for a bounded slice, and `LEDGER.jsonl` for
  the exact sha. The harness never retries it automatically; this is by design.

## 12. What does a fresh session read first?
`CLAUDE.md` → `agent.md` (auto-loaded) → `bin/ae paths` (first run if `config.sh` is missing) → `state/STATE.md` → `state/CHECKLIST.md` → `cluster/CARD.md` →
`PROJECT.md` → `ae status`. This is about 250 lines. Read everything else with grep, on demand.
