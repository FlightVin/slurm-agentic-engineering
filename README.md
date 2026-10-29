# slurm-agentic-engineering

This harness lets an AI agent (Claude Code) on your laptop run a research project on **CMU Babel**.
The agent plans the work and submits Slurm jobs that are pinned to a commit. It gives code changes
to tinkers (agents on compute nodes), brings small results home, and keeps the scientific state in
a few short documents. Slurm stays the only source of truth for job status.

**It ships tuned for Babel.** The config template, the cluster card and the cluster reference
contain Babel's measured pools, QOSes, quotas, storage layout and known traps. A new Babel project
sets two values in `config.sh` and runs. To port the harness to another cluster, edit `config.sh`
and the cluster card; nothing in `bin/` or `lib/` names a cluster.

- **Operating manual for the agent:** [`agent.md`](agent.md). `CLAUDE.md` loads it. It also sets the
  writing standard for every document the agent writes, and lists the rules learned on Babel.
- **Design:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Operator Q&A:** [`docs/OPERATOR.md`](docs/OPERATOR.md)
- **History:** [`examples/`](examples/README.md) — the full record of a finished Babel study (read-only).

## Terms

- **authoritative branch** (`AE_BRANCH`): the branch whose commits runs are pinned to.
- **pinned**: a job runs an exact commit that cannot change while it is queued.
- **tinker**: a compute-side Claude agent that changes code on branch `inv/<id>`.
- **standby**: a long-running placeholder job that holds a node, so a tinker or check can start at
  once (`AE_DBG_*` settings).
- **pool**: a partition + QOS pair: `preempt`/`preempt_qos`, `general`/`normal`, and CPU-only
  `preempt`/`preempt_cpu_qos`.
- **tier**: the pool a standby uses: `cpu`, `gpu` (preempt GPU) or `gen` (general GPU).
- **distillate**: the small result files a job writes to `$AE_RESULTS` for harvest.
- **workspace**: the git-ignored project documents inside `slurm-agentic-engineering/`.

## Quick start

```bash
cd ~/path/to/your-project          # a git repo with a GitHub remote
git clone git@github.com:FlightVin/slurm-agentic-engineering.git && cd slurm-agentic-engineering && claude
```
That is all. On the first start, the agent sees that `config.sh` is missing and runs the
**First run** procedure in [`agent.md`](agent.md). In that procedure, the agent:

1. excludes the harness from your project's history and runs `ae init`;
2. asks you a few questions in one message: authoritative branch (`AE_BRANCH`), what to do with uncommitted files,
   Babel clone path, what the project is for, and pool preference;
3. writes `config.sh`, clones the project on Babel, and runs `ae setup` and the self-tests;
4. verifies the GPU, CPU and time limits of `preempt` and `general`, and measures the queues;
5. writes `PROJECT.md` with you, and reports.

If ssh to Babel is not set up yet, the agent stops and asks (see "Before you start").

The harness's `.claude/settings.json` pre-approves the `ae`, `ae-watch` and `ae-capacity`
commands, read-only `git status/log/diff`, and the test suites. Slurm access goes through
`ae slurm` (part of `ae`): it quotes every argument, so no argument can chain a remote command.
Its job control (cancel, hold, release, requeue, update) accepts only job IDs that this project
created (ledger rows or its own standbys). Anything else (project files, `ssh`, `git push`) still asks. To let the agent edit project
code without a prompt per file, type `/add-dir ..` once in Claude. Alternatively, start Claude in
the project root and say "Read and follow `slurm-agentic-engineering/agent.md`".

The manual steps further below are the same procedure, for reference.

> ### Let the agent do the work
> You do not have to type the `ae` commands yourself. Start Claude in the harness directory
> (`cd slurm-agentic-engineering && claude`) and ask in plain language. The agent knows every
> command from `agent.md`. For example:
> - *"Check the setup and tell me what is missing."*
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
> The agent asks for your approval before actions that are hard to reverse or that hold shared
> resources. For example, `ae pool` with GPU tiers holds 4 GPUs of quota.

