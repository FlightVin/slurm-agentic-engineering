# Implementation log — agentic-engineering system

Durable record of what was built, what broke, and what was learned. A fresh
session can read this to understand *why* the system is shaped as it is.
Append-only; newest section at the bottom.

> **IF YOU ARE AN AGENT FOLLOWING `PROJECT.md` AND RUNNING EXPERIMENTS: READ THIS
> FILE FOR CONTEXT, BUT DO NOT WRITE TO IT.** Write your findings, reasoning and
> per-experiment notes to `agentic-engineering/log/YYYY-MM.md` instead.
>
> This file is the **harness's own** implementation history — how `bin/ae`,
> `lib/`, the cluster integration and the templates came to be, and which defects
> shaped them. Only write here when you change the harness itself.


## 2026-09-17 — initial build

### Repo state established
- Laptop repo: `wllms/`, branch **`vineeth-agent`** created from updated `origin/main` (2756709).
- `origin/new-data` (4 commits ahead of main) left untouched on the remote; nothing lost.
- `agentic-engineering/`, `CLAUDE.md`, `.claude/settings.local.json` excluded via
  **`.git/info/exclude`**, NOT `.gitignore` — `.gitignore` is tracked and shared with
  a collaborator (repo is `HarshilBhatia/wllms`).

### Verified cluster facts (measured, not assumed)
| Fact | Value | Why it matters |
|---|---|---|
| ssh auth to login node, unmultiplexed | **5–31 s**, high variance | orchestrator issues dozens of commands; unusable without multiplexing |
| ssh with ControlMaster | ~0.9 s (remote shell startup on load ~18) | 0.9 s is the *floor*; multiplexing removes the auth handshake, not shell startup |
| `sacct` retention | **2+ years** (rows exist from 2025-09-01) | status is durable and derivable — never store it |
| `sacct` `Comment` field | **NOT persisted** (`AccountingStoreFlags = (null)`) | commit sha cannot be recovered from Slurm → the ledger must exist |
| GitHub auth from compute | works **without** agent forwarding (key `FlightVin`) | batch jobs can pull/push on their own |
| Compute outbound internet | yes (api.anthropic.com / api.wandb.ai reachable) | compute-side Claude agents are viable |
| GPU standby scheduling | **2.5–3.5 h** (tier-1 `preempt` queue) | GPU standby is expensive to keep warm |
| CPU standby scheduling | **5 seconds** (`preempt_cpu_qos`, separate quota) | → made CPU the DEFAULT tinkering tier |
| tooling on compute | claude, tmux, git 2.52, python3, jq, rsync all present | — |

### Bugs found by actually testing (all fixed)
1. **`scp` does not expand `$HOME`** in remote paths (it is SFTP; `ssh` does expand).
   → `ensure_link` now resolves `AE_REMOTE_ROOT`/`AE_REMOTE_REPO` to literals once
   per invocation (`$RROOT`/`$RREPO`).
2. **`ssh` consumes stdin**, so `rsh` inside a `while read` loop ate the here-string
   and the loop ran once. → `rsh()` now uses `ssh -n`. Affected `harvest` and `status`.
3. **Backticks inside a double-quoted `printf`** were executed (`fg: no job control`)
   and corrupted `FINDINGS.md`. → single-quoted format string.
4. **`$AE_SHA` empty inside a phase.** `phase` runs its command in a child `bash -c`,
   so variables must be **exported**, not merely set. `$AE_RESULTS` worked only because
   the parent shell expanded it at call time. → preamble now exports all `AE_*`.
5. **tmux started from `srun --overlap` dies when that step exits.** Slurm cleans up the
   step's processes. → the **standby batch job** now hosts a long-lived tmux *server*;
   `launch` adds a *window* to it, so the agent outlives the launching step.
6. **Headless agent blocked on permissions.** `--permission-mode acceptEdits` allows
   file edits but still gates every Bash call, and nobody is there to approve. The agent
   did the work, could not `git commit`/`push` or write its report, and exited. It
   diagnosed this itself. → scoped allowlist in `lib/tinker-permissions.json`
   (git/test/read commands allowed; `sbatch`/`scancel`/`srun`, pushes to the
   authoritative branch, force-push, `rm -rf`, `ssh`/`scp` **denied**). Chose
   least-privilege over `--permission-mode bypassPermissions` deliberately.
7. **`claude --add-dir <d> "<prompt>"` swallowed the positional prompt**
   ("Input must be provided either through stdin or as a prompt argument").
   → dropped `--add-dir`; the agent writes its report to `.ae-report.md` *inside* its
   own worktree, git-excluded, so no extra directory permission is needed.
8. A linked worktree's git dir has **no `info/` directory**; appending to
   `info/exclude` failed. → `mkdir -p "$GD/info"` first.

### Design decisions locked
- **Dirty tree at submit: REFUSE** (`--allow-dirty` auto-commits). A run must be
  attributable to a commit, and an unpushed sha cannot be materialised as a worktree —
  so this is enforced structurally, not by convention.
- **`afterany` + each job checking its own precondition**, never `afterok`. A parent
  that bundles evaluation can fail its eval while producing a perfectly good artifact;
  `afterok` would cancel every dependent.
- **No handler/monitor jobs.** The laptop is persistent by invariant, so cluster-side
  self-healing is dead weight. This is the layer that failed in the previous attempt.
- **Two standby tiers.** CPU is the default (5 s to schedule, separate quota, 0 GPUs);
  GPU is opt-in via `--gpu` (hours to schedule, costs the 24-GPU budget).
- **Squash-merge on accept**; the `inv/*` branch is kept as the WIP archive.

### End-to-end verification on Babel (all bounded, all passed)
| Test | Result |
|---|---|
| `ae setup` / `ae doctor` | remote layout created; ssh, git, GitHub auth, Slurm, quota all verified |
| CPU standby | RUNNING in **5 s**; tmux server up |
| `ae submit` (gpus=0) | auto-routed to `preempt_cpu_qos`; detached worktree at the sha |
| pinned-commit check | job asserted `git rev-parse HEAD == $AE_SHA` — **passed** |
| requeue simulation | resubmitted with results present → **every phase skipped** |
| `ae tinker` full loop | agent read brief → wrote file → committed `62fe07a` → **pushed to GitHub from the compute node with no agent forwarding** → wrote a conforming report |
| `ae report` / `ae accept` | squash-merged to `vineeth-agent`; `inv/*` kept as archive |
| dependency chaining | dependent held at `Reason=Dependency`, ran only after the parent reached a terminal state; `chain.json` confirms ordering |
| `ae harvest` | 28 KB total for two experiments; `FINDINGS.md` appended |
| `ae status --changed` | prints `no change` when idle → cheap polling wakes |

### Known limitations / not yet exercised
- **GPU standby never reached RUNNING** during implementation (queue ETA 2.5–3.5 h).
  The CPU tier exercised the identical code path (same `standby.sh`, same tmux
  server, same launch path), so the mechanism is verified; only GPU *scheduling
  latency* is unverified, and it is a queue property, not our code.
- **A real preemption mid-experiment was not observed** (smoke jobs run for
  seconds). The requeue path was verified by simulation — resubmitting with
  results present, which is exactly what Slurm re-executes on requeue. The
  USR1 preemption-vs-walltime discriminator is logic-reviewed, not fired in anger.
- `--replace` does **not** auto-rewire dependents. Documented in `DECISIONS.md`.
- `ae` issues several sequential ssh calls per command (~0.9 s each). Fine
  interactively; batch them if `status` is ever put on a fast loop.

## 2026-09-17 — final audit

