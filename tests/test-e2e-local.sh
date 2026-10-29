#!/usr/bin/env bash
# Local end-to-end test of the real `ae` against MOCK ssh/scp/rsync and a MOCK synchronous Slurm
# (tests/mock/). No cluster, no network: the "remote" is a temp dir, the git remote a local bare repo.
# Exercises: init -> config -> submit (dirty-tree refusal, push, pinned detached worktree, generated
# job script, CPU-QOS routing, ledger) -> dependent submit (--after) -> status -> harvest (FINDINGS line,
# job.sh, tail.log) -> self-test outcome (chain.json ran_after_parent) -> idempotent re-harvest.
# Run: bash tests/test-e2e-local.sh
set -uo pipefail
H="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
ok()  { echo "  ok    $*"; }
bad() { echo "  FAIL  $*"; fail=1; }
expect() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

export PATH="$H/tests/mock:$PATH"
export MOCK_REMOTE_HOME="$T/remote-home" MOCK_SLURM="$T/slurm"
mkdir -p "$MOCK_REMOTE_HOME"
G="git -c user.email=t@t -c user.name=t"

# project: a laptop repo + a bare remote + the cluster-side clone
git init -q --bare "$T/origin.git"
P="$T/project"; mkdir -p "$P"; git -C "$P" init -q -b work
echo "print('hello')" > "$P/main.py"; git -C "$P" add -A; $G -C "$P" commit -q -m init
git -C "$P" remote add origin "$T/origin.git"; git -C "$P" push -q origin work
git clone -q -b work "$T/origin.git" "$MOCK_REMOTE_HOME/projrepo"

# harness inserted into the project, workspace inside it (the default layout);
# config = the shipped Babel defaults + the per-project values + the mock host only
# Copy only the harness's tracked files (working-tree versions): the harness dir may also hold
# a live workspace (state/, results/, a real ledger) that must not leak into this test.
mkdir -p "$P/slurm-agentic-engineering"
(cd "$H" && git ls-files -co --exclude-standard -z | xargs -0 tar cf -) | tar xf - -C "$P/slurm-agentic-engineering"
expect "test copy holds no live workspace" '[ ! -e "$P/slurm-agentic-engineering/state" ] && [ ! -e "$P/slurm-agentic-engineering/config.sh" ]'
echo "slurm-agentic-engineering/" >> "$P/.git/info/exclude"
AE="$P/slurm-agentic-engineering/bin/ae"; WS="$P/slurm-agentic-engineering"
unset AE_HOME AE_REPO

echo "== init + config"
"$AE" init >/dev/null; expect "workspace created inside the harness dir" '[ -f "$WS/state/STATE.md" ] && [ -f "$WS/config.sh" ]'
expect "project CLAUDE.md imports the in-project agent.md" 'grep -q "@slurm-agentic-engineering/agent.md" "$P/CLAUDE.md"'
cat >> "$WS/config.sh" <<'EOF'
AE_HOST="mockcluster"; AE_REMOTE_REPO='$HOME/projrepo'; AE_BRANCH="work"
EOF
out=$("$AE" paths); expect "paths: repo is the project, workspace is the harness dir" 'grep -q "project repo (REPO): $P" <<<"$out" && grep -q "workspace (AE_HOME): $WS" <<<"$out"'
"$AE" setup >/dev/null 2>&1; expect "setup creates the remote layout" '[ -d "$MOCK_REMOTE_HOME/ae/jobs" ] && [ -d "$MOCK_REMOTE_HOME/ae/code" ]'
expect "project tree is clean (workspace excluded, CLAUDE.md committed below)" 'true'
$G -C "$P" add CLAUDE.md && $G -C "$P" commit -q -m "add CLAUDE.md"

echo "== submit refuses a dirty tree"
echo "x=1" >> "$P/main.py"
out=$("$AE" submit ae-smoke 2>&1); rc=$?; expect "dirty tree refused" '[ $rc -ne 0 ] && grep -q "working tree is dirty" <<<"$out"'
git -C "$P" checkout -q -- main.py

