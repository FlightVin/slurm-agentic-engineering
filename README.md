# slurm-agentic-engineering

A reusable harness for running research experiments on a preemptible Slurm cluster with a
persistent laptop-side AI agent as the orchestrator. **It ships tuned for CMU Babel**: the config
template, cluster card and cluster reference carry Babel's measured pools, QOSes, quotas, storage
layout and known traps, so a new Babel project fills in two values and runs. (Porting elsewhere means
editing `config.sh` and the cluster card; nothing in `bin/` or `lib/` names a cluster.) The agent plans, submits commit-pinned jobs,
delegates code changes to sandboxed compute-side agents, harvests small results, and keeps the
scientific state in a few short documents — while Slurm stays the only source of truth for jobs.

- **Operating manual:** [`agent.md`](agent.md) (canonical). `CLAUDE.md` points Claude Code at it.
- **Design:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · **Operator Q&A:** [`docs/OPERATOR.md`](docs/OPERATOR.md)
- **History:** [`examples/`](examples/README.md) — real documents from a finished study (inert).

## What it guarantees
- **Commit-pinned runs.** `ae submit` refuses a dirty tree, pushes, and runs the job in a detached
  worktree at that SHA; the recipe is hashed too (`expsha`). A requeue re-enters the same tree.
- **Slurm is the job-status authority.** Nothing caches job state; `ae status` asks `squeue`/`sacct`.
- **Preemption-safe jobs.** Phases with done-predicates, `--requeue`, a signal handler that tells
  preemption from walltime (`lib/preamble.sh`).
- **Bounded harvest.** Only `$AE_RESULTS` comes home, capped per experiment.
- **Review gate for code.** Compute-side agents work on `inv/<id>` branches under a least-privilege
  allowlist (no `sbatch`, no push to the authoritative branch, no force-push, no `rm -rf`, no ssh);
  `ae accept` squash-merges after you review.
- **No daemons.** Monitoring is a cheap script (`ae-watch`) that wakes the agent only on events.

## Layout
```
slurm-agentic-engineering/
  agent.md  CLAUDE.md  README.md  config.example.sh
  bin/ae            the CLI (laptop only)
  bin/ae-watch      event watcher: exits with one line when a job fails/completes
  bin/ae-capacity   measured GPU-hours, waits and preemptions per partition
  bin/ae-topup      optional ordered fleet submitter (submit caps, idle-pool fill)
  lib/              job preamble, standby host, tinker launcher/bootstrap/permissions
  templates/        exp.sh, inv.md (brief), project/ (workspace documents incl. the Babel card + reference)
  scripts/reset_project.py   initialise or reset workspace documents (dry-run by default)
  selftest/         ae-smoke + ae-smoke-dep (CPU pool, pinning, chaining), ae-smoke-gen (general pool)
  tests/            offline tests (preamble logic, CLI, reset utility, local end-to-end with mock Slurm)
  docs/  examples/
  -- created by `ae init`, git-ignored here (the project WORKSPACE) --
  config.sh  PROJECT.md  cluster/{CARD,BABEL}.md  state/  exp/  inv/  results/  log/
```
The workspace lives inside this directory by default and is ignored by this repo, so you can
`git pull` harness updates without touching project state. Override with `AE_HOME=<dir>`
(workspace) and `AE_REPO=<dir>` (project repo, default: the parent of this directory).

## Requirements
Laptop: bash, git, ssh, rsync, python3 ≥ 3.8, and an agent CLI (default: Claude Code). Babel: an
account with `preempt_qos`, `preempt_cpu_qos` and (for the second pool) `normal`; git and tmux are
already there; install the agent CLI under your home for tinkers; clone your project once.

## Integrate into a project
```bash
cd /path/to/your-project                        # a git repo with a remote the cluster can reach
git clone <url-of-this-repo> slurm-agentic-engineering   # or copy the directory in
echo "slurm-agentic-engineering/" >> .git/info/exclude    # keep harness + workspace out of project history
export PATH="$PWD/slurm-agentic-engineering/bin:$PATH"

ae init                 # config.sh (Babel), PROJECT.md, cluster/CARD.md + BABEL.md, state/*, ./CLAUDE.md
$EDITOR slurm-agentic-engineering/config.sh     # set AE_REMOTE_REPO and AE_BRANCH; the rest is Babel
ae paths                # check what resolved where (offline)
```
On Babel, once: `ssh babel 'mkdir -p ~/projects && git clone <project-url> ~/projects/<name>'`
(the path you put in `AE_REMOTE_REPO`). Then from the laptop:
```bash
ae setup                # remote layout under AE_REMOTE_ROOT + `ae doctor` (QOSes, live quotas, /home)
ae pool cpu             # warm CPU standby for tinkers (seconds on a quiet preempt_cpu_qos; can be an hour)
ae submit ae-smoke && ae submit ae-smoke-dep --after ae-smoke
ae submit ae-smoke-gen  # general pool + GPU + /data/user_data check (needs a GPU; may queue)
ae wait ae-smoke-dep 600 && ae harvest          # expect results/ae-smoke-dep/chain.json: "ran_after_parent": true
claude                  # start the orchestrator in the project root; it reads CLAUDE.md -> agent.md
```

