# V8 workspace experiments — execution instructions

## 1\. Goal, deadline, and order of work

Test whether workspace tokens improve the existing V7 poker predictors. Train workspace variants of the **5M and 200M** models and compare them with the already-trained standard models and existing oracles. **Do not retrain standard 5M or standard 200M.** Locate their final checkpoints through `intermediate-analyses/` and the associated code, configs, and run records.

**Hard reporting deadline: October 10, 2026, 1:00 PM America/New\_York (EDT; 17:00 UTC).** This absolute deadline supersedes the earlier relative 18-hour window. Training, evaluation, result harvesting, and report writing must be interleaved. Do not finish training first and leave all evaluation until the end. You must use both the general as well as the preempt babel partitions effectively to ensure the fastest complete results.

Use this priority order for scheduling AND producing evaluated results:

1. **4 workspace tokens, ordinary NTP**, all configurations.  
2. **4 workspace tokens, auxiliary objectives, full historical access** (`hybrid`).  
3. **4 workspace tokens, auxiliary objectives, partial historical access** (`strict`).  
4. **16 workspace tokens, ordinary NTP**, all configurations.

Within each tier, progress both model sizes and prioritize completing training plus both validation evaluations, rather than merely starting many jobs. Earlier-tier runnable work and evaluation take precedence. Backfill later-tier work only when it does not delay earlier-tier results. Recover baseline/oracle suffix scores early in parallel.

Implement actual scheduler/watchdog timers, not just a written intention:

| Time, EDT on October 10 | Required action |
| :---- | :---- |
| Continuously | Harvest completed evaluation shards; update analysis within 20 minutes of material results |
| At execution start, then hourly | Recalculate training \+ evaluation ETAs and disk/GPU availability; log completion forecast |
| 10:00 AM | Deadline feasibility audit; prioritize completing earlier-tier cells and their evaluations |
| 12:00 PM | Stop launching work whose measured ETA would compromise final evaluation/reporting; reserve adequate evaluation resources |
| 12:30 PM | Assemble final coverage tables and narrative while remaining feasible evaluations finish |
| 12:45 PM | Close out unfinished compute safely; finish harvesting, integrity checks, and plots |
| **By 1:00 PM** | **Return the final report, complete available tables, artifact paths, and explicit missing-cell ledger** |

If starting after a milestone, perform that milestone immediately. Set scheduler wall times and a project-owned watchdog so jobs cannot drift beyond closeout. Apply timers only to this study's jobs. Do not silently extend the deadline, shorten training, or represent pending measurements as results.

## 2\. Recover the existing implementation; change only what is new

Start implementation from the current fetched **main** in a new branch/worktree. Preserve unrelated dirty work. Inspect `intermediate-analyses/`, past code/changes, existing datasets, model configs, checkpoint records, evaluation scripts, oracle outputs, and compute harness. Locate the actual resources; do not rely on guessed paths or historical filenames supplied externally. If required implementation lives in earlier changes, inspect and port it explicitly onto the new main-based worktree.

Before launching production, write a compact resolved-inputs/config manifest identifying:

- Existing training corpus and what **`val_seen` and `val_unseen`** actually mean; use the repository's names, with no invented “well” aliases.  
- Tokenizer, population/split definitions, legal-action labels, information boundaries, session structure, and model-visible versus metadata-only information. Read and understand these; preserve them.  
- Existing V7 5M/200M architecture configs, training seed settings, optimizer conventions, final standard checkpoints, and oracle algorithms/results.  
- Data/config/code/checkpoint identifiers, discovered paths, and integrity fingerprints sufficient to reproduce the work.

**Reuse all existing datasets without regeneration or synthetic continuation generation.** Derived index maps and teacher caches are allowed. Do not alter policies, splits, parser grammar, legal-action semantics, or oracle priors to improve results. Missing artifacts are explicit blockers, not grounds to fabricate replacements.

Use **the seed settings from the earlier configurations**, with one run per configuration and no seed sweep. Recover the values rather than choosing a new seed. Preserve the existing backbone architectures and positional conventions. Hyperparameter selection and optimization are your responsibility using existing training/development evidence, never final validation tuning; record and justify choices.

Every production training run is **from scratch for exactly four complete epochs** over the original training corpus, including short sessions. No early stopping, data subsampling, extra auxiliary-only epochs, or fifth epoch. Requeue/resume continues the same run. Epochs count original data passes, not inserted workspace positions. Reuse standard checkpoints only as comparators/teacher, not initialization for these from-scratch workspace experiments.

## 3\. Exact scope and counts

Both model sizes participate in every applicable cell. Auxiliary models of either size use the existing frozen standard 200M teacher; a 200M student is same-size distillation.

Basic factors:

```
model_size:   5M, 200M
WS_count:     4, 16
access:       hybrid, strict
boundary:     after 40 completed hands, after 80 completed hands
construction: causal, independent
WS_dropout:   0, 0.2
objective:    NTP
```

Auxiliary factors: fix WS\_count=4, cross both sizes, both accesses, both boundaries, both constructions, both dropout values, and objectives O1–O5 below. No-auxiliary controls are already in the basic sweep.

| Priority | Scope | Runs |
| :---- | :---- | ----: |
| 1 | 4 WS, NTP: 2 sizes × 2 accesses × 2 boundaries × 2 constructions × 2 dropout values | 32 |
| 2 | 4 WS, hybrid auxiliary: 2 sizes × 2 boundaries × 2 constructions × 2 dropout values × 5 objectives | 80 |
| 3 | 4 WS, strict auxiliary: same product as tier 2 | 80 |
| 4 | 16 WS, NTP: same product as tier 1 | 32 |
| **Total** | **64 basic \+ 160 auxiliary; no baseline retraining** | **224** |

Generate the full manifest and assert uniqueness/counts before scheduling. A row contains every factor, recovered seed settings, exact four-epoch budget, status, job/checkpoint lineage and validation coverage. This is the required scope, not a claim that available resources can finish it by the deadline. Measure feasibility immediately. If capacity is insufficient, preserve the priority order and all manifest rows, and report uncompleted cells honestly.

### 3.1 Tasks and interpretation of the basic ablations

Implement and run every Cartesian-product cell above; do not pick one anchor and vary only one factor. For each factor comparison pair runs differing only in that factor, within model size and objective, then report both individual paired differences and the distribution of differences across other settings.

| Factor | Implementation task | Scientific comparison and limits |
| :---- | :---- | :---- |
| 4 versus 16 WS | Insert the selected number of positions using the same marker and backbone. | More memory positions and computation, not more unique training data. The positional shift and attention cost also change; do not call this a pure information-capacity experiment. Only NTP has this count comparison. |
| Hybrid versus strict | Change suffix-to-prefix visibility at every layer; leave prefix/WS construction identical. | Does the summary help with history still available, and can it replace historical access? A hybrid gain alone does not show compression sufficiency. |
| Boundary 40 versus 80 | Parse completed hands and insert once at the selected boundary. | Later compression has more source evidence and a shorter suffix. Use common-query comparisons as well as each boundary's full eligible suffix. |
| Causal versus independent WS | Allow or block attention between workspace positions as specified below. | Does communication among slots help? Both use the same layer count and one batched training pass. Neither samples workspace symbols. |
| Dropout 0 versus 0.2 | Mask future access to a random subset of already-constructed slots. | Does training with unreliable slot access improve prediction/robustness? Validation retains all slots. This is distinct from dropping history or applying ordinary activation dropout. |

Execution tasks: implement the index mapping and reference masks; verify losses/gradients; launch the priority-1 matrix; harvest suffix scores against existing baselines/oracles; implement auxiliary labels/heads while basic runs progress; run tiers 2 and 3; run tier 4 as capacity allows. Report negative results without changing the dataset or excluding hard groups.

## 4\. Workspace inputs, construction, and masks

### 4.1 Tokenization and placement

Inspect the existing vocabulary for unused/reserved IDs. Prefer **one existing ID verified absent from all original train/validation tokens and distinct from BOS, EOS, padding and action IDs**, reused at every workspace position. Preserve vocabulary size and checkpoint compatibility when possible. Do not assume an unused-looking ID is actually safe. If no safe ID exists, append a single marker without renumbering old IDs and record the exact parameter change.

Workspace inputs are fixed markers with trainable embeddings. Their context-dependent hidden states/per-layer K/V representations are the memory. **Do not decode/sample workspace vocabulary outputs, and do not apply a teacher-forcing loss to workspace targets.** Future ordinary-token loss backpropagates through workspace representations. Retain the original ordinary-vocabulary output normalization: if an existing reserved ID is reused, keep its original softmax treatment; if a new ID is appended, exclude that new output class from ordinary prediction normalization. Record which case applies.

