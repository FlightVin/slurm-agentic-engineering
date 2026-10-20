#!/usr/bin/env bash
#EXP gpus=0 cpus=1 time=00:10:00 after=ae-smoke
# HYPOTHESIS: none -- harness self-test (child). Submitted with --after ae-smoke (afterany), it
# re-checks its own precondition -- the parent's marker on the shared path -- because afterany
# does not mean the parent succeeded. Expect results/ae-smoke-dep/chain.json with
# "ran_after_parent": true after `ae harvest`.
export SMOKE_DIR="$AE_ROOT/selftest"

phase chain "test -s $AE_RESULTS/chain.json" '
    if [ -s "$SMOKE_DIR/$AE_SHA.parent" ]; then
        parent=$(cat "$SMOKE_DIR/$AE_SHA.parent"); now=$(date -u +%s)
        printf "{\"ran_after_parent\": true, \"parent_finished_s_ago\": %s, \"sha\": \"%s\"}\n" \
            "$((now - parent))" "$AE_SHA" > "$AE_RESULTS/chain.json"
    else
        echo "PRECONDITION FAILED: parent marker $SMOKE_DIR/$AE_SHA.parent missing"; exit 1
    fi
'
