#!/usr/bin/env python3
"""Measured preempt capacity from sacct -D -X -P (JobID,JobName,Partition,State,Submit,Eligible,Start,End,AllocTRES)."""
import sys, re, statistics as st
from datetime import datetime, timedelta
now = datetime.now().replace(microsecond=0)
P = lambda s: None if s in ("Unknown", "None", "") else datetime.fromisoformat(s)
rows = [l.rstrip("\n").split("|") for l in open(sys.argv[1]) if l.count("|") == 8]
def gpus(t):
    m = re.search(r"gres/gpu=(\d+)", t); return int(m.group(1)) if m else 0
for part in ("preempt", "general"):
    att = [(r[0], r[1], r[3], P(r[4]), P(r[5]), P(r[6]), P(r[7]) or now, gpus(r[8])) for r in rows if r[2] == part]
    att = [a for a in att if a[7] > 0 and a[5]]
    for hrs in (72, 24):
        w0 = now - timedelta(hours=hrs)
        gh = sum(a[7] * max(0, (min(a[6], now) - max(a[5], w0)).total_seconds()) for a in att) / 3600
        print(f"{part:8} last {hrs:2} h: {gh:7.1f} GPU-h received = {gh/hrs:5.2f} GPUs average")
    waits = [(a[5] - (a[4] or a[3])).total_seconds() / 3600 for a in att if a[5] >= now - timedelta(hours=72) and (a[4] or a[3])]
    if waits: print(f"{part:8} attempts started in 72 h: {len(waits)}; median wait (eligible->start) {st.median(waits):.2f} h; p90 {sorted(waits)[int(.9*len(waits))-1]:.2f} h")
    pre = [a for a in att if a[2] == "PREEMPTED" and a[6] >= now - timedelta(hours=72)]
    print(f"{part:8} preemptions in 72 h: {len(pre)}; mean attempt length before preemption {st.mean([(a[6]-a[5]).total_seconds()/3600 for a in pre]) if pre else 0:.2f} h")