### Issues found and FIXED during audit
| # | Severity | Finding | Fix |
|---|---|---|---|
| S8 | **HIGH** | **Experiment recipe was not pinned.** `agentic-engineering/` is git-excluded, so editing an `exp/*.sh` does not dirty the tree; the ledger recorded only the project sha. Two different runs could claim the same identity. | ledger now records `expsha` (sha256 of the exp file); generated script archived per `(sha, expsha)` instead of overwritten; `harvest` copies it to `results/<expid>/job.sh` |
| S9 | **HIGH** | **Silent data loss in `harvest`.** A job can leave the queue before its last writes are visible over NFS. Harvesting immediately saw 0 KB, copied nothing, and still wrote `.harvested` — permanently marking it collected. Reproduced, then fixed. | settle-retry on empty remote dir; post-copy verification refuses to mark `.harvested` if the remote had artefacts and none were copied |
| A2 | MEDIUM | `AE_MAX_SUBMIT` defined but never used; `AE_MAX_GPUS_PER_USER` only printed in `doctor`. Both documented as "quota guards". These are PENDING reasons, not rejections, so an over-quota job silently pends. | both now enforced in `cmd_submit` before anything is pushed or submitted |
| T3 | MEDIUM | `rsh`/`scp` had no `ConnectTimeout` — a connection attempt could hang indefinitely. | `ConnectTimeout=20` on both (`rscp` wrapper added); `ServerAliveInterval 15`/`CountMax 3` in ssh config bounds a dead connection at ~45 s |
| B1 | MEDIUM | **Bootstrap/brief conflict.** `tinker-bootstrap.md` says "commit early and often"; a brief said "do NOT commit". The agent resolved it correctly and flagged the ambiguity itself. | explicit `PRECEDENCE` section: the brief wins, and the agent must say which it followed |
| D1 | LOW | `ARCHITECTURE.md`/`OPERATOR.md` described the pre-fix ledger schema. | updated for `expsha` and the harvest verification |
| D2 | LOW | `CLAUDE.md` referenced `state/log/`, which did not exist, and a bare `STATE.md`. | created `log/README.md` (pedagogy log); references made absolute |

### Verified working (bounded tests, this audit)
- All 15 `ae` commands dispatch and have implementations; every documented `ae <cmd>` exists.
- Guards: dirty tree refused · duplicate live submit refused · unknown expid refused ·
  dependency on a never-submitted experiment refused · wrong-branch refused ·
  `ae wait` on unknown expid refused · `ae cancel` on a live job works.
- Recipe pinning: `expsha` recorded == file hash; mutating the file changes it;
  archived script is per-`(sha,expsha)`.
- Harvest race: reproduced the failure, fixed, re-tested with the exact triggering
  sequence (submit → wait → immediate harvest) → 2 artefacts + `job.sh` returned.
- `ae tinker` one-shot: branch + brief + agent launch + report, verified via `ae report`.
- `ae attach` emits a correct `srun --overlap --pty` command.
- No hidden-knowledge references to any prior conversation in any doc.
- Every path referenced as a link in the docs resolves.

### Still NOT verified (and why)
- **GPU standby reaching RUNNING** — queue ETA 2.5–3.5 h. Same code path as the CPU
  tier (identical `standby.sh`, tmux server, launch path), which is verified. To
  verify: `ae pool` then `squeue -u $USER -n ae-dbg` after a few hours.
- **A real mid-experiment preemption** — smoke jobs run for seconds. Requeue was
  verified by simulation (resubmit with results present is exactly what Slurm
  re-executes). To verify: submit a long job, `scancel --signal=USR1` it, and read
  the log for the preemption-vs-walltime branch in `lib/preamble.sh`.
- **The standby WIP-commit handler firing on a real preemption** — same reason.
  To verify: `scancel --signal=TERM <standby jobid>` with a dirty dev worktree, then
  check `git log` on that `inv/*` branch.

## 2026-09-17 — second audit pass (deeper: targeted what pass 1 did not test)

Pass 1 tested the happy paths and doc consistency. Pass 2 attacked the logic that
only fires under conditions hard to observe. It found four more defects, two of
them in the preemption machinery that is the system's whole reason for existing.

| # | Severity | Finding | Status |
|---|---|---|---|
| P1 | **HIGH** | `_left_secs` returned **0 for `UNLIMITED`** (bash arithmetic turns a non-numeric word into 0). A job with no walltime would read as "0s left" and self-requeue on every preemption, discarding the 2-min grace window. Found by unit test; this path had never executed. | FIXED + unit test added |
| P2 | **HIGH** | **The standby WIP-commit handler was deferred up to 30 s** behind a foreground `sleep 30`. bash defers traps until the current foreground command finishes. Measured latency after fix: **1 s**. | FIXED, measured |
| P3 | MEDIUM | **Two standby allocations on the same node shared one tmux socket** (`duplicate session: ae-host`), so one's `kill-server` would destroy the other's running agents. | FIXED: per-allocation socket `tmux -L ae-$SLURM_JOB_ID`, attach hint updated |
| P4 | MEDIUM | `ae pool` counted **COMPLETING** jobs as live capacity, so it refused to top up while old allocations drained — leaving the pool empty exactly when being replaced. | FIXED: `-t R,PD,CF` |
| P5 | LOW | `save_worktrees` swallowed all errors (`2>/dev/null || continue`). A handler whose purpose is not losing work must not fail silently. | FIXED: every skip now states its reason |

### Correction to an in-flight claim
I initially called P2 a FAILURE of the WIP handler. That was wrong and I corrected
it on evidence: the handler did commit (`41985dc`), it was merely late, and my
check ran at 12 s. The defect was latency, not failure.

### Pass-2 tests
- `_left_secs` unit test: 10 cases incl. `D-HH:MM:SS`, `MM:SS`, `SS`, empty,
  `UNLIMITED`, `INVALID`, garbage → all pass. Saved as `tests/test-preamble.sh`.
- Decision-boundary table printed and checked around the 300 s threshold. Default
  on UNKNOWN is deliberately "self-requeue": a false *walltime* only loses the
  grace window, whereas a false *preemption* silently ends the chain.
- WIP handler: dirty worktree → `scancel --signal=TERM` → committed in **1 s**.
- `exp_meta`: multi-line `#EXP` headers, all four keys, defaults.
- `ae` path resolution is cwd-independent.
- Project-specific leakage: zero hits for project nouns in `bin/`, `lib/`,
  `templates/` — site values live only in `config.sh`.
- Final regression after all fixes: standby on isolated socket → tinker loop →
  chained experiments → harvest, 44 KB returned, 2 + 1 artefacts, `job.sh` included.

## 2026-09-17 — third audit pass: closed the previously-unverified gaps

Passes 1 and 2 left three items "implemented but not fully verified". Pass 3
forced all three rather than re-surveying. **No new defects found** — the
mechanisms behaved as designed under real conditions.

### VERIFIED: USR1 discriminator, BOTH branches, in anger
This is the logic the whole system rests on, and until now it had never executed.

**Preemption branch** (`exp/ae-preempt-branch.sh`, 30-min walltime, external USR1):
```
*** USR1 with 1771s of walltime left -> this is PREEMPTION, not the limit.
*** NOT self-requeueing: Slurm requeues after the grace window, [...]
state=RUNNING elapsed=0:41   Restarts=0
```
Correctly did NOT self-requeue and did NOT consume the grace window. This is
exactly the defect the original `~/scripts` had (they self-requeued 46s into a
6h08m allocation, killing the step 0.8s later).

**Walltime branch** (`exp/ae-requeue.sh`, 3-min walltime, `--signal=B:USR1@120`):
```
[+36s] *** USR1 near the walltime (144s left) -> self-requeue to chain
       ===== AE JOB START =====
       *** REQUEUE ATTEMPT #1 (appending to same log) ***
       attempt 1 -> restarted -> completing
sacct -D: 10483205 REQUEUED 00:00:36 | 10483205 COMPLETED 00:00:02  (same JobID)
result: {"requeued": true, "attempt": 1}
```
Full chain verified: self-requeue → same JobID → `SLURM_RESTART_COUNT` → append
-mode log → phase completes on the restart.

