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
out=$("$AE" help 2>&1); expect "ae help exits 0 and lists commands" '[ $? -eq 0 ] && grep -q "SETUP / HEALTH" <<<"$out"'
out=$("$AE" paths 2>&1); expect "ae paths resolves workspace + repo" 'grep -q "workspace (AE_HOME): $W" <<<"$out" && grep -q "project repo (REPO): $P" <<<"$out" && grep -q MISSING <<<"$out"'
out=$("$AE" status 2>&1); rc=$?; expect "ae status refuses without config" '[ $rc -ne 0 ] && grep -q "no site config" <<<"$out"'
out=$("$AE" bogus 2>&1); rc=$?; expect "unknown command fails" '[ $rc -ne 0 ] && grep -q "unknown command" <<<"$out"'
out=$("$H/bin/ae-watch" --once 2>&1); rc=$?; expect "ae-watch refuses without config" '[ $rc -eq 2 ]'
expect "harness dir untouched by offline commands" '[ ! -e "$H/state" ] && [ ! -e "$H/config.sh" ]'

echo "== init"
out=$("$AE" init 2>&1); rc=$?; expect "ae init exits 0" '[ $rc -eq 0 ]'
for f in config.sh PROJECT.md cluster/CARD.md state/STATE.md state/CHECKLIST.md state/FINDINGS.md \
         state/DECISIONS.md state/IMPLEMENTATION-LOG.md; do
    expect "init created $f" '[ -f "$W/$f" ]'
done
expect "init created project CLAUDE.md -> agent.md" 'grep -q "agent.md" "$P/CLAUDE.md"'
expect "CLAUDE.md pointer resolves" 'ref=$(grep -o "@[^ ]*agent.md" "$P/CLAUDE.md" | head -1 | cut -c2-); case "$ref" in /*) [ -f "$ref" ];; *) [ -f "$P/$ref" ];; esac'
out=$("$AE" init 2>&1); expect "second ae init changes nothing" '! grep -qE "^  (create|reset) " <<<"$out"'

echo "== config validation"
out=$("$AE" status 2>&1); rc=$?; expect "empty required config is refused" '[ $rc -ne 0 ] && grep -q "AE_HOST is not set" <<<"$out"'
cat >> "$W/config.sh" <<'EOF'
AE_HOST="fakehost"; AE_REMOTE_REPO='$HOME/p'; AE_BRANCH="work"
AE_PARTITION="part"; AE_QOS_GPU="qg"; AE_QOS_CPU="qc"; AE_PARTITION_GEN="gen"
EOF
out=$("$AE" status 2>&1); rc=$?; expect "second pool without its QOS is refused" '[ $rc -ne 0 ] && grep -q "AE_PARTITION_GEN is set but AE_QOS_GEN is not" <<<"$out"'

echo "== permissions template"
r=$(sed "s/{{AUTH_BRANCH}}/work/g; s/{{REMOTE}}/origin/g" "$H/lib/tinker-permissions.json")
expect "renders to valid JSON" 'python3 -c "import json,sys; json.loads(sys.stdin.read())" <<<"$r"'
expect "denies pushing to the authoritative branch" 'grep -q "\"Bash(git push origin HEAD:work:\*)\"" <<<"$r" && grep -q "\"Bash(git push origin work:\*)\"" <<<"$r"'
expect "denies sbatch / rm -rf / force-push" 'grep -q "Bash(sbatch:\*)" <<<"$r" && grep -q "Bash(rm -rf:\*)" <<<"$r" && grep -q "Bash(git push --force:\*)" <<<"$r"'
expect "no placeholder left after rendering" '! grep -q "{{" <<<"$r"'

echo "== preamble logic"
bash "$H/tests/test-preamble.sh" >/dev/null && ok "test-preamble.sh" || bad "test-preamble.sh"

[ $fail -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
