# Cecy adaptive period, bleeding, ovulation and fertile-window forecast

October 2, 2026 · Calendar forecast V3 · `testing/on-device-fixes`

## Status and scope

Implemented locally in Swift. This document supersedes the formulas and display limitations in `OVULATION_FORECAST.md`. The existing primary period-start engine and its historical evidence policy are retained; the forecast layer now learns bleeding duration, distinguishes a six-day fertile window from a single ovulation estimate, and propagates uncertainty through future projections.

This is a transparent calendar heuristic, **not a clinically validated fertility predictor**. More period records can improve knowledge of cycle timing and bleeding duration. They cannot confirm ovulation, measure an individual's luteal phase, guarantee increasing accuracy, or identify safe days for unprotected sex. No AI or network service calculates these dates.

## 1. Inputs and date semantics

- Latest actual period start `S`.
- Entered typical cycle length `C`, used only when no measured start-to-start interval exists.
- Entered typical period duration `D`, used only when no confirmed bleeding duration exists.
- Validated actual period starts and optional confirmed end dates.
- Cycle-context answers, used for warnings rather than numerical adjustments or blanket suppression.

Dates are `LocalDay` civil Gregorian dates; arithmetic does not divide elapsed seconds by 86,400. A cycle length is the difference between adjacent starts, with no `+1`. A bleeding duration includes both start and end: `end − start + 1`. Forecast intervals are inclusive. Fractional medians round to the nearest whole day, with `.5` rounding away from zero. Stored data and statistics are not rounded or changed.

New onboarding supplies editable defaults of 28 and 5, but old missing profile values remain unknown. Setup currently permits cycle lengths 10–120 and period durations 1–30, with period duration not exceeding cycle length. These are input-validation limits, not definitions of medically normal cycles.

## 2. Next period start: existing unified adaptive engine

Sort actual starts and calculate adjacent intervals. Use the most recent six intervals, without excluding a record because it is unusually long or short.

### No measured intervals

If `C` exists:

- Central next start `P = S + C`.
- Possible start bounds `A = S + max(1, C − 3)` and `B = S + C + 3`.
- Basis: entered typical cycle, not measured history. Confidence stays Low.

If neither an entered length nor a measured interval exists, no forecast is fabricated.

### One or more measured intervals

Let `x` be up to six recent lengths:

- `L = rounded median(x)`.
- `P = S + L`.
- `A = S + max(1, min(x) − 2)`.
- `B = S + max(x) + 2`.

Measured lengths replace, rather than silently mix with, the entered typical length. There is no four-period eligibility threshold. The short rolling history can adapt when cycle timing changes, while a median is less sensitive than a mean to an isolated extreme value. A long gap is never divided into invented cycles.

If `max(x) − min(x) > 14`, the existing engine withholds the forecast and asks the user to review records. It does not fall back to an apparently precise profile-based estimate when recorded history contradicts it.

The 2/3-day padding, six-interval limit and variation thresholds are transparent product policies—not clinically established error bounds. This update does not claim a new validated statistical model for period starts.

## 3. Primary period confidence and refinement

`EvidencePredictionEngine` retains forward-only historical replay. Each historical prediction sees only earlier recorded intervals, never the future target or today's profile assumptions.

Moderate period-start confidence requires all of:

- Six source intervals, spanning at most seven days.
- At least three scored estimates in the last six eligible replay rows.
- No withheld estimate in those rows.
- At least 80% of those actual starts inside their reconstructed windows.
- Mean absolute center error no greater than three days.

Otherwise confidence is Low. There is no High confidence. Retrospective coverage is not a probability for the next period. This confidence applies to the **primary period start**, not to ovulation, fertility, bleeding duration or later hypothetical cycles.

More data can narrow, widen, shift or withhold a forecast; improvement is not guaranteed or forced. Corrections and deletions re-run the same calculation.

## 4. Expected bleeding interval: separate duration learning

Take the most recent six periods with explicitly confirmed end dates, sorted by start. Missing ends are excluded from duration learning, not treated as one-day periods. Calculate:

- `d = rounded median(confirmed durations)`.
- `dMin = minimum confirmed duration`.
- `dMax = maximum confirmed duration`.

With no confirmed durations, use the entered typical duration (`d = dMin = dMax = D`). Show which source was used and how many confirmed durations support it. One confirmed duration is usable, but is not described as an established pattern.

For the next period:

- **Expected bleeding dates:** `[P, P + d − 1]`.
- **Bleeding timing envelope:** `[A, B + dMax − 1]`.

The expected dates answer “when might the next period occur?” The wider envelope combines start-date uncertainty with observed duration variation; it is **not** a claim that bleeding will last across that entire interval. With only an entered duration there is no measured duration variability; the real duration may still differ.