### VERIFIED: concurrent tinkering agents
Two launched simultaneously. Separate worktrees on separate branches
(`inv/ae-cc1`, `inv/ae-cc2`), separate tmux windows on the same per-allocation
socket, both produced independent conforming reports, both trees left clean.
Isolation is by construction and now also by test.

### STILL BLOCKED BY ENVIRONMENT: GPU standby reaching RUNNING
`ae-dbg` job 10482599 has been PENDING since ~19:30 with a Slurm start estimate
of 21:50 — consistent with the documented 2.5-3.5h tier-1 queue. This is a queue
property, not a code property: the CPU tier exercises the identical `standby.sh`,
tmux server and launch path and is verified. **Verification procedure:** run
`ae pool`, then later `squeue -u $USER -n ae-dbg`; once RUNNING, `ae tinker <id>
--gpu` and confirm the agent lands with a GPU visible via `nvidia-smi`.

### Retained test experiments
`exp/ae-requeue.sh` and `exp/ae-preempt-branch.sh` are kept as permanent
regression tests for the preemption machinery. `ae-requeue` costs ~4 minutes of
1 CPU and is the only test that exercises a real requeue; run it after any change
to `lib/preamble.sh`.

## 2026-09-17 — fourth audit pass: remaining untested paths

Passes 1-3 covered the happy paths, doc consistency, and the preemption
machinery. Pass 4 attacked the paths still never executed. Four defects found,
two of them silent.

| # | Severity | Finding | Status |
|---|---|---|---|
| U4 | **HIGH** | **`squeue -j ""` lists EVERY job instead of failing.** A missing/malformed jobid therefore made `harvest` read `live=RUNNING` and skip the experiment **silently, forever** — it could never be collected and said nothing. Same trap latent in `wait`/`logs`/`status`. | FIXED: `valid_jobid()` guard at every consumer; ledger parsing also relaxed to tolerate spaced JSON |
| U3 | **HIGH** | **`du -sk` under-reports on this NFS**: 2 KB for a genuine 3 MB file. The harvest size cap — whose whole purpose is stopping large artefacts coming home — would therefore have passed anything. | FIXED: `du -sk --apparent-size` via `remote_kb()`; cap now correctly refuses (`3073KB > 2048KB`) |
| U5 | MEDIUM | **Pinned worktrees were never reclaimed.** One per `(expid, sha)`, forever: 7 smoke tests alone left **58 MB** under `~/ae/code`. Unbounded growth on a shared filesystem. | FIXED: new `ae prune [--yes]`, dry-run by default, refuses to touch live or unharvested runs. Reclaimed 60 MB → 1.7 MB |
| U6 | LOW | `du` allocated-vs-apparent discrepancy also made footprint reporting misleading (58 MB allocated vs 15 MB apparent). | Consistent `--apparent-size` everywhere |

### Verified working this pass
- `--allow-dirty`: auto-committed (`b95451c`), tree clean afterwards.
- **Multi-dependency**: `after=a,b` → `--dependency=afterany:10483297:10483205`,
  correct colon form; `ae-multidep` COMPLETED and harvested.
- **Harvest size cap** now genuinely fires (was silently passing).
- `ae prune` protects live and unharvested runs; only the main checkout remained.
- Archived recipes are correctly per-`(sha, expsha)`: `ae-smoke-59d2eb7-6d80f80e0168.sh`
  and `ae-smoke-b95451c-6d80f80e0168.sh` coexist — same recipe, two project shas.
- Compute repo remains on `main` and clean; it is only a worktree source.

### STILL BLOCKED BY ENVIRONMENT
GPU standby (`ae-dbg` 10482599) has been PENDING since ~19:30; Slurm's start
estimate has slipped 21:50 → 23:13. This is the documented tier-1 queue, not a
code fault; the CPU tier exercises the identical code path and is verified.
**Verification:** `squeue -u $USER -n ae-dbg`; once RUNNING, `ae tinker <id> --gpu`
and confirm `nvidia-smi` sees a GPU inside the agent's window.

## 2026-09-17 — fifth audit pass: FRESH-SESSION TEST (the one that mattered)

Passes 1-4 were self-audits and found 7/5/0/4 defects. Pass 5 delegated a
**context-free** session, given only `CLAUDE.md` and told to operate the system
read-only. It found 12 findings, including **two behavioural traps that four
self-audits missed entirely**. Lesson recorded plainly: inspecting your own work
has a ceiling; a reader without your assumptions does not.

| # | Severity | Finding | Status |
|---|---|---|---|
| **F7** | **CRITICAL** | **`$AE_RESULTS` was keyed by expid alone.** Resubmitting an experiment at NEW code found the previous run's outputs, **skipped every phase, and reported COMPLETED having done nothing.** Confirmed on disk: job 10483297 at sha `b95451c` logged only "already complete, skipping". This silently defeats the pinning invariant and produces wrong science. | FIXED: `AE_RUNDIR`/`AE_RESULTS` now keyed by `<sha>-<expsha>`. Same identity → skip (requeue preserved); new sha OR new recipe → run. All three cases re-tested. |
| **F6** | **HIGH** | **`.harvested` was sticky across resubmission.** Nothing cleared it, so a fresh run could never be collected and `ae status` displayed stale results as current. Confirmed: local `identity.txt` showed job 10483006/sha 59d2eb7 while the ledger pointed at 10483297/b95451c. | FIXED: marker records the identity; harvest/status/prune compare against the ledger's current identity. |
| F1 | HIGH (onboarding) | **The bootstrap did not execute.** `CLAUDE.md` says "run `ae status`" but `ae` is not on PATH; the invocation form appeared only in `OPERATOR.md`, which the bootstrap tells you *not* to read. A fresh session's first action was `command not found`. | FIXED: invocation stated in `CLAUDE.md`. |
| F2 | MEDIUM | `ARCHITECTURE.md`/`OPERATOR.md` both claimed "`ae launch` calls `ae pool`". It did not — it just died. | FIXED by making the code true: `cmd_launch` tops up the pool before failing. |
| F4 | MEDIUM | `ae doctor`'s standby check covered the **GPU tier only**, so it reported a healthy pool while the *default* CPU tier could be entirely gone. | FIXED: both tiers reported. |
| F3 | LOW | Architecture said "the 24 h walltime"; the default CPU tier is 12 h. | FIXED |
| F5 | LOW | `CLAUDE.md` forbade editing `LEDGER.jsonl`; the tool's own error said "Fix state/LEDGER.jsonl". | FIXED: one sanctioned repair path documented. |
| F8 | LOW | Three docs gave three different destinations for state evicted from `STATE.md`. | FIXED: unified. |
| F9 | LOW | `templates/inv.md` named the report `report.md`; the real path is `.ae-report.md`. A hand-written brief copying the template would make `ae report` print "(none)". | FIXED |
| F10 | LOW | `ae pool` takes TWO positionals (cpu, gpu), `ae attach` takes a SLURM job name not a "tier", `ae launch`'s `--gpu`/`--jobid` were undocumented. | FIXED in help |
| F12 | LOW | `ae doctor` prints `maxlab*` QOS on every run; `CARD.md` never mentioned them. Also: compute clone sits on `main` while the authoritative branch is `vineeth-agent` — reads as a mismatch until you realise worktrees are cut from fetched refs. | FIXED: both explained in `CARD.md` |
| — | — | `STATE.md` claimed "built and verified end to end", stronger than `IMPLEMENTATION-LOG.md` supports. | FIXED: now names the unverified gap |

### Regression tests for F6/F7 (all passed)
- New sha → phases **RUN** (job 10483352).
- Same sha + same recipe → phases **SKIP** (job 10483364) — requeue semantics intact.
- Same sha + **changed recipe** → phases **RUN** (job 10483370, recipe `e486f88be343`).
- Harvest collected the new identity; `.harvested` = `73b63c8-e486f88be343`;
  `identity.txt` job == ledger's latest job. Stale-result display eliminated.