**Concrete tokenizer contract:** operate on the existing dataset's integer token IDs, after its original tokenizer/parser. Do not serialize a literal string such as `[WS]` into the raw text and let an unrelated tokenizer split it. A debug name such as `WS` is only a display label for the chosen single ID. Record `ws_token_id`, original vocabulary size, output-class exclusions, tokenizer fingerprint and the verified zero-occurrence count in original data. Reserve this ID consistently across all configurations; do not assign distinct IDs to each slot or change IDs by model size. Original action tokens remain single original IDs, and existing oracle/parser inputs never receive the inserted marker.

The same learned input embedding is used at all WS positions; augmented positional information and their allowed context distinguish their hidden states. Preserve embedding tying if present. If the backbone has position-only attention encodings rather than additive position embeddings, retain them unchanged. Independent slots may be similar when their position signal is weak; report measured redundancy rather than adding unrequested slot-specific parameters.

A marker ID, its input embedding, its layerwise hidden states, and its output logits are different objects. The ID is fixed, the embedding is a learned parameter, and hidden states are computed afresh from each session. There is no stored cross-session belief, no supervision saying what a WS symbol should be, and no generated WS token target. With tied embeddings, the row can also receive ordinary softmax-denominator gradients under the original reserved-ID convention; this is not a positive WS-target loss. Audit downstream gradient flow separately.

For original session x\[0..n-1\], let c be the index of BOH immediately following the b-th completed hand. Insert once, only if that next hand exists:

```
y = x[:c] + [WS]*K + x[c:]
P = [0,c)                 # old prefix
W = [c,c+K)               # workspace span
S = [c+K,n+K)             # ordinary suffix
e = c+K-1                # final workspace position
phi(i) = i if i<c else i+K
```

Short sessions with \<=b hands receive no workspace: train them normally, but they have no eligible validation targets. Do not insert repeatedly every b hands. Keep original IDs/order unchanged and save original↔augmented offset maps. Reset positions at session boundaries using the original positional scheme; use sequential augmented positions, recording the K-position suffix shift. No truncation of long sessions. Isolate packed sessions in attention and loss.

### 4.2 Allowed keys at every layer

| Query region | Allowed keys |
| :---- | :---- |
| Prefix | Causal prefix only |
| WS, causal construction | All prefix plus self and preceding WS positions |
| WS, independent construction | All prefix plus self only; no other WS positions |
| Suffix, strict | Retained WS plus causal suffix; no prefix, including header |
| Suffix, hybrid | All prefix plus retained WS plus causal suffix |

Both construction modes run in a standard teacher-forced decoder pass with different masks. “Causal” does not require repeated final-state feedback or K separate generation passes. Independent means independent slot construction given common history, not independent prediction of vocabulary labels. Future-token access is forbidden. No separate encoder or recurrent architectural change is in this scope.

Strict compresses only pre-boundary history. Newly observed suffix hands remain available. The stored memory is the complete layerwise WS bank, not merely final-layer vectors. Every implementation/kernel/cache path must respect the same graph.

### 4.3 Dropout

Construct all slots first. At training time independently retain each WS slot with probability 1-p, with one mask per session/epoch, constant across layers and suffix positions. Mask dropped WS **keys for suffix queries**; do not delete input positions or change WS construction. Keep all slots at evaluation. Use purpose-separated deterministic randomness derived from recovered run settings, reproducible after resume.

Boundary exception to implement explicitly: the final WS hidden state predicts the first suffix token. If that slot is dropped, replace this one prediction's readout state with a content-free state derived from the WS input embedding through the ordinary final norm/head. Otherwise a dropped slot's residual path would still reveal history. If retained, use its normal hidden state. This prediction is normally BOH; later action queries can use every retained slot. In independent construction the first structural prediction reads only the final slot, not all slots; do not add a hidden extra computation pass to change that. Test all-dropped cases. In causal construction, retained slots may already summarize dropped slots; this is expected access dropout, not erasure during construction.

## 5\. Training and validation must use different target masks

Let z\[i\] be logits at input position i, predicting target y\[i+1\]. Define masks on **target indices**, not predictor indices.

```
T(t) = 1 if y[t] is an original predictable nonpadding token,
       has a predecessor within the same session,
       and is not excluded by original BOS/session-start conventions;
       0 for every workspace target, padding and cross-session target.

V(t) = T(t) * 1[t > e]  for sessions with an inserted workspace;
       0 everywhere     for sessions with no insertion.
```

Training:

\[ L\_{NTP}=-\\frac{\\sum\_t T(t)\\log q\_\\theta(y\_t\\mid z\_{t-1})}{\\sum\_t T(t)}. \]

**All ordinary prefix and suffix targets contribute**, including structural/card/amount/outcome tokens, not only actions. Do not detach prefix/WS gradients. Globally normalize by valid-target counts across devices/accumulation, not by unequal batch means.

Validation ordinary-token NLL uses **V**, never T. Action metrics use

\[ V\_r(t)=V(t),1{y\_t\\text{ is an action of role }r}. \]

No pre-workspace or workspace target may contribute to any reported validation accuracy, NLL, calibration, probability-mass statistic or model–oracle gap.

Alignment example:

```
input:    ... EOH  WS1  ... WSK  BOH  STACK ...
target:       WS1  ... WSK  BOH  STACK ...
train mask:    0   ...  0    1     1   ...
eval mask:     0   ...  0    1     1   ...
```

Earlier ordinary targets, including EOH, still have training loss from their own predecessors, but zero validation weight. **The final WS logit predicting BOH is eligible because the TARGET is after the span.** Do not discard it because its predictor is WS. Do not add a skip-over-WS prediction from EOH to BOH. If the framework shifts labels internally, do not shift twice. BOS ID zero must not accidentally become ignore\_index/padding.

Evaluate teacher-forced true histories, with dropout off. Process pre-boundary inputs to construct memory without scoring their predictions. Validation is inference-only. Empty evaluation cells have n=0 and NA, not 0% accuracy.

## 6\. Auxiliary tasks — four WS tokens only

### 6.1 Shared training contract

Every auxiliary run retains full-sequence NTP, including the original prefix targets. Auxiliary losses use **existing post-workspace TRAIN action sites**, both focal and opponent. The standard 200M teacher is frozen and evaluated on original unmodified visible prefixes. It gets neither WS markers nor extra cards/strategy metadata. No synthetic continuation, online teacher-generated action rollout, or new dataset is allowed. Student inputs are the same recorded trajectories under the configured access/dropout mask.

Teacher inference uses `eval()` and `no_grad()`; student inference remains differentiable through prefix and WS. Cache by teacher checkpoint, dataset, original query ID, legal-menu fingerprint, extraction convention and precision. Cache only selected sites/layers rather than complete attention tensors. Student auxiliary heads are trained jointly in the same four-epoch updates and removed for ordinary evaluation; count their parameters separately. No additional optimizer-only phase or epoch.

For eligible action site u, let A\_u be the exact engine-legal action-ID set. With teacher/student logits l\_T,l\_S, define

\[ p\_T^\\tau(a)=\\frac{\\exp(l\_T(a)/\\tau)}{\\sum\_{v\\in A\_u}\\exp(l\_T(v)/\\tau)},\\quad q\_S^\\tau(a)=\\frac{\\exp(l\_S(a)/\\tau)}{\\sum\_{v\\in A\_u}\\exp(l\_S(v)/\\tau)},\\quad D\_u=\\tau^2\\sum\_{a\\in A\_u}p\_T^\\tau(a)\\log\\frac{p\_T^\\tau(a)}{q\_S^\\tau(a)}. \]

Use stable log-softmax, identical legal menus and detached teacher probabilities. No vocabulary-wide KL is substituted. Temperature and auxiliary weights are selected on existing development evidence and frozen before final comparisons. Default candidate temperature 1 transfers actual teacher probabilities; temperature is not tuned to improve rank-based validation metrics. All reported inference probabilities use temperature 1\.

The five variants below are separate objectives, not cumulatively stacked O1+O2+O3+O4+O5. Within each variant, all 16 architectural cells per size are required. If auxiliary query subsampling is needed, predeclare inclusion probabilities and implement the specified mean or an unbiased estimator. A batch with no eligible auxiliary site has zero auxiliary contribution and normal NTP loss. Accumulate sums/counts across ranks correctly; do not average unequal microbatch means.

### 6.2 O1 — imitate the teacher's action distribution

**Task:** on each eligible observed suffix action, reproduce the teacher's soft probabilities rather than just its top action. This can convey uncertainty and plausible alternatives under partial observation.

\[ L\_{O1}=L\_{NTP}+\\lambda\_K\\frac{1}{|U|}\\sum\_{u\\in U}D\_u. \]