## Before you start (once per laptop and account)

1. **ssh to Babel with connection sharing.** Every `ae` command is an ssh round trip. Without
   `ControlMaster`, each one spends 5–31 s on authentication. Add this to `~/.ssh/config`, unless
   a `Host babel` block with `ControlMaster` already exists:
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
   `inv/*` branches. To check, run `ssh babel 'ssh -T git@github.com'`; it must greet your GitHub user.
3. **Slurm access.** Your account needs `preempt_qos`, `preempt_cpu_qos` and, for the
   non-preemptible pool, `normal`. `ae doctor` checks this.
4. **Tools.** Laptop: bash, git, ssh, rsync, python3 ≥ 3.8, Claude Code. Babel: git and tmux are
   already installed. Install Claude Code under your Babel home only if you want tinkers.

## Add the harness to a project manually (what the first run does)

The project must be a git repo with a GitHub remote, checked out on the authoritative branch (`AE_BRANCH`).

**1. Clone the harness into the project and create the workspace**
```bash
cd ~/path/to/myproject
git clone git@github.com:FlightVin/slurm-agentic-engineering.git
echo "slurm-agentic-engineering/" >> .git/info/exclude   # keep it out of the project's history
export PATH="$PWD/slurm-agentic-engineering/bin:$PATH"     # optional; else use ./slurm-agentic-engineering/bin/ae
ae init --no-claude-md
```
`ae init` creates the workspace inside `slurm-agentic-engineering/`: `config.sh` (Babel values),
`PROJECT.md`, `cluster/CARD.md`, `cluster/BABEL.md`, `state/*`, and the empty directories `exp/ inv/
results/ log/`. It never overwrites an existing file. Without `--no-claude-md`, it also writes a
short `CLAUDE.md` in the project root that imports `agent.md`.

**2. Set the two per-project values in `slurm-agentic-engineering/config.sh`**
```bash
AE_REMOTE_REPO='$HOME/projects/myproject'   # single quotes: $HOME expands on Babel
AE_BRANCH="main"                            # authoritative branch; runs are pinned to its commits
```
Leave everything else as it is. `ae paths` prints where each location resolves (it works offline).

**3. Clone the project on Babel** at the path in `AE_REMOTE_REPO`
```bash
ssh babel 'mkdir -p ~/projects && git clone git@github.com:<you>/myproject.git ~/projects/myproject'
```

**4. Check the setup and run the self-tests**

Commit first and stay on `AE_BRANCH`: `ae submit` refuses uncommitted changes and untracked files.
```bash
ae setup                                    # creates ~/ae on Babel, then runs ae doctor
ae submit ae-smoke && ae submit ae-smoke-dep --after ae-smoke    # CPU pool: pinning + chaining
ae submit ae-smoke-gen                      # general pool: GPU visible + /data/user_data mounted
ae wait ae-smoke-dep 3600 && ae wait ae-smoke-gen 3600 && ae harvest
```
(The agent waits with `bin/ae-watch` instead of `ae wait`; both work.)

Pass criteria:
- `ae doctor` shows `held:` for all three QOSes, and shows the free space on `/home`.
- After the harvest, `results/ae-smoke-dep/chain.json` contains `"ran_after_parent": true`.
- `results/ae-smoke/pin.json` shows `"pinned": true` and `qos` `preempt_cpu_qos`.
- `results/ae-smoke-gen/pool.json` shows `"partition": "general"` and `"user_data_mounted": "yes"`.

**4b. Verify limits and measure the queues** (the first run does this). Check the GPU, CPU,
running/submitted and wall-time limits of both pools with `sacctmgr show qos` and
`scontrol show partition`. Measure the queue state and start times. Record all of it in
`cluster/CARD.md` ("Verified on this account"). The docs make no claim about wait times.

**5. Describe the project** in `slurm-agentic-engineering/PROJECT.md`: objective, success
criteria, constraints, how a run executes (environment, entry point), and `PROJ_DATA` (for example
`/data/user_data/$USER/myproject`). The agent can write this with you.

