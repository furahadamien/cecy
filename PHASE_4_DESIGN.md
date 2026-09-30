# Cecy — Phase 4: prediction evidence

Date: September 29, 2026
Branch: phase-4
Status: Implemented; 52 unit/storage/state tests, 12 UI flows, and Release simulator build passed. Manual release checks remain pending.

## Scope
Pure Swift retrospective evaluation, reproducible algorithm comparison, evidence-aware confidence, and readable local prediction evidence. No persistence changes, prediction logging, networking, AI, or optional integrations.

## Evaluation semantics
- Sort and validate current period records as of today. Invalid/future context fails visibly, never silently removes data.
- Each completed start-to-start interval is a target. At its start, supply only preceding completed intervals (up to six) to a replaceable CyclePredicting engine. The target length and later dates never enter the predictor.
- First three target intervals have insufficient training history and are retained as warm-up outcomes, not counted as predictions. Wide-variation and arithmetic failures remain explicit withheld outcomes.
- This is a chronological reconstruction from CURRENT corrected records, not an audit of predictions actually displayed. Entry timestamps are not used to fabricate historical availability; late entry, edits, missing starts and changing algorithms limit the interpretation. No clinical accuracy claim.
- Score available estimates only: absolute center error, signed error (positive means actual start was later), inclusive window coverage, window span in days (latest minus earliest), and distance outside the window. Denominators and withheld counts stay visible. No scored cases yields nil metrics, not zero accuracy.
- Retain all replay rows for inspection; confidence uses only the six latest non-warm-up opportunities, including withheld opportunities. No persistence of derived results.

## Candidate comparison and selection
Compare frozen V1 median, arithmetic mean, and linear recent-weighted mean (weights 1 through n, oldest to newest) on exactly the same folds, six-interval cap, minimum three training intervals, min/max ±2-day window and >14-day spread abstention. Median is the robust baseline. Do not remove outliers, infer missing starts or gate inputs on bleeding ends.

Synthetic fixtures: constant, alternating, gradual drift, sudden shift, one long gap, and broad variation. Report MAE, coverage counts, average span and abstentions per fixture and candidate. Synthetic results test behavior only, not real-world calibration. Retain median for production unless independent representative evidence supports replacement; no per-user model-selection overfitting or settings picker.

## Production policy V2
- Preserve V1 center/range generation exactly: median rounded half away from zero, earliest max(1, min−2), latest max+2, using three to six latest intervals; withhold if spread >14 days.
- Confidence can only be Low or Moderate, never a probability. Moderate requires all of:
  - Six source intervals and spread ≤7 days.
  - At least three scored replay opportunities among the last six non-warm-up opportunities.
  - No withheld opportunities in that recent subset.
  - At least 80% of replay windows included the next recorded start and mean absolute center error ≤3 days.
- These are conservative, versioned display heuristics, not calibrated thresholds or clinical cutoffs. A failed rule yields Low with a reason. Replay confidence is not recursive: evaluate the frozen window algorithm, not the evidence-aware wrapper.
- Forecast window can remain unchanged while confidence decreases after poor results. Unknown ends do not affect source intervals. Calendar only draws the available range. Passed-window behavior is unchanged.

## UX and architecture
- New pure domain replay/report types and confidence assessment. Existing CyclePredicting boundary remains replaceable; V1 engine remains directly testable.
- TrackerSession derives replay alongside overview after committed edits/deletion/reset and date changes; errors clear stale replay. Symptoms never affect forecasts.
- Today retains its compact range, label and explanation action. Explanation shows policy, actual source start pairs/lengths, confidence reason and links to replay details.
- Insights provides a Prediction history check destination even without an available current estimate. Explain reconstruction limitations before metrics; show counts and average absolute error in days rather than future percentages. Rows show training date range, forecast range/center, actual next start and error or withheld reason.
- Native scalable text, list/cards, meaningful labels; no color-only scoring. No additional editor or Simulator application windows during checks.

## Acceptance
- [x] Replay prefix isolation, sorted inputs, inclusive coverage boundaries, sign/error/width arithmetic, warm-up/withheld denominators, zero history and date limits tested.
- [x] Mean/weighted candidates use identical folds and windows; reproducible synthetic comparison recorded.
- [x] V2 confidence quantity/spread/replay gates and rolling limits tested; V1 arithmetic remains frozen.
- [x] Source dates explain each estimate. Edits/deletes/reset/date-context changes recompute without stale evidence.
- [x] UI evidence access, sparse states and source/replay details tested; previous UI flows regress successfully.
- [x] Debug tests and Release simulator build pass; manual minimum-OS/device/accessibility gates remain explicit.

Results and algorithm decision: [PHASE_4_VALIDATION.md](PHASE_4_VALIDATION.md). No independent real-world calibration is claimed. Minimum-OS runtime, physical-device/offline, storage protection and manual accessibility verification remain release gates.
