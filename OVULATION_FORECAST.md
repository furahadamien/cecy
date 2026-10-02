# Paired period and ovulation forecast

> Superseded October 2, 2026 by [ADAPTIVE_CYCLE_FORECAST.md](ADAPTIVE_CYCLE_FORECAST.md). The current version adds learned bleeding duration, a separate six-day fertile window, 10–16-day illustrative ovulation offsets and accumulated future-cycle uncertainty. The equations and validation below are historical, not the current specification.

October 2, 2026 · `testing/on-device-fixes`

## Why the previous marker was insufficient

The original marker used only the next estimated period center minus 14 days. Once that ovulation day passed, there was nothing upcoming to display. It did not project subsequent cycles. This update supersedes that single-marker behavior documented in `DEVICE_FEEDBACK_ROUND_6.md`; daily-insight behavior is unchanged.

## Shared deterministic algorithm

`CycleForecast.calculate` consumes the production `CycleOverview`. The same rounded median of up to six completed intervals drives period and ovulation projections. When there is no measured interval, the existing period engine uses the user-entered typical cycle length. Profile assumptions never become historical measurements.

Let `L` be the number of civil days from the latest recorded start to the existing estimated next start. For indices `k = 0, 1, 2`:

- Period center = existing center + `k × L` days.
- Period earliest = existing earliest + `k × L − k` days.
- Period latest = existing latest + `k × L + k` days.
- Possible ovulation center = projected period center − 14 days.
- Possible ovulation earliest = projected period earliest − 16 days.
- Possible ovulation latest = projected period latest − 12 days.

The first period window is exactly unchanged. Each subsequent period window widens by one additional day on either side. These are explicitly provisional display bounds, **not calibrated confidence intervals** or measured probabilities. The ovulation range incorporates both period-start uncertainty and a broad 12–16-day timing assumption.

Ovulation is withheld if its illustrative range cannot fit strictly after the preceding actual/assumed start and before its projected period window. No period estimate (including wide variability) means no future forecast. Context selections no longer suppress dates: hormonal contraception gets a warning that some methods prevent ovulation and the date may not apply; recently stopped contraception, postpartum, breastfeeding and perimenopause get specific timing limitations. Cecy does not know the contraceptive method or detect ovulation. Warnings do not change the numerical calculation, saved answers, statistics or AI inputs.

## Bounded projections, not invented history

- Exactly three cycles at most, anchored to the latest **recorded** start. No unlimited roll-forward across missing records.
- Later cycles explicitly assume preceding predicted starts happen. Their UI says **Projection** and explains that no records were added.
- A passed primary period estimate stays passed. Reminders, recorded cycle-day counts and prediction backtesting still use the existing single-cycle engine, not hypothetical later cycles.
- If all three projections have passed, show a request for recent actual starts rather than projecting indefinitely.
- New or corrected actual starts and profile changes recalculate the cached forecast; deletion restores the forecast from remaining facts. No health-storage migration.

For a September 2 start and 28-day typical cycle, centers are September 30 / October 28 / November 25 for periods and September 16 / October 14 / November 11 for possible ovulation. On September 29, October 14 is the upcoming ovulation projection even though the first ovulation date has passed.

## UI

- Calendar plus Today’s collapsed, expanded and large-text calendars use one cached `session.cycleForecast`.
- Period-start windows: red dashed outlines. Only the central estimated ovulation date receives a green dotted outline; neighboring dates in the uncertainty envelope do not. This is a display distinction, not evidence of exact-day accuracy or safe days.
- Selecting a marked date shows its paired estimate, data basis, context warnings and assumptions. Timing uncertainty expands the illustrative range, explicitly not a duration of ovulation, fertile window or calibrated confidence interval. Actual timing can fall outside it. Upcoming uses a center on/after today rather than a past center whose range extends into today; a passed marker does not confirm ovulation occurred.
- Forecasts are not recorded bleeding duration, confirmed ovulation, a fertile-window estimate or contraception guidance. Actual ovulation can differ or not occur.

## Sources and limitations