If duration is missing, preserve the start prediction and show that bleeding duration is unknown. If the largest duration is at least the modeled cycle length, do not create a bleeding interval overlapping the next central cycle; explain that duration does not fit the model rather than silently truncating it. No record is discarded or altered.

## 5. Possible ovulation date

For a projected next period start `P`:

- **Central possible ovulation date:** `O = P − 14 civil days`.
- **Illustrative timing bounds:** `[A − 16, B − 10]`.

The 14-day central offset is a conventional calendar assumption, not an individually measured luteal phase. The broader 10–16-day offset is informed by NHS cycle-physiology guidance. It is not a hard biological boundary: actual timing can be outside it, and ovulation may not occur.

Counting convention is explicit: these are absolute date differences, not an assertion that every 28-day cycle ovulates on cycle day 14. `S` is cycle day 1; `S + 14` is cycle day 15. Calendar products differ in day-count conventions and offsets. Cecy does not claim to reproduce Apple's formula.

Do not narrow this biological uncertainty merely because period starts are regular. Personalization of actual ovulation timing would require suitable biomarker inputs (for example LH tests or temperature data), a separately designed interpretation policy and validation. Symptoms and sexual activity are not used as evidence that ovulation occurred.

## 6. Full estimated fertile window

ASRM defines a six-day fertile interval ending on ovulation for counseling purposes. Cecy displays:

- **Central estimated fertile window:** `[O − 5, O]`, six inclusive days.
- **Wider fertile timing envelope:** `[A − 16 − 5, B − 10]`.

The six-day window is one possible placement based on the central model. The wider interval is the union of placements across the illustrative ovulation bounds, not a claim that someone is biologically fertile for every day in it. It is available in details rather than painting weeks of “ovulation.”

The modeled six-day interval must fit on or after the preceding actual/assumed start. If even that central interval cannot fit (for example a 10-day cycle), omit ovulation and fertile estimates with an explanation; do not clip a six-day window into a misleading shorter one. Broader uncertainty is retained even when it crosses an assumed cycle boundary, making model limitations visible rather than artificially narrowing it.

**No calendar day is labeled safe, infertile, or guaranteed fertile.** The end of a marker does not establish that ovulation happened or pregnancy is impossible. Not for contraception, diagnosis or as the sole guide for conception.

## 7. Cycle context

Existing selections remain saved and do not automatically hide calendar reference dates. Cautions appear in paired details and date accessibility descriptions:

- Hormonal contraception: some methods suppress ovulation; bleeding may not reflect a natural ovulatory cycle. Cecy does not know the method, so the displayed reference may not apply and does not assert ovulation will occur.
- Recently stopped contraception: timing may be unpredictable as ovulation returns.
- Postpartum: ovulation can return before the first period; old lengths may not describe current timing.
- Breastfeeding: ovulation can be delayed or unpredictable but pregnancy remains possible.
- Perimenopause: irregular or anovulatory cycles limit the method.

These answers provide no validated adjustment factor. Mathematical outputs are not diagnoses. Clinical review of the warning/display policy remains a release gate.

## 8. Future cycles and cumulative uncertainty

At most three paired cycles are projected from the last **recorded** start. Let `L = P − S`, `a = A − S`, `b = B − S`. For projection number `j = 1, 2, 3`:

- Central period start: `Pj = S + j × L`.
- Start bounds: `[Aj, Bj] = [S + j × a, S + j × b]`.
- Bleeding, ovulation and fertile intervals follow the formulas above using `Pj`, `Aj`, `Bj`.

This carries uncertainty from each assumed intervening cycle forward. It replaces the former arbitrary extra one day per side. Linear propagation is a conservative display policy, not a calibrated confidence interval or an independence assumption. Bounds can overlap; the app does not erase uncertainty just to make a cleaner calendar.

Later cycles explicitly say **Projection** and assume intervening estimated periods occur. They are not inserted into storage or historical calculations. The primary next start never rolls forward because it is overdue. Reminders and historical evaluation still use the primary prediction, not hypothetical future records.

The upcoming card keeps the primary period forecast visible even when its ovulation date has passed, with the next future ovulation projection available separately. After three projected cycles, request updated actual records rather than extend indefinitely.

## 9. Worked example

Inputs: October 1, 2026 last start; 28-day typical cycle; 5-day typical period; no completed interval/end date.

| Output | Estimate |
|---|---|
| Next period central start | October 29 |
| Possible start window | October 26–November 1 |
| Expected bleeding dates | October 29–November 2 (five days) |
| Bleeding timing envelope | October 26–November 5 |
| Possible ovulation date | October 15 |
| Estimated fertile window | October 10–15 (six days) |
| Ovulation timing bounds | October 10–22 |
| Fertile timing envelope | October 5–22 |

