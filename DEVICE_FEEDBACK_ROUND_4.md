# Device feedback — Today access and sparse records

Date: October 2, 2026 · Branch: `testing/on-device-fixes`

## Implemented

- **Immediate logging:** Record period and Symptoms appear directly below Today’s calendar, before the icon legend and cycle/prediction cards. Controls retain at least 44-point targets, stack at accessibility text sizes, and remain disabled for future selected dates. Secondary logging/history actions remain available further down.
- **Calendar evidence:** collapsed dates and expanded month/list dates display recorded activity icons and a dashed estimated-start window independently of selection. Predictions remain possible starts, never recorded bleeding spans. The legend explains the distinction.
- **Calendar work reduction:** the strip uses lazy date rendering; an immutable activity index is rebuilt when the session publishes records, not for every date during scrolling. Symptom/activity lookups are keyed by day and confirmed periods use binary lookup without expanding bleeding spans into invented daily records. Selecting a date already loaded does not rebuild the strip range.
- **One prediction pipeline:** removes the separate setup fallback and the three-completed-interval eligibility gate. The same median-window calculation accepts the entered typical cycle length when no measured interval exists, otherwise the most recent one through six observed intervals. The provisional assumption window remains ±3 days; measured windows extend two days around their minimum/maximum. There is no engine switch at four starts. Sparse evidence stays Low; wide-variation withholding and evidence-based confidence remain. Neither profile defaults nor passed estimates create records.
- **Historical replay:** available from one prior measured interval (three recorded starts for the first comparison). Today’s profile assumption is never inserted retrospectively. Replay counts and synthetic golden comparisons are updated accordingly.
- **Sparse AI:** Generate insights is available from Insights and Observations for one period start or recent symptom record. Uses the existing question endpoint/fields with bounded descriptive aggregates and explicit unknowns. Cycle-length questions accept a single start without pretending its length is known. Open cycles and cycles without confirmed ends can generate descriptions; fully measured cycles keep the existing summary contract. Repeated-pattern thresholds are retained for actual pattern claims, not used to block descriptions. Consent, privacy, cancellation, and stale-result rules remain.
- **Single-point charts:** a lone recorded start is shown on a date chart, not as a made-up cycle duration. A lone measured interval retains its point, with padded axes and no implied connecting line. A lone symptom count remains visible.

## Validation

- Debug/app/test compilation passed. **207 selected unit tests in 37 suites passed.** The initial broad run also reproduced the previously documented `PhaseFivePrivacyTests.protectedExportsExcludeBackupsAndCleanupIsScoped()` failure (four simulator protection-attribute assertions). Only that test was excluded from the final selected run; its assertions and privacy implementation remain unchanged. This is not a passing full regression baseline.
- **Six affected UI scenarios passed across focused runs:** immediate logging/legend ordering and marker continuity; one-start charts and consent-gated AI generation; largest-text calendar/logging; the existing calendar/future-date regression; and both historical-replay scenarios. The final isolated largest-text rerun passed in 72.1 seconds after correcting partial-visibility scrolling in the test helper. Symptom-chip accessibility containment was corrected without removing its assertion.
- **Unsigned iOS Release build passed** in 63.2 seconds. No simulator reset, live AI request, backend change, commit, or push.
- Date formatting now reuses locale-aware formatters, and Today’s wellness context no longer runs unnecessary prediction backtests.
- Jobs had hard deadlines of 150–360 seconds. Failing combined runs emitted test results but stalled in Xcode reporting; those reporter processes were stopped. Evidence is retained under `/tmp/cecy-feedback4-*`: `verified.log` contains the selected unit/standard UI results, and `large-text.status` and `release-verified.status` confirm successful final jobs.
- Stale editor buffers reintroduced historical duplicate AI/calendar definitions during edits. Verified historical copies were removed and source uniqueness checked before the final compile. Whitespace checks passed.

## Limits

Physical-device responsiveness, VoiceOver, and older-OS/layout review remain necessary. Reduced rendering/lookup work is not a measured on-device latency guarantee. Predictions are uncalibrated, not medical guidance or contraception. A single point is not an established pattern. The remote provider’s interpretation of sparse descriptive facts has not been validated with a live request.

This policy supersedes the three-interval starter/history transition described in `CYCLE_SETUP_REFRESH.md`; that document records the earlier implementation and validation.
