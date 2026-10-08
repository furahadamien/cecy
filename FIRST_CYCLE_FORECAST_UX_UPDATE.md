# First-cycle forecasting and Today/Calendar UX

Implemented October 8, 2026.

## Behavior

- A first recorded period start anchors cycle day 1 and enables low-confidence next-period, phase, ovulation and fertile-window estimates where supported.
- With no measured interval, use the entered typical cycle length or Cecy’s existing 28-day default. For first-cycle bleeding duration, use an explicit recorded end, otherwise the entered typical period length or the existing 5-day default.
- October 7 with a 5-day duration: October 7 is recorded; October 8–11 are estimated period days. Estimates never create records or confirmed ends.
- New period entries from Today/Calendar now leave the end unknown. Previously, the route silently prefilled a same-day confirmed end, which prevented any remaining-period estimate.
- Explicit end edits immediately replace estimated current-period days and recalculate the phase timeline and learned duration. Existing saved end dates—including one-day periods—are preserved, not reinterpreted.
- Recorded period spans and explicit daily answers override conflicting per-day estimates. Other bleeding does not implicitly create a period or restart cycle counting.
- Actual measured intervals still supersede starter assumptions. Unsuitable measured history is not replaced with default dates. Existing cycle-context warnings, uncertainty and overdue-cycle behavior remain.

## UX

- **Period** records a cycle start or updates period dates; **Other bleeding** records spotting or a daily check-in without starting a cycle. Each editor has a short explanation.
- The shared Other bleeding action uses the same green symbol on Today and Calendar.
- Today no longer contains a symbol legend.
- Calendar retains a meaning-based legend for recorded periods, estimated starts/days, estimated ovulation/fertile dates, symptoms, sexual activity and daily bleeding answers. Labels no longer describe border styling.
- Recorded spotting uses a different symbol from estimated ovulation.

## Data boundaries

No schema, migration, network, consent, export or AI-context changes. Default values remain labelled, derived assumptions: they do not fill unknown profile answers, become measured statistics, enter retrospective prediction scoring, or manufacture periods. Notifications remain subject to existing preferences and eligibility.

## Validation

- All 380 runnable unit tests passed (381 discovered; one existing physical-device-only test skipped), including the new October 7, default/profile precedence, end-edit, daily-answer, replay and session tests.
- Nineteen distinct targeted UI scenarios passed across the validation runs: first-start/relaunch, unknown-history onboarding at largest text, cross-calendar forecasts, Today legend removal, Calendar meanings/actions, date guards, daily logging and reviewed period corrections.
- The first-start UI test exposed and verified the fix for the silent same-day end. A period-link UI helper now reveals the nested native switch before tapping and retains explicit value/save/record-retention assertions. Intermittent simulator interaction failures were retained in the evidence; the isolated boundary-review run passed.
- Remaining validation limitation: the boundary-review test is not consistently green. A fresh-simulator rerun failed before opening the editor because the Calendar-tab tap did not expose the Calendar date button; an earlier attempt also missed a save transition. One attempt reported an accessibility automation-type mismatch. No persistence or forecasting assertions were relaxed. UI automation reliability remains unresolved; this is not a clean full UI-suite sign-off.
- Final application source passed an unsigned generic-iOS Release build. This is not signed-device or App Store validation.
- Logs and result bundles: `/tmp/cecy-first-cycle-20261008/` (`final`, `verified`, `boundary-diagnostic`, `boundary-fresh`, `release-final`; earlier failed attempts retained).

This update supersedes the earlier unknown-setup rule that a lone recorded start without an entered cycle length must remain forecast-unavailable. Zero recorded starts still produce no dated forecast.