### Consequence for earlier audit claims
My pass-4 "`--allow-dirty` verified" was **invalid**: that submission was the very
run that silently no-op'd under F7. Re-verified after the fix.

## 2026-09-17 — sixth pass: SIMULATED REAL WORKFLOW + second fresh-session test

Ran a realistic diamond DAG (`sim-pretrain → {sim-mid-a, sim-mid-b} → sim-report`)
with downstream experiments authored and chained WHILE the parent ran, plus a
second context-free session test. **The first run appeared to succeed and was
silently broken in two ways.** Both were caught, both fixed.

| # | Severity | Finding | Status |
|---|---|---|---|
| **S1** | **CRITICAL** | **A set-but-not-exported variable silently made a precondition check pass with its input absent.** `phase` runs `bash -c`, where an unexported var expands to empty, so `[ ! -f $CKPT ]` became `[ ! -f ]` = false. `sim-mid-a/b` reported COMPLETED having verified nothing and emitted invalid JSON (`"base_loss": ,`). | FIXED: phases now run under **`bash -u`** — an unset variable is an error. Proven: identical phase went from `passed (WRONG) exit=0` to `CKPT: unbound variable exit=127`. |
| **S2** | **CRITICAL (doc)** | **The cross-experiment data contract was written nowhere.** `$AE_RUNDIR`/`$AE_RESULTS` are keyed `<expid>/<sha>-<expsha>`, which a downstream job **cannot compute** — so artifacts placed there are unreachable. `templates/exp.sh` offered exactly those two destinations and called `$AE_RUNDIR` "persists across requeue", inviting precisely the wrong inference. Every real chain depends on this. | FIXED: contract stated in `templates/exp.sh`, `lib/preamble.sh`, `PROJECT.md` (now a REQUIRED section declaring `PROJ_DATA`) and `cluster/CARD.md`. |
| **S3** | **HIGH (doc was wrong)** | **`/data/user_data` is NOT mounted on the login node.** Verified: login node `ls` fails; a probe job on `babel-l5-32` read a checkpoint written by `babel-n5-20`. So it is shared *between compute nodes* only. `BABEL.md` said "shared: Yes" without that caveat, and the orchestrator therefore cannot read project data at all. | FIXED: verified filesystem table added to `cluster/CARD.md`. This is *why* distillates must go to `$AE_RESULTS` under `/home`. |
| S4 | MEDIUM | Project-path predicates are not sha-keyed, so a resubmit at new code skips phases guarded by a durable project artifact (F7 one layer up). | DOCUMENTED in the contract; the correct pattern is to version the project path or compare a recorded sha. |

### A REAL preemption finally occurred, unprompted, and recovered correctly
`sim-pretrain` (job 10483601) was genuinely preempted mid-training:
```
sacct -D:  PREEMPTED 00:01:46 babel-n5-20  |  COMPLETED 00:00:02 babel-n5-20
log:       [+22s] *** USR1 with 697s of walltime left -> this is PREEMPTION, not the limit.
           [+103s] checkpoint written ... PHASE train -- ok
           *** REQUEUE ATTEMPT #1 ***  -> all phases "already complete, skipping"
```
The discriminator classified it correctly, did **not** waste the grace window, the
job finished its work inside the grace period, Slurm requeued the same JobID, and
the retry skipped everything in 1 s. Dependents stayed `PENDING/Dependency`
throughout the requeue. **This closes the last standing unverified gap.**

### Final DAG on the fixed system (all COMPLETED)
`sim-pretrain → {sim-mid-a, sim-mid-b} → sim-report`, harvested to 80 KB total.
The handoff is demonstrably real: `base_loss: 0.4000` propagated from the
checkpoint into both variants (previously empty), and `sim-report` ran on
`babel-n5-28` — a different node from the pretrain — proving compute-to-compute
sharing of `PROJ_DATA`.

---

## 2026-09-18 — fixes made while starting the hash→strategy project

### H1. `ae pool` counted jobs Slurm had parked forever as live capacity
Slurm holds a job at `Priority=0` with reason `launch_failed_requeued_held` when a node
fails to launch it. Both CPU standbys hit this on `babel-o9-20`; they showed as `PENDING`,
so `_pool_tier`'s `-t R,PD,CF` count read them as alive and the pool never topped up.
`ae tinker` then refused with "no RUNNING standby", and the pool would have stayed empty
indefinitely. **FIXED**: `_release_held` releases exactly that hold before counting —
never an operator or admin hold, which is a human decision.

### H2. A resume read the same 240 MB checkpoint four times
`resolve_resume` digested the file, `_read_validated` digested and `torch.load`ed it,
`read_checkpoint_metadata` did both again, and `load_checkpoint` a third time: four
sha256 passes and three loads of identical bytes. Measured **stalling for over ten
minutes** on this cluster's NFS under load (inv/orient01, killed at exit 137). On a
preemptible partition that cost is paid at *every* requeue and can exceed the work the
requeue was meant to preserve. **FIXED** in `infra/checkpoint.py`: a one-entry cache
keyed by (path, size, mtime_ns), the redundant pre-digest in `resolve_resume` dropped,
and `drop_cached_checkpoint()` called once the weights are in the model so the payload is
not held for the rest of training. Net: one digest, one load.

### H3. `position_labels.py` hardcoded a log(40) ceiling for hash rows
Correct for the pretraining corpus, wrong for every roster-based one — it produced
"excesses" as large as −3.689 in the previous round's reports (its own defect list, §13.3).
**FIXED**: `label_session` now takes `focal_hash_ids`/`opp_hash_ids` (which also admits
reserved ids as hashes) and a `hazard` override, with `fixed_length_hazard(n)` for
constant-length corpora. Defaults are unchanged, so the pretraining reports are unaffected.

### H4. `prepare_corpus.py` hard-imported one session factory
It imported `naive_poker_v3_midtraining_experiments.generator` by name, so a second
roster package could not reuse its preempt-safe sharding without forking the file.
**FIXED**: the experiment names its own `generator_module` and optional
`validator_module`; both default to today's values. `verify_split` gained `validate=` and
`allow_reserved=`, needed because a corpus whose player hashes ARE reserved ids is
otherwise rejected for containing exactly what it is supposed to contain.

### Operational note, not a bug
Importing torch from `/data/user_data/.../envs` on a busy node can take **ten minutes**
(process in D-state on `folio_wait_bit_common`). It is a one-off per process, so it costs
a training job nothing measurable, but it makes short interactive probes look wedged.

### H5. `multiprocessing.Pool` wedges at startup on this partition, intermittently
Corpus generation hung three times, each with the same signature: the parent blocked in
`waitpid` (`do_wait`), a handful of zombie children, and far fewer workers than requested
ever created — 12 of 32 the first time, 5 of 20 the third. Python 3.10's `Pool` has no
recovery from a worker that dies during or after startup: `imap` waits forever for a
result that will never arrive.

What it is NOT: memory (parent RSS 88–206 MB against a 20–32 GB allocation), and not
worker count as such — 20 workers completed all 23 corpora of the other shard without
incident, then 20 workers wedged on a different node. Pinning BLAS to one thread per
worker (which it needed anyway: 32 workers × 32 default threads is ~1,000 threads from
one job) did not prevent the third hang. The remaining explanation is how many forks the
node will grant at that moment, which varies with what else is on it.

**Mitigation, not a fix:** fewer workers than allocated CPUs, so there is slack at fork
time. It costs throughput and does not make the hang impossible. What makes it cheap is
that `prepare_corpus` is resumable per corpus AND per shard: a wedged job loses only the
corpus in flight, and a resubmit skips every finished one. Three restarts cost minutes.

