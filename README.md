# slurm-agentic-engineering

A harness that lets a laptop-side AI agent (Claude Code) run a research project on **CMU Babel**.
The agent plans the work, submits commit-pinned Slurm jobs, delegates code changes to sandboxed
agents on compute nodes, brings small results home, and keeps the scientific state in a few short
documents. Slurm stays the only source of truth for job status.

**It ships tuned for Babel.** The config template, cluster card and cluster reference carry
Babel's measured pools, QOSes, quotas, storage layout and known traps. A new Babel project sets
two values in `config.sh` and runs. (To port to another cluster, edit `config.sh` and the cluster
card; nothing in `bin/` or `lib/` names a cluster.)

- **Operating manual for the agent:** [`agent.md`](agent.md). `CLAUDE.md` loads it.
- **Design:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Operator Q&A:** [`docs/OPERATOR.md`](docs/OPERATOR.md)
- **History:** [`examples/`](examples/README.md) — the full record of a finished Babel study (read-only).

## Quick start (two commands)

```bash
cd ~/path/to/your-project          # a git repo with a GitHub remote
git clone git@github.com:FlightVin/slurm-agentic-engineering.git && cd slurm-agentic-engineering && claude
```
That is all. On the first start the agent sees that `config.sh` is missing and runs the
**First run** procedure in [`agent.md`](agent.md): it excludes the harness from your project's
history, runs `ae init`, asks you a few questions in one message (study branch, what to do with
uncommitted files, Babel clone path, what the project is for), writes `config.sh`, clones the
project on Babel, runs `ae setup` and the self-tests, writes `PROJECT.md` with you, and reports.
It stops and asks if ssh to Babel is not set up yet (see "Before you start"). Claude asks you to
approve each new command; choose "Yes, and don't ask again" for `bin/ae` once and the rest of the
setup runs without prompts. To let the agent edit project code without a prompt per file, type
`/add-dir ..` once in Claude, or start Claude in the project root and say "Read and follow
`slurm-agentic-engineering/agent.md`". The manual steps
below are the same procedure, for reference.

> ### ✨ Let the agent do the work
> You do not have to type the `ae` commands yourself. Start Claude in the harness directory
> (`cd slurm-agentic-engineering && claude`) and ask in plain language. The
> agent knows every command from `agent.md`. For example:
> - *"Set up this harness for my project. The Babel clone should live at `~/projects/myproject`
>   and we work on `main`."* — it fills in `config.sh`, clones the project on Babel, and runs
>   `ae setup`.
> - *"Run `ae doctor` and tell me if anything is wrong."*
> - *"Run the Babel self-tests and tell me when they pass."* — it submits `ae-smoke`,
>   `ae-smoke-dep` and `ae-smoke-gen`, watches them with `ae-watch`, and harvests.
> - *"Help me write PROJECT.md."* — it interviews you and writes the objective, success
>   criteria, run entry point and `PROJ_DATA` path.
> - *"Write an experiment that trains X on Y and submit it."* — it writes `exp/<id>.sh` from the
>   template, commits, submits, monitors, harvests, and records the result.
> - *"Warm CPU standby"*, *"What is running?"*, *"Harvest and summarise"*, *"Investigate why job
>   N failed"* (it starts a tinker), *"Audit STATE against Slurm"*.
>
> The agent needs your approval for actions that are hard to reverse or that hold shared
> resources (for example, `ae pool` with GPU tiers holds 4 GPUs of quota).

## Before you start (once per laptop and account)

1. **ssh to Babel with connection sharing.** Every `ae` command is an ssh round trip; without
   `ControlMaster` each one costs 5–31 s of authentication. Add to `~/.ssh/config` (skip this if
   a `Host babel` block with `ControlMaster` already exists):
   ```
   Host babel
       HostName login.babel.cs.cmu.edu
       User <andrew-id>
       ControlMaster auto
       ControlPath ~/.ssh/cm-%r@%h:%p
       ControlPersist 10m
       ServerAliveInterval 15
   Host babel-*
       User <andrew-id>
   ```
2. **Babel can reach GitHub over ssh.** Babel clones and fetches your project, and tinkers push
   `inv/*` branches. Check: `ssh babel 'ssh -T git@github.com'` must greet your GitHub user.
3. **Slurm access.** Your account needs `preempt_qos`, `preempt_cpu_qos` and (for the
   non-preemptible pool) `normal`. `ae doctor` checks this.
4. **Laptop tools:** bash, git, ssh, rsync, python3 ≥ 3.8, Claude Code.
   **Babel tools:** git and tmux exist already. Install Claude Code under your home only if you
   want tinkers (compute-side agents).

## Add the harness to a project manually (what the first run does)

The project must be a git repo with a GitHub remote, on the branch you work on.

