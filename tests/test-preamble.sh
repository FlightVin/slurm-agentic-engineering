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
[ $fail -eq 0 ] && echo "PASS" || { echo "FAIL"; exit 1; }