The broad envelopes explicitly show how little one start can establish. They are not displayed as 18 days of fertility or 13 days of ovulation. For example, with later measured cycle lengths 28 and 30, the median center becomes 29 days after the latest actual start; confirmed period durations of 4 and 6 days yield a five-day bleeding estimate independently.

## 10. Calendar presentation and accessibility

All three presentations—Calendar, Today strip, and Today expanded calendar—consume the same cached `session.cycleForecast`:

- Recorded bleeding: existing filled drop / recorded styling.
- Possible starts: red dashed outlines.
- Expected bleeding: red dashed outlines **plus hollow drops**.
- Possible ovulation: **one green dotted outline per cycle**.
- Estimated fertile days: green **leaf markers**, not multiple ovulation outlines.
- Actual activity markers remain intact; an estimate never replaces a logged event.

Selecting any marked date opens its paired forecast with central dates, separate intervals, duration source, caution text and timing envelopes. Overlapping windows retain all relevant information. VoiceOver names expected versus recorded information, fertile dates, context limitations and future-cycle assumptions. Color alone is not the only distinction. Forecast and recorded icons share one eager grid; Today reserves sufficient row height for loaded dates. Today’s legend wraps to additional lines instead of scrolling horizontally. Calendar’s legend contains symbol labels only; explanatory cautions remain in forecast details.

## 11. Implementation map and persistence

- `Domain/CycleAnalysis.swift`: existing primary median period-start engine and profile fallback.
- `Domain/PredictionEvaluation.swift`: unchanged evidence policy and no-future-leakage replay.
- `Domain/PossibleOvulation.swift`: `ForecastInterval`, `BleedingDurationEstimate`, expanded `ProjectedCycle`, shared `CycleForecast` and context cautions.
- `App/TrackerSession.swift`: passes actual periods into the cached forecast after committed changes.
- `Shared/CycleForecastView.swift`: four outputs, source information and uncertainty disclosures.
- `Shared/ActivityCalendarStrip.swift`, `Shared/ExpandableMonthCalendar.swift`, `Features/Calendar/TrackerCalendarView.swift`, `Features/Today/TodayView.swift`: shared calendar semantics and markers.

No SwiftData schema migration, profile field, health record, remote payload, automatic AI request or new notification is introduced. Add/edit/delete, profile updates and imports use the existing committed-state recalculation path. An unknown end stays unknown. Privacy reset and access-loss handling continue to clear session state.

## 12. Research reviewed

- [ASRM: Optimizing natural fertility (committee opinion)](https://www.asrm.org/practice-guidance/practice-committee-documents/optimizing-natural-fertility-a-committee-opinion-2021/): six-day fertile window ending on ovulation; approximate calendar method; substantial limitations of exact-day app estimates.
- [NHS: Periods and fertility in the menstrual cycle](https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/): roughly 10–16 days from ovulation to the next period; variable cycles; some hormonal methods suppress ovulation.
- [Apple: Track your period with Cycle Tracking](https://support.apple.com/en-us/120356): period prediction uses entered/logged cycle and period information; distinguishes fertile-window predictions from temperature-supported retrospective ovulation; no use as birth control. Apple describes its own offset and additional data sources—Cecy does not claim to implement that system.

Reviewed October 2, 2026. Clinical sources support the distinctions and limitations, not validation of Cecy's statistical padding, exact dates or cumulative bounds.

## 13. Validation and remaining gates

The final focused run passed **52 unit/persistence tests in eight suites and all three selected calendar UI scenarios together**, including the final bleeding outlines. It completed in 97.7 seconds. Tests cover distinct outputs, inclusive date arithmetic, six fertile days versus one ovulation marker, confirmed-duration learning, missing ends, six-record bounds, widening uncertainty, short cycles, context warnings, leap-day transitions, session edits/deletion, existing setup/evidence policy and consistent calendars. Debug app/test compilation and a separate **unsigned iOS Release build passed** (36.7 seconds). Runs had hard limits; no simulator retry loop was needed.

Evidence: `/tmp/cecy-adaptive-final.xcresult`, `/tmp/cecy-adaptive-final.log`, `/tmp/cecy-adaptive-final.status`, `/tmp/cecy-adaptive-release.log` and `/tmp/cecy-adaptive-release.status`. An initial narrower run also passed 33 unit tests and the same three UI scenarios; the final run supersedes it. No live network requests, commits or pushes.

Physical-device/VoiceOver/largest-text visual review, full-app regression, clinical wording review, prospective calibration and real-world prediction accuracy remain open. Automated synthetic fixtures establish implementation behavior—not clinical validity. Existing deferred release/privacy acceptance gates are unchanged.
