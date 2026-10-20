# ==========================================================================
# JOB PREAMBLE — inlined verbatim into every generated job script.
# Generic: knows nothing about any project. Provides preemption safety.
#
# Contract for experiment definitions:
#   phase <name> <done-predicate> <command...>
#     - done-predicate is eval'd; if it succeeds the phase is SKIPPED.
#       This is what makes a requeue cheap: Slurm re-runs the whole script
#       from the top, and finished phases must cost seconds.
#   $AE_RUNDIR    per-experiment scratch, keyed <sha>-<expsha> (compute-side)
#   $AE_RESULTS   write small distillates here; only THIS is harvested
#   $AE_ROOT      the remote harness root (jobs/, code/, results/, ...); stable across runs
#
# CROSS-EXPERIMENT DATA CONTRACT -- read this before chaining anything:
#   $AE_RUNDIR/$AE_RESULTS are keyed by <expid>/<sha>-<expsha>. A DOWNSTREAM
#   experiment cannot compute those paths, so it can never read them. Anything a
#   later experiment must consume goes to a PROJECT path (see PROJECT.md).
#   Variables a phase uses must be EXPORTed -- `phase` runs a child shell.
# ==========================================================================
set -uo pipefail          # deliberately NOT -e: a killed child must not abort
                          # this script before the trap/status logic runs.
# `phase` runs its command in a child `bash -c`, so anything a phase may refer to
# must be EXPORTED, not merely set. (Caught by the smoke test: $AE_SHA came
# through empty inside a phase while $AE_RESULTS worked, because the latter was
# expanded by the parent shell at call time.)
export AE_EXPID AE_SHA AE_ROOT AE_CODE AE_RUNDIR AE_RESULTS
SECONDS=0
AE_STATUS=0
exec > >(while IFS= read -r l; do printf '[%s] %s\n' "$(date '+%F %T')" "$l"; done) 2>&1
# The timestamping reader is a CHILD of this shell. Without an explicit close-and-wait
# below, the shell exits, Slurm tears down the step, and the reader dies with output
# still in flight -- silently truncating exactly the lines a failed job needs. Observed
# twice: neither `PHASE <name> -- FAILED` nor the epilogue reached the log, so the job
# looked like it had stopped mid-test for no reason.
AE_LOG_PID=$!
log() { echo "[+${SECONDS}s] $*"; }

log "===== AE JOB START ====="
log "exp=$AE_EXPID  sha=$AE_SHA  job=$SLURM_JOB_ID  node=$(hostname)"
log "restart=${SLURM_RESTART_COUNT:-0}  qos=${SLURM_JOB_QOS:-?}  part=${SLURM_JOB_PARTITION:-?}"
[ "${SLURM_RESTART_COUNT:-0}" -gt 0 ] && log "*** REQUEUE ATTEMPT #${SLURM_RESTART_COUNT} (appending to same log) ***"

mkdir -p "$AE_RUNDIR" "$AE_RESULTS"

