# Cluster card — <cluster name>

<!-- Everything the orchestrator needs in normal operation, in under ~80 lines. Verified facts only,
     each with how/when it was verified. Long references go in a separate file to grep, never load.
     A complete real example: examples/cluster/card-example-babel.md. -->

## Pools
| | <AE_PARTITION> | <AE_PARTITION_GEN, if any> |
|---|---|---|
| GPU QOS | <qos> | <qos> |
| CPU-only QOS | <qos> | — |
| GPUs / running / submitted per user | <n> / <n> / <n> | <n> / <n> / <n> |
| Max walltime | <d-hh:mm:ss> | <d-hh:mm:ss> |
| Preemptible | <yes/no> | <yes/no> |
| Default walltime | <value> — never omit `-t` | |

## Storage
| path | shared between nodes | on login node | quota | notes |
|---|---|---|---|---|
| <path> | <y/n> | <y/n> | <size> | <notes> |

## Traps (verified)
- <trap>: <what happens> — <how to avoid> (verified <date>)

## Measured
- Typical queue wait: <value> (<date>)
- Preemption rate: <value> (<date>) — `ae-capacity`