U contains eligible action sites in the effective training batch, with global counts across devices. Prefix ordinary tokens retain NTP but receive no auxiliary KL. Compare O1 to the same size/K/access/boundary/construction/dropout NTP run. This isolates the effect of teacher-distribution supervision. Hard-label NTP remains because the teacher is fallible.

### 6.3 O2 — preserve predictions across different future distances

**Task:** make the one workspace created at the boundary useful for both nearer and farther observed future actions, instead of allowing frequent near-term contexts to dominate auxiliary supervision.

For each eligible session s, partition observed suffix action queries by role and distance `completed_hands - boundary`: 0–9, 10–29, and \>=30. Let C\_s be its nonempty role×distance cells and U\_sc their queries. Define

\[ L\_F=\\frac{1}{|S\_+|}\\sum\_{s\\in S\_+}\\frac{1}{|C\_s|} \\sum\_{c\\in C\_s}\\frac{1}{|U\_{sc}|}\\sum\_{u\\in U\_{sc}}D\_u, \\qquad L\_{O2}=L\_{NTP}+\\lambda\_F L\_F. \]

S\_+ contains sessions with at least one eligible action. Each session contributes equally, then each of its nonempty cells equally. Preserve complete-session accounting if batches are chunked. Use the same teacher laws as O1; only weighting changes. Log cell sizes and weighted contributions. This is **balanced supervision on observed future contexts**, not evidence that multiple hypothetical futures were covered, and not a new MTP head. Compare O2 with O1 and matched NTP; keep auxiliary target budgets comparable.

### 6.4 O3/O4 shared task — predict which earlier hands matter to a future query

These add an evidence-ranking head to O2. They do not ask a workspace token to become the ID or textual description of a historical hand. Four slots may summarize many hands.

For each selected future query u, construct a training-only distribution over the b pre-boundary hands. Freeze a deterministic subset of existing training sessions/queries for these expensive targets, shared between O3 and O4. This limits auxiliary labels, not NTP data or epoch coverage.

A concrete head:

1. Compute `m` as the mean of retained final-layer WS states; use a learned null vector if none are retained.  
2. Construct a query feature `c_u` by pooling embeddings of the original current-hand tokens strictly before the target action. Exclude the target and all later tokens. This local feature does not read historical contextual states or metadata. A small trainable projection is sufficient; do not add a full-history encoder.  
3. Form `z_u = MLP(concat(m, c_u))`.  
4. For each old hand i, form detached candidate features `e_i` by pooling **input token embeddings**, not contextual states that encode other hands, plus a deterministic hand-index encoding. Candidate features exist only in the auxiliary head. Freeze/detach their construction for the auxiliary gradient path; record the exact pooling/encoding.  
5. Set `r_S(i|u)=softmax_i(z_u^T P e_i)` and train against the teacher relevance distribution with `L_E=mean_u KL(r_T(.|u)||r_S(.|u))` on the registered evidence-query set.

The candidate-hand bank must never feed action logits, the workspace construction, or the main predictor's query states. At evaluation remove the entire head and its candidate bank. Ensure retained WS states receive gradients from L\_E. The head could still exploit current-context/candidate shortcuts, so evaluate evidence rankings with WS replaced by a constant, in addition to normal rankings; this diagnostic does not count as another production training run. Evidence-ranking success alone is not proof of sufficient memory.

### 6.5 O3 — attention-derived evidence labels

**Teacher target:** at the original teacher position whose logits predict action u, extract final-layer attention before attention dropout (teacher eval mode), average across heads, and sum weights over the original tokens of each pre-boundary hand. Renormalize only across those b hands:

\[ a\_i(u)=\\frac{1}{n\_h}\\sum\_h\\sum\_{j\\in\\text{hand }i}\\alpha^{last,h}*{u-1,j}, \\qquad r\_T(i|u)=a\_i(u)/\\sum*{j=1}^{b}a\_j(u). \]

Exclude session header and suffix from this target. If the total old-hand mass is below a documented numerical threshold, skip only that query's evidence loss, retaining NTP/future KL and logging the skip. If the optimized teacher kernel cannot expose weights, use a verified equivalent extraction path on the registered subset, not guessed scores.

Train `L_O3 = L_NTP + lambda_F L_F + lambda_E L_E`. Compare O3 to O2 in identical cells to isolate attention guidance. Teacher attention indicates a computational access pattern; contextual values, residual routes and cancellations mean it is not a verified measure of causal information value.

### 6.6 O4 — intervention-derived evidence labels

**Teacher target:** for every old hand i at each registered query, compute a full-history teacher law p\_T and an intervened law p\_T^(-i). Recompute the intervened prefix from scratch with all tokens of hand i blocked as keys for every later query in every layer, including later positions inside that hand. Keep token positions/IDs and current query unchanged. Do not reuse unmodified later K/V states: they may already carry the erased evidence. Later observed actions/outcomes can themselves convey related information; the intervention removes one direct historical record, not all logically related evidence.

Define

\[ d\_i(u)=KL(p\_T(\\cdot|H\_u)\\Vert p\_T^{(-i)}(\\cdot|H\_u)), \\qquad r\_T(i|u)=\\operatorname{softmax}\_i(d\_i(u)/\\eta). \]

Both distributions use the original query's identical legal menu. Choose eta on development data. Compute all b hand scores for each selected query; if reducing query count for cost, keep the common O3/O4 subset fixed and report it. Batch interventions where memory permits and cache only resulting scores/laws.

Train `L_O4 = L_NTP + lambda_F L_F + lambda_E L_E`. Compare to O2 and O3. This is a deliberately distribution-shifting teacher intervention on fixed data, not a generated poker trajectory. Scores measure sensitivity rather than guaranteed usefulness; one-at-a-time interventions miss redundant or complementary evidence. Report numerical instability and label cost without dropping difficult action sites from the main objectives/evaluation.

### 6.7 O5 — teacher representation supervision

**Task:** help the student's action-prediction computation approximate the teacher's internal representation, in addition to its output probabilities. Extract both final prediction-position hidden states **after their existing final normalization and before the vocabulary projection**. The teacher position is the predecessor of the original action; the student position is its mapped augmented predecessor.

Use a trainable linear map P from student width to teacher width (also trainable for a same-size student). Let `normalize(v)=v/max(||v||_2, epsilon)`:

\[ R\_u=|\\operatorname{normalize}(P h\_S(u))-\\operatorname{stopgrad}(\\operatorname{normalize}(h\_T(u)))|\_2^2. \]

Average R\_u using the same role/horizon/session weighting as L\_F, and train `L_O5 = L_NTP + lambda_F L_F + lambda_R L_R`. Record epsilon and extraction convention. The projection is discarded after training. Do not directly equate four WS states with arbitrary teacher token states. Gradients reach WS through the student's prediction path; hybrid models can instead use raw history, so this loss does not establish workspace use.

### 6.8 Algorithmic rationale and required loss diagnostics

NTP is proper conditional log loss; direct prefix supervision supplies gradients without relying solely on the bottleneck. Distillation supplies conditional probability targets richer than one observed action. For memory M=f(H) and visible suffix/query D,

\[ \\mathbb E\[-\\log q(A|M,D)\]-H(A|H,D) \=I(A;H|M,D)+\\mathbb E KL(p(\\cdot|M,D)\\Vert q(\\cdot|M,D)). \]

A bottleneck can discard predictive information while making the remaining map easier to learn. It cannot create information or guarantee matching 200M. For dropout condition on its retention realization; M includes retained layerwise representations. Do not infer Bayesian internal computation from teacher agreement or attention imitation.

For every objective log NTP numerator/denominator, each auxiliary raw mean and weight, weighted contribution, eligible/used/skipped queries, role/horizon coverage and gradient norms for WS versus backbone versus head. Unit-test exact O1/O2/O5 aggregation on unequal cell sizes; teacher gradients must be absent, student gradients present. Apply no auxiliary head at reported model/oracle validation scoring. Hyperparameter choices remain with the executing agent and must not alter these task definitions.

## 7\. Evaluation and oracle comparisons

Recover existing scorers and all oracle methodology from code/results; preserve their priors, legal semantics, information privileges, numerical settings and validity flags. Identify known/unknown focal and known/unknown opponent references and which are exact or approximate. Reuse per-query outputs where valid; do not rerun expensive oracle inference unnecessarily.

Process the entire visible history in the oracle before filtering predictions to suffix queries. Never reset the posterior at the insertion boundary. Full-history oracle references are not workspace-matched exact oracles. Explicitly retain any unseen-family prior privilege and unknown-opponent approximation limitations.

Use stable original query IDs: dataset/session/original target offset/role/decision. For each boundary, every configuration must score the identical eligible query set, independent of WS count, size, masks, dropout and loss. Re-score existing standard 5M/200M on unmodified histories using those same query IDs; whole-session historical aggregates are not acceptable suffix comparators. Reuse cached per-query standard results when adequate.

