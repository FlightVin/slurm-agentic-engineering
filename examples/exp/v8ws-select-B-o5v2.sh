#!/usr/bin/env bash
#EXP gpus=0 cpus=8 mem=64G time=1:30:00
# HYPOTHESIS: none -- owner Amendment V8-A9 item 8 (iii): Selection B re-run for the O5 group ONLY. Apply the FROZEN rule
# (rule_sha256 ea0b49e9..., unchanged) with select_aux_weights --only-group O5 to the O5 v2 Stage B candidates (b80
# representative cells, lambda_F = the Selection A O2 value per access, o5_loss_version 2, run suffix -o5v2) against the
# matched NTP references, DEV split only. lambda_par(R) is the v2 measurement (LP_R_B80_HYB / LP_R_B80_STR / LP_R_B40,
# required). Every non-O5 group, candidate row and top-level key of the current selection file stays byte-identical
# (asserted by the script and again by postcheck); the current file is read only, the result goes to
# $AE_RESULTS/aux-weight-selection.json. CPU work (~40 min with the item-17 learning gap).
# lambda_par(R), v2 loss (orchestrator fills from the v2 grad-ratio / lambda_par measurement), e.g.:
# export LP_R_B80_HYB=... LP_R_B80_STR=... LP_R_B40=... LP_R_SOURCE='measured <date>: ...'
export LP_R_B80_HYB=0.0198381 LP_R_B80_STR=0.0198381 LP_R_B40=0.0636927 EXPECT_N=11
export LP_R_SOURCE='orchestrator 2026-10-15: v2 L_R averages over all eligible sites (IPW), so lambda_par(R) = lambda_par(F) per boundary (V8-A4 item 1 count rule; Selection A O2 lambda_par_b80 .0198381, b40 .0636927); grid from v2 grad ratios (assets/aux-weight-stageB-grid-o5v2.json)'
export PYTHONUNBUFFERED=1 OMP_NUM_THREADS=8 PROJ_DATA=/data/user_data/$USER
export PY=$PROJ_DATA/envs/wllms/bin/python PYTHONPATH=$AE_CODE:$PROJ_DATA/envs/v6extra
for v in LP_R_B80_HYB LP_R_B80_STR LP_R_B40; do
  test -n "${!v:-}" || { echo "FATAL: $v unset (lambda_par(R) of the v2 loss is required)"; exit 1; }
done
LP_R_SOURCE=${LP_R_SOURCE:-"v2 L_R lambda_par(R) supplied by the orchestrator via LP_R_B80_HYB / LP_R_B80_STR / LP_R_B40"}
M=$PROJ_DATA/v8ws/dev/metrics
CUR=$AE_CODE/intermediate-analyses/2026-10-09-workspace-assets/aux-weight-selection.json
CUR_SEL_SHA=83bf903038a4a7deaed19bc0771b78fa06ae31b9f63534d335002f3ffb8bc97e
# matched NTP references: the v2 re-scores (v8ws-devmetrics-ntpv2-5M-*; carry r.design), overridable
NTP_HYB=${NTP_HYB:-$M/K4-b80-hybrid-indep-d02-ntpv2.json}
NTP_STR=${NTP_STR:-$M/K4-b80-strict-indep-d0-ntpv2.json}
CANDS=$(ls $M/K4-b80-hybrid-indep-d02-O5-lf0.01984-lr*-o5v2.json $M/K4-b80-strict-indep-d0-O5-lf0.00496-lr*-o5v2.json 2>/dev/null \
        | grep -E '/K4-b80-(hybrid-indep-d02-O5-lf0\.01984|strict-indep-d0-O5-lf0\.00496)-lr[0-9.e-]+-o5v2\.json$' | tr '\n' ' ')