**Worth knowing before trusting a long CPU job here:** a wedged Pool looks exactly like a
quiet one. The tell is `ps --ppid <parent> -o stat | sort | uniq -c` showing zombies with
the parent in `do_wait`. `PYTHONUNBUFFERED=1` is what makes the silence visible at all —
without it, python block-buffers into the job's log pipe and a healthy job also goes quiet
for minutes at a time.

### H6. Transient NFS write errors killed finished training runs
Three training jobs died within one minute of each other, all at a checkpoint save, as
soon as the fleet was large enough to checkpoint concurrently:

```
OSError: [Errno 512] Unknown error 512        (ERESTARTSYS leaking to userspace)
InterruptedError: [Errno 4] Interrupted system call   (EINTR)   x2
```

One of them had completed **all 812 steps** and every validation pass, and died on the
final save — the most expensive possible moment. The same save took 8 s early in the run
and 69 s once twenty jobs were writing into the same NFS mount.

**FIXED** in `infra/checkpoint.py`: a bounded retry (5 attempts, linear backoff) around a
generation write. It cannot mask a real failure — each attempt writes atomically under a
fresh name so a failed one leaves no partial generation, its leftovers are unlinked, and
the last error is re-raised if all attempts fail. `InterruptedError` is an `OSError`
subclass, so both observed errors are covered.

**Judgement, recorded because CLAUDE.md forbids auto-retrying a failed experiment:** these
three were resubmitted by hand. That rule exists so a *deterministic* failure stops and
waits for judgement. This one was diagnosed to a transient I/O fault, fixed at the source,
and the resubmissions run at the fixed commit — and because the run directory is durable
and `resume: auto` works, each resumed from its last good checkpoint rather than starting
over. That is a decision, not a retry loop.

### H7. The checkpoint cadence was the cause, not the victim
H6 treated the transient NFS errors as something to retry. Retrying was right but it was
not the fix, because the load causing them was self-inflicted:

At 5% of an 812-step run the checkpoint interval was 29 steps — **28 generations per
variant, of which 26 are deleted immediately after**. 6.7 GB written to keep 480 MB, per
variant, across 46 runs sharing one NFS mount: roughly 255 GB of pure waste. Once ~20 jobs
were checkpointing concurrently the mount returned, in one hour:

```
OSError [512] ERESTARTSYS   on a FINAL save, after all 812 steps had completed
InterruptedError [4] EINTR  x2
OSError [116] ESTALE        stale file handle
FileNotFoundError [2]       a file that existed moments earlier
ModuleNotFoundError         a PINNED WORKTREE that briefly stopped being readable
```

Individual saves went 8 s → 70 s, so the writes were also most of the wall clock: 28 saves
at 70 s is 33 minutes of an ~50 minute job.

**FIXED**: save every 25% instead of 5% — four generations per variant, still landing
exactly on both epoch boundaries, with a preemption costing at most 203 steps (under three
minutes at 0.8 s/step). Validation is now a separate, still-frequent interval, because a
validation pass is four seconds and a checkpoint is 240 MB. `runtime.*` is excluded from
`experiment_signature`, so every running job resumed across the change.

**The general lesson for this harness**: "bound what a preemption can destroy" is a
preference with a price, and the price is paid on a shared filesystem by every other job.
A 5% interval is sensible for a run measured in hours and absurd for one measured in
minutes. `make_config` now derives both intervals from the run length rather than fixing
a fraction.

### H8. A coarse done-predicate silently pinned every result to its first schema
Each evaluation phase carried `test -f <last artefact>.json` as its done-predicate, while
`run_all` separately skips any report whose recorded `SCHEMA_VERSION` matches the
evaluator's. The phase predicate fires FIRST, so once a corpus had been evaluated once,
the phase was skipped and `run_all` never ran — and therefore never noticed that four
evaluators had gained measurements. Resubmitting all 23 jobs at the versioned commit
changed nothing: `scoring_ep2` stayed at schema 1 in all 23 corpora, `rollout_ep2` in 25.

Two gates for the same decision, and the coarse one wins. **FIXED**: the phase predicate
is now `false` and the fine, version-aware skip inside `run_all` is the only one. Re-running
the phase is cheap precisely because that skip is precise.

**The tell was a number, not a log.** Every job reported COMPLETED and every log looked
clean; the only symptom was that a column I had just added stayed empty. Worth
remembering: `ae status` COMPLETED means the recipe ran, not that it recomputed anything.

### H9. `ae status` and `ae harvest` were O(n) SSH round trips
Both issued one `sacct -j <id>` per experiment not currently in the queue, and `harvest`
additionally a `squeue -h -j <id>` per candidate. `squeue` was already batched into a
single call in `status`; `sacct` never was. Fine at the five experiments the harness was
built against, and at sixty — where a finished project lands — `ae status` exceeded 120 s
and `harvest` ran for minutes before moving a byte.

**FIXED**: one `sacct -j <comma-list>` and one `squeue` per command, with the results
matched by job id in awk. Measured: `ae status` 120 s+ → **17 s**, `ae harvest` minutes →
**13.6 s**. Nothing about the data changes; it was purely per-call latency (~1–2 s against
a loaded login node) multiplied by ledger length.

**Worth generalising**: anything in this harness that loops over experiments and talks to
Slurm inside the loop will do this. The pattern to keep is the one `status` already used
for `squeue` — collect the ids, ask once, match locally.

## 2026-09-19 — full evaluation-code audit: 22 defects in the hashmap instruments

Eight passes over 31 measurements x 54 corpora (1,674 cells). Passes found
**7 / 7 / 3 / 0 / 2 / 1 / 0 / 1** new defects; the last full pass found one
(`evaluate_one.sh`), so a ninth pass was run and found nothing. Durable record:
`results/hashmap-audit/audit_matrix.md`, regenerated by
`scripts/hashmap_audit_matrix.py` from `defects.json` + `shapes.json`.

**The shape of nearly all of them: a statistic and its reference computed over different
objects.** A guess credited against the header token while the prior counted players. A
causal delta measured toward the nearest rival while the swap installed the rotation
successor. A mean over buckets of unequal size called "pooled". A rename rate averaged
across two arms that differ by 0.67. Not one was a crash, and every job had reported
COMPLETED.

### The ones that move a published number

| id | what | effect |
|---|---|---|
| A1 | `identification` credited the HEADER HASH, not the player that played. On `cx_switch` the header names the playing strategy in exactly 40/80 sessions by design. | its oracle ceiling was **0.525**; measured correctly it is **1.000**. The reported "in-context identification collapsed" was a mis-aimed test. |
| A2 | the win-hypothesis counterfactual was `others[0]`, not the rotation successor | wrong on 2 of 4 hashes on every four-hash side; on `cx_many_to_one` it compared a matchup against itself |
| A3 | `rollout` picked the rival by token, so `FOCAL_2` (`g0#2`) was compared against `FOCAL_0` (`g0`) — the same policy | a quarter of that corpus's prompts contributed exact zeros to both arms |
| A4 | `moved_toward_named` was `null` in all 54 harvested summaries | the corrected causal quantity had never been computed anywhere |
| A19 | the identification prior counted TOKENS while accuracy credited PLAYERS | `cx_many_to_one`'s chance rate is 0.500, not the reported 0.300 |
| A20 | `focal_binding_mean` was `sum(bucket means)/7` over buckets holding 1,1,3,5,10,15,15 hands | `cx_switch` pooled binding 0.671 → **0.788**; within 0.01 elsewhere |
| A10 | the rollout rename rate pooled the named and swapped arms | named **0.000** on 48/54 corpora, swapped **0.389-0.673**; the pooled ~0.33 describes neither |
| A12 | the causal statistics had no `attainable` filter while binding did | dilutes by 32-37% on the two fold-rate designs; **0%** on `cx_four_focal`, so it is not that corpus's explanation |

### A21 — a shell defect that hid for 27 jobs

