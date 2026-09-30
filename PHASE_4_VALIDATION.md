# Phase 4 — Prediction evaluation record

September 29, 2026 · branch `phase-4`

## What was evaluated
`PhaseFourDomainTests.reproducibleSyntheticComparison` replays six deterministic synthetic histories from January 1, 2020. Each has 12 completed intervals and three warm-up intervals. Each prediction sees only the prior three to six intervals. The next interval is used only for scoring. Median, arithmetic mean, and linear recent-weighted mean (oldest weight 1 through newest weight n) share the same min/max ±2-day window, rounding, training cap and spread-above-14 withholding rule.

These histories are invented behavior checks, not representative medical data, user telemetry, clinical validation or an independently collected accuracy study. No future probability can be inferred from the table.

## Reproducible results
Measured by the Swift implementations on iPhone 17 Pro / iOS 26.2. MAE is mean absolute center error in days. Span is latest minus earliest, not the inclusive count of possible dates. Coverage and span are identical for all candidates because their windows are held fixed. Withheld estimates do not enter the scored denominator.

| Fixture | Median MAE | Mean MAE | Recent-weighted MAE | Starts in window / scored | Withheld | Mean span |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Constant | 0.00 | 0.00 | 0.00 | 9 / 9 | 0 | 4.00 |
| Alternating | 3.67 | 3.22 | 3.33 | 9 / 9 | 0 | 10.00 |
| Gradual drift | 2.78 | 2.78 | 2.67 | 9 / 9 | 0 | 8.33 |
| Sudden shift | 2.67 | 2.67 | 2.00 | 8 / 9 | 0 | 7.89 |
| One long gap | 9.33 | 9.33 | 9.33 | 2 / 3 | 6 | 4.00 |
| Broad variation | N/A | N/A | N/A | 0 / 0 | 9 | N/A |

Fixture intervals:
- Constant: twelve 28-day intervals.
- Alternating: 26,32 repeated six times.
- Drift: consecutive lengths 24 through 35.
- Shift: 28,28,28,28,28,35,35,35,35,35,35,35.
- Long gap: 28,28,28,28,56,28,28,28,28,28,28,28.
- Broad: 20,40,25,45,21,42,24,44,20,40,25,45.

## Decision
Retain the robust median center and existing window dates. Recent weighting reduces error in the synthetic shift case, but there is no independent representative evaluation supporting generalization. Do not select a different model per user from these small retrospective samples. Do not remove unusual intervals or infer unrecorded starts.

The long-gap result is an important limitation: the initial large error is scored, then the long interval causes six withheld estimates. Hiding those abstentions would give a misleading account of model availability. Likewise, complete coverage of the alternating fixture is not exact-date accuracy: its windows span ten days.

Confidence policy V2 supplements history count/spread with the last six non-warm-up replay opportunities. Moderate requires at least three scored opportunities, no withheld opportunities, at least 80% observed coverage, and MAE at most three days, in addition to six source intervals spanning at most seven days. These thresholds are explicit conservative display heuristics, NOT calibrated probabilities or clinical cutoffs. No High confidence label is introduced.

## Verification
- 52 Swift Testing tests across eight suites passed in `/tmp/cecy-phase4-unit-verified.xcresult`.
- New coverage includes replay prefix stability, future target exclusion, warm-up/withheld denominators, inclusive boundaries, signed and absolute errors, arithmetic failure, identical candidate folds, confidence thresholds/rolling cap, and state recomputation after corrections/deletion/reset/date changes.
- Existing V1 arithmetic and all storage migration tests remain passing. No storage changes in this phase.
- Initial Debug attempts exposed one Calendar call using the old explanation initializer; it was corrected and the full unit run passed.
- Final unit rerun with golden comparison totals: all 52 tests passed in `/tmp/cecy-phase4-final.xcresult`.
- All 12 UI flows passed in `/tmp/cecy-phase4-ui.xcresult`, including the two new evidence flows and all ten prior regressions.
- Release generic iOS Simulator build passed for arm64/x86_64 with iOS 17 deployment target; log: `/tmp/cecy-phase4-release.log`. This is not an iOS 17 runtime test. Expected App Intents metadata warnings and existing test trailing-closure warnings do not block builds.
- Local temporary logs/result bundles are not committed. Fixtures contain synthetic data only.

## Remaining limitations
No archived issued forecasts exist, so the history screen reconstructs estimates from current corrected records. Chronological slicing prevents target leakage but cannot reconstruct when each fact was actually known. Real-world calibration, missing-record behavior, and confidence thresholds require independent representative validation before making performance claims. iOS 17 runtime, signed physical-device/offline use, storage protection/backup behavior, and manual accessibility/layout checks remain release gates.
