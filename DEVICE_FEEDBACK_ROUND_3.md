# Device feedback — October 2 refinement

Branch: `testing/on-device-fixes`

## Implemented

- **Today dates:** a Weather-inspired, unboxed weekday/date strip, filled circular selection, current-day accent, centered selected-date caption and existing activity icons. The month heading expands/collapses a full month with previous/next navigation and matching activity markers. Both views share selection. Expanded mode respects locale week order, uses a list at accessibility text sizes/narrow widths, and allows future viewing without enabling future health logging. Return to Today remains available.
- **Goals:** “Health and wellness” is an optional local tracking goal in onboarding and Profile. Existing profiles decode unchanged. It does not introduce an unsupported wellness-API goal code or change predictions.
- **Questions:** removed the request-information disclosure and suggested-question button. Scope-driven starting text remains editable. Symptoms are highlighted multi-select chips with an explicit selection count; empty selection produces a local prompt rather than a request. The 100-character limit, consent and cancel/stale-result rules remain.
- **Multi-symptom context:** one request, not one request per symptom. Single-symptom payloads retain their shape. Multiple choices use a stable, sorted `facts.symptoms` array of typed per-symptom counts/timing aggregates, bounded by the existing symptom taxonomy. The existing domain calculations remain authoritative. No raw notes, profile, dates, sexual records, or full history are uploaded. Routing rejects mismatched symptom names, unselected symptoms, unsupported windows and medical questions. General questions referring to “these symptoms” are accepted only in the supported scope.
- **Flow:** optional overall-flow dropdown replaced by icon chips for Not recorded, Light, Moderate and Heavy. Persisted raw values and save/discard behavior are unchanged.
- **Cards:** record headers use colored icon badges and a clear title/date hierarchy; period and observation status appears in small pills. Private notes remain expandable. Separated capsule-style actions retain identifiers, 44-point targets, large-text fallbacks and delete confirmations. Sexual activity retains its red accent. Shared surfaces use a subtle edge treatment instead of adding glass behind health text.

## Validation

- Unsigned Debug build-for-testing passed in 28.1 seconds.
- **37 focused unit/transport tests in six suites passed**, including the existing context/transport/privacy boundaries and new multiple-symptom, goal round-trip and flow-symbol checks.
- **All four affected UI scenarios passed across focused runs:** expandable calendar and future-date restrictions (30.3 seconds), flow/goal save and relaunch persistence (74.4 seconds), multi-symptom selection and generation (24.9 seconds), and the question limit/scope-change regression (21.7 seconds).
- The first UI run exposed accessibility identifiers inherited from new containers. Explicit child-containing accessibility groups fixed the calendar, flow and symptom controls. A real transient 101-character display bug was fixed with a bounded native question editor. Its native keyboard-dismissal accessory was then verified in the final input-only run. No assertions were removed to obtain passes.
- **Final unsigned iOS Release build passed in 28.9 seconds**, including the keyboard fix. Source uniqueness and whitespace checks passed. Tests had a six-minute hard cap; the final single-input run had a 150-second cap. No simulator resets or live API calls.
- Temporary local evidence: `/tmp/cecy-feedback3/compile.log`, `focused.xcresult` (initial failures), `recheck.xcresult` (37 unit tests and three passing UI flows), `input-final.xcresult` (passing final input regression), `release.log` and corresponding status JSON files. Earlier failing evidence is retained. This is not a passing full-app regression baseline.
- The editor reintroduced historical duplicate copies into the question-view file. Only copies verified against committed source were removed; the new implementation was preserved. The now-unused context-preview view was removed too. Source uniqueness and whitespace checks passed before compiling.
- Automated tests use synthetic data and mocked transport. No live gateway calls or backend changes.

## Remaining gates

- Verify `facts.symptoms` acceptance with the existing deployed gateway using synthetic data before distribution. Client fixtures prove encoding and a single dispatch, **not server acceptance** of the newly populated aggregate-list field. No backend contract was independently retrieved or altered in this change.
- Review circular dates, expanded calendar, record cards, flow icons and selection contrast on physical devices, in dark mode, with largest text, VoiceOver and iPad/landscape layouts. No animations were added.
- Historical full-suite/device acceptance and provider/privacy review remain open; these focused checks are not release sign-off.
