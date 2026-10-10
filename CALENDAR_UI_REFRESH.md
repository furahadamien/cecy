# Calendar UI refresh — October 9, 2026

Presentation-only follow-up on `feat/today-ui-refresh`. Not committed or pushed.

## Changes
- Removed the large Calendar heading; retained the records/estimates subtitle, Go to date, return-to-today, and previous/next month controls.
- Centered month heading, mint background, rounded calendar surface, and a wrapping icon/meaning legend.
- Seven legend entries; no separate empty droplet for estimated period days. Recorded period, estimated dates, ovulation, fertile window, sex, symptoms, and other bleeding remain explained. The daily-answer disclosure and uncertainty distinctions remain available.
- Logging actions reuse Today's unboxed icons with text underneath. Date labels, future-date messages/guards, and accessible list behavior remain unchanged.
- Selected-day records precede the upcoming forecast. Calendar-specific date-header/action styling reuses the existing records and their metadata, notes, editing, and deletion handlers.
- Calendar forecast tiles retain the exact existing full dates, remaining start window, center, starter/reference notices, uncertainty labels, unavailable states, and later-projection disclosure. Larger text wraps into fewer columns.
- Both history routes remain available. Today retains its existing presentation defaults.

No changes to domain calculations, stored data/schema, session mutations, authentication, privacy, or remote services.

## Validation
- 15 targeted unit tests passed across five suites, including narrow/wide layouts, light/dark appearance, Dynamic Type, forecast/marker semantics, and record preservation.
- Eight distinct UI scenarios passed across focused runs on iPhone 16e (iOS 26.2): month/date controls and daily-answer disclosure; records before forecast and period actions; symptom edit/delete/relaunch; logging row/date guards; largest-text logging; legend meanings; both-tab forecast hierarchy/expansion; Today initial-viewport regression.
- Unsigned iOS Release build passed. `git diff --check` passed.
- A test helper's assumed top margin and immediate month assertion were corrected for the compact toolbar. Final navigation rerun passed. One failed-run result collector was stopped after all cases completed; per-case outcomes remain in its log.
- Evidence: `/tmp/cecy-calendar-refresh-checks.log`, `/tmp/cecy-calendar-refresh-final.xcresult`, `/tmp/cecy-calendar-navigation-final.xcresult`, `/tmp/cecy-calendar-refresh-release.log`.

The full test suite, physical-device/VoiceOver review, and signed release validation were not performed.
