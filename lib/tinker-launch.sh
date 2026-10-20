#!/bin/bash
# Start (or restart) a compute-side tinkering agent for investigation $1.
# Runs via `srun --overlap` inside a standby allocation, but adds the agent as a
# WINDOW on the standby job's long-lived tmux server -- so the agent survives
# this step exiting. (A session created by the step itself does not.)
set -uo pipefail
ID="$1"; AE_ROOT="${2:-$HOME/ae}"
W="$AE_ROOT/work/$ID"; I="$AE_ROOT/inv/$ID"
SESSION="ae-host"
TMUX_SOCK="ae-${SLURM_JOB_ID:-0}"   # must match the standby that owns this allocation
cd "$W" || { echo "no worktree $W"; exit 1; }

tmux -L "$TMUX_SOCK" has-session -t "$SESSION" 2>/dev/null || {
    echo "FATAL: no '$SESSION' tmux server on $(hostname)."
    echo "That server is created by the standby job. Is this allocation a standby one?"
    exit 1
}

PROMPT_FILE="$I/prompt.txt"
{
    cat "$I/bootstrap.md"
    echo
    echo "--- INVESTIGATION BRIEF ---"
    cat "$I/brief.md"
    echo
    echo "--- PATHS ---"
    echo "worktree (your cwd): $W"
    echo "write your report to: $W/.ae-report.md   (inside your worktree; it is git-excluded)"
} > "$PROMPT_FILE"

# LEAST PRIVILEGE, not a blanket bypass. The agent is headless in a tmux window
# with nobody to answer a prompt, so anything it legitimately needs must be
# pre-authorised -- but submitting jobs, pushing to the authoritative branch,
# force-pushing, hard-resetting and rm -rf are explicitly DENIED. Those belong to
# the orchestrator. (Observed without this: the agent did the work, could not
# commit or report, and exited.)
mkdir -p "$W/.claude"
cp "$AE_ROOT/tinker-permissions.json" "$W/.claude/settings.local.json"
# Keep the agent's own artefacts out of the repo. A linked worktree's git dir has
# no info/ by default, so create it.
# A linked worktree's own git dir is NOT consulted for info/exclude; git reads
# the COMMON dir's. Using --git-dir here silently did nothing (the agent caught
# it: `?? .claude/` still showed in git status).
GD="$(git -C "$W" rev-parse --git-common-dir)"
mkdir -p "$GD/info"
for f in '.claude/' '.ae-report.md'; do
    grep -qxF "$f" "$GD/info/exclude" 2>/dev/null || echo "$f" >> "$GD/info/exclude"
done

tmux -L "$TMUX_SOCK" kill-window -t "$SESSION:$ID" 2>/dev/null || true
# The agent CLI comes from the laptop's config (AE_AGENT_CMD, written to $AE_ROOT/agent-cmd
# by `ae launch`). Default: Claude Code in acceptEdits mode; the prompt is its last argument.
AGENT_CMD="claude --permission-mode acceptEdits"
[ -s "$AE_ROOT/agent-cmd" ] && AGENT_CMD="$(head -1 "$AE_ROOT/agent-cmd")"
tmux -L "$TMUX_SOCK" new-window -d -t "$SESSION" -n "$ID" -c "$W" \
    "$AGENT_CMD \"\$(cat '$PROMPT_FILE')\" 2>&1 | tee -a '$I/agent.log'; echo AGENT_EXITED >> '$I/agent.log'; sleep 86400"
sleep 3
if tmux -L "$TMUX_SOCK" list-windows -t "$SESSION" -F '#W' 2>/dev/null | grep -qx "$ID"; then
    echo "  agent running: tmux -L $TMUX_SOCK $SESSION:$ID on $(hostname)"
else
    echo "  FAILED to start; see $I/agent.log"; tail -5 "$I/agent.log" 2>/dev/null
fi