### ssh (mandatory)
Every `ae` command is an ssh round trip; without connection sharing each one pays a multi-second
authentication. In `~/.ssh/config`:
```
Host babel
    HostName login.babel.cs.cmu.edu
    User <andrew-id>
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
    ServerAliveInterval 15
```

## Configuration (`config.sh`)
| variable | you set it? | Babel value / meaning |
|---|---|---|
| `AE_REMOTE_REPO` | **yes** | compute-side clone of the project (single-quoted, e.g. `'$HOME/projects/x'`) |
| `AE_BRANCH` | **yes** | authoritative branch; runs are pinned to it, tinkers can never push to it |
| `AE_HOST` | no | `babel` (your ssh alias) |
| `AE_PARTITION`, `AE_QOS_GPU`, `AE_QOS_CPU` | no | `preempt`, `preempt_qos`, `preempt_cpu_qos` |
| `AE_PARTITION_GEN`, `AE_QOS_GEN`, `AE_GEN_*` | no | `general`, `normal`; 8 GPUs, 10 running, 50 submitted, 2-day wall |
| `AE_REMOTE_ROOT` | no | `$HOME/ae` |
| `AE_DBG_*` | no | standby: CPU ×2 (12 h), preempt GPU ×2 (24 h), general GPU ×2 (2 days) |
| `AE_MAX_GPUS_PER_USER`, `AE_MAX_SUBMIT` | no | 24, 100 (`preempt_qos`) |
| `AE_HARVEST_MAX_KB` | no | per-experiment harvest cap, 2048 |
| `AE_AGENT_CMD` | no | tinker agent command (default `claude --permission-mode acceptEdits`) |

## Commands
```
ae paths | init | setup | doctor
ae pool [cpu|gpu|gen|all] | pool <ncpu> [ngpu] | attach [tier]
ae submit <expid> [--after a,b] [--replace] [--allow-dirty]
ae status [--changed] | logs <expid> [n] | harvest [expid] | wait <expid> [s] | cancel <expid> | prune [--yes]
ae tinker <id> [--gpu] < brief.md | investigate <id> | launch <id> | report <id> | accept <id>
ae-watch [--once] [--suppress-done RE] [--when-complete RE:N:LABEL]
ae-capacity [hours] | ae-topup <queue-file> [interval]
```

## Reset for a new project
Workspace documents (`PROJECT.md`, `cluster/{CARD,BABEL}.md`, `state/{STATE,CHECKLIST,FINDINGS,DECISIONS,
IMPLEMENTATION-LOG}.md`) can be restored to the pristine templates. Nothing else is touched: not
code, git, `state/LEDGER.jsonl`, `results/`, `log/`, `exp/`, `inv/`, or `config.sh` (create-only).
```bash
python3 slurm-agentic-engineering/scripts/reset_project.py --target .            # dry run: prints the plan
python3 slurm-agentic-engineering/scripts/reset_project.py --target . --apply    # backs up, then resets
```
Backups go to `<workspace>/.reset-backups/<UTC stamp>/`. Re-running is a no-op; it never runs git,
so a dirty tree is fine. `--missing-only` creates absent documents only (that is `ae init`).

## Tests
```bash
bash tests/test-preamble.sh        # preemption-vs-walltime logic
bash tests/test-cli.sh             # CLI entry points, path resolution, init, permissions rendering
python3 tests/test_reset_project.py  # reset utility: dry run, apply, backups, idempotence, safety
bash tests/test-e2e-local.sh       # the real `ae` on the Babel defaults against mock ssh/Slurm
```
On Babel the end-to-end tests are the self-tests above (`ae-smoke`, `ae-smoke-dep`, `ae-smoke-gen`);
run them after any change to `bin/` or `lib/`.

## Known limits
- The tinker allowlist matches a command's first word (Claude Code permission rules). `env …`
  and `python …` are allowed for running tests, so the allowlist is a guard against mistakes, not
  a security boundary against a hostile agent; denials cover the dangerous direct forms.
- `part=auto` relies on `sbatch --test-only` estimates, which are a tie-breaker, not a promise.