phase precheck "false" "
    n=0; for f in $CANDS; do test -s \$f && test -s \$f.sessions.npz || { echo MISSING \$f; exit 1; }; echo cand \$f; n=\$((n+1)); done; echo candidates \$n
    nh=\$(printf '%s\n' $CANDS | grep -c -- '-hybrid-' || true); ns=\$(printf '%s\n' $CANDS | grep -c -- '-strict-' || true)
    test \$nh -ge 2 && test \$ns -ge 2 || { echo too few O5 v2 candidates: hybrid \$nh strict \$ns; exit 1; }
    test -z \"\${EXPECT_N:-}\" || test \$n -eq \$EXPECT_N || { echo expected \$EXPECT_N candidates, found \$n; exit 1; }
    case \"$CANDS $NTP_HYB $NTP_STR $CUR\" in *val_seen*|*val_unseen*|*evals/v7f-labels/val_*|*v8ws/evals/*) echo FORBIDDEN input path; exit 1;; esac
    test -s $NTP_HYB && test -s $NTP_HYB.sessions.npz && test -s $NTP_STR && test -s $NTP_STR.sessions.npz || { echo 'MISSING NTP reference (v2 re-score; run the v8ws-devmetrics-ntpv2-5M-* exps first):' $NTP_HYB $NTP_STR; exit 1; }
    test -s $M/std-5M.json && test -s $M/std-200M.json || { echo MISSING reference; exit 1; }
    test -d $PROJ_DATA/v8ws/dev/oracle-corpus || { echo MISSING dev oracle corpus; exit 1; }
    \$PY - $CUR $CUR_SEL_SHA $NTP_HYB $NTP_STR <<'PYEOF'
import json, sys
c = json.load(open(sys.argv[1]))
assert c['selection_sha256'] == sys.argv[2], ('current selection file is not the expected one', c['selection_sha256'])
assert c['rule_sha256'].startswith('ea0b49e9') and 'o5_rerun' not in c, 'current file: rule / already re-run'
for p in sys.argv[3:]:
    d = (json.load(open(p)).get('r') or {}).get('design')
    assert d in ('o5v2', 'q1_complete'), f'{p}: NTP r.design {d!r} is not the exact-mean form; re-score it with the current dev_metrics'
print('current selection', c['selection_sha256'], 'NTP r.design OK')
PYEOF
    sha256sum $CUR $NTP_HYB $NTP_STR
"
phase select "false" "
    cd \$AE_CODE && \$PY -m scripts.v8.select_aux_weights --only-group O5 --selection $CUR \
      --out \$AE_RESULTS/aux-weight-selection.json --candidates $CANDS \
      --ntp $NTP_HYB $NTP_STR \
      --std $M/std-5M.json $M/std-200M.json --oracle-dir $PROJ_DATA/v8ws/dev/oracle-corpus \
      --lambda-par b80:R:hybrid=$LP_R_B80_HYB --lambda-par b80:R:strict=$LP_R_B80_STR --lambda-par b40:R=$LP_R_B40 \
      --lambda-par-source '$LP_R_SOURCE' \
      > \$AE_RESULTS/select.log 2>&1 || { tail -30 \$AE_RESULTS/select.log; exit 1; }
    tail -30 \$AE_RESULTS/select.log
    cp $CUR \$AE_RESULTS/aux-weight-selection.prev.json
"
phase postcheck "false" "
    cd \$AE_CODE && \$PY - $CUR \$AE_RESULTS/aux-weight-selection.json <<'PYEOF' | tee \$AE_RESULTS/postcheck.log
import json, sys
from scripts.v8 import select_aux_weights as SEL
ta, tb = open(sys.argv[1], encoding='utf-8').read(), open(sys.argv[2], encoding='utf-8').read()
a, b = json.loads(ta), json.loads(tb)
SEL.postcheck_o5(a, b, ta, tb)
r = b['o5_rerun']
assert r['o5_loss_version'] == 2 and r['reason'] == 'V8-A9 O5 loss deviation', r
assert all(c['cell'].endswith('-o5v2') for c in b['candidates'] if c['group'].startswith('O5/'))
for g in SEL.O5_GROUPS:
    s = b['selected'][g]
    assert isinstance(s['lambda_b80'], float) and isinstance(s['lambda_b40'], float), (g, s['lambda_b40'])
    print(f'{g:22s} m*={s[\"m_star\"]:.4g} lambda_b80={s[\"lambda_b80\"]:.5g} lambda_b40={s[\"lambda_b40\"]:.5g} '
          f'cell={s[\"selected_cell\"]} within_1se={s[\"within_1se_of_best\"]} notes={s[\"notes\"]} '
          f'(old m*={a[\"selected\"][g][\"m_star\"]:.4g} lambda_b80={a[\"selected\"][g][\"lambda_b80\"]:.5g})')
print('selection_sha256', b['selection_sha256'], 'previous', a['selection_sha256'])
print('POSTCHECK OK: O5-only re-run; every non-O5 group byte-identical; rule unchanged')
PYEOF
"
