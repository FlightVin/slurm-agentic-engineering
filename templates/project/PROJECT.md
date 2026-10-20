# PROJECT — <project name>

<!-- The plug-in point for the science. The orchestrator reads this at every session start.
     Keep the top section short (~30–60 lines); append owner amendments at the end, in order,
     each with a date and a one-line summary. Never rewrite an amendment after the fact. -->

## Objective
<!-- The question this project answers, in two or three sentences. -->
<objective>

## Success criteria
<!-- What must be true for the project to be done. Concrete and checkable. -->
- <criterion>

## Hypotheses
- H1: <hypothesis>

## Constraints
<!-- Compute/time budget, deadlines, what must not change, data-use rules (e.g. which split may
     drive selection decisions). -->
- <constraint>

## Required artifacts
<!-- Final deliverables and where they live (report path, tables, plots). -->
- <artifact> -> <path>

## How a run executes
<!-- Entry points, environment, the command an experiment's phases call. -->
- Environment: <how to activate on the cluster>
- Training / evaluation entry point: <command>

## Data and paths
<!-- Where datasets and checkpoints live on COMPUTE storage. Anything a later experiment consumes
     goes here, never in $AE_RESULTS. -->
- PROJ_DATA: <compute-side path>

## What a finished experiment must emit
<!-- The small distillate written to $AE_RESULTS (harvested; stays under AE_HARVEST_MAX_KB). -->
- <file>: <contents>

## Amendments
<!-- ## Amendment A1 (owner, <YYYY-MM-DD>) — <title>
     <text, verbatim or faithfully summarised> -->