**1. Clone the harness into the project and create the workspace**
```bash
cd ~/path/to/myproject
git clone git@github.com:FlightVin/slurm-agentic-engineering.git
echo "slurm-agentic-engineering/" >> .git/info/exclude   # keep it out of the project's history
export PATH="$PWD/slurm-agentic-engineering/bin:$PATH"     # optional; else use ./slurm-agentic-engineering/bin/ae
ae init --no-claude-md
```
`ae init` creates the workspace inside `slurm-agentic-engineering/`: `config.sh` (Babel values),
`PROJECT.md`, `cluster/CARD.md`, `cluster/BABEL.md`, `state/*`, and the empty `exp/ inv/ results/
log/`. It never overwrites an existing file. Without `--no-claude-md` it also writes a one-line
`CLAUDE.md` in the project root that imports `agent.md`.

**2. Set the two per-project values in `slurm-agentic-engineering/config.sh`**
```bash
AE_REMOTE_REPO='$HOME/projects/myproject'   # single quotes: $HOME expands on Babel
AE_BRANCH="main"                            # the branch you work on; runs are pinned to its commits
```
Leave everything else. `ae paths` prints what resolved where (offline).

**3. Clone the project on Babel** (same path as `AE_REMOTE_REPO`)
```bash
ssh babel 'mkdir -p ~/projects && git clone git@github.com:<you>/myproject.git ~/projects/myproject'
```

**4. Check the setup and run the self-tests**
```bash
ae setup                                    # creates ~/ae on Babel, then runs ae doctor
ae submit ae-smoke && ae submit ae-smoke-dep --after ae-smoke    # CPU pool: pinning + chaining
ae submit ae-smoke-gen                      # general pool: GPU visible + /data/user_data mounted
ae wait ae-smoke-dep 3600 && ae harvest
```
`ae submit` refuses uncommitted changes in the project: commit and stay on `AE_BRANCH` first.
`ae doctor` must show `held:` for all three QOSes and the free space on `/home`. After the
harvest, `results/ae-smoke-dep/chain.json` must contain `"ran_after_parent": true` and
`results/ae-smoke-gen/pool.json` must show `"partition": "general"`. The CPU queue can take
from seconds to over an hour.

**5. Describe the project** in `slurm-agentic-engineering/PROJECT.md`: objective, success
criteria, constraints, how a run executes (environment, entry point), and `PROJ_DATA` (for example
`/data/user_data/$USER/myproject`). The agent can write this with you.

**6. Start the orchestrator**
```bash
cd slurm-agentic-engineering && claude
```
Claude loads `CLAUDE.md` → `agent.md`, reads `state/STATE.md`, `state/CHECKLIST.md`,
`cluster/CARD.md` and `PROJECT.md`, and runs `ae status`. If you start Claude in the project root
instead (useful when it must edit project code a lot), tell it once: *"Read and follow
`slurm-agentic-engineering/agent.md`."*

**Update the harness later:** `git -C slurm-agentic-engineering pull`. The workspace is
git-ignored by the harness repo, so a pull never touches your project state.

## Where things live

Everything below is inside `slurm-agentic-engineering/` on the laptop. Neither git repo tracks
it, so back it up yourself (or set `AE_HOME` to a directory that you version).

| path | contents |
|---|---|
| `config.sh` | site config (Babel values + your two lines) |
| `PROJECT.md` | the science: objective, criteria, protocol, owner amendments |
| `cluster/CARD.md`, `cluster/BABEL.md` | Babel facts (card: read; reference: grep) |
| `state/STATE.md`, `state/CHECKLIST.md` | current scientific state; live plan |
| `state/FINDINGS.md`, `state/DECISIONS.md` | results (append-only); dated decisions |
| `state/IMPLEMENTATION-LOG.md` | harness changes and operational lessons (never results) |
| `state/LEDGER.jsonl` | one line per submission: expid, jobid, commit sha, recipe hash |
| `exp/`, `inv/`, `results/`, `log/` | experiment definitions, tinker briefs/reports, harvested distillates, monthly reasoning log |

On Babel: `~/ae/` holds pinned code (`code/`), job scripts (`jobs/`), Slurm logs (`out/`),
results before harvest (`results/`) and per-run scratch (`run/`). Datasets and checkpoints go to
`/data/user_data/$USER` (500 GB, compute nodes only). `/home` is 100 GB: never put checkpoints there.

## How a run works

1. Write `exp/<id>.sh` from `templates/exp.sh`: a header such as
   `#EXP gpus=1 time=04:00:00 part=preempt` and a few `phase` steps, each with a "done" check.
2. `ae submit <id>` refuses a dirty tree, pushes `AE_BRANCH`, creates a detached worktree at that
   commit on Babel, generates the Slurm script (requeue, 2-minute preemption signal), and writes
   the ledger line. Routing: `gpus=0` → `preempt_cpu_qos`; `part=general` → `normal`;
   `part=auto` → whichever pool estimates the earlier start.
