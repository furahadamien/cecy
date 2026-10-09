# Today UI refresh — October 9, 2026

Branch: `feat/today-ui-refresh`. Not committed or pushed.

## Scope
- Mint Today background, combined title/date controls, and a ring/countdown hero with current-period status beneath it.
- Four logging action cards and four concise phase tiles at standard text size; enlarged text uses roomier layouts.
- Both ring segments and phase tiles open the existing phase details. Full phase explanations remain in those sheets.
- Refreshed Today estimates, forecast hierarchy, and full-width daily-history link. Existing record editors and confirmations remain available.
- Today and Calendar no longer draw the redundant `forecast.bleeding` droplet. Red estimated-period outlines remain; Calendar's legend describes them together.

No changes to domain calculations, forecast eligibility, records, storage/schema, account flows, AI, or services. Marker filtering is visual only: accessible date descriptions and underlying forecasts remain intact. Recorded period, daily bleeding, symptom, sex, and fertile-window markers are preserved.

## Validation
- Clean standalone unit run: **388 passed, 1 skipped** (physical-device file protection), across 74 suites.
- **8 focused UI checks passed across final-source runs**: ring and tile details, first-period setup/relaunch, actual side-by-side hero placement, selected-date/future guards, large-text action access, recorded-status relaunch, estimated status, and largest-text status.
- Earlier focused runs also passed Calendar legend and both forecast hierarchy checks.
- Unsigned iOS Release build passed; edited-file diagnostics and `git diff --check` passed.
- Added width/theme/Dynamic Type tests and a regression proving the hidden marker does not remove forecast data or other marker types.

During iteration, checks caught intrinsic-width hero stacking and a duplicate ring accessibility identifier; both were corrected. Status tests now account for scaled SF Symbol accessibility bounds (up to 3 points) and reveal lazy form controls before reading them. Some failed-run result collectors stalled and were stopped after their cases finished; the final unit and status runs completed successfully with result bundles.

Local evidence: `/tmp/cecy-today-units-final.xcresult`, `/tmp/cecy-today-status-final.xcresult`, `/tmp/cecy-today-ui-verified.log`, and `/tmp/cecy-today-release.log`.

Full UI suite, physical-device visual/VoiceOver review, and signed release validation were not performed.