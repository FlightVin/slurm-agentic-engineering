#!/usr/bin/env bash
# Unit test for lib/preamble.sh's preemption-vs-walltime discriminator.
# Pure logic, no cluster needed. Run after ANY change to preamble.sh:
#   bash slurm-agentic-engineering/tests/test-preamble.sh
# This matters because the real code path only fires during an actual preemption,
# which is hard to observe -- a bug here is invisible until it costs you work.
set -uo pipefail
SRC="$(dirname "${BASH_SOURCE[0]}")/../lib/preamble.sh"
FN=$(awk '/^_left_secs\(\) \{/,/^\}/' "$SRC")
fail=0
eval "SLURM_JOB_ID=1; squeue(){ echo \"\$FAKE_LEFT\"; }; $FN"
check(){ FAKE_LEFT="$1"; local g; g=$(_left_secs)
         if [ "$g" = "$2" ]; then echo "  ok    %L='$1' -> '$g'"
         else echo "  FAIL  %L='$1' -> got '$g' want '$2'"; fail=1; fi; }
check "5:00:00"    18000     # hours left  -> preemption
check "1-11:27:08" 127628    # leading-zero fields are decimal, not octal (bug 2026-10-01)
check "09:08"      548
check "2-08:09:09" 202149
check "1-00:00:00" 86400     # days
check "2-03:04:05" 183845    # days+h:m:s
check "12:30"      750       # MM:SS
check "45"         45        # SS
check "0:04:00"    240       # near limit -> self-requeue
check ""           ""        # unknown    -> self-requeue (never break the chain)
check "UNLIMITED"  inf       # no limit   -> must NOT read as 0s
check "INVALID"    inf
check "garbage"    ""
# on_usr1 must write the preemption notice for the child in BOTH branches (preemption and
# near-walltime), and self-requeue only near the walltime. (Added 2026-10-22: the child is
# SIGKILLed ~1 s after SIGTERM, so the notice file is its only early warning.)
USR1FN=$(awk '/^on_usr1\(\) \{/,/^\}/' "$SRC")
tmpd=$(mktemp -d); requeued=""
eval "log(){ :; }; scontrol(){ requeued=\"\$*\"; }; $USR1FN"
for case in "18000 no" "100 yes"; do
    set -- $case; left=$1; want_rq=$2; requeued=""
    eval "_left_secs(){ echo $left; }"
    AE_PREEMPT_FLAG="$tmpd/notice-$left"; on_usr1
    got_rq=no; [ -n "$requeued" ] && got_rq=yes
    if [ -s "$AE_PREEMPT_FLAG" ] && grep -qE '^[0-9]+$' "$AE_PREEMPT_FLAG" && [ "$got_rq" = "$want_rq" ]; then
        echo "  ok    on_usr1 left=${left}s -> notice written, requeue=$got_rq"
    else
        echo "  FAIL  on_usr1 left=${left}s -> notice '$(cat "$AE_PREEMPT_FLAG" 2>/dev/null)', requeue=$got_rq want $want_rq"; fail=1
    fi
done
rm -rf "$tmpd"
[ $fail -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
