# Examples — preserved history, never active defaults

Everything here comes from real projects run with this harness on a two-pool preemptible cluster
("Babel"). Nothing in this directory is read by `ae`, copied by `ae init`, or restored by
`scripts/reset_project.py`. Use it to see what good working documents, experiments, briefs and
audits look like at the end of a long study; copy patterns, not content.

| path | what it is |
|---|---|
| `project-example.md` | a full `PROJECT.md`: objective, protocol, nine owner amendments in order |
| `state-example.md` | `STATE.md` at the end of the study (compact, verified facts only) |
| `checklist-example.md` | a long-running `CHECKLIST.md` with NON-NEGOTIABLE owner sections |
| `findings-example.md` | append-only `FINDINGS.md`, including dated CORRECTION entries |
| `implementation-log-example.md` | `IMPLEMENTATION-LOG.md`: machinery lessons (permissions, NFS, ...) |
| `decisions-example.md`, `sweep-ledger-example.md` | small decision log; a hyper-parameter sweep ledger |
| `cluster/card-example-babel.md` | one project's `cluster/CARD.md` at the end of a study, with its project-specific notes (the harness's own Babel card is `templates/project/cluster/CARD.md`; the reference moved to `templates/project/cluster/BABEL.md`) |
| `cluster/config-babel.sh` | that project's filled-in `config.sh` (same Babel values as `config.example.sh`, plus its repo/branch and a raised harvest cap) |
| `exp/sim-*.sh` | a validated diamond DAG (pretrain → two midtrains → report) that survived a real preemption |
| `exp/v8ws-*.sh` | production experiment definitions: training, sweep points, dev scoring, teacher cache, selection, audits, final report build |
| `briefs/*.md` | tinker briefs, each with Objective / Do NOT / exact success command |
| `audits/*.md` | a scheduled deep audit and a closeout audit before a final report |
| `bin/*` | study-specific helpers that preceded `ae-watch`, `ae-capacity` and `ae-topup` (not executable on purpose) |
| `docs/claude-md-original.md` | the project `CLAUDE.md` that `agent.md` was generalised from |
| `docs/claude-md-earlier-sample.md`, `docs/readme-original.md` | earlier versions of the operating manual and README |
| `docs/log-example-2026-10.md` | a monthly reasoning log (`log/YYYY-MM.md`) |
| `docs/acceptance-checklist-example.md` | a requirement-by-requirement acceptance checklist |
| `docs/topup-queue-example.txt` | an `ae-topup` queue file |

To try one of the `sim-*` experiments in a project: copy it into your workspace `exp/`, set its
`PROJ_DATA` for your cluster, then `ae submit sim-pretrain`.