Evaluate every final checkpoint on complete `val_seen` and `val_unseen` separately. Required suffix-only outputs:

- Focal and opponent legal-action and all-action top1/top2/top4; all-action means existing action vocabulary, not all vocabulary tokens.  
- Legal-normalized action NLL, ordinary-vocabulary action NLL, ordinary suffix-token NLL, realized-action probability, illegal/non-action mass with normalization declared.  
- Exact eligible counts, group/template and controlled/rare slices, completed-hand counts and contiguous five-hand bins, distance after insertion; decision-weighted and session/actor-macro metrics.  
- Paired differences and session-clustered uncertainty where feasible; not training-seed uncertainty.  
- Each applicable oracle on exactly matched queries. Separate full validation coverage from frozen sampled-oracle coverage. Evaluate models on existing saved sampled-oracle inputs when available; never present sampled results as full validation or regenerate missing sample inputs.

Oracles are independent of WS count/construction/dropout; filter once per split/boundary and join their tables to configuration results. Expose missing coverage/approximation flags, never drop failed sites to improve accuracy. Use original deterministic ties and legal deduplication. Assert top1\<=top2\<=top4, legal\>=all-action and top-k=1 when menu size\<=k. Zero-probability NLL is infinite; any display clipping must be explicit.

Boundary40 and80 score different suffix populations. Also report paired comparisons on their exact common query intersection, not just incomparable suffix totals. Do not tune on these final evaluations.

## 8\. Implement → verify → fix → verify

Write salient tests before production, implement, test and review, fix every discovered bug, then repeat until all checks pass with no known unresolved correctness issue. Re-run affected tests after changes. Quarantine invalid results/checkpoints; correctly evaluating an incorrectly trained model does not repair it.

Required gates:

1. Factorial counts/IDs/priorities correct; reused standard baselines; recovered seeds; four-epoch budgets.  
2. Dataset/tokenizer unchanged; reserved WS ID verified safe; original↔augmented mapping and action labels correct.  
3. Boundary lengths39/40/41 and79/80/81; one insertion only; short sessions train but have zero validation targets.  
4. Target-index mask/alignment fixture: all prefix ordinary targets trained, none validated; WS targets never scored; first suffix target scored once; BOS/padding/packed-session handling.  
5. Nonzero prefix NTP gradients and downstream WS gradients; no inadvertent detach; finite empty-auxiliary behavior.  
6. Layerwise mask tables, no future or cross-session leak, independent slots isolated. Hold all WS K/V fixed and perturb prefix states: strict suffix outputs must remain unchanged.  
7. Dropout deterministic across resume/recompute; dropped keys inaccessible; boundary readout/all-dropped cases correct.  
8. Optimized kernel versus reference forward/gradient parity; cached versus full teacher-forced inference parity; no hidden causal-mask override or all-masked NaNs.  
9. DDP/accumulation globally weighted loss correct; no duplicate/drop of final data batches; exact resume/data-cursor equivalence and four full epochs.  
10. Teacher labels aligned/no leakage; teacher frozen; distinct O1/O2 weighting; evidence heads cannot bypass into action logits.  
11. Model/baseline/oracle query equality; scoring invariants; exact numerator/denominator fixtures.  
12. Idempotent shard harvesting, missing/duplicate detection, checkpoint completion/integrity gates and report masking checks.

Tiny software fixtures/overfit checks are tests, not shortened reportable experiments. Discard their weights. Keep concise test results and bug/fix records in the analysis assets.

## 9\. Compute and disk management

Use all available authorized GPUs effectively across **general and preemptible partitions**. Inspect actual partitions/quotas rather than guessing. Benchmark throughput early for both sizes and actual masks. Parallelize independent 5M jobs, including measured safe GPU sharing where useful; use multi-GPU 200M only when throughput justifies it. Reserve resources for evaluation/teacher-cache jobs throughout. Use length bucketing, verified efficient attention/precision and data caching; never truncate sessions or reduce epochs for speed.

You are authorized to delete files as required to manage this project's storage. Use targeted deletion and record what was removed. Preserve original datasets, the standard 5M/200M checkpoints needed here, source/provenance, final study checkpoints, and result tables; do not remove unrelated users' work. Recomputable caches, temporary files, failed-run outputs and superseded study checkpoints can be deleted when no active consumer needs them.

**Rolling checkpoint policy:** retain the last verified resumable checkpoint only. Write its replacement atomically, verify it loads and includes optimizer/scheduler/RNG/data cursor, then delete the older checkpoint. Brief overlap during verification is allowed; do not accumulate epoch or step snapshots. Verify whether the existing trainer already implements this and fix it if not. At training completion retain only the final checkpoint; delete intermediate checkpoints and redundant optimizer snapshots. Final checkpoint metadata must prove four epochs; preserve resumable state only while it remains necessary. Coordinate deletion with readers and don't delete an in-flight evaluator's checkpoint.

Preemption: periodic durable rolling saves plus signal-triggered save when possible; resume exact committed cursor without duplicate updates. Record lineage/requeues and ETA. Budget cache size; share immutable teacher targets across runs and delete consumed temporary caches when safe. Monitor disk proactively so checkpoint writes cannot fail from avoidable exhaustion.

## 10\. Continuous analysis and final return

Create immediately:

```
intermediate-analyses/2026-10-09-workspace-intermediate-analyses.md
intermediate-analyses/2026-10-09-workspace-assets/
```

Keep the intermediate document updated as evaluations arrive, with results ordered by the four priorities. Store canonical machine-readable manifest/job/shard ledgers and long-form CSV/Parquet metrics, plus Markdown tables and plots generated from them. Use atomic single-writer aggregation. Every partial row shows completed/expected coverage; never rank partial results as complete. Preserve statuses for all 224 cells.

Minimum metric keys/values:

```
run_id, priority, size, WS_count, access, boundary, construction, dropout,
objective, recovered_seed, epochs_completed, checkpoint_id, dataset_id,
split, coverage_kind, role, group, history_bin, metric, normalization, k,
numerator, denominator, value, n_sessions, flagged_queries,
completed_shards, expected_shards, status, updated_at, evidence_path
```

Retain sufficient per-session/query statistics for paired comparisons. Report NA with reasons, not invented zeros. Plot accuracy/NLL versus history and group with matched baselines/oracles, facet by split/role/configuration, and include factorial/auxiliary differences. Keep plots readable and provide all underlying data tables. Training charts may show prefix/suffix components; validation charts are suffix-only.

Interleave job submission, monitoring, eval launches and analysis updates until the deadline. At closeout produce `intermediate-analyses/2026-10-09-workspace-final-analysis.md` containing:

1. Completed/required counts by priority, model size, training and each validation split; blockers and deadline status first.  
2. Complete available validation accuracies for both model sizes and every applicable configuration, separated into `val_seen`/`val_unseen`; explicit missing rows for unfinished cells.  
3. Existing standard-model suffix baselines and all applicable matched oracle tables, with sample coverage and information/approximation qualifications.  
4. Paired effects, history/group plots, exact denominators, uncertainty limitations and conservative interpretation.  
5. Recovered configs/seeds, changes to code/token use, tests and fixes, compute/storage/deletion ledger, reproduction commands and artifact locations.

A complete run requires four valid epochs and both full validation evaluations with correct suffix masks. The final response must be returned **by 1:00 PM EDT October 10**, even if scope is incomplete: provide results already obtained and a precise remaining-work ledger. Do not defer reporting until every scheduled job finishes.  
## Amendment V8-A1 (owner, 2026-10-09 20:30 EDT) — 5M students only

1. **Only 5M models are trained.** No 200M model is trained in this study, in any tier.
2. **The 200M participates only as the existing, already-trained V7 standard 200M**, located and verified:
   `$PROJ_DATA/runs/naivepoker_v7_pretrain_200M_4epoch/std/4B/seed-6-c11b76c35a8e/`,
   `checkpoint-01790932025709805600-28f193cd.pt` (sha256 prefix `d9b7beec54d6`, step 108,648, seed 6;
   passes `scripts/v7/final_ckpt.py`). Uses: (a) frozen teacher for O1–O5 (§6), and (b) suffix comparator
   re-scored on the identical query sets (§7). The 5M standard comparator is
   `.../naivepoker_v7_pretrain_5M_4epoch/std/4B/seed-6-4388e837adfe/` (sha256 `cd057b2edbe0`).
3. **Scope becomes 112 trainable cells**: P1 16 (4 WS NTP), P2 40 (4 WS hybrid aux, O1–O5), P3 40 (4 WS strict
   aux), P4 16 (16 WS NTP). Priority order unchanged. The 112 200M rows remain in the 224-row manifest with
   status `out_of_scope_owner_A1`; they are not failures and are not reported as missing results.