`a43074f` spliced the retry loop into the middle of `evaluate_one.sh`'s `--resummarise`
invocation, leaving

    exit $status \
        --resummarise

`exit` with two arguments prints `exit: too many arguments`, **returns 1 and does not
exit** — verified directly. So the re-summarise pass never ran, the retry loop's status
was discarded, and every job fell through to a second unguarded `run_all`. The string
`too many arguments` is in the harvested log of **all 27** evaluation experiments and
nobody read it. No number was wrong, because no summariser had changed; the repair
mechanism was simply absent.

**A log line in 27 of 27 jobs is not noise.** Same lesson as H8, from the other side:
there, COMPLETED hid a skip; here, a clean-looking job hid an error it printed.

### A18 — the corpus, not the instrument

`cx_four_focal_close` is described in `roster.py` as the same design "at roughly HALF the
measured behavioural separation". The frozen roster says otherwise: `c0 = g0`, `c1 = g2`,
`c2 = g1` are the same underlying candidates (separation exactly 0.0000), so it shares
**three of four players** with `cx_four_focal`. Mean separation is unchanged
(0.292 → 0.294); only the MINIMUM halves (0.205 → 0.106).

`freeze.pick_nearest_separation` targets the minimum deliberately and documents why. The
selection is right and the description is wrong — and the honest description is the
stronger one: the two corpora differ in exactly one player.

### The fix that had to be found twice

`moved_toward_named` was added at `f0a7b7e` and looked up `swap_maps[label].get(true_hash)`
— a token STRING against a map keyed by token ID. It missed at every position, the
accumulator stayed empty, the summariser wrote `null`, and the report's fallback quietly
served the superseded quantity. The job succeeded.

Fixed at `16afb4b` with `vocab.TOKEN_TO_ID[true_hash]` **plus a `RuntimeError` that fails
the job when a side with two or more hashes produces no samples**. The guard is the
durable part: a silently empty accumulator reads exactly like a real result.

### What the audit cost, and what it bought

A 59-test suite in `tests/dataset_specific_evaluators/naivepoker_v3_hashmap/`, one test
per defect plus the metric arithmetic and the edge cases. 59/59 pass, alongside 51
pre-existing evaluator tests and 31 generator tests. `scripts/hashmap_audit_diff.py`
compares every reported field before and after a code change and separates changes a
recorded defect explains from changes nothing explains.

### Verification: every figure that moved, measured at the fleet's own sample size

Four corpora were re-evaluated at 120 sessions on the fixed code — on CPU, because the
GPU fleet was still queued — and compared field by field against the pre-audit
distillates. **No previously-correct number moved.** Largest delta in any field that no
recorded defect touches: **0.0014**, on all four corpora. Every model-independent
quantity is bit-identical.

| corpus | figure | before | after | defect |
|---|---|---|---|---|
| `cx_four_focal__seen` | causal delta | +0.0016 | **+0.1830** | A4 — 100x, from the same forward passes |
| | where the prediction lands | not measured | **+0.5808** (hand 0), **+0.7579** (first action) | new diagnostic |
| | hypothesis direction | 1.000 | **0.500** | A2 |
| | hypothesis true magnitude | 0.1304 | **0.1149** | A2 |
| | pooled binding | 0.6092 | **0.6167** | A20 |
| `cx_four_focal_close__seen` | causal delta | −0.0277 | **+0.1625** (n=20) | A4 |
| `cx_many_to_one__seen` | hypothesis direction | 0.500 | **1.000** | A2 |
| | hypothesis true magnitude | 0.1519 | **0.1824** | A2 |
| | pooled binding | 0.8020 | **0.8082** | A20 |
| | same-player embedding pairs | counted as separations | **+0.047, reported separately** | A5 |
| | identification prior | 0.300 (tokens) | **players and tokens both reported** | A19 |
| `cx_switch__seen` | pooled binding | 0.6713 | **0.7886** | A20 |
| | hypothesis direction | **−1.00** | **null**, 2 pairs ambiguous | A17 |
| | oracle ceiling | 0.525 | **1.000** | A1 |
| | binding at the first action | not measured | **+0.0350** against +0.2202 at hand 0 | A9 |
| all | rename rate | ~0.33 pooled | **0.000 named / 0.680 swapped** | A10 |

**A2 moved two corpora in opposite directions** — `cx_four_focal` down, `cx_many_to_one`
up — which is what a fix looks like when its direction was not chosen. The downgrade is
the more useful half: on `cx_four_focal` the model does NOT predict the direction of the
matchup's win-rate change, and a 1.000 scored against a counterfactual the swap never
produced had hidden that.

### The claim this retires

`cx_switch` is built so its header carries no information about the player: the generator
announces the other focal hash on odd session indices. Whatever binding reads there
cannot come from the header.

    binding at hand 0        +0.2202
    binding at first action  +0.0350

The previous write-up called binding at hand 0 "the HASH-ATTRIBUTABLE figure, and it is
the headline". On the corpus built so that the hash attributes nothing, it reads +0.22.
**0.185 of that is the model watching the player act inside the first hand.** The
first-action bucket added by this audit is the statistic that claim needed.

### Tests

`tests/dataset_specific_evaluators/naivepoker_v3_hashmap/` — 59 tests, one per defect
plus the metric arithmetic and the edge cases. At `b372c18`: **110 evaluator tests and 31
generator tests pass** (the 110 includes 51 that predate this audit).

### H10. `ae submit`'s GPU guard was stricter than Slurm, and it cost a second queue traversal

`ae submit` counted GPUs across `R,PD` and refused once the sum reached
`AE_MAX_GPUS_PER_USER` (24). Slurm's `MaxTRESPU=gres/gpu=24` caps **allocated** GPUs, not
submitted ones, so a 27-job fleet against a 24-GPU quota is legal: the surplus sits on
`QOSMaxGRESPerUser` and starts automatically as earlier members finish.

The guard therefore left three of the 27 evaluation experiments unsubmitted
(`shared-mixed`, `shared-silly`, `shared-stoch` — six corpora). When the queue is
minutes deep that is harmless. On 2026-09-19 it was not: 529 higher-priority jobs ahead,
backfill never reaching us, four hours with no start. Those three would have needed a
SECOND traversal of that queue, roughly doubling wall-clock for no benefit.

**FIXED**: count RUNNING gpus, which is what Slurm enforces, and report rather than
refuse when the pending surplus exceeds the quota. `MaxSubmitPU` is still a hard refusal,
because that one genuinely rejects.

### Slurm diagnosis, 2026-09-19 — recorded because the conclusion is counter-intuitive

Four hours with 24 jobs `PENDING (Priority)` and nothing started. Every configuration
hypothesis was ruled out with evidence before blaming the queue:

| checked | finding |
|---|---|
| partition / QOS | `preempt` / `preempt_qos`, correct |
| dependency | `Dependency=(null)` |
| a QOS or assoc limit | all 25 jobs report `Reason=Priority`; none reports a limit |
| resource request | `ReqTRES` **byte-identical** to jobs that COMPLETED on 18 Sep |
| GPU type / node feature | `Features=(null)`, `gres/gpu=1` untyped — any of the 7 models qualifies |
| reservation | none |

**The cause is fairshare, and it is not ours.** Priority decomposes as
Partition 2000 + FairShare 336 + JobSize 498 + QOS 33 + Age 15 = **2883**, against a
pending-queue median of 3234 and p75 of 2912 over 686 jobs — bottom quartile, with **529
jobs outranking us**. `PriorityWeightFairShare` is 5000 and we score 336, a factor of
0.067. `sshare` says why: our account holds 10.65% of cluster usage and **our own
RawUsage is 28,093 of the account's 2,971,561,283 — 0.0009%**. The deficit is inherited
from another member's history, decaying on a 7-day half-life.

**An earlier guess in this log's spirit was wrong and is corrected here**: cancelling our
idle standby pools to "free fairshare for the GPU jobs" cannot help. Our entire usage is
nine ten-thousandths of one percent of the account's.