- [NHS periods overview](https://www.nhs.uk/conditions/periods/) describes ovulation approximately 12–16 days before the next period and the effect of hormonal contraception. This general observation cannot determine an individual’s ovulation.
- [Apple Cycle Tracking](https://support.apple.com/en-us/120356) distinguishes calendar-based predictions from retrospective ovulation estimates using supported Watch data. Cecy does not have temperature or ovulation-test evidence and does not claim those capabilities.
- This is a transparent calendar heuristic, not a clinically validated ovulation predictor. Medical/wording review and calibration remain release gates.

## Initial paired-forecast validation (before the single-day correction)

- All **22 focused unit tests** in four suites passed, including eight new projection/session checks for paired dates, source selection, uncertainty widening, finite horizon, context suppression, leap dates and record-driven recalculation.
- Both calendar UI scenarios passed, verifying existing and future markers in Calendar and collapsed/expanded Today, paired October period/ovulation dates and disabled future logging.
- One test fixture initially supplied a 32-day interval while asserting 31. Its source dates were corrected; all unit checks then passed without changing product code.
- Debug app/test compilation and **unsigned iOS Release build passed**. Release took 41.3 seconds; final unit run took 18.0 seconds. Runs had hard limits and no optional simulator diagnostics collection.
- Evidence: `/tmp/cecy-future-forecast-tests.xcresult`, `/tmp/cecy-future-forecast-final-tests.xcresult`, `/tmp/cecy-future-forecast-release.log` and their status files.
- No live AI calls, backend changes, commits or pushes. Full regression, medical review/calibration and physical-device/VoiceOver/color/large-text review remain open.

## Scientific review and single-day correction

The broad green band was uncertainty about timing, not multiple days of ovulation. Its presentation was misleading. Context suppression was also too broad: general profile categories do not establish whether an individual ovulates. The current implementation uses one central marker and specific limitations instead of a blanket hide rule. A 14-day calendar assumption remains a heuristic, not a personalized biological measurement or newly validated algorithm.

Sources reviewed:
- [ASRM: Optimizing natural fertility](https://www.asrm.org/practice-guidance/practice-committee-documents/optimizing-natural-fertility-a-committee-opinion-2021/) distinguishes a six-day fertile window from ovulation, explains the approximate 14-day calendar method and warns about poor exact-day prediction by calendar apps. Its cited study is not a measured accuracy for Cecy.
- [NHS: combined pill](https://www.nhs.uk/contraception/methods-of-contraception/combined-pill/what-is-it/) confirms ovulation suppression for that specific method. A generic hormonal-contraception answer cannot identify the method or establish ovulation status.
- [NHS: contraception after birth](https://www.nhs.uk/conditions/baby/support-and-services/sex-and-contraception-after-birth/) explains pregnancy can occur before periods return and while breastfeeding; these selections cannot be treated as proof of absent ovulation.
- [NHS: cycle physiology](https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/) describes broader 10–16-day timing. The retained 12–16-day envelope is illustrative, not a universal physiological boundary. Showing one marker does not justify narrowing uncertainty or claiming higher clinical accuracy.

More precise or retrospective ovulation assessment would need appropriate biomarker inputs and validated interpretation, not another arbitrary calendar formula. This change does not add LH tests, temperature interpretation, a fertile window, fertility guarantees, or contraception advice. Those require separate design and clinical validation.

### Latest validation

- All **24 focused unit tests** in four suites passed, including exactly one marker per projected cycle, unmarked adjacent days, retained uncertainty, non-past Upcoming selection, context warnings without hidden dates, and unchanged period calculations.
- **All three targeted UI scenarios passed in the same run**: existing calendar markers; future markers plus unmarked neighboring dates in all presentations; saved breastfeeding context with a visible caution and no blanket suppression.
- Debug app/test compilation and **unsigned iOS Release build passed**. Tests took 119.5 seconds; Release took 32.5 seconds. Runs had hard limits; no retry loop or live AI calls.
- Evidence: `/tmp/cecy-ovulation-refinement-tests.xcresult`, `/tmp/cecy-ovulation-refinement-release.log` and associated status files.
- Physical-device/accessibility review, full regressions, clinical wording/calibration and release acceptance remain open. Nothing committed or pushed.