4. Everything else in this document (four full epochs, recovered seed 6, masks, targets, evaluation,
   deadline 2026-10-10 13:00 EDT, honest missing-cell ledger) is unchanged.

## Amendment V8-A2 (owner, 2026-10-09)

**Amendment V8-A2 (owner, 2026-10-09).** The 13:00 EDT Oct 10 deadline becomes a *draft* deadline; the study continues to full completion afterward.

1. **Draft by 13:00 EDT, Oct 10:** write `intermediate-analyses/2026-10-09-workspace-final-analysis-draft.md`. It is built from cells that are fully complete (four valid epochs plus both `val_seen` and `val_unseen` evaluations), in priority order (P1, then P2, P3, P4), with standard 5M/200M baselines and oracle tables on matched queries. Label it clearly as a draft, include coverage and missing-cell ledgers, and never present partial results as complete. Prioritize evaluation resources so every cell that finishes training before ~12:00 is evaluated on both splits in time for the draft.

2. **No 12:45 cancellation.** Do not cancel training at closeout. All remaining work continues until it finishes: P2, P3, P4, and gaps G3–G6. The 12:00 "stop launching" rule no longer applies, except that evaluation capacity for the draft takes precedence until 13:00.

3. **Final report after completion:** once all 112 in-scope cells have four valid epochs and both full validation evaluations, write `intermediate-analyses/2026-10-09-workspace-final-analysis.md` with everything §10 requires, including all comparisons and ablations.

4. **Monitoring:** keep wake-up timers running **every hour** through completion; timers in the agent's local session on the owner's laptop are acceptable. Each wake-up does the following:

   - recompute completion counts and ETAs from per-run progress;
   - harvest evaluation shards;
   - check disk, GPUs, and preemptions;
   - requeue failed or preempted jobs;
   - re-rank the queue by priority;
   - update the intermediate analysis.

   The continuous rule still applies: update the analysis within 20 minutes of material results.

5. **Seeds:** all runs use the seed settings recovered from the original standard 5M and 200M configs and run records, verified as in the checklist. No seed is chosen independently.

6. **Unchanged:** everything else in this document and in V8-A1, including no 200M training, four full epochs, masks, suffix-only evaluation, and honest missing-cell reporting.

## Amendment V8-A3 (owner, 2026-10-09 22:40 EDT) — epoch-budget tolerance

The owner accepts a training budget within **1–2% of exactly four epochs**; bit-exact epoch accounting is not required.
Consequences recorded by the orchestrator:
- All 112 cells keep ONE budget rule (the accepted v8-ws trainer: whole updates of 16 rows, floor(4 x epoch-0 plan bins
  / 16) updates). Per-epoch repacked plans differ slightly, so measured deviations from the exact sum of the four plans
  are: K4-b40 +12 bins (+0.0007%), K4-b80 +21 (+0.0012%), K16-b40 -17 (-0.0010%), K16-b80 +21 (+0.0012%) — all far
  inside the tolerance. These are reported per cell, not hidden.
- The exact-budget implementation (partial final update; branch `v8-ws-tail2-merge`) is archived, not used, so every
  cell is trained under the same rule and the factor comparisons are not confounded by a budget-rule change.
- Gate 9 / acceptance B1 becomes: budget complete per final_ckpt.py, and |trained bins − sum of the 4 epoch plans| /
  (sum of the 4 epoch plans) <= 2%.
Everything else in V8-A1 and V8-A2 is unchanged.

## Amendment V8-A4 (owner, 2026-10-10) — development sweep of auxiliary weights

**Amendment V8-A4 (owner, 2026-10-10): development sweep of auxiliary weights; production at the selected weights.**  
  
**Why.** P2 at λ \= 1 tests a mis-scaled objective. Per-site means at λ \= 1 give each teacher site about 50× the weight of one NTP token. The O1 student ends farther from the teacher than NTP-only. The auxiliary weights were never selected on development data, against §6.1. This amendment selects them properly, then runs the auxiliary tiers at the selected weights.  
  
**1\. Units.** For each auxiliary term X ∈ {K (O1 KL), F (O2–O5 future KL), E (O3/O4 evidence), R (O5 representation)}, define  
  
λ\_par(X) \= (mean number of sites contributing to term X per effective batch) / (mean number of NTP targets per effective batch).  
  
Measure it from existing training logs, using the logged numerators and denominators, and record the value. At λ \= λ\_par(X), the total weight of term X equals the weight of the same number of NTP tokens.  
  
**2\. Development data only.** Selection uses a development split that is disjoint from train, `val_seen` and `val_unseen`. Locate the existing V7 development split (the one behind the V7 "final dev loss"). Do not use `val_seen` or `val_unseen` for any selection decision. Do not generate new data. If no usable development split exists, stop this part and report a blocker. Teacher caches on the development split are allowed.  
  
**3\. Representative cells.**  

- Hybrid: `5M-K4-b80-hybrid-independent-d0.2`, which the running sweep already uses.  
- Strict: `5M-K4-b80-strict-independent-d0`.

  
Every sweep run is identical to the production configuration of its cell except for the swept weight and its output paths. Every sweep run uses the recovered seed settings and four full epochs. Sweep runs are development runs. They go in a separate sweep ledger, and they are never reported as production cells.  
  
**4\. Grids** (multiples of λ\_par).  

- **Stage A** (now; runs in parallel):  
  - O1: λ\_K ∈ λ\_par(K) × {0.25, 1, 4, 16}. If the measured λ\_par(K) is within \[0.015, 0.025\], use {0.005, 0.02, 0.1, 0.3} instead, and reuse the three running hybrid runs once their configs are verified identical except for λ\_K.  
  - O2: λ\_F ∈ λ\_par(F) × {0.25, 1, 4, 16}.  
  - Both access modes.  
- **Stage B** (after λ\_F is selected per access mode; λ\_F fixed at that value):  
  - O3: λ\_E ∈ λ\_par(E) × {0.25, 1, 4}.  
  - O4: λ\_E ∈ λ\_par(E) × {0.25, 1, 4}, swept separately from O3.  
  - O5: λ\_R ∈ λ\_par(R) × {0.25, 1, 4}.  
  - Both access modes.  
- **Reference runs:** strict representative cell at λ \= 1 for O1–O5, with the same λ \= 1 for every term as in P2. The hybrid λ \= 1 references are the existing P2 cells. The NTP references are the existing P1 cells.  
- **Fixed:** temperature τ \= 1\. The O4 temperature η stays at its recorded value; record how and on which data it was chosen. If it was chosen on validation data, report that as a violation.

  
**5\. Selection rule** (pre-declared; freeze it in this file before any Stage A result is read).  

1. For each (objective, access mode, swept term), compute on the development split at the b80 suffix queries: legal action NLL, focal and opponent pooled, with a session-clustered SE.  
2. Eligible values must show that the auxiliary term is actually optimized:  
   - O1/O2: KL(teacher ‖ student) on development sites is below that of the matched NTP model;  
   - O3/O4: evidence loss L\_E is below the same head evaluated with the workspace replaced by a constant;  
   - O5: R is below that of the matched NTP model.  
3. Among eligible values, select the lowest NLL. If two values are within 1 SE, select the smaller λ.  
4. If no value is eligible, select the lowest-NLL value anyway, and record "auxiliary term not optimized at any swept weight".  
5. If the selected value is worse than matched NTP, still select it, and record "no swept weight helps". Production then answers the question at the best weight.

  
Write `aux-weight-selection.json` with every candidate, metric, SE and constraint value, the selected λ per (objective, access mode, term), and its SHA-256 hash. Copy the selected values into this file. The selection is then frozen.  
  
**6\. Production at the selected weights.**  

- **P2-sel:** 40 hybrid cells, O1–O5, with the same factor product as P2.  
- **P3-sel:** 40 strict cells, O1–O5, with the same factor product as P3.

  
Each (objective, access mode) uses its selected λ in all 8 architectural cells and at both boundaries. All rules for four epochs, seeds, masks, suffix-only evaluation, both validation splits and audit gates apply unchanged.  
  
**7\. Manifest.**  

- Add 80 rows (P2-sel, P3-sel), with the selected λ recorded per row.  
- Mark the 40 original P3 λ \= 1 rows `superseded_owner_A4`. They are not failures and not missing results; the strict λ \= 1 reference runs stand in for them as an ablation.  
- P2 λ \= 1 cells continue to completion and stay as the as-specified record.  
- Assert unique IDs and the new counts before scheduling.

  
**8\. Priority** (running jobs are never cancelled for priority) — **SUPERSEDED by V8-A6 item 6 (2026-10-11):**  