**Why `squeue --start` returns `N/A` for us**: `SchedulerParameters = bf_continue` only,
so `bf_max_job_test` is the default 100. With 529 ahead, backfill never evaluates our
jobs. It is a depth cutoff, **not** a walltime rejection — confirmed by 31-day jobs
holding estimates while 59 one-hour jobs do not.

**A real mistake of ours, separately**: the experiments requested `time=08:00:00` for work
whose measured runtime is 8:40–24:12 with an all-time maximum of 53:17. Nine times the
observed worst case. Corrected to `02:00:00`. **It bought nothing measurable** — still
0 of 27 jobs hold a backfill estimate afterwards — but over-requesting walltime on a
shared preemptible partition is wrong regardless, and it cost only 15 priority points of
lost age (0.5%).

**Age accrues at `PriorityWeightAge` 1000 over `PriorityMaxAge` 12 days ≈ 3.5 points per
hour.** Reaching the queue median by ageing alone would take ~100 hours. That is the
pessimistic bound; the optimistic one is ~2 hours, from 295 GPU starts per hour against
529 ahead. Slurm itself declines to estimate.

## 2026-09-20 — starting naive-poker v4/v5

### V1. `bin/v4-watch`: a task tracker, because PROJECT.md requires one
PROJECT.md §0 asks that "any and all task runs must be tracked through scripts written
by you that indicate back when something salient (success / failure) happen" and that
every task have a monitor **and a timeout**. `agentic-engineering/bin/v4-watch` polls
`ae status`, emits one line per STATE CHANGE for the `v4-*` experiments, and exits 0 when
all are COMPLETED, 2 if any reached a non-COMPLETED terminal state, 1 on its own timeout.

It is a **laptop-side** poller driven by the orchestrator, not a cluster-side daemon —
CLAUDE.md forbids the latter and it is the layer a previous attempt at this project
failed on.

Two things worth keeping:
- **It emits on every terminal state, not just COMPLETED.** A watcher that greps for
  success is silent through a failure, and silence is indistinguishable from "still
  running".
- **The first version died immediately on `declare: -A: invalid option`.** The
  orchestrator runs on macOS, whose `/bin/bash` is 3.2 and has no associative arrays.
  The seen-state map is a temp file now. Anything added to `bin/` has to assume bash 3.2.

### V2. The queue, not compute, is the constraint — and it changed how jobs are sized
On 2026-09-20 the `preempt` partition held **753 pending against 158 running**. Nothing
of ours started in 40 minutes, *including the CPU standby pool*, which `CARD.md` measures
at 5 seconds and which uses a separate quota. That is the same fairshare deficit
diagnosed on 2026-09-19, still decaying.

Consequence for how v4 work is packaged, recorded because it is the opposite of the
obvious choice: corpus generation is ~5 hours per split, and the obvious job is one long
allocation. A long allocation on a saturated partition is close to unbackfillable — this
log already records ours sitting PENDING for ten hours for exactly that reason. So the
2B-token splits run as **four separate ≤2-hour, 16-CPU, 0-GPU jobs** that rely on
`prepare_corpus`'s per-shard resumability and the preamble's near-walltime self-requeue
to make progress across several short, backfillable allocations. `--splits` was added to
`prepare_corpus` for this; `corpus_meta.json` is written by whichever split finishes
second.

### V5. `v4-watch` kept its seen-state in a fresh temp file, so every re-arm was noise
A monitor expires after 30 minutes and has to be re-armed. Each re-arm started with an
empty seen-state map, so it re-reported all fifteen experiments as though they had just
changed — fifteen spurious events per re-arm, which is precisely the noise that trains a
reader to stop looking at the notifications. **FIXED**: the map persists at
`$TMPDIR/v4watch-<prefix>state`, and `V4_WATCH_STATE=<fresh path>` resets it on purpose.

Worth generalising: a watcher's job is to report CHANGES, so its idea of "what I have
already reported" has to outlive the process. Anything in this harness that is re-armed
on a timer has the same property.

### V7. Waiting on a deep queue: one detached poller, not a re-armed monitor
A `Monitor` expires after 30 minutes and must be re-armed, so watching a queue measured
in hours produced a dozen empty wake-ups and a dozen "nothing changed" turns. PROJECT.md
§0 asks for the opposite — "spawn shells to poll the remote compute or task runs without
wasting tokens".

`agentic-engineering/bin/v4-wait-for-start` is one detached shell that sleeps, polls
`ae status`, and exits exactly once: when any `v4-*` experiment stops being PENDING, or
when its deadline passes. It wakes for ANY non-pending state, not just RUNNING — a
FAILED or TIMEOUT is progress of a kind that matters more, and a watcher that greps only
for success is silent through a failure.

Use the re-armed monitor for something that changes often and the detached poller for
something that changes once. Getting that backwards is cheap in tokens and expensive in
attention.

## 2026-09-21 — the gates ran, and two of the three failures were real

The queue cleared overnight. All four corpora generated and COMPLETED; every gate job
failed. Three distinct causes, and the split between them is the point.

| job | cause | class |
|---|---|---|
| `v4-smoke`, `v4-stage4`, `v4-corpus-verify` | `ModuleNotFoundError` | my mistake, avoidable |
| `v4-stage3` | `test_validator_rejects_a_tampered_stack` — the VALIDATOR was wrong | real defect |
| `v4-stage6` | `test_packing_wastes_little` — 22.9% waste, not <6% | real defect |

### V8. `$PY scripts/x.py` does not put the repo root on `sys.path`
Thirteen existing scripts in `scripts/` open with
`sys.path.insert(0, str(Path(__file__).resolve().parents[1]))`. Mine did not. Running a
file as a script puts its OWN directory on `sys.path[0]`, so every `from
dataset_generation...` failed. The corpus jobs survived only because they are invoked as
`$PY -m dataset_generation...`, where `-m` puts the cwd on the path instead.

**The lesson is not about `sys.path`.** It is that the convention was already in the
repository, in thirteen files, and I wrote seven new ones without looking. Grep the
directory you are adding to.

### V18. afterany means every job checks its own precondition
`ae` chains with `afterany` on purpose: `afterok` would cancel a dependent whose input is
fine merely because the parent's own eval failed. The corollary is that each job must
check its own precondition, and the four corpus jobs had none worth the name -- they
checked disk space. Their real precondition is that Stage 4 passed, so Stage 4 writes
`sequence_length.json` only when every gate did, clears any stale copy before it starts,
and each corpus job refuses to run without it. The marker carries the one number Stage 4
produces that anything downstream needs, so the gate and the hand-off are one file.


> The project-science entries that were here (V3, V4, V6, V9-V17) have moved to
> `agentic-engineering/log/2026-09.md`, per this file's banner: they are findings
> about naive-poker v4, not about the harness. Only harness changes stay here.

## 2026-09-21 — `general` partition added (second pool)

`normal` QOS was granted, closing the gap diagnosed on 2026-09-17. Verified:
`sacctmgr` shows `normal` in the association; a dry run to `-p general -q normal`
resolves; and **no QOS lists `normal` in its Preempt set**, so `general` is
genuinely non-preemptible.

Harness changes (all generic, no experiment needs rewriting):
- `#EXP part=preempt|general`, default `preempt`.
- Routing: `part=general` → `-p general -q normal`. **`gpus=0` is forced back to
  `preempt_cpu_qos` regardless of `part=`** — `normal` carries the same
  `MinTRES=gres/gpu=1` trap, so a CPU-only job there would pend on QOSMinGRES
  forever.
- Quota guards are now **per pool** (preempt 24 gpu/100 jobs, general 8 gpu/50).
  Counting them together would refuse a general job because preempt is busy.
- Walltime guard: `general` MaxTime is 2 days; longer is refused at submit with
  the preempt alternative named, rather than letting Slurm reject it opaquely.