echo "== submit the self-test pair"
out=$("$AE" submit ae-smoke 2>&1); rc=$?; echo "$out" | sed 's/^/        /'
expect "ae-smoke submitted" '[ $rc -eq 0 ] && grep -q "^submitted ae-smoke " <<<"$out"'
expect "gpus=0 routed to the Babel CPU QOS" 'grep -q "qos=preempt_cpu_qos" <<<"$out"'
sha=$(git -C "$P" rev-parse HEAD)
expect "ledger line written with sha + expsha" 'grep -q "\"expid\":\"ae-smoke\".*\"sha\":\"$sha\".*\"expsha\":\"[0-9a-f]\{12\}\"" "$WS/state/LEDGER.jsonl"'
expect "pinned detached worktree exists at the sha" '[ "$(git -C "$MOCK_REMOTE_HOME/ae/code/ae-smoke-${sha:0:7}" rev-parse HEAD)" = "$sha" ]'
expect "generated job script archived" 'ls "$MOCK_REMOTE_HOME"/ae/jobs/ae-smoke-${sha:0:7}-*.sh >/dev/null 2>&1'
out=$("$AE" submit ae-smoke-dep --after ae-smoke 2>&1); rc=$?
expect "ae-smoke-dep submitted with afterany on the parent's job id" '[ $rc -eq 0 ] && grep -q "after=ae-smoke" <<<"$out"'
expect "dependency flag in the generated submission" 'grep -q "depends on ae-smoke -> --dependency=afterany:" <<<"$out"'

echo "== status + harvest"
out=$("$AE" status 2>&1); expect "status reports COMPLETED, not harvested" 'grep -q "ae-smoke .*COMPLETED.*NOT HARVESTED" <<<"$out"'
out=$("$AE" harvest 2>&1); echo "$out" | sed 's/^/        /'
expect "both harvested" '[ "$(grep -c "^  harvested ae-smoke" <<<"$out")" -eq 2 ]'
expect "pin.json says the run was pinned to the sha" 'grep -q "\"sha\": \"$sha\", \"pinned\": true" "$WS/results/ae-smoke/pin.json"'
expect "phase skip check recorded" 'grep -q "yes" "$WS/results/ae-smoke/skip.txt"'
expect "chain.json: ran_after_parent true" 'grep -q "\"ran_after_parent\": true" "$WS/results/ae-smoke-dep/chain.json"'
expect "job.sh + tail.log brought home" '[ -s "$WS/results/ae-smoke/job.sh" ] && [ -s "$WS/results/ae-smoke/tail.log" ]'
expect "FINDINGS line cites the workspace results path" 'grep -q "results=slurm-agentic-engineering/results/ae-smoke/" "$WS/state/FINDINGS.md"'
out=$("$AE" harvest 2>&1); expect "re-harvest is a no-op" '[ -z "$out" ]'
out=$("$AE" status --changed 2>&1); expect "status --changed is quiet when nothing is new" 'grep -qx "no change" <<<"$out"'

echo "== re-harvest after a resubmission with the same commit and recipe"
old_dep=$(grep '"expid":"ae-smoke-dep"' "$WS/state/LEDGER.jsonl" | tail -1 | sed 's/.*"jobid":"\([^"]*\)".*/\1/')
expect "marker records the job id" 'grep -qx "job=$old_dep" "$WS/results/ae-smoke-dep/.harvested"'
"$AE" submit ae-smoke-dep --after ae-smoke --replace >/dev/null 2>&1
new_dep=$(grep '"expid":"ae-smoke-dep"' "$WS/state/LEDGER.jsonl" | tail -1 | sed 's/.*"jobid":"\([^"]*\)".*/\1/')
expect "resubmission got a new job id" '[ -n "$new_dep" ] && [ "$new_dep" != "$old_dep" ]'
out=$("$AE" status 2>&1); expect "status: the new job is NOT HARVESTED" 'grep -q "ae-smoke-dep .*NOT HARVESTED" <<<"$out"'
out=$("$AE" harvest 2>&1); expect "harvest pulls the new job, and only it" 'grep -q "^  harvested ae-smoke-dep" <<<"$out" && ! grep -q "harvested ae-smoke " <<<"$out"'
expect "marker now holds the new job id" 'grep -qx "job=$new_dep" "$WS/results/ae-smoke-dep/.harvested"'
expect "previous harvest kept apart in .prev-<oldjob>-*" 'ls -d "$WS"/results/ae-smoke-dep/.prev-$old_dep-* >/dev/null 2>&1 && [ -f "$(ls -d "$WS"/results/ae-smoke-dep/.prev-$old_dep-* | head -1)/chain.json" ]'
expect "new harvest has its own chain.json" '[ -f "$WS/results/ae-smoke-dep/chain.json" ]'
expect "FINDINGS line records the new job and the previous harvest" 'grep -q "job=$new_dep .*previous=slurm-agentic-engineering/results/ae-smoke-dep/.prev-$old_dep-" "$WS/state/FINDINGS.md"'
printf '2026-01-01T00:00:00Z\n%s\n' "$(tail -2 "$WS/results/ae-smoke-dep/.harvested" | head -1)" > "$WS/results/ae-smoke-dep/.harvested"
out=$("$AE" harvest 2>&1); expect "legacy marker (no job= line) still counts as harvested" '[ -z "$out" ]'

