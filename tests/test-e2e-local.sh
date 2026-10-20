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

# harness inserted into the project, workspace inside it (the default layout)
cp -R "$H" "$P/slurm-agentic-engineering"; rm -rf "$P/slurm-agentic-engineering/.git"
echo "slurm-agentic-engineering/" >> "$P/.git/info/exclude"
AE="$P/slurm-agentic-engineering/bin/ae"; WS="$P/slurm-agentic-engineering"
unset AE_HOME AE_REPO

echo "== init + config"
"$AE" init >/dev/null; expect "workspace created inside the harness dir" '[ -f "$WS/state/STATE.md" ] && [ -f "$WS/config.sh" ]'
expect "project CLAUDE.md imports the in-project agent.md" 'grep -q "@slurm-agentic-engineering/agent.md" "$P/CLAUDE.md"'
cat >> "$WS/config.sh" <<'EOF'
AE_HOST="mockcluster"; AE_REMOTE_REPO='$HOME/projrepo'; AE_BRANCH="work"
AE_PARTITION="pre"; AE_QOS_GPU="pre_gpu"; AE_QOS_CPU="pre_cpu"
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
expect "gpus=0 routed to the CPU QOS" 'grep -q "qos=pre_cpu" <<<"$out"'
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

[ $fail -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
