#!/bin/bash
# V8-A6 top-up submitter (orchestrator tooling; deterministic; makes no scientific decisions).
# Works through an ORDERED queue file written by the orchestrator, one entry per line:
#     <expid>|<dest general|preempt>|<after-expids comma list or ->
# Each cycle (default every 300 s):
#   1. submit the next entry while its destination has room (general < 50 submitted, preempt < 100). `ae submit` places
#      every exp on general (#EXP part=general), so a preempt entry is moved right after submission
#      (scontrol update Partition=preempt QOS=preempt_qos) — Slurm cannot race one job across both pools (CARD.md).
#   2. no-idle rule: if general has a free GPU and no runnable pending general job, move the oldest runnable pending
#      preempt job named in the queue file (P-sel / P4 training) to general.
# Prints one line per action (stdout = event stream for the orchestrator); skips a cycle when the tree is dirty.
# General entries are submitted only while general < 49 (slot 50 is the transit slot for preempt entries).
# Commands inside the `while read` loops take stdin from /dev/null (else ae/ssh swallow the queue file).
# Usage: v8-topup.sh <queue-file> [interval-seconds]
set -u
cd "$(dirname "$0")/../.." || exit 1
Q=${1:?queue file}; IV=${2:-300}; AE=./agentic-engineering/bin/ae
GEN_CAP=50; PRE_CAP=100; GEN_GPUS=8
DONE="$Q.done"; touch "$DONE"
while true; do
  if [ -n "$(git status --porcelain --untracked-files=no)" ]; then sleep "$IV"; continue; fi
  snap=$(ssh babel 'squeue -u $USER -h -o "%i|%P|%T|%r|%j|%b"' 2>/dev/null) || { sleep "$IV"; continue; }
  gen=$(grep -c '|general|' <<<"$snap"); pre=$(grep -c '|preempt|' <<<"$snap")
  # 1. submit in order
  while IFS='|' read -r exp dest after; do
    [ -z "$exp" ] && continue
    grep -qxF "$exp" "$DONE" && continue
    grep -q "|ae-$exp|" <<<"$snap" && { echo "$exp" >> "$DONE"; continue; }
    # one general slot stays free as the transit slot for preempt entries (ae submits on general, then we move it);
    # a blocked general entry does not block preempt entries (independent pools), order is kept within each pool
    [ "$gen" -ge "$GEN_CAP" ] && break
    [ "$dest" = general ] && [ "$gen" -ge $((GEN_CAP-1)) ] && continue
    [ "$dest" = preempt ] && [ "$pre" -ge "$PRE_CAP" ] && continue
    dep=""; [ -n "$after" ] && [ "$after" != "-" ] && dep="--after $after"
    out=$($AE submit "$exp" $dep 2>&1 < /dev/null)
    jid=$(grep -oE '^submitted .* job=[0-9]+' <<<"$out" | grep -oE '[0-9]+$')
    if [ -z "$jid" ]; then echo "TOPUP-SUBMIT-FAILED $exp: $(grep -E '^ae:|rror' <<<"$out" | head -1)"; break; fi
    git commit -q agentic-engineering/state/LEDGER.jsonl -m "ae: ledger ($exp, topup)" < /dev/null && git push -q < /dev/null 2>/dev/null
    if [ "$dest" = preempt ]; then
      # 4 CPUs (owner-approved 2026-10-12 00:45): training uses ~1 core (sacct); most free preempt GPUs sit on nodes with
      # < 8 free CPUs. Memory request (48G) unchanged.
      # a move counts only if scontrol succeeds; else the job stays on general and is counted there
      if msg=$(ssh -n babel "scontrol update JobId=$jid Partition=preempt QOS=preempt_qos NumCPUs=4 MinCPUsNode=4 CpusPerTask=4" 2>&1); then
        pre=$((pre+1)); echo "TOPUP $exp job=$jid -> preempt"
      else
        gen=$((gen+1)); echo "TOPUP-MOVE-FAILED $exp job=$jid stays on general: $(head -1 <<<"$msg")"
      fi
    else
      gen=$((gen+1)); echo "TOPUP $exp job=$jid -> general"
    fi
    echo "$exp" >> "$DONE"
  done < "$Q"
  # 2. no idle general GPU while a runnable job waits on preempt
  snap=$(ssh babel 'squeue -u $USER -h -o "%i|%P|%T|%r|%j|%b"' 2>/dev/null) || { sleep "$IV"; continue; }
  grun=$(awk -F'|' '$2=="general" && $3=="RUNNING" && $6 ~ /gpu/' <<<"$snap" | wc -l | tr -d ' ')
  grunnable=$(awk -F'|' '$2=="general" && $3=="PENDING" && $4!="Dependency" && $4!="JobHeldUser" && $4!="BeginTime"' <<<"$snap" | wc -l | tr -d ' ')
  gen=$(grep -c '|general|' <<<"$snap")
  if [ "$grun" -lt "$GEN_GPUS" ] && [ "$grunnable" -eq 0 ] && [ "$gen" -lt "$GEN_CAP" ]; then
    while IFS='|' read -r exp dest after; do
      [ "$dest" = preempt ] || continue
      jid=$(awk -F'|' -v n="ae-$exp" '$2=="preempt" && $3=="PENDING" && $5==n && $4!="Dependency" {print $1}' <<<"$snap" | head -1)
      [ -z "$jid" ] && continue
      if ! msg=$(ssh -n babel "scontrol update JobId=$jid Partition=general QOS=normal" 2>&1); then
        echo "TOPUP-IDLEFILL-FAILED $exp job=$jid stays on preempt: $(head -1 <<<"$msg")"; continue
      fi
      echo "TOPUP-IDLEFILL $exp job=$jid preempt -> general (general GPUs running $grun/$GEN_GPUS, no runnable general job)"
      break
    done < "$Q"
  fi
  sleep "$IV"
done
