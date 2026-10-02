# Historical logging and upcoming forecasts

October 2, 2026 · `testing/on-device-fixes`

## Problems addressed

- Calendar logging always created a new period start. Entering another bleeding day could therefore create a one-day cycle interval, or conflict with an existing period.
- Wide variation in actual intervals withheld the primary prediction and removed the dependent calendar forecast.
- The calendar only generated the first three cycles after the last actual start. Old histories could leave every projection in the past.
- Today labelled the primary overdue window as the next period.

## Recording behavior

Today and Calendar now use the same period-entry routing:

1. A selected date inside a recorded period opens that period for editing.
2. A nearby prior period (selected day less than 30 days after its start) offers **New period** or **Add bleeding days**. Save is disabled until the user chooses. This is a UI suggestion, not a medical boundary or automatic merge.
3. Choosing Add bleeding days edits the existing record ID and preserves its flow/notes. The user sees and confirms the continuous start-through-last-bleeding-day range; every date in that range must be an actual bleeding day. No duration is supplied from a prediction.
4. A genuinely new entry initially confirms the selected day only. **Include confirmed bleeding days** and **Last bleeding day** allow a longer actual range. Users can turn off the range when only the start is known. Save says **Save period**, **Save bleeding**, or **Save changes** instead of Record start.
5. Start and end pickers cannot select future dates. Repository validation still rejects future starts, future ends, reversed ranges, duplicate starts and overlaps. Calendar and Today disable all future logging actions, including symptoms and sexual activity.

All other records stay intact. There is no automatic deletion, inferred missing period, silent merging, or storage migration. Historical corrections still use the atomic existing save/update path and prediction-update progress indicator.

## Upcoming presentation versus historical evidence

The primary period engine and its evidence replay remain unchanged. Actual starts still determine recorded cycle day and statistics. The session passes the **real current day**, not the selected logging date, to the calendar forecast.

Let `P` be the primary central date and `L` the modeled cycle length. The first upcoming zero-based cycle index is:

`i = max(0, ceil((today − P) / L))`

The calendar retains original indices 0, 1 and 2 and adds indices `max(0, i − 1)` through `i + 2`. The sorted union has at most seven cycles regardless of how old the last record is. This preserves the original nearby calendar context while ensuring three central period dates on/after today. The preceding projection is kept for bleeding intervals that may still overlap today.

Every date remains anchored to the latest **recorded** start. Existing cumulative timing uncertainty is retained; it can become very broad after long gaps. Nothing establishes that the assumed intervening periods or ovulation actually occurred. The app does not increase confidence to make an old history look reliable.

Today’s **Estimated next period start** and Upcoming card select the first center on/after today. The visible start window begins at `max(today, earliest)`; this removes elapsed dates from the upcoming presentation, not from the model or its historical uncertainty. Later projections are explicitly provisional and Low confidence. Historical date details can still show past dates as historical projections. Original primary predictions, backtesting, recorded intervals and reminder scheduling do not silently roll forward.

## Inconsistent history

If the primary period engine withholds an estimate, or its central cycle length is outside the existing 10–120-day setup range, the calendar may use a **saved user-entered typical cycle length** as a provisional reference. The reference carries a specific review notice, Low confidence and entered-length provenance. It is not described as a history-supported prediction. This prevents an accidental adjacent start or a long historical gap from removing all calendar estimates.

No profile length means no invented default: the app instead asks for review or a typical length. The primary history outcome remains unchanged (including wide-variation withholding), so statistics, replay and AI facts are not falsely rewritten. Saving a correction or deleting an erroneous start recomputes the reference/history choice.

This is a usability policy, not a new scientifically validated predictor. The existing ovulation/fertility limitations, context cautions and contraception warning remain. Unmarked dates are not safe days.

## Validation

All **53 unit/persistence tests in nine suites and all three new UI scenarios passed together**. They cover old starts, preserved record IDs, historical gaps, adjacent starts, symptom logging, bleeding-duration edits, no future writes, relaunch persistence, future-facing Today text and calendar projections. Existing primary-engine, setup and retrospective-evidence regressions also passed. Debug app/test compilation and the separate **unsigned iOS Release build passed** (47.3 seconds). No automatic reruns were needed.

Evidence: `/tmp/cecy-historical-logging.xcresult`, `/tmp/cecy-historical-logging-tests.log`, `/tmp/cecy-historical-logging-tests.status`, `/tmp/cecy-historical-logging-release.log`, `/tmp/cecy-historical-logging-release.status`. Earlier UI assertions that expect logging on existing periods to be disabled require updating to the intentional edit behavior; the previously documented logging-label frame check remains unresolved and was not included in this targeted run.

Device/VoiceOver/large-text review, clinical calibration and the previously deferred full regression/release gates remain open. No live AI requests, backend changes, commits or pushes.
