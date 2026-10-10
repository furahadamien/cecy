# Compact Today layout — October 9, 2026

Follow-up to TODAY_UI_REFRESH.md on `feat/today-ui-refresh`; supersedes its title and logging-card presentation.

- Removed the large Today heading; reduced top inset, date-strip spacing, section gaps, and hero padding.
- Logging actions show icons with text underneath, without enclosing backgrounds.
- Confidence/source copy uses the hero's full width. Equal-height phase tiles show icons, names, and days; full explanations remain in their existing sheets.
- Calendar and prediction, data, storage, and logging logic are unchanged.

## Validation

On iPhone 16e (iOS 26.2), all four UI checks passed: fully visible/equal-height phases without scrolling, the same during a newly recorded period, large-text logging access, and ring/tile detail interaction.

All 10 targeted presentation tests across three suites passed, covering width/theme/Dynamic Type layout, countdown/status behavior, and forecast sections. App and test compilation passed.

Evidence: `/tmp/cecy-today-compact-checks.xcresult`. Full-suite, Release, and physical-device checks were not repeated for this follow-up. Changes are not committed or pushed.