**6. Start the orchestrator**
```bash
cd slurm-agentic-engineering && claude
```
Claude loads `CLAUDE.md` → `agent.md`, reads `state/STATE.md`, `state/CHECKLIST.md`,
`cluster/CARD.md` and `PROJECT.md`, and runs `ae status`. You can also start Claude in the project
root, which helps when it must edit a lot of project code. Then tell it once: *"Read and follow
`slurm-agentic-engineering/agent.md`."*

**Update the harness later** with `git -C slurm-agentic-engineering pull`. The harness repo
git-ignores the workspace, so a pull never touches your project state.

## How a run works

1. **Define.** Write `exp/<id>.sh` from `templates/exp.sh`. It has a header such as
   `#EXP gpus=1 time=04:00:00 part=preempt` and a few `phase` steps, each with a "done" check.
2. **Submit.** `ae submit <id>` refuses a dirty tree and pushes `AE_BRANCH`. It then generates the
   Slurm script (requeue, 2-minute preemption signal), creates a detached worktree at that commit
   on Babel, submits the job, and writes the ledger line. Routing:
   - `gpus=0` → `preempt_cpu_qos`;
   - `part=general` → `normal`;
   - `part=auto` → the pool that estimates the earlier start.

   You choose the pool, or the agent chooses it by measurement. `cluster/CARD.md` ("Choosing a
   pool") lists the current suggestions.
3. **Preemption.** Slurm requeues the job under the same job ID, and the job skips finished phases.
   A USR1 signal is a warning: 2 minutes before a preemption, or near the time limit. On every USR1,
   the preamble writes `$AE_PREEMPT_FLAG`. The program can then save a checkpoint. If the program
   exits, its phase must call `scontrol requeue`. `templates/exp.sh` shows how.
4. **Monitor.** `ae status` asks Slurm. `ae-watch` (a plain script) wakes the agent only when a job
   fails or completes.
5. **Harvest.** `ae harvest` copies `$AE_RESULTS` home (≤ 2 MB per experiment) and appends to
   `state/FINDINGS.md`. It records the job ID, so a rerun with the same commit and recipe is
   harvested again.

**Code changes on compute go through tinkers.** `ae tinker <id> < brief.md` starts a tinker on a
standby node, on branch `inv/<id>`. The tinker cannot run `sbatch`, push to `AE_BRANCH`, force-push,
run `rm -rf`, or use ssh. Read its result with `ae report <id>`; merge it with `ae accept <id>`.

A tinker needs a RUNNING standby. `ae tinker` and `ae launch` never submit one on their own,
because a standby uses GPU budget. You have three options:
- start one with `ae pool <tier>`;
- pass `--jobid <J>` to reuse an allocation you hold;
- pass `--topup`: it fills the requested tier only, up to its configured pool size (`AE_DBG_*_POOL`).
  If the new standby has not started yet, the command stops; run it again when the standby runs.

## Where things live

Everything below is inside `slurm-agentic-engineering/` on the laptop. Neither git repo tracks
it, so back it up yourself, or set `AE_HOME` to a directory that you version.

| path | contents |
|---|---|
| `config.sh` | site config (Babel values + your two lines) |
| `PROJECT.md` | the science: objective, criteria, protocol, owner amendments |
| `cluster/CARD.md`, `cluster/BABEL.md` | Babel facts (card: read; reference: grep) |
| `state/STATE.md`, `state/CHECKLIST.md` | current scientific state; live plan |
| `state/FINDINGS.md`, `state/DECISIONS.md` | results (append-only); dated decisions |
| `state/IMPLEMENTATION-LOG.md` | harness changes and operational lessons (never results) |
| `state/LEDGER.jsonl` | one line per submission: expid, jobid, commit sha, recipe hash |
| `exp/`, `inv/`, `results/`, `log/` | experiment definitions, tinker briefs, harvested distillates, monthly reasoning log |

On Babel, `~/ae/` holds pinned code (`code/`), job scripts (`jobs/`), Slurm logs (`out/`),
results before harvest (`results/`), per-run scratch (`run/`), tinker dev worktrees (`work/`) and
tinker briefs and agent logs (`inv/`). `ae report <id>` prints a tinker's report from `work/<id>/.ae-report.md`. Datasets and checkpoints go to
`/data/user_data/$USER` (500 GB, compute nodes only). `/home` is 100 GB: never put checkpoints there.

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
| `AE_INV_PREFIX` | optional | tinker branch prefix (default `inv`); set a unique one when another agent shares the git remote |
| `AE_DBG_EXCLUDE` | optional | nodes no standby may use, e.g. a node with a known GPU fault |
| `AE_MAX_GPUS_PER_USER`, `AE_MAX_SUBMIT` | no | 24, 100 (`preempt_qos`) |
| `AE_HARVEST_MAX_KB` | no | per-experiment harvest cap, 2048 |
| `AE_AGENT_CMD` | no | tinker agent command (default `claude --permission-mode acceptEdits`) |

## Commands
```
ae paths | init [--no-claude-md] | setup | doctor
ae pool [cpu|gpu|gen|all] | pool <ncpu> [ngpu] | attach [cpu|gpu|gen]
ae submit <expid> [--after a,b] [--replace] [--allow-dirty]
ae status [--changed] | logs <expid> [n] | harvest [expid] | wait <expid> [s] | cancel <expid> | prune [--yes]
ae slurm <squeue|sacct|sinfo|sprio|sstat|show> [args] | slurm <cancel|hold|release|requeue|update> <jobid> ...
ae tinker <id> [--gpu|--gen] [--jobid J] [--topup] < brief.md
ae investigate <id> | launch <id> [--gpu|--gen] [--jobid J] [--topup] | report <id> | accept <id>
ae-watch [--once] [--suppress-done RE] [--when-complete RE:N:LABEL]
ae-capacity [hours] | ae-topup <queue-file> [interval]
```
`ae help` prints the full list. `ae pool cpu` holds CPU standby only. Plain `ae pool` also holds
2 GPU standby in each GPU pool, which is 4 GPUs of quota with the default sizes.

## Reset for a new project
The reset restores the workspace documents (`PROJECT.md`, `cluster/{CARD,BABEL}.md`,
`state/{STATE,CHECKLIST,FINDINGS,DECISIONS,IMPLEMENTATION-LOG}.md`) to the templates. It changes
nothing else: not code, git, `state/LEDGER.jsonl`, `results/`, `log/`, `exp/`, `inv/`, or an existing
`config.sh`. It only creates `config.sh` and the project `CLAUDE.md` when they are missing.
```bash
python3 slurm-agentic-engineering/scripts/reset_project.py --target .            # dry run: prints the plan
python3 slurm-agentic-engineering/scripts/reset_project.py --target . --apply    # backs up, then resets
```
Backups go to `<workspace>/.reset-backups/<UTC stamp>/`. A second run does nothing. The script
never runs git. Add `--no-claude-md` if you do not want a project-root `CLAUDE.md`.

## Tests
```bash
bash tests/test-preamble.sh          # preemption-vs-walltime logic
bash tests/test-cli.sh               # CLI entry points, paths, init, Babel defaults, permissions
python3 tests/test_reset_project.py  # reset utility: dry run, apply, backups, idempotence, safety
bash tests/test-e2e-local.sh         # the real `ae` on the Babel defaults against mock ssh/Slurm
```
On Babel, the self-tests (`ae-smoke`, `ae-smoke-dep`, `ae-smoke-gen`) are the end-to-end tests.
Run them after any change to `bin/` or `lib/`.

## Known limits
- The tinker allowlist matches only the first word of a command (Claude Code permission rules).
  Tests need `env …` and `python …`, so both are allowed. The allowlist therefore guards against
  mistakes, not against a hostile agent. Deny rules cover the dangerous direct forms.
- `part=auto` uses `sbatch --test-only` estimates. They break a tie; they do not promise a start time.
- By default, nothing versions the workspace (see "Where things live").
