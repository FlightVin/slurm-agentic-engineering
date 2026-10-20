# agentic-engineering

A generic system for running experiments on a **preemptible** SLURM cluster with
a persistent laptop-side Claude as the orchestrator.

Nothing in `bin/`, `lib/`, `config.sh` or `cluster/` is project-specific. All
project science lives in `PROJECT.md`, `exp/*.sh` and `state/`.

## A fresh session reads exactly these, in order

| # | File | Lines | Why |
|---|---|---|---|
| 1 | `../CLAUDE.md` | 56 | your role, the loop, the rules (auto-loaded) |
| 2 | `state/STATE.md` | ≤60 | where the science stands right now |
| 3 | `cluster/CARD.md` | 57 | cluster facts and traps |
| 4 | `PROJECT.md` | ~30 | what this project is about |

Then run `ae status`. **That is the entire bootstrap.**

## Read only when a question demands it
| File | For |
|---|---|
| `ARCHITECTURE.md` | why the system is shaped this way |
| `OPERATOR.md` | the 12 operator questions, answered |
| `cluster/BABEL.md` | full cluster reference (853 lines — **grep, never load**) |
| `state/IMPLEMENTATION-LOG.md` | what was built, what broke, what was learned |
| `state/FINDINGS.md` | append-only results |
| `state/DECISIONS.md` | open questions |

## Layout
```
bin/ae                    the orchestrator (laptop-only)
config.sh                 THE ONLY file with cluster-specific values
lib/preamble.sh           job framework: traps, phases, requeue safety
lib/standby.sh            standby allocation (hosts the tmux server)
lib/tinker-launch.sh      starts a compute-side agent
lib/tinker-bootstrap.md   what that agent is told about how to behave
lib/tinker-permissions.json  its least-privilege allowlist
templates/exp.sh          copy this to define an experiment
templates/inv.md          copy this to brief a tinkering agent
exp/<expid>.sh            experiment definitions (~15 lines each)
inv/<id>/brief.md         investigation briefs
state/                    LEDGER, STATE, FINDINGS, DECISIONS, IMPLEMENTATION-LOG
results/<expid>/          harvested distillates
```

## Self-test
`exp/ae-smoke.sh` and `exp/ae-smoke-dep.sh` are the system's own end-to-end test:
they verify commit pinning, phase skipping, CPU-QOS routing, dependency chaining
and harvest, and cost seconds of CPU. After any change to `bin/` or `lib/`:
```
ae submit ae-smoke --replace && ae submit ae-smoke-dep --replace
ae wait ae-smoke-dep 300 && ae harvest
```
Expect `chain.json` with `"ran_after_parent": true`.

## Not in git
`agentic-engineering/`, `CLAUDE.md` and `.claude/settings.local.json` are listed
in `.git/info/exclude` (local-only; `.gitignore` is tracked and shared with a
collaborator). The orchestration surface is yours, on the laptop.