1. finish the running P2 λ \= 1 and P4 jobs;  
2. Stage A sweep;  
3. Stage B sweep;  
4. P3-sel and P2-sel, interleaved, strict first within each objective;  
5. P4 cells not yet started, on capacity not needed above.

  
**9\. Required evaluations for every P2-sel and P3-sel cell:**  

- full `val_seen` and `val_unseen` suffix metrics;  
- the WS-swap control;  
- slot redundancy;  
- for O3/O4, evidence ranking with the real workspace and with a constant workspace.

  
**10\. Required comparisons in the final report:**  

- each O at its selected λ vs. matched NTP;  
- O2 vs. O1, O3 and O4 vs. O2, O3 vs. O4, O5 vs. O2, all at selected λ;  
- selected λ vs. λ \= 1 for every objective and access mode;  
- hybrid vs. strict under auxiliary objectives;  
- the full sweep curves (NLL and the constraint metric vs. λ) as a figure.

  
**11\. Final analysis.** Write `2026-10-09-workspace-final-analysis.md` only after all of the following are complete and audited: P1, P2 (λ \= 1), P2-sel, P3-sel and P4, both sweeps, and every evaluation in item 9\. Until then, update the draft hourly.  
  
**12\. Unchanged:** everything else in PROJECT.md, V8-A1 and V8-A2.

### V8-A4 items 13–18 (owner addition, 2026-10-10 ~17:55; frozen before any Stage A dev result is read)

**13. Boundary scaling.** The selection is recorded as a multiple m\* of λ\_par, not as an absolute λ. Production uses
λ = m\* × λ\_par(boundary) for each term, with λ\_par measured separately at b40 and b80. Both values are recorded per
manifest row.

**14. Paired selection.** "Within 1 SE" means the session-clustered SE of the *paired* difference between candidates on
identical dev sessions. Every candidate's paired difference against matched NTP is reported with its SE.

**15. Stage B grids.** Before Stage B, compute from the λ = 1 O3/O4/O5 runs the ratio of auxiliary gradient norm to NTP
gradient norm, per term. Set each λ\_E and λ\_R grid to 4 points spanning a ratio from about 0.1 to 1. Always include
the λ\_par × {1, 4} points and the production value (λ\_E = 0.1 and the production λ\_R) as references. Report the
ratios and final grids before submitting; if this exceeds the GPU budget, report the cost to the owner first.

**16. No-workspace distillation control.** Train the std 5M architecture (K = 0) with O1 and with O2 at their selected
m\*, on the b80 suffix sites, everything else identical to std 5M: 2 runs, plus a matched K = 0 NTP reference if the
existing std 5M checkpoint is not an exact config match. The final report compares these against hybrid P2-sel; if
equal, the teacher effect is distillation, not workspace use.

**17. Learning-gap metrics.** For every P-sel cell and every sweep candidate, report (a) the fraction of the std 5M →
std 200M gap closed, (cell − matched NTP) / (std 200M − std 5M), per role, split and boundary; (b) excess NLL against
oracle 2 (focal) and oracle 3 (opponent) on the same suffix queries. Both are added to the item-10 comparisons.

**18. Seed variance.** Run a second seed for matched NTP and for the selected-λ O1 run at both representative cells
(4 runs). The seed is derived with the recovered seed rule plus a recorded offset. The spread is used to judge whether
the selected λ beats NTP and neighbouring λ values.

### V8-A4 frozen selection (filled in by the orchestrator from aux-weight-selection.json; empty until selection)
Rule frozen 2026-10-10 18:00 EDT before any Stage A sweep dev result: intermediate-analyses/2026-10-09-workspace-assets/
aux-weight-selection.json (copy: $PROJ_DATA/v8ws/dev/selection/), rule_sha256 ea0b49e93ae7513358375f82f2aeba91bfda3c3d20cf74220c0388c2f03560ee,
file sha256 066d364f64b78b10c1d37ed252391192a3cf92948685c46b9c150476dc978ba2. Selected values:
- **Selection A** (job v8ws-select-A 10730739, 2026-10-11 07:48 EDT, commit 14f10af; DEV split only; rule section
  byte-identical, rule_sha256 ea0b49e9; output file sha256 9e75984100a8109d83a5047b726ac7db2076b15f93c40d7a647eaf2a080f3461,
  selection_sha256 7ca12270b68be4c3ff28f1ea33417ea57d875e068d2f67ecac2132a1d8970668):
  | term | access | m* | λ (b80) | λ (b40) | dev NLL Δ vs matched NTP (paired SE) |
  |---|---|---|---|---|---|
  | O1 λ_K | hybrid | 5.04 | 0.1 | 0.321 | −0.0041 (0.0006) |
  | O1 λ_K | strict | 1.008 | 0.02 | 0.0642 | −0.0175 (0.0010) |
  | O2 λ_F | hybrid | 1.000 | 0.01984 | 0.0637 | −0.0026 (0.0006) |
  | O2 λ_F | strict | 0.250 | 0.00496 | 0.0159 | −0.0037 (0.0009) |
  No tie (within_1se = selected only) in any group; no "not optimized" / "no swept weight helps" notes.
- **Selection B** (O3 λ_E, O4 λ_E, O5 λ_R; job v8ws-select-B 10766899, 2026-10-12 19:14 EDT, commit 5e9fb3a; DEV split
  only; one run over all 37 grid candidates (16 Stage A + 21 Stage B; the six λ = 1 anchors, trained at λ_F = 1, are
  references, not candidates); rule section byte-identical, rule_sha256 ea0b49e9; postcheck: Selection A groups and rows
  identical to the A file above; output file sha256 54450305191130cd47db7ced04b785685789220d75ee22facfc3bd094a94f4f8,
  selection_sha256 83bf903038a4a7deaed19bc0771b78fa06ae31b9f63534d335002f3ffb8bc97e; previous A-only file kept as
  aux-weight-selection.A.json). b40 λ_par(R) = 3.18547e-3, pending in the rule, supplied as measured (first 2 finished
  b40 O5 λ = 1 runs, 2026-10-11 18:23) and recorded under `lambda_par_supplied`. λ_F fixed at the Selection A O2 value.
  | term | access | m* | λ (b80) | λ (b40) | dev NLL Δ vs matched NTP (paired SE) |
  |---|---|---|---|---|---|
  | O3 λ_E | hybrid | 1.000 | 1.4e-4 | 4.491e-4 | −0.0053 (0.0006) |
  | O3 λ_E | strict | 4.000 | 5.601e-4 | 1.797e-3 | −0.0119 (0.0009) |
  | O4 λ_E | hybrid | 1.000 | 1.4e-4 | 4.491e-4 | −0.0010 (0.0006); tie: within 1 SE {1.4e-4, 5.601e-4} -> smallest |
  | O4 λ_E | strict | 29.34 | 4.108e-3 | 1.318e-2 | +0.0043 (0.0008); note "no swept weight helps" |
  | O5 λ_R | hybrid | 1.000 | 9.92e-4 | 3.185e-3 | −0.0011 (0.0006) |
  | O5 λ_R | strict | 1.000 | 9.92e-4 | 3.185e-3 | +0.0053 (0.0008); note "no swept weight helps" |
  Every Stage B candidate satisfied its eligibility constraint (aux term optimized). Strict effects are smaller than the
  strict NTP seed swing (dev +.0134, item 18 pending) -> reported as within seed noise (V8-A6 item 5).