# --- signal handling ------------------------------------------------------
# PreemptParameters=send_user_signal means USR1 arrives on PREEMPTION too, not
# only near the walltime. Self-requeueing on a preemption throws away the 2-min
# grace window that could still reach a checkpoint. So: discriminate.
_left_secs() {
    # Prints seconds remaining, "inf" when there is no walltime, or "" if unknown.
    # NOTE: bash arithmetic turns a non-numeric word into 0, so "UNLIMITED" must be
    # caught explicitly -- otherwise it reads as "0s left" and looks like a
    # walltime warning. (Found by unit test during audit.)
    local l; l=$(squeue -h -j "$SLURM_JOB_ID" -o "%L" 2>/dev/null | tr -d ' ')
    case "$l" in
        "")                       echo ""; return;;
        UNLIMITED|INVALID|NOT_SET) echo "inf"; return;;
    esac
    local d=0
    case "$l" in *-*) d=${l%%-*}; l=${l#*-};; esac
    case "$l" in *[!0-9:]*) echo ""; return;; esac   # anything else unparseable
    local IFS=:; set -- $l
    case $# in
        3) echo $(( 10#$d*86400 + 10#$1*3600 + 10#$2*60 + 10#$3 ));;   # 10#: "08"/"09" are not octal
        2) echo $(( 10#$d*86400 + 10#$1*60 + 10#$2 ));;
        1) echo $(( 10#$d*86400 + 10#$1 ));;
        *) echo "";;
    esac
}
on_usr1() {
    local s; s=$(_left_secs)
    # Which misclassification is worse decides the default:
    #   wrongly "walltime"  -> we self-requeue during a preemption; Slurm would have
    #                          requeued us anyway, so we only lose the grace window.
    #   wrongly "preemption"-> we do NOT self-requeue near the limit; the job TIMEOUTs
    #                          and the chain silently STOPS. Much worse.
    # So an UNKNOWN remaining time self-requeues; only a confident "lots of time
    # left" (or no limit at all) is treated as preemption.
    if [ "$s" = "inf" ]; then
        log "*** USR1 with no walltime set -> PREEMPTION. Not self-requeueing."
    elif [ -n "$s" ] && [ "$s" -gt 300 ]; then
        log "*** USR1 with ${s}s of walltime left -> this is PREEMPTION, not the limit."
        log "*** NOT self-requeueing: Slurm requeues after the grace window, and the"
        log "*** child keeps running meanwhile and may still reach a checkpoint."
    else
        log "*** USR1 near the walltime (${s:-unknown}s left) -> self-requeue to chain"
        scontrol requeue "$SLURM_JOB_ID"
    fi
}
trap on_usr1 USR1
trap 'log "*** SIGTERM (preemption / scancel / end of grace). Durable state is on disk."' TERM

# --- run a child so bash can service traps immediately --------------------
run_child() {
    "$@" &
    local pid=$! st
    wait $pid; st=$?
    # `wait` returns 128+N the moment a TRAPPED signal lands, even though the
    # child is still alive. Re-wait until it is actually reaped.
    while [ $st -gt 128 ] && kill -0 $pid 2>/dev/null; do
        log "wait returned $st (trapped signal) but PID $pid alive -- resuming wait"
        wait $pid; st=$?
    done
    return $st
}

phase() {
    local name="$1" done_pred="$2"; shift 2
    if eval "$done_pred" >/dev/null 2>&1; then
        log "PHASE $name -- already complete, skipping"
        return 0
    fi
    log "PHASE $name -- running"
    # -u: an UNSET variable is an error, not an empty string. Without this a
    # phase referring to a set-but-not-exported var silently evaluates garbage
    # (observed: a precondition check passed with its input absent).
    # -o pipefail: a pipeline reports the FAILING stage, not the last one. Without
    # it `pytest ... | tail -40` exits with tail's status, so a phase whose whole
    # job is to run a test suite reports "ok" while the suite is red -- observed on
    # hashmap-freeze, where 28 tests ran, one errored, and the phase passed. Same
    # class of silent pass as the -u case, and the same remedy.
    # -e: a phase is ONE step of a recipe, and a multi-command phase took its status
    # from the LAST command. Observed on hashmap-corpus-b, where corpus generation
    # died with a traceback, the summary heredoc then died with FileNotFoundError,
    # and a trailing `du -sh` returned 0 -- so the job reported COMPLETED in 1 second
    # having produced nothing. Third instance of the same failure family as -u and
    # pipefail. Safe for every existing recipe here: `if [ ... ]` and `cmd || fallback`
    # are exempt from -e, and an assignment from a command substitution that fails is
    # exactly the S1 bug this harness already fixed once.
    # --noprofile --norc, and BASH_ENV/ENV unset: a phase must not run the operator's
    # dotfiles. `~/.bashrc.d/*` here prints a decorative banner and probes for torch,
    # which was harmless noise until -e arrived and made the banner's first line
    # ("+-----+": command not found) abort the job in 1 second. Beyond that specific
    # break, a job whose behaviour depends on the submitting user's shell configuration
    # is not reproducible, which is the whole point of pinning it to a commit.
    run_child env -u BASH_ENV -u ENV bash --noprofile --norc -euo pipefail -c "$*"
    local st=$?
    if [ $st -ne 0 ]; then
        AE_STATUS=$st
        log "PHASE $name -- FAILED (status $st)"
        [ $st -gt 128 ] && log "  (>128 = killed by signal $((st-128)); Slurm requeues preemptions automatically)"
        exit $st
    fi
    log "PHASE $name -- ok"
}

ae_epilogue() {
    local st=$?
    log "===== AE JOB END  status=$st  elapsed=${SECONDS}s ====="
    if [ $st -eq 0 ]; then
        log "all phases complete; distillates in $AE_RESULTS:"
        ls -la "$AE_RESULTS" 2>/dev/null | tail -n +2 | while read -r l; do log "  $l"; done
    else
        log "NOT complete. If this was a preemption Slurm has already requeued the"
        log "same JobID; a dependent afterany job correctly stays PENDING."
    fi
    # Close the pipe so the reader sees EOF, then wait for it to drain. Everything
    # above this point is the diagnostic record; losing it is the one failure mode a
    # log cannot recover from.
    exec 1>&- 2>&-
    [ -n "${AE_LOG_PID:-}" ] && wait "$AE_LOG_PID" 2>/dev/null
    return 0
}
trap ae_epilogue EXIT
