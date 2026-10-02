# Device feedback — Possible ovulation and daily insights

Date: October 2, 2026 · Branch: `testing/on-device-fixes`

**Follow-up:** The single-day ovulation marker below is superseded by the paired three-cycle forecasts in [OVULATION_FORECAST.md](OVULATION_FORECAST.md). Daily-insight behavior is unchanged. Validation below records the earlier checkpoint.

## Implemented behavior

- Calendar and Today (collapsed/expanded/accessibility list) show possible period **start** dates with red dashed outlines and a possible ovulation day with a green dotted outline. Confirmed records remain independent; this does not invent bleeding duration or ovulation observations.
- Possible ovulation is a calendar approximation: existing predicted center minus 14 civil days. It is withheld without a period estimate or if it falls on/before the latest recorded start or overlaps the earliest predicted start. It never rolls forward when a period is unrecorded. Labels/details explicitly say possible, not detected/confirmed, and not for contraception or fertility planning. This is not a calibrated ovulation algorithm or a fertile-window feature. Confidence in the period estimate does not validate ovulation timing.
- Insights opens with an immediate, local daily record summary. A separately confirmed **Prepare daily insights** option allows one automatic bounded `answer_cycle_question` request on the first eligible active/unlocked visit each day. Existing AI opt-in alone does not enable automatic requests. Toggle is available from Insights → Daily preparation and Settings → Privacy and export.
- A protected preference stores the attempted local day **before** sending. Storage failure prevents sending. Relaunch, failure, cancellation, record edits and toggle changes do not automatically spend another request that day. Manual generation remains available. No background scheduling, retry loop or new backend.
- Generated daily output is memory-only, shared between Insights and the record-insights screen, and retained on unchanged, unlocked same-day refresh. Record/day changes, revoked consent, lock, logout and reset invalidate results. Leaving the foreground cancels pending requests; manual requests take priority. A cold relaunch shows local facts rather than silently repeating an already attempted daily request.
- Ask about your records has three prepared factual answers: number of recorded starts/confirmed ends, measured cycle lengths, and most logged observations over 90 days. These are calculated locally, available offline without AI consent, and refreshed from current records. They do not upload questions, private notes, identity or sexual activity. Sparse records remain sparse; missing symptoms/end dates are not invented.
- No health-model migration, backend change, live gateway call, commit or push.

## Research and limits

- [Apple Cycle Tracking](https://support.apple.com/en-us/120356) distinguishes calendar-based fertility estimates from retrospectively estimated ovulation using compatible Watch data. Cecy has neither temperature nor ovulation-test evidence and does not claim Apple’s retrospective capability.
- [NHS periods overview](https://www.nhs.uk/conditions/periods/) describes ovulation as approximately 12–16 days before the next period and notes that some hormonal contraception prevents ovulation. Fourteen days is only a rough midpoint, not an individual guarantee. Irregular/anovulatory cycles and cycle factors can make this approximation misleading; the UI warns about those limits.
- This does not implement general cycle-phase inference or send phase/ovulation assumptions to wellness requests.

## Validation

- Debug app/test compilation passed. An initial expensive Swift type-inference expression was split into typed aggregation steps.
- **29 focused unit tests in four suites passed**, including 13 new tests for date boundaries, withheld estimates, no fabricated/rolled-forward records, prepared-answer privacy/sparsity, legacy preferences, daily consent, persistent request limits, failed saves, midnight rollover, cancellation and stale responses. Existing AI consent and sparse-data tests also passed.
- **Both new synthetic UI scenarios passed across focused runs:** matching ovulation markers in Today and Calendar, and locally prepared answers plus separately confirmed daily generation. The initial daily test queried an unexposed SwiftUI container; asserting the actual fixture answer passed on rerun. No product safeguard was removed and no test called the production gateway.
- **Unsigned iOS Release build passed** in 49.8 seconds. The final focused test run took 68.4 seconds. Evidence: `/tmp/cecy-feedback6-tests.xcresult`, `/tmp/cecy-feedback6-final-tests.xcresult`, `/tmp/cecy-feedback6-release.log` and their status files. Runs used hard limits and disabled optional UI-test diagnostics collection.
- Full-suite, physical-device/VoiceOver/large-text/color review, medical wording/calibration and live gateway/distribution acceptance remain open. Generated responses remain session-only, so cold relaunch after an attempted request falls back to local facts rather than automatically spending another request. No commits or pushes.