- **Selection B, O5 re-run (V8-A9 item 8 (iii))** (job v8ws-select-B-o5v2 10812946, 2026-10-15 08:0x EDT; DEV split only;
  11 O5 v2 Stage B candidates (o5_loss_version 2); NTP references re-scored with the v2 dev_metrics (-ntpv2, compare OK);
  λ_par(R) v2 = λ_par(F) (b80 .0198381, b40 .0636927); rule section byte-identical, rule_sha256 ea0b49e9; postcheck: all
  30 non-O5 candidate rows and 8 non-O5 selected entries byte-identical; file sha256 4ff969f9be088c00…, selection_sha256
  9473810f6e67…; previous file kept as aux-weight-selection.B-v1O5.json). The old O5 rows in the Selection B table above are INVALID (V8-A9).
  | term | access | m* | λ (b80) | λ (b40) | dev NLL Δ vs matched NTP (paired SE) |
  |---|---|---|---|---|---|
  | O5 λ_R (v2) | hybrid | 1.000 | 0.01984 | 0.06370 | −0.0009 (0.0006); tie: within 1 SE {0.01984, 0.03711} -> smallest |
  | O5 λ_R (v2) | strict | 1.954 | 0.03876 | 0.1244 | +0.0098 (0.0008); note "no swept weight helps" |
  Every v2 candidate satisfied its eligibility constraint (dev R below the matched NTP model's).

## Amendment V8-A5 (owner, 2026-10-10 ~18:15) — final-analysis deadline, Stage B grid, deadline guard
**SUPERSEDED IN PART by V8-A6 (2026-10-11 16:25):** items 1 (Tuesday 12:00 deadline), 6 (deadline guard) and 7 (fallback)
no longer apply. Items 2–5 stay in force, and the Stage B cuts already made under item 6 are kept (not restored).

1. **Deadline.** The final analysis is due by **12:00 EDT on Tuesday 13 October**. Extra GPU-hours are acceptable if the
   forecast meets this deadline. Plan to finish compute by **09:00 Tuesday**, leaving 3 hours for the final aggregate,
   audit and report.
2. **Stage B grid.** Merge any gradient-ratio point within 1.5× of a λ_par × {1, 4} point. The existing λ = 1 runs are the
   production-value anchors: hybrid P2 b80-indep-d0.2 O3/O4/O5 and the strict references b80-indep-d0 O3/O4/O5; their
   λ_F = 1 (not the selected value) is recorded. All remaining points run; no run cap. The final grid, run count and
   forecast finish time are sent to the owner, then submitted without waiting for a reply.
3. **Gradient ratios.** The auxiliary-to-NTP gradient-norm ratio is measured on the matched NTP checkpoint and on a step-0
   initialization, using training batches (not the λ = 1 checkpoints). Both measurements and the λ each target ratio
   implies are reported.
4. **Item 18 gate.** The selected-λ O1 seed-7 runs at both representative cells are submitted right after Selection A.
5. **Ledger discipline.** Every edit is verified by reading the file back.
6. **Deadline guard.** Every hourly wake-up recomputes the final-analysis forecast. If it goes past 09:00 Tuesday, trim in
   this order and only as far as needed: (i) hybrid Stage B to 3 points per term (keep λ_par × 1 and the two points
   closest to the selected λ_F); (ii) strict Stage B to 4 points per term. Every cut is reported to the owner. Never cut
   P2-sel, P3-sel, the item-9 evaluations, or V8-A4 items 16, 17 or 18.
7. **Fallback.** If work is still running at 10:30 Tuesday, deliver the final analysis at 12:00 from all complete, audited
   cells with an explicit missing-cell ledger; then let the remaining runs finish and write an addendum. Partial results
   are never presented as complete.

## Amendment V8-A6 (owner, 2026-10-11 ~16:25) — living final analysis, Friday cutoff, both partitions, measured forecast
Replaces two earlier owner messages of 2026-10-11, both withdrawn by the owner while they were being applied.
Supersedes V8-A5 items 1, 6, 7 and the V8-A4 item-8 order.

1. **Deadlines.** The Tuesday 12:00 deadline is cancelled. By **14:00 EDT Tue 13 Oct** deliver
   `intermediate-analyses/2026-10-09-workspace-final-analysis.md`, built from every cell complete and audited at that
   time. Update the same file every 6 hours, and also whenever a selection, a control (item 16 or 18) or a complete tier
   lands, until **12:00 EDT Fri 16 Oct**; then freeze it. That frozen version is the final analysis.
2. **Rules for every version.** Header: version number, timestamp, cell counts per tier, and either
   "LIVING VERSION, updated until Fri 16 Oct 12:00" or "FINAL, frozen Fri 16 Oct 12:00". Only complete, audited cells;
   explicit missing-cell ledger; partial results never presented as complete and never ranked. Every item-10 and item-17
   comparison the complete cells allow; each one not yet computable is marked NA with the reason. The existing
   `...-final-analysis-draft.md` is frozen as it is now, with a pointer to the new file.
3. **Friday cutoff.** From Thu 12:00, at every hourly check, launch no job whose measured duration plus its evaluations
   would end after Fri 10:00. At Fri 12:00 freeze the final analysis, then cancel any job of this study still running,
   list it in the missing-cell ledger as "not completed by Fri 12:00 cutoff", and delete its partial outputs following
   the storage rules.
4. **Scope.** As much as possible of PROJECT.md and its amendments, in the item-6 order: P1, P2 λ=1, all 16 P4 cells;
   the Stage B runs as already cut, then Selection B; items 16 and 18; all 80 P-sel cells with every item-9 evaluation.
   Stage B cuts are kept (not restored); the frozen selection rule is unchanged; Selection A is not reopened.
5. **Seed variance.** Record in STATE and in the final analysis: the strict seed swing (+0.0134 dev NLL, ≈ 13× the
   paired SE) is larger than some selection margins. No selection changes because of it. The final analysis states it as
   a limitation, compares every strict selected-λ effect with the item-18 seed spread, and calls an effect "within seed
   noise" when it is smaller than that spread.
6. **Capacity and priority.** Use everything available to the owner on both partitions (≈ 8 GPUs general, 24 preempt),
   within cluster policies and quotas. Keep the preempt queue full at all times (a preempt GPU goes only to a job already
   waiting there). Use a multi-partition request if policy allows it; keep critical-path jobs (dev scoring, Stage B,
   Selection B inputs, items 16 and 18) preferentially on general; put P-sel and P4 training on both partitions.
   Critical path: (1) dev scoring of finished Stage B runs; (2) remaining Stage B runs; (3) item 16 and item 18 runs;
   (4) P-sel O1/O2, started now alongside Stage B, strict (P3-sel) before hybrid (P2-sel); (5) directly after
   Selection B, P-sel O3/O4/O5, strict before hybrid; (6) the 6 unstarted P4 cells, lowest priority on both partitions.
   Never leave a GPU idle while a runnable job waits. Never cancel a running job for priority (the Friday cutoff is the
   only exception). Keep each partition's queue at its job limit with a top-up submitter in this order; bundle small
   jobs (dev scoring, item-9 evaluations, audits) several per Slurm job. No change to any training or evaluation method
   (four epochs, seeds, masks, evaluation rules).
   *Orchestrator note (cluster policy, CARD.md):* `-p general,preempt` is not usable because the QOSes are
   partition-specific, so jobs are submitted per partition; the top-up submitter moves a waiting preempt job to general
   whenever a general GPU would otherwise be idle, which gives the same effect.
7. **Forecasting and monitoring.** Measure preempt capacity from sacct (GPU-hours received on preempt per hour over the
   last 72 h and 24 h; median queue wait before a preempt start; mean recompute lost per preemption). Forecast three
   scenarios: (1) general only (8 GPUs); (2) general + the measured preempt rate net of preemption loss — the main
   forecast; (3) all 32 GPUs. Give scenario 2 for the Tue 14:00 version and for each tier's completion by Fri 10:00.
   Hourly checks continue and update the rate and the three forecasts. If scenario 2 shows a tier cannot finish by
   Fri 10:00, tell the owner at once, with the GPU count needed and the measured preempt rate. Never conclude that a
   deadline will be missed from a general-only forecast.

## Owner instruction (2026-10-12 ~23:10 EDT) — deep self-audit every 12 hours (NON-NEGOTIABLE)
Run a deep self-audit now and at 00:00 and 12:00 EDT until the Fri 16 Oct 12:00 freeze, plus one final audit after it;
also after any new amendment, and first thing at the next wake-up if a timer misses. Treat STATE, CHECKLIST, ledgers and
memory as claims; verify against squeue/sacct (both partitions), files on disk, git and command output; label findings
[verified]/[claimed]/[unknown]. Write `intermediate-analyses/2026-10-09-workspace-assets/audits/audit-<YYYYMMDD-HHMM>.md`
with one row per requirement of this file and its amendments (ID, requirement, governing text or "superseded by",
status, evidence, how verified, gap, action), explicitly covering: every in-scope cell (four epochs, both val evals,
audit, item-9 diagnostics, recorded λ); every LEDGER.jsonl job vs sacct (lost/failed/duplicated/unsubmitted work, both
queues full); selection integrity (rule hash, dev-only data, paired SEs, m* per boundary); correctness (no validation
leakage, config diffs, seed-7 and K=0 runs outside the production audit root, C3); items 16, 17, 18 and item 10 and
what is computable; the deliverable schedule and its timers; a three-scenario forecast from measured rates; storage and
checkpoint retention. List gaps closed / still open / new since the previous audit. Fix in the order correctness →
critical path → missing evaluations on trained cells → tracking, verifying each fix. Then STATE (< ~60 lines, last and
next audit times), CHECKLIST (first item, NON-NEGOTIABLE; no stale lines), acceptance checklist and sweep ledger are
updated from verified results only and committed. Every hourly check confirms the audit timer is armed. Report in ≤ 15
lines: requirement counts by status, top 5 gaps + fixes, every correctness error, the forecast, timer ID + next fire,
audit file path + commit hash. Do not cancel or pause running jobs for an audit unless a correctness error is found.

## Amendment V8-A7 (owner, 2026-10-13 ~13:00 EDT) — audit before the final analysis; stop only after it is written
1. **Audit first.** The final analysis may be written only after a rigorous audit, done as a precise research agent, that
   leaves zero scope for misreporting: re-read and test the code paths behind every number (training, masks,
   evaluation, aggregation, pairing, selection, report generation); recompute a sample of reported values independently
   from raw outputs; check every denominator, query set, label and status; verify against ground truth (scheduler, files,
   commits, command output), not the orchestrator's own records.
2. **Stop rule.** The orchestrator may stop only after the final analysis file is written.
3. **Required corrections and completions (owner list):** complete-but-unaudited cells shown as "complete, C3 pending"
   (never "NA (complete)") and C3 run on every waiting cell; strict "gap closed" reported beside each cell's gap relative
   to std 5M, with plain words that a value above 1.0 does not mean "better than 200M"; hybrid O1 seed spread verified
   (same cell, same evaluation for seed 6 and seed 7; no Stage A sweep evaluation as the seed-6 value) and every "within
   seed noise" label recomputed, each effect reported against both the NTP spread and the selected-λ spread with the
   label's basis stated; item 16 reported as statistically resolved (±0.0002) AND within seed noise; §8 bin text
   corrected to the V8-A3 rule and the measured deviation ≤ 0.0012%; item-9 evaluations for every complete P-sel cell
   (WS-swap, slot redundancy, O3/O4 evidence real vs constant WS on validation and dev); A2 / oracle-4 scoring of every
   complete WS cell incl. P-sel; the not-started P2-sel cells (b80-hybrid-indep-d0, O3–O5) run; every PARTIAL (k/N)
   comparison recomputed as cells land; the dev hybrid-vs-strict comparison kept to the one-factor rule (point to the
   validation pairs); every plot shows selected-λ cells with their λ and never mixes them with λ = 1 cells.
4. **Language.** The final analysis is written about 80% in ASD-STE100 Simplified Technical English and follows all
   earlier formatting rules (V8-A6 item 2, §10).

## Amendment V8-A8 (owner, 2026-10-14 ~09:20 EDT) — run the 13 cut Stage B points (record only); new FINAL rule
Supersedes the V8-A6 refresh-and-freeze schedule (6-h living refreshes, the Thu 12:00 launch rule, the Fri 12:00 freeze and
its FINAL build) and the V8-A5 / V8-A6 "Stage B cuts are kept" rule.
1. **Timers.** Disarm the 6-hourly refresh plan (v14–v21) and the scheduled Fri 12:00 FINAL build (and the timers that
   only serve that freeze: the Thu 12:00 launch rule and the Fri 12:45 post-freeze audit). Keep the 12-hourly deep audits
   armed until the final document is written.
2. **The 13 cut Stage B points** (strict O3 λ_E 0.2464; strict O4 λ_E 0.1383; strict O5 λ_R 0.3463, 1.052; hybrid O3 λ_E
   0.008847, 0.02502, 0.2502; hybrid O4 λ_E 0.008797, 0.01406, 0.1406; hybrid O5 λ_R 0.1181, 0.3181, 1.181; λ_F at the
   Selection A value per access) run now as full four-epoch runs on their b80 representative cells, on both partitions in
   parallel; each identical to its Stage B siblings except the swept weight and output paths (config diff verified); each
   scored on the dev split.
3. **Record only, no re-selection.** The frozen rule (ea0b49e9) and the selected weights stay unchanged; no P-sel cell is
   retrained. The 13 points enter the sweep curves, the dev tables and the learning-gap tables; their ledger status changes
   from `cut_owner_A5` to complete development runs. If a cut point would have won under the frozen rule, the report states
   it plainly as a limitation; nothing acts on it.
4. **Tracking.** STATE, CHECKLIST, the acceptance checklist and the sweep ledger are updated and read back.
5. **Final document.** When all 13 are scored: rebuild the final analysis from the complete study; then a full V8-A7 audit
   of every script written in this study and every collated result (code paths re-read and tested; a sample recomputed
   independently from raw outputs; every denominator, query set, label, status, link and ledger row checked against ground
   truth); fix every error and re-verify; record the audit in audits/; MEASURE the share of ASD-STE100-style text and
   correct toward 80% if needed. Only after a clean audit: build the document with the header "FINAL, frozen <date and
   time>", confirm the published file is byte-identical to the build, disarm all remaining study timers and the Fri
   backstop, commit, report the final commit hash and audit file path. Stop only after the FINAL document is written,
   audited and committed.

## Amendment V8-A9 (owner, 2026-10-14 ~10:20 EDT) — O5 loss deviation: invalidate, fix, retrain all O5
Supersedes V8-A8 item 2 for the five O5 points (they are cancelled, not run) and V8-A8 item 3 for O5 (Selection B is re-run
for the O5 group only). Everything else in V8-A8 stays in force, including its closeout (item 5).
1. **Old O5 results are invalid.** Every O5 result trained with the old loss is invalid: P2 λ = 1 O5 (8 hybrid cells), the
   strict λ = 1 O5 reference, every Stage B O5 point, and every P2-sel and P3-sel O5 cell (16). Reason: spec deviation in
   `model/aux.py:347-358`. L_R uses the 5% cached subset, recomputes the balancing weights on it and divides by S5, so it
   is neither the §6.7 mean nor an unbiased estimator.
2. **Ledger.** These runs get status `invalid_O5_loss_deviation`. They are kept as a record; they are not failures and are
   not deleted.
3. **Living final analysis.** Every old O5 number, comparison, sweep curve, plot and learning-gap row is labelled
   "INVALID: O5 loss deviation (V8-A9)" or moved to a clearly marked appendix. The text states that no conclusion uses them.
4. **In-flight O5 runs stopped.** The five V8-A8 O5 sweep runs (hybrid λ_R 0.1181, 0.3181, 1.181; strict λ_R 0.3463,
   1.052) and their chained dev jobs are cancelled (done 10:2x Wed: train 10797454/65/71/97, 10797502; devmetrics
   10797461/67/74, 10797500/04). The 8 V8-A8 O3/O4 runs continue.
5. **Backstop moved.** The Slurm backstop 10715530 (cancels every ae-v8ws-* job) moved from Fri 16 Oct 12:15 to
   **Fri 23 Oct 12:15 EDT** so it cannot cancel this work. It is cancelled at the final closeout.
6. **Fix the O5 loss.** L_R must equal the §6.7 / §6.1 objective: averaged over every eligible post-workspace site, with
   the same session and role × distance weighting as L_F. Method: (a) cache the teacher's final normalized hidden states
   for every site; or, if storage or compute forbids that, (b) a pre-declared stratified subsample with recorded inclusion
   probabilities and inverse-probability weights, so the expected loss equals the specified mean, with rare cells
   oversampled so no cell is systematically empty. Record the choice, why, and its cost. L_F and every other objective
   stay unchanged.
7. **Proof before any production run:** a fixture test that the estimator's expectation equals the exact mean on unequal
   cell sizes; a gradient check; a test that no teacher gradient flows; a config diff showing each new run differs from
   its old counterpart only in the O5 loss version, λ_R and output paths.
8. **Retrain all O5, in dependency order.** (i) Recompute the λ_R gradient-norm ratios with the fixed loss on the matched
   NTP checkpoint and at step 0 (V8-A5 item 3). (ii) Rebuild the O5 Stage B grid with the same rules (V8-A4 item 15,
   V8-A5 item 2); run every point, no cuts; score on dev. (iii) Re-run Selection B for the O5 group only with the frozen
   rule unchanged (ea0b49e9); record m* and λ_R at both boundaries; all other selections stay frozen. (iv) Retrain the
   strict λ = 1 O5 reference, the 8 P2 λ = 1 O5 cells, and the 16 P2-sel / P3-sel O5 cells at the new selected weight.
   (v) Run every item-9 evaluation, A2 / oracle-4 scoring, C3 audit, and every item-10 and item-17 O5 comparison for them.
9. **Execution.** Both partitions, the top-up submitter and hourly monitoring; 12-h deep audits continue. Report GPU-hours
   and a three-scenario forecast before submitting the production cells, then continue without waiting.
10. **Finish.** When all fixed O5 work and the 13 V8-A8 runs are complete (8 O3/O4 now): the V8-A8 closeout in full —
    rebuild with the valid O5 results (old O5 in the marked invalid appendix); v8a8fix + v8a8notes corrections; full
    V8-A7 audit of every script and collated result with independent recomputation, every finding fixed and re-verified;
    re-measured STE share; header "FINAL, frozen <date and time>"; byte-identical publish; disarm all study timers and the
    backstop; commit; report the commit hash and audit file path. Stop only after the FINAL document is written, audited
    and committed.
