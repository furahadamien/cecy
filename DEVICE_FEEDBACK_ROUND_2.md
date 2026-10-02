# Device feedback — second refinement pass

Date: October 1, 2026 · Branch: `testing/on-device-fixes`

## Implemented scope

- Numeric context previews now limit decimal metrics to one fractional digit, consistent with statistics and measurement displays. Integer counts remain integers. Calculation/storage/export precision is unchanged; private notes and server-authored free text are not rewritten as numeric data.
- Ask about your records uses horizontally scrolling, accessible scope chips, preserving the existing local scope validation and 100-character limit.
- Progress says “Hang tight while we gather your insights.” The finite timeout and cancellation behavior remain; no duration promise or automatic retry was added.
- Recorded-period and observation components have smaller padding, clearer label/date/rating hierarchy, and adjacent edit/delete actions with vertical fallbacks at accessibility text sizes. Notes remain available; delete confirmation and 44-point targets remain.
- Today presents movement, food, hydration and recovery excerpts after an explicit wellness request, with links to the full result and Profile preferences. The full For today screen prioritizes suggestions above request controls. Routine notices use smaller text; severe-symptom and service safety messages remain readable and visible.
- The last successful wellness result is held **only in memory**, matched to its exact request context. Navigation cancellation preserves it; refresh attempts clear it first. Existing invalidation clears it on background/access loss, consent revocation, record/profile mutation, day refresh, logout or reset. No automatic network requests, database fields, disk cache or exports were added.
- Insights contains native Swift Charts: up to 12 chronological completed intervals and up to six most-logged observations during the last 90 days (today included). Charts use local facts only, expose accessible labels/value lists, handle empty data, count unique logged days, exclude future data, and do not imply symptom absence or a forecast.
- Height/weight wheels open with Add/Edit and collapse with Done, Clear or a units change. The same component serves onboarding and Profile. Unit choices are Metric / Imperial; actual values retain their measurement units. Profile Save/Cancel semantics and canonical precision remain.
- A static native launch storyboard shows Cecy branding on adaptive light/dark colors. It contains no personal data or artificial launch delay; iOS controls cold-launch visibility. It does not replace the opaque app-switcher privacy shield.
- Sexual-activity hearts now use a warm red accent, with light/dark variants, in date-strip/month markers, calendar legend, logging choices/actions and record headers. Period and symptom colors remain independent. Shapes and accessible labels still identify activity without relying on color.

## Validation

- Initial unsigned Debug build-for-testing passed in 236.9 seconds before the continuation's red-icon and final safety/test additions.
- Current simulator health check: existing iOS 26.2 iPhone 17 Pro is Booted, responds to commands and reports a running SpringBoard. No device reset/erasure or runtime reinstall was performed. This is a new health observation, not a diagnosis of earlier migration failures.
- Final Debug build-for-testing passed in 24.2 seconds after removing an editor-inserted duplicate of the original insight-screen source. The updated implementation was preserved; the duplicate was verified against HEAD before removal.
- All **17 focused unit tests in four suites passed**: chart data, wellness presentation, consent/lifecycle and visual colors/layout. This includes both light/dark red-icon contrast cases.
- **All three new UI scenarios passed across targeted runs:** charts/scope chips (13.6 seconds), Today wellness generation/navigation/background invalidation (36.8 seconds), and measurement collapse/reopen/save/persistence (34.8 seconds). The first run exposed test-helper navigation-bar assumptions; the next measurement failure came from a gesture turning the wheel instead of scrolling the form. The final measurement-only run passed after correcting that interaction. Assertions for collapse, retained value and saved value were preserved. This is not a claim that the historical full suite passed.
- Fresh unsigned iOS Release build **passed** in 39.1 seconds. Only warning: skipped App Intents metadata extraction because the app has no AppIntents dependency. Launch storyboard configuration, asset JSON and whitespace checks passed as well.
- Evidence: `/tmp/cecy-feedback2/compile-final.log`, `focused.xcresult` (17 passing unit tests and initial UI failures), `ui-corrected.xcresult` (two passing UI scenarios), `measurement-final.xcresult` (passing final scenario), `release-final.log`, and corresponding status JSON files. These temporary local artifacts are not committed. UI runs had a six-minute deadline; the final single-scenario run had a 150-second deadline. No infrastructure retry loop was used.
- New tests cover chart boundaries/deduplication/order, matching wellness presentation, refresh failure, privacy invalidation/late-result rejection, scope chips, inline wellness navigation, and measurement collapse/reopen/persistence. Color tests cover the red icon against content and calendar surfaces in both appearances. Existing onboarding measurement tests now use Metric/Imperial and explicit Done/Edit actions.
- Tests use synthetic fixtures only; no live gateway requests.

## Acceptance still open

Physical-device launch appearance, light/dark icon appearance, charts and largest-text layouts, VoiceOver, landscape/iPad, Reduce Transparency/Motion and minimum-OS checks. The historical full-suite/file-protection, signed-device and live gateway/provider review gates remain open. This UI iteration does not waive them.