3. Preemption: Slurm requeues the same job ID; finished phases are skipped.
4. `ae status` asks Slurm. `ae-watch` (a plain script) wakes the agent only when a job fails or
   completes.
5. `ae harvest` copies `$AE_RESULTS` (≤ 2 MB per experiment) home and appends to `state/FINDINGS.md`.

Code changes made on compute go through tinkers: `ae tinker <id> < brief.md` starts an agent on
a standby node on branch `inv/<id>` (no `sbatch`, no push to `AE_BRANCH`, no force-push, no
`rm -rf`, no ssh). Read it with `ae report <id>`; merge it with `ae accept <id>`.

## Configuration (`config.sh`)
| variable | you set it? | Babel value / meaning |
|---|---|---|
| `AE_REMOTE_REPO` | **yes** | Babel clone of the project (single-quoted, e.g. `'$HOME/projects/x'`) |
| `AE_BRANCH` | **yes** | authoritative branch; runs are pinned to it; tinkers can never push to it |
| `AE_HOST` | no | `babel` (the ssh alias above) |
| `AE_PARTITION`, `AE_QOS_GPU`, `AE_QOS_CPU` | no | `preempt`, `preempt_qos`, `preempt_cpu_qos` |
| `AE_PARTITION_GEN`, `AE_QOS_GEN`, `AE_GEN_*` | no | `general`, `normal`; 8 GPUs, 10 running, 50 submitted, 2-day wall |
| `AE_REMOTE_ROOT` | no | `$HOME/ae` |
| `AE_DEFAULT_TIME`, `AE_DEFAULT_CPUS` | no | `08:00:00`, 4 (Babel's own default walltime is 30 min) |
| `AE_DBG_*` | no | standby: CPU ×2 (12 h), preempt GPU ×2 (24 h), general GPU ×2 (2 days) |
| `AE_MAX_GPUS_PER_USER`, `AE_MAX_SUBMIT` | no | 24, 100 (`preempt_qos`) |
| `AE_HARVEST_MAX_KB` | no | per-experiment harvest cap, 2048 |
| `AE_AGENT_CMD` | no | tinker agent command (default `claude --permission-mode acceptEdits`) |

## Commands
```
ae paths | init [--no-claude-md] | setup | doctor
ae pool [cpu|gpu|gen|all] | pool <ncpu> [ngpu] | attach [cpu|gpu|gen]
ae submit <expid> [--after a,b] [--replace] [--allow-dirty]
ae status [--changed] | logs <expid> [n] | harvest [expid] | wait <expid> [s] | cancel <expid> | prune [--yes]
ae tinker <id> [--gpu] < brief.md | investigate <id> | launch <id> | report <id> | accept <id>
ae-watch [--once] [--suppress-done RE] [--when-complete RE:N:LABEL]
ae-capacity [hours] | ae-topup <queue-file> [interval]
```
`ae help` prints the full list. `ae pool cpu` is the routine standby call; plain `ae pool` also
holds 2 GPU standby in each GPU pool (4 GPUs of quota).

## Reset for a new project
Restore the workspace documents (`PROJECT.md`, `cluster/{CARD,BABEL}.md`,
`state/{STATE,CHECKLIST,FINDINGS,DECISIONS,IMPLEMENTATION-LOG}.md`) to the templates. Nothing else
changes: not code, git, `state/LEDGER.jsonl`, `results/`, `log/`, `exp/`, `inv/`, or `config.sh`.
```bash
python3 slurm-agentic-engineering/scripts/reset_project.py --target .            # dry run: prints the plan
python3 slurm-agentic-engineering/scripts/reset_project.py --target . --apply    # backs up, then resets
```
Backups go to `<workspace>/.reset-backups/<UTC stamp>/`. A second run is a no-op. It never runs
git. Add `--no-claude-md` if you do not want a project-root `CLAUDE.md`.

## Tests
```bash
bash tests/test-preamble.sh          # preemption-vs-walltime logic
bash tests/test-cli.sh               # CLI entry points, paths, init, Babel defaults, permissions
python3 tests/test_reset_project.py  # reset utility: dry run, apply, backups, idempotence, safety
bash tests/test-e2e-local.sh         # the real `ae` on the Babel defaults against mock ssh/Slurm
```
On Babel the end-to-end tests are the self-tests (`ae-smoke`, `ae-smoke-dep`, `ae-smoke-gen`).
Run them after any change to `bin/` or `lib/`.

## Known limits
- The tinker allowlist matches a command's first word (Claude Code permission rules). `env …` and
  `python …` are allowed for tests, so the allowlist guards against mistakes, not against a hostile
  agent. Denials cover the dangerous direct forms.
- `part=auto` uses `sbatch --test-only` estimates. They are a tie-breaker, not a promise.
- The workspace is not versioned by default (see "Where things live").
