#!/usr/bin/env bash
# Offline CLI tests: entry points, path resolution, init, config validation, permissions rendering.
# Needs no cluster and no network. Run: bash tests/test-cli.sh
set -uo pipefail
H="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0
ok()   { echo "  ok    $*"; }
bad()  { echo "  FAIL  $*"; fail=1; }
expect() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

# a throwaway project + workspace outside the harness, so the harness dir stays clean
P="$T/project"; W="$T/ws"; mkdir -p "$P"
git -C "$P" init -q && git -C "$P" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
export AE_REPO="$P" AE_HOME="$W"
AE="$H/bin/ae"

echo "== syntax"
for f in "$H"/bin/ae "$H"/bin/ae-watch "$H"/bin/ae-capacity "$H"/bin/ae-topup "$H"/lib/*.sh \
         "$H"/selftest/*.sh "$H"/templates/exp.sh "$H"/tests/*.sh; do
    bash -n "$f" 2>/dev/null && ok "bash -n $(basename "$f")" || bad "bash -n $f"
done
python3 -m py_compile "$H/scripts/reset_project.py" && ok "py_compile reset_project.py" || bad "py_compile"

echo "== entry points (no config)"
# The harness dir may already hold a workspace (the default layout). Compare its
# top-level listing before and after, rather than assume it has no workspace.
snap() { ls -A "$H" | sort; }
before=$(snap)
out=$("$AE" help 2>&1); expect "ae help exits 0 and lists commands" '[ $? -eq 0 ] && grep -q "SETUP / HEALTH" <<<"$out"'
out=$("$AE" paths 2>&1); expect "ae paths resolves workspace + repo" 'grep -q "workspace (AE_HOME): $W" <<<"$out" && grep -q "project repo (REPO): $P" <<<"$out" && grep -q MISSING <<<"$out"'
out=$("$AE" status 2>&1); rc=$?; expect "ae status refuses without config" '[ $rc -ne 0 ] && grep -q "no site config" <<<"$out"'
out=$("$AE" bogus 2>&1); rc=$?; expect "unknown command fails" '[ $rc -ne 0 ] && grep -q "unknown command" <<<"$out"'
out=$("$H/bin/ae-watch" --once 2>&1); rc=$?; expect "ae-watch refuses without config" '[ $rc -eq 2 ]'
expect "harness dir untouched by offline commands" '[ "$(snap)" = "$before" ]'

echo "== init"
out=$("$AE" init 2>&1); rc=$?; expect "ae init exits 0" '[ $rc -eq 0 ]'
for f in config.sh PROJECT.md cluster/CARD.md cluster/BABEL.md state/STATE.md state/CHECKLIST.md state/FINDINGS.md \
         state/DECISIONS.md state/IMPLEMENTATION-LOG.md; do
    expect "init created $f" '[ -f "$W/$f" ]'
done
expect "init created project CLAUDE.md -> agent.md" 'grep -q "agent.md" "$P/CLAUDE.md"'
expect "CLAUDE.md pointer resolves" 'ref=$(grep -o "@[^ ]*agent.md" "$P/CLAUDE.md" | head -1 | cut -c2-); case "$ref" in /*) [ -f "$ref" ];; *) [ -f "$P/$ref" ];; esac'
out=$("$AE" init 2>&1); expect "second ae init changes nothing" '! grep -qE "^  (create|reset) " <<<"$out"'

echo "== first-run path (ae init --no-claude-md)"
P2="$T/project2"; W2="$T/ws2"; mkdir -p "$P2"; git -C "$P2" init -q
out=$(AE_REPO="$P2" AE_HOME="$W2" "$AE" paths 2>&1); expect "fresh workspace: paths reports config MISSING" 'grep -q "config: .*MISSING" <<<"$out"'
AE_REPO="$P2" AE_HOME="$W2" "$AE" init --no-claude-md >/dev/null 2>&1
expect "--no-claude-md: workspace created, project root untouched" '[ -f "$W2/config.sh" ] && [ -f "$W2/state/CHECKLIST.md" ] && [ ! -e "$P2/CLAUDE.md" ]'

echo "== config validation"
out=$("$AE" status 2>&1); rc=$?; expect "empty per-project config is refused" '[ $rc -ne 0 ] && grep -q "AE_REMOTE_REPO is not set" <<<"$out"'
cat >> "$W/config.sh" <<'EOF'
AE_HOST="fakehost"; AE_REMOTE_REPO='$HOME/p'; AE_BRANCH="work"
AE_PARTITION="part"; AE_QOS_GPU="qg"; AE_QOS_CPU="qc"; AE_PARTITION_GEN="gen"; AE_QOS_GEN=""
EOF
out=$("$AE" status 2>&1); rc=$?; expect "second pool without its QOS is refused" '[ $rc -ne 0 ] && grep -q "AE_PARTITION_GEN is set but AE_QOS_GEN is not" <<<"$out"'

echo "== Babel defaults (config.example.sh)"
out=$(bash -c 'set -u; . "$1"; echo "$AE_HOST $AE_PARTITION $AE_QOS_GPU $AE_QOS_CPU $AE_PARTITION_GEN $AE_QOS_GEN $AE_MAX_GPUS_PER_USER $AE_GEN_MAX_GPUS $AE_GEN_MAX_SECONDS $AE_DBG_POOL $AE_DBG_GEN_POOL"' _ "$H/config.example.sh")
expect "template carries Babel's pools, QOSes and caps" '[ "$out" = "babel preempt preempt_qos preempt_cpu_qos general normal 24 8 172800 2 2" ]'
expect "only the per-project values are blank" '[ "$(grep -cE "^AE_[A-Z_]+=(\"\"|'"''"')" "$H/config.example.sh")" -eq 2 ]'
expect "init installed the Babel card + reference" 'grep -q "^# Babel cluster card" "$W/cluster/CARD.md" && grep -q "^# Babel SLURM Reference" "$W/cluster/BABEL.md"'

echo "== permissions template"
r=$(sed "s/{{AUTH_BRANCH}}/work/g; s/{{REMOTE}}/origin/g" "$H/lib/tinker-permissions.json")
expect "renders to valid JSON" 'python3 -c "import json,sys; json.loads(sys.stdin.read())" <<<"$r"'
expect "denies pushing to the authoritative branch" 'grep -q "\"Bash(git push origin HEAD:work:\*)\"" <<<"$r" && grep -q "\"Bash(git push origin work:\*)\"" <<<"$r"'
expect "denies sbatch / rm -rf / force-push" 'grep -q "Bash(sbatch:\*)" <<<"$r" && grep -q "Bash(rm -rf:\*)" <<<"$r" && grep -q "Bash(git push --force:\*)" <<<"$r"'
expect "no placeholder left after rendering" '! grep -q "{{" <<<"$r"'

echo "== harness Claude settings"
expect ".claude/settings.json is valid JSON and pre-approves the ae commands" 'python3 -c "import json,sys; a=json.load(open(sys.argv[1]))[\"permissions\"][\"allow\"]; assert \"Bash(bin/ae *)\" in a and \"Bash(bin/ae-watch *)\" in a" "$H/.claude/settings.json"'

echo "== preamble logic"
bash "$H/tests/test-preamble.sh" >/dev/null && ok "test-preamble.sh" || bad "test-preamble.sh"

[ $fail -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
