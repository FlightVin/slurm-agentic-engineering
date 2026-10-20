# inv/{{ID}} — {{QUESTION}}

## Objective
<What must be TRUE when this is done. Two or three lines. Be specific enough
that the agent can tell whether it succeeded.>

## Scope
Touch only: <paths>
Do NOT: <explicit exclusions — other modules, full-scale data generation,
         anything that would take hours>

## Success criterion
<The exact command to run and the observable that means it worked.>
```
<command>
```
→ expect: <observable>

## Context you need
- <3-5 bullets, or pointers to files. NOT the project's whole history.>

## Report back
Write `.ae-report.md` in your worktree (the exact path is given in your prompt),
at most 40 lines:
### Changed
### Verified   — command + ACTUAL output, <=20 lines
### Uncertain  — anything you did not verify. Say so plainly.
### Cost       — wall time, GPU type