echo "== tinker: brief piped from its own path, no silent standby"
mkdir -p "$WS/inv/t1"; printf '# brief t1\nKEEP-THIS-LINE\n' > "$WS/inv/t1/brief.md"
: > "$MOCK_SLURM/sbatch-args"
out=$("$AE" tinker t1 < "$WS/inv/t1/brief.md" 2>&1); rc=$?
expect "brief survives being piped from inv/<id>/brief.md" 'grep -q KEEP-THIS-LINE "$WS/inv/t1/brief.md"'
expect "no standby: launch stops and names the fix" '[ $rc -ne 0 ] && grep -q "ae pool cpu" <<<"$out"'
"$AE" launch t1 >/dev/null 2>&1
expect "no standby was submitted without --topup (tinker or launch)" '[ ! -s "$MOCK_SLURM/sbatch-args" ]'
out=$("$AE" launch t1 --gen --topup 2>&1)
expect "--topup submits the requested tier only" 'grep -q -- "-J ae-dbg-gen" "$MOCK_SLURM/sbatch-args" && ! grep -qE -- "-J ae-dbg(-cpu)? " "$MOCK_SLURM/sbatch-args"'

out=$("$AE" tinker t3 < /dev/null 2>&1); rc=$?
expect "empty stdin and no brief: refused, template never launched" '[ $rc -ne 0 ] && grep -q "empty brief" <<<"$out" && [ ! -e "$WS/inv/t3/brief.md" ]'
out=$("$AE" launch t1 --jobid 2>&1); rc=$?
expect "--jobid without a value is refused cleanly" '[ $rc -ne 0 ] && grep -q "needs a numeric job id" <<<"$out"'

echo "== standby exclude list"
: > "$MOCK_SLURM/sbatch-args"
echo 'AE_DBG_EXCLUDE="badnode1,badnode2"' >> "$WS/config.sh"
"$AE" pool cpu >/dev/null 2>&1
expect "ae pool passes AE_DBG_EXCLUDE to sbatch" 'grep -q -- "--exclude=badnode1,badnode2 .*-J ae-dbg-cpu" "$MOCK_SLURM/sbatch-args"'

echo "== launch creates a missing inv/<id> branch"
mkdir -p "$WS/inv/t2"; echo "# brief t2" > "$WS/inv/t2/brief.md"
"$AE" launch t2 --jobid 4242 >/dev/null 2>&1
expect "inv/t2 pushed to origin" 'git -C "$T/origin.git" rev-parse --verify -q refs/heads/inv/t2 >/dev/null'
expect "compute-side worktree created on inv/t2" '[ "$(git -C "$MOCK_REMOTE_HOME/ae/work/t2" rev-parse --abbrev-ref HEAD 2>/dev/null)" = "inv/t2" ]'

