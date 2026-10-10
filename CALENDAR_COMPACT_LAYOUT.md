# Compact Calendar follow-up — October 9, 2026

Supersedes the horizontal forecast and tall legend presentation in CALENDAR_UI_REFRESH.md. Changes remain uncommitted on `feat/today-ui-refresh`.

- Reduced date-grid spacing and badge height while retaining date targets of at least 44 points.
- Compact inline legend entries retain all seven meanings. Longer caveats and daily-answer states remain under Symbol details.
- Period and symptom Edit/Delete controls occupy the left column at standard text sizes; large text stacks safely. Visible labels are short; descriptive accessibility labels and deletion confirmations are preserved.
- Forecast entries now stack vertically, retaining all dates, uncertainty/source copy, and the later-projection disclosure.
- No domain, data, prediction, or mutation changes. Today keeps its existing record presentation.

## Validation

Nine targeted unit tests across four suites passed. Six distinct UI scenarios passed across the focused run and final navigation rerun: compact calendar/legend dimensions and navigation, left-hand period actions, left-hand symptom actions, symptom editing/deletion/relaunch, largest-text logging, and vertical forecasts/projection expansion on both tabs.

The month-arrow simulator test initially missed a tap. Its helper now waits for the target month and retries only if unchanged; the final rerun passed. App and test compilation and diff formatting checks passed.

Evidence: `/tmp/cecy-calendar-compact-records.xcresult` (initial navigation failure, other checks passed), `/tmp/cecy-calendar-compact-final.xcresult` (passing rerun and units).

Full-suite, Release, physical-device, and VoiceOver validation were not repeated for this follow-up. No commit or push performed.
