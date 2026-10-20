#!/bin/bash
# Standby allocation: holds a node warm so the orchestrator can start work
# immediately instead of waiting out a queue. Generic; knows no project.
#
# It hosts a persistent tmux SERVER. This matters: a tmux server started from a
# transient `srun --overlap` step is killed when that step exits (verified), so
# agents must be added as WINDOWS to a server owned by this long-lived batch
# process instead.
#
# Preemption: --requeue returns this same JobID to PENDING and it comes back on
# a new node by itself (2-5 min typical). Before it goes, the USR1/TERM handler
# commits and pushes every dirty dev worktree, so a tinkering agent loses at
# most its current thought, never its work.
set -uo pipefail
AE_ROOT="${AE_ROOT:-$HOME/ae}"
SESSION="ae-host"
TMUX_SOCK="ae-${SLURM_JOB_ID:-0}"   # per-allocation socket: two standbys can share a node

save_worktrees() {
    # Verbose on purpose. This handler exists so a preemption costs at most the
    # current thought; a silent `continue` here means silently losing work, which
    # is the exact failure it is meant to prevent. Every skip states its reason.
    local w rc
    for w in "$AE_ROOT"/work/*/; do
        [ -d "$w" ] || continue
        if [ ! -e "$w/.git" ]; then echo "[standby]   skip $w (not a worktree)"; continue; fi
        if [ -z "$(git -C "$w" status --porcelain 2>&1)" ]; then
            echo "[standby]   skip $w (clean)"; continue
        fi
        git -C "$w" add -A; rc=$?
        [ $rc -ne 0 ] && { echo "[standby]   FAILED add in $w (rc=$rc)"; continue; }
        if git -C "$w" commit -q -m "ae: wip (allocation ending)"; then
            echo "[standby]   committed $(git -C "$w" rev-parse --short HEAD) in $w"
            if git -C "$w" push -q origin HEAD 2>&1; then
                echo "[standby]   pushed $w"
            else
                echo "[standby]   WARNING pushed FAILED for $w -- commit is local only"
            fi
        else
            echo "[standby]   FAILED commit in $w"
        fi
    done
}

# NOTE: bash defers a trap until the current FOREGROUND command finishes, so a
# plain `sleep 30` swallows the grace window entirely -- verified: the handler
# never ran and uncommitted work was lost. `wait` is interruptible, so the idle
# loop below must background the sleep and wait on it.
on_signal() {
    echo "[standby] signal received on $(hostname) -- saving dirty worktrees"
    save_worktrees
    echo "[standby] save complete"
}
trap on_signal USR1
trap on_signal TERM

echo "[standby] up on $(hostname) job ${SLURM_JOB_ID:-?} restart ${SLURM_RESTART_COUNT:-0}"
echo "[standby] gpu=${CUDA_VISIBLE_DEVICES:-none} cpus=${SLURM_CPUS_PER_TASK:-?}"

# Fresh server each attempt: the previous one died with the previous node.
tmux -L "$TMUX_SOCK" kill-server 2>/dev/null || true
tmux -L "$TMUX_SOCK" new-session -d -s "$SESSION" -c "$AE_ROOT" "echo 'ae standby host'; sleep infinity"
echo "[standby] tmux server up: socket $TMUX_SOCK session $SESSION"
echo "$SLURM_JOB_ID $(hostname)" > "$AE_ROOT/standby.$(hostname).info" 2>/dev/null || true

while true; do
    sleep 30 &            # backgrounded + wait: makes the traps above fire AT ONCE
    wait $! 2>/dev/null   # (a foreground sleep would defer them past the grace window)
done