echo "== ae slurm (quoted, allow-listed Slurm access)"
: > "$MOCK_SLURM/ctl-calls"
out=$("$AE" slurm squeue -h -o '%i' 2>&1); rc=$?; expect "read-only query runs" '[ $rc -eq 0 ]'
"$AE" slurm squeue "x; touch $T/pwned" >/dev/null 2>&1
expect "a quoted ';' cannot chain a remote command" '[ ! -e "$T/pwned" ]'
own=$(grep '"expid":"ae-smoke"' "$WS/state/LEDGER.jsonl" | head -1 | sed 's/.*"jobid":"\([^"]*\)".*/\1/')
out=$("$AE" slurm cancel "$own" 2>&1); rc=$?
expect "cancel of a ledger job runs scancel <id>" '[ $rc -eq 0 ] && grep -qx "scancel $own" "$MOCK_SLURM/ctl-calls"'
out=$("$AE" slurm cancel 99999 2>&1); rc=$?
expect "cancel of a job not in the ledger is refused" '[ $rc -ne 0 ] && grep -q "not this project" <<<"$out" && ! grep -q 99999 "$MOCK_SLURM/ctl-calls"'
out=$("$AE" slurm cancel -u someone 2>&1); rc=$?
expect "cancel with flags (-u) is refused" '[ $rc -ne 0 ] && ! grep -q -- "-u" "$MOCK_SLURM/ctl-calls"'
out=$("$AE" slurm update "$own" Partition=general QOS=normal 2>&1); rc=$?
expect "update with allowed keys runs scontrol update JobId=<id>" '[ $rc -eq 0 ] && grep -qx "scontrol update JobId=$own Partition=general QOS=normal" "$MOCK_SLURM/ctl-calls"'
out=$("$AE" slurm update "$own" Comment=x 2>&1); rc=$?
expect "update with a key outside the list is refused" '[ $rc -ne 0 ] && grep -q "key not allowed" <<<"$out"'
out=$("$AE" slurm hold "$own" 2>&1); expect "hold of a ledger job runs scontrol hold <id>" 'grep -qx "scontrol hold $own" "$MOCK_SLURM/ctl-calls"'
out=$("$AE" slurm bogus 2>&1); rc=$?; expect "unknown subcommand is refused" '[ $rc -ne 0 ]'

echo "== launch refuses the unedited template brief and a zero-size top-up"
"$AE" investigate t4 >/dev/null 2>&1
out=$("$AE" launch t4 --jobid 4242 2>&1); rc=$?
expect "template brief is refused" '[ $rc -ne 0 ] && grep -q "unedited template" <<<"$out"'
out=$("$AE" tinker t4 --jobid 4242 < /dev/null 2>&1); rc=$?
expect "tinker with empty stdin does not launch the template" '[ $rc -ne 0 ] && grep -q "unedited template" <<<"$out"'
echo 'AE_DBG_GEN_POOL=0' >> "$WS/config.sh"
out=$("$AE" launch t1 --gen --topup 2>&1); rc=$?
expect "--topup on a tier with pool size 0 says so" '[ $rc -ne 0 ] && grep -q "pool size 0" <<<"$out"'
sed -i.bak '/^AE_DBG_GEN_POOL=0$/d' "$WS/config.sh"

echo "== ae-watch (event watcher)"
W="$P/slurm-agentic-engineering/bin/ae-watch"
out=$("$W" --once 2>&1); rc=$?
expect "first pass reports both completions" '[ $rc -eq 0 ] && grep -q "DONE ae-ae-smoke(" <<<"$out" && grep -q "DONE ae-ae-smoke-dep(" <<<"$out"'
out=$("$W" --once 2>&1); rc=$?; expect "watermark: nothing re-reported (exit 3)" '[ $rc -eq 3 ] && [ -z "$out" ]'
rm -f "$WS/.ae-watch-wm"
out=$("$W" --once --suppress-done 'ae-smoke' --when-complete 'ae-smoke:2:selftest' 2>&1)
expect "suppressed completions + one group event" '! grep -q "DONE" <<<"$out" && grep -q "ALL-COMPLETE selftest (2/2)" <<<"$out"'

echo "== recipe pinning"
echo "# edit" >> "$WS/selftest/ae-smoke.sh"
out=$("$AE" submit ae-smoke --replace 2>&1); new=$(grep -o 'recipe=[0-9a-f]*' <<<"$out" | cut -d= -f2)
old=$(grep '"expid":"ae-smoke"' "$WS/state/LEDGER.jsonl" | head -1 | sed 's/.*"expsha":"\([^"]*\)".*/\1/')
expect "editing the recipe changes expsha at the same project sha" '[ -n "$new" ] && [ "$new" != "$old" ]'
expect "project tree still clean (workspace never dirties the project)" '[ -z "$(git -C "$P" status --porcelain)" ]'

echo "== Babel second pool routing"
out=$("$AE" submit ae-smoke-gen 2>&1)
expect "part=general -> general partition, normal QOS, 1 GPU" 'grep -q "^submitted ae-smoke-gen .*part=general  qos=normal  gpus=1" <<<"$out"'
expect "generated job carries the general partition + GRES" 'grep -q "^#SBATCH -p general" "$MOCK_REMOTE_HOME"/ae/jobs/ae-smoke-gen-*.sh && grep -q "^#SBATCH --gres=gpu:1" "$MOCK_REMOTE_HOME"/ae/jobs/ae-smoke-gen-*.sh'

[ $fail -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