- `hms_to_secs()` helper added.

Tested: GPU job → `-p general -q normal`; `gpus=0 part=general` → warned and
routed to `preempt_cpu_qos`; `time=3-00:00:00 part=general` → refused. Generated
`#SBATCH` directives confirmed on the cluster. Probe jobs cancelled.

Note at time of writing: `general` had 0 idle nodes and 67 pending jobs, and the
dry run estimated a ~1-day start. It is not a fast lane, it is a safe one.

---

> **IF YOU ARE AN AGENT FOLLOWING `PROJECT.md` AND RUNNING EXPERIMENTS: READ THIS
> FILE FOR CONTEXT, BUT DO NOT WRITE TO IT.** Write your findings, reasoning and
> per-experiment notes to `agentic-engineering/log/YYYY-MM.md` instead.
>
> This file is the **harness's own** implementation history — how `bin/ae`,
> `lib/`, the cluster integration and the templates came to be, and which defects
> shaped them. Only write here when you change the harness itself.
>
> (Repeated here because this file is long and append-only — an agent that
> scrolled to the bottom to append should see it before writing.)

## 2026-09-21b — dual-pool standby, latching, and `part=auto`

- `ae pool [cpu|gpu|gen|all]` — three tiers now, selectable. `gen` is GPU standby
  on the non-preemptible pool. Legacy numeric form still works.
- `ae attach --gpu` / `ae tinker --gpu` take the oldest RUNNING GPU standby in
  **either** pool (latch onto whichever won the race); `--preempt`/`--gen` force one.
- `#EXP part=auto` — `sbatch --test-only` against both pools, take the earlier ISO
  start time. Auto-forces preempt when `time > 2 days`.
- **Why not `-p preempt,general`:** measured — `--test-only` accepts
  `-p preempt,general -q preempt_qos` and reports "in partition general", which
  general's `AllowQos=normal` forbids. It does not validate the pairing, so a real
  multi-partition submit is undefined. We ask each pool separately instead.
- Measured 2026-09-21, same 1-GPU/1h job: general `2026-09-22T08:13` vs preempt
  `2026-10-03T07:05`. Neither pool is reliably faster; that is the whole reason
  `auto` exists.
- **But `--test-only` is a poor oracle.** It predicted general at `2026-09-22T08:13`;
  an actual general standby submitted a minute later was RUNNING in ~60 s. `auto`
  is a tie-breaker, not a prediction. Warm standby in both pools is the reliable
  way to start work immediately.
- Preempt-safety verified unchanged on general: generated job carries `--requeue`,
  `--signal=B:USR1@120`, USR1 discriminator, `run_child`, phase skipping.
  Note `run_child` now uses `env -u BASH_ENV -u ENV bash --noprofile --norc
  -euo pipefail -c` — stronger than the `bash -u` I originally added.

### V19. Do not `--amend` a commit that a submitted job is pinned to
Invariant 2 says every run is pinned to a commit and `ae submit` materialises a detached
worktree at that sha. Amending after submitting rewrites the sha, so the commit the
ledger names becomes unreachable from any branch and is eventually garbage-collected —
at which point the only record of what a run actually executed stops resolving.

It happened once. The job had already fetched and was RUNNING, and the amend only fixed
a shell-mangled commit message, so the tree was byte-identical — but `ae submit` had
already pushed the original sha, so the next submit failed on a **non-fast-forward
push**: the branch no longer contained the commit the remote (and the ledger) named.

**The repair is `git rebase origin/<branch>`, never `push --force`.** Force-pushing
would delete the commit a submitted run is pinned to, which is precisely what invariant 2
exists to prevent — and `ae` refusing the push is that invariant defending itself. The
rebase replays the new work on top of the pushed commit and silently drops the amended
one as a duplicate, since its tree is identical. History stays linear, the pinned sha
stays reachable, and nothing is rewritten on the remote.

The cheaper habit is not to amend after submitting. If a commit message needs fixing
after a job is out, fix it in a follow-up commit or leave it: the message is prose and
the ledger entry is evidence.

Shell note that caused it: backticks inside a double-quoted commit message are command
substitution. Use single quotes, or no backticks, in `git commit -m` from a shell.

## V20 — a batch step cancelled before it wrote a byte (unexplained, one occurrence)

`v5-session-example` job 10552056 went FAILED with `ExitCode 0:53`, batch step CANCELLED,
after 1:56 on babel-m5-28. **No `.out` file was created at all**, so the preamble never
ran and no project code executed.

Evidence gathered before acting: the node was `mix`, `REASON=none`, with six other jobs
running on it and one COMPLETED in the same window — so "bad node" had no support. Nothing
in the recipe changed between the attempt that worked and this one except a commit to a
Python file the job never reached.

Resubmitted **once**, on the judgement that a step which produces no output has not run
the experiment, so this is not the deterministic failure CLAUDE.md says to stop on. It
landed on **babel-m5-28 again** and completed in 40 s, which rules the node out rather
than implicating it.

Left unexplained on purpose. One occurrence, no mechanism, and a guess written down as a
cause is worse than a recorded gap. If a batch step is ever again cancelled with no `.out`
file, this is the second data point and the pair is worth chasing.

## 2026-09-27 — `hms_to_secs` octal bug (v7 session)
`ae submit` printed `d*86400+08: value too great for base` for `time=08:00:00`: bash
arithmetic reads a leading-zero field as octal, so 08/09 hours, minutes or seconds broke the
walltime-to-seconds conversion used by the general-pool 2-day guard and `part=auto`. The
submit itself went through (the conversion only feeds those checks). Fixed with `10#`
prefixes; verified 08:00:00 -> 28800, 2-00:00:00 -> 172800, 09:09:09 -> 32949.

## 2026-09-28 ae: optional `gtype=` #EXP key
`#EXP ... gtype=RTX_PRO_6000` -> `--gres=gpu:RTX_PRO_6000:<gpus>` (both partitions). Needed to
pin a diagnostic to one GPU type (v7 Blackwell NCCL probe). Absent key = previous behaviour.

## 2026-09-28 v7-watch fixes
Metric lines are prefixed by the preamble's [timestamp]; strip to the first '{' before json.loads
(progress had always printed step=0). Error grep no longer matches bare 'nan' / the start event.

- 2026-10-14 ~11:00: owner raised the harvest cap AE_HARVEST_MAX_KB 2048 -> 5120 (agentic-engineering/config.sh; config
  overrides the environment variable, so the cap lives there). Jobs should still emit summaries, not full logs.
- 2026-10-14 ~15:40: tinker permission refusals explained. lib/tinker-permissions.json allow-lists commands by their
  FIRST word: `env ...`, `bash ...`, `python ...` pass; a leading `VAR=value` (e.g. `CUDA_VISIBLE_DEVICES= ...`) or an
  absolute interpreter path (`/data/.../python`) is refused, and so are `git fetch` / `git merge`. Briefs must give the
  test command as `env CUDA_VISIBLE_DEVICES= PYTHONPATH=... /data/.../python -m pytest ...`. To start a tinker from a
  merged tree, push it to origin/inv/<id> first: `ae tinker <id>` checks out that branch when it exists.
- 2026-10-14 17:1x: lesson. v8o5fix's 31 tests exercised the loss, cache and config generator but never ran the generated
  config through config.py validation or a real train start, so every v2 run failed at train start (allow-list).
  Rule from now on: a change that adds a config key must include a test that validates the REAL generated config, and
  a new run family is released as ONE canary first (wait for its first training metrics line) before the rest.
- 2026-10-14 20:3x: `ae pool <N>` (numeric form) applies to ALL tiers (cpu gpu gen) and submitted 2 GPU + 2 general
  standbys; cancelled before any started. To add a CPU standby before expiry use `ae pool cpu` only after one has ended,
  or accept the gpu/gen side effects and cancel them at once.
