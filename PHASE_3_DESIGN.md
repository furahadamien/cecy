# Cecy — Phase 3 design and acceptance

Date: September 29, 2026
Branch: phase-3
Status: Implemented; automated verification passed September 29, 2026. Manual release checks remain pending.

## Scope and decisions
- Add local symptom/observation CRUD, Calendar markers, fast entry from Today/Calendar, record management, and deterministic structured insights. Keep prediction V1 unchanged. No AI, network, notifications, subscriptions, HealthKit or cloud.
- Stable observation codes: cramps, headache, bloating, fatigue, mood changes, acne, back pain, nausea, breast tenderness, sleep quality, energy level, cravings. Adding a type requires no schema change. Unknown persisted codes fail visibly rather than silently discarding records.
- One entry per type per civil day. Duplicate additions and conflicting edits are rejected with guidance to edit the existing record; no silent overwrites or repeated-day count inflation.
- Optional values 1–3: symptoms use Mild/Moderate/Severe; energy uses Low/Typical/High; sleep uses Poor/Fair/Good. Nil means not rated, not absent. Logging a symptom means it was reported; no zero/absent state is inferred. Energy and sleep presence alone is not an adverse symptom.
- Optional private notes: at most 2,000 characters, no truncation, whitespace-only becomes nil. Date semantics and timestamp/identity preservation match periods. Future observations are prohibited; travel never rewrites saved civil days.
- Raw symptoms are independent from periods. Correcting/deleting period history recomputes associations but never deletes symptoms. Symptom logging works with no period history.

## Storage and state
- V3 adds SymptomRecord with ID, civil day key, type code, optional value/notes, createdAt/updatedAt. Reuse unchanged V2 PeriodRecord/AppStateRecord types; keep V1/V2 model definitions frozen.
- Explicit lightweight V1 → V2 → V3 migration in the same existing store URL. CloudKit remains disabled. Test both upgrade origins and empty-history onboarding.
- Extend the existing repository contract and coherent TrackerSnapshot with symptom operations. Validate complete candidate symptom history; disable autosave; publish only after a successful transaction; roll back on failure. Preserve IDs/creation timestamps on edits.
- Reset deletes symptoms, periods and onboarding state in one current-store transaction. Keep the existing allowlisted legacy cleanup and failure disclosure. No symptom caches, notes or derived insights retained after reset.
- Legacy cleanup is separate from the current-store transaction and cannot be rolled back with it. If cleanup or the subsequent save fails, report failure and preserve current-store records; already removed legacy files remain removed. Retrying is safe.
- TrackerSession owns derived insight results, recomputed after every committed change and clock refresh. Invalid/future date context withholds insights with an explanation, not silent filtering. Period prediction remains independent from symptom data.

## Deterministic pattern policy V1
These are conservative display heuristics, not statistical significance, clinical cutoffs, causation or calibrated probability.

### Recurring logged timing
- Use up to six most recent eligible recorded starts. An eligible start has elapsed through start + 2 days and has at least six days between it and either neighboring start, avoiding overlapping [-3,+2] windows. Arithmetic boundaries exclude an unrepresentable window.
- Compare two fixed windows: three days before a start [-3,-1], or start through two days after [0,+2]. The latter is not a confirmed bleeding duration or a phase.
- Require at least three eligible starts, logs in at least three distinct start windows, and at least 60% of eligible starts with a matching log. Multiple days in one window count once.
- At most one timing insight per type: choose the window with more matching starts; ties choose before-start. Sleep/energy timing includes only explicitly Poor/Low (value 1), never nil, Fair/Typical or Good/High ratings.
- Always state matching count, total eligible starts and the exact supporting starts/log days. Unmatched starts mean no matching recorded observation, NOT absence. Do not claim symptom prevalence or use predicted dates as anchors.
- Insight evidence labels are separate from prediction confidence: Limited recorded evidence by default; Repeated recorded evidence only with six eligible starts and at least five matched. No probability or High label.

### Recorded changes
- Cycle length: compare previous three versus most recent three completed start-to-start intervals (requires seven starts). Display if absolute mean difference is at least three days.
- Cycle variability: same groups, population standard deviation; display if absolute difference is at least two days.
- Bleeding duration: use six most recent period records only if ALL have confirmed ends. Compare previous three with recent three inclusive durations; display if absolute mean difference is at least one day. Do not skip unknown ends to manufacture a comparison.
- All comparison insights carry Limited recorded evidence, both numeric groups and date range. Describe recent records as longer/shorter or more/less variable, not a trend continuing into the future. Missing periods may explain long intervals; no outlier removal.
- Stable IDs, category, generated civil day, evidence label, relevant range, source record IDs, supporting values/counts/dates. Derived insights are never persisted. Explicit policy version makes later changes testable.

## UI/UX
- One native entry form for adding/editing: required type/date, optional rating appropriate to type, optional note. Default type is unselected. Changing type clears its rating so severity cannot become an energy rating silently. Review then save, no automatic writes.
- Inline errors preserve drafts; cancel with changes confirms discard. Conflicting same-day entry messages point users to managing observations.
- Today: Log symptoms action and at most one evidence-backed insight below primary cycle information. No fabricated insight when evidence is insufficient.
- Calendar: separate non-color observation marker, spoken observation count, selected-day log action (past/current only), recorded observations with edit/delete. Preserve recorded period and estimated-start decorations.
- Insights: dedicated local observations/evidence destination, all structured insights, frequency as recorded-day counts (not symptom-free denominators), and all raw observation records including records needing date correction. No information requires a phase inference.
- Destructive symptom deletion uses an explicit two-action alert. Settings reset/privacy copy includes observations and notes; backup/secure-erasure limitations stay visible.
- Native controls, scalable text, 44-point actions, accessible labels and isolated previews. No extra editor/Simulator windows during implementation checks.

## Acceptance and validation
- [x] V1 and V2 file-backed stores migrate to V3 without losing periods, flow, notes, IDs or onboarding state.
- [x] Symptom CRUD round-trips and preserves identity; duplicates, invalid ratings/codes, future dates, long notes and bad timestamps fail safely.
- [x] Failed symptom writes/reset preserve committed state and drafts; retry is safe; reset removes every observation.
- [x] Missing logs never imply absence; repeated days do not inflate matched-start counts; ratings are not treated as adverse by presence alone.
- [x] Timing boundaries, six-start cap, short-interval overlap, open windows, date-line/DST and date arithmetic extremes have deterministic tests.
- [x] Change thresholds, group boundaries, empty/sparse data, unknown ends and correction/deletion recomputation are covered.
- [x] UI add/edit/delete/cancel/relaunch from Today and Calendar, duplicate prevention, reset, and evidence views are exercised.
- [x] Phase 1/2 regression tests, Debug and Release builds pass. Record actual results and remaining manual device/iOS17/accessibility checks in IMPLEMENTATION_PLAN.md.

Verification: 42 Swift Testing tests across six suites passed; all seven existing UI flows passed, and the corrected focused rerun passed all three Phase 3 flows plus the large-text Calendar regression. Debug testing and the final generic simulator Release build passed. See the implementation tracker for result-bundle locations and initial-failure history.

- [ ] Release acceptance: iOS 17 runtime, physical-device/offline behavior, signing/data protection, dark mode/iPad layouts, and manual VoiceOver/Dynamic Type checks. Simulator tests do not establish these requirements.
