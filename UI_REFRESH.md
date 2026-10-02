# Cecy visual refresh

## Design approach

Use a quiet, readable content layer and native glass navigation rather than putting translucent panels behind health records.

References reviewed:
- [Apple: Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
- [Human Interface Guidelines: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)

Apple recommends native navigation, no custom backgrounds covering system glass, and sparing use of glass on actions rather than content. A custom overlay tab bar would duplicate selection, safe-area, keyboard, VoiceOver, and navigation-stack behavior; Cecy retains `TabView` instead.

## Implemented

- **Tabs:** native rounded Liquid Glass on iOS 26+ with Today, Calendar, Insights and Settings labels kept visible while scrolling. No nested glass backgrounds or custom tab-bar overlays. iOS 17/18 retain the native legacy tab bar; they do **not** render true Liquid Glass. Minimum deployment remains iOS 17.
- **Typography:** Dynamic Type-aware SF Rounded, stronger page-title and metric hierarchy, readable secondary descriptions, monospaced numeric metrics.
- **Color:** warm ivory and forest in light mode; deep green surfaces and mint accents in dark mode. Muted rose denotes recorded period days; estimates retain their green dashed outlines. Icons, selection underlines, text and accessibility labels remain independent of color.
- **Surfaces:** consistent continuous rounded cards, subtle outlines and shadows, 640-point readable content width. Increased Contrast strengthens shared card/chip/date-strip borders.
- **Forms:** Settings, onboarding, profile/date sheets, logging, and AI symptom review share native grouped-form styling and interactive keyboard dismissal. Native rows, date pickers, toolbars and confirmation flows remain intact.
- **Actions:** shared native glass prominent buttons on iOS 26+. Reduce Transparency and older OS versions use opaque bordered-prominent buttons. Primary fill has sufficient contrast with white labels in both appearances.
- **Screen structure:** grouped logging actions on Today, grouped navigation on Insights, matching icon badges in Settings, and a coordinated onboarding heading/footer.
- **Privacy:** the separate opaque privacy-cover window is unchanged. Records, predictions, consent, persistence and authentication logic are not modified by this refresh.

## Shared implementation

`cecy/Shared/TrackerStyle.swift` owns palette roles, typography/layout tokens, page headings, cards, navigation labels, form styling and primary-button styling. The accent asset supplies light/dark and increased-contrast system tints. The root applies rounded typography and capsule button borders to its descendants, including sheets.

Do not apply `.glassEffect` to cards or add opaque `toolbarBackground` overrides to the tab bar. Do not add custom animations without respecting Reduce Motion. The native glass controls already adapt to the system setting.

## Validation

- `VisualStyleTests`: light/dark solid-surface text/accent contrast (at least 4.5:1), primary-action contrast and shared layout constraints.
- `VisualRefreshUITests`: all four native tabs, scrolling, logging-sheet presentation/dismissal, navigation-stack preservation across tabs, dark appearance, largest accessibility text, selected-state semantics and touch targets. Screenshots are retained as test attachments, not pixel-diff assertions.
- Existing device-feedback and largest-text onboarding UI tests are also included in the regression run.

### October 1 — bounded validation continuation

The visual implementation is in place; runtime acceptance is **not complete**. No application-code changes were needed during this continuation.

- **Simulator discovery:** responded in 2.8 seconds; no stale automation processes were running.
- **Boot health:** iPhone 17 Pro / iOS 26.2 returned in 7.3 seconds with exit 0 but reported **Data Migration Failed**. The wrapper's success label reflected exit status only; the boot output takes precedence. This is an environment blocker, not proof of the root cause of earlier stalls or of a Cecy defect.
- **Focused tests:** blocked, not launched. No retries, device erasure or runtime reinstallation. Previous temporary logs/results were unavailable, so earlier conversational test reports are not treated as fresh evidence.
- **Unsigned iOS Release:** passed in 54.2 seconds with a five-minute hard deadline, independent of simulator execution. Only warning: App Intents metadata extraction skipped because the app has no AppIntents dependency.

Evidence: `/tmp/cecy-refresh-final/simulator-health.json`, `simulator-boot.log`, `release.log`, and `release-status.json` (temporary local artifacts, not committed). No new `.xcresult` was produced.

On a verified healthy simulator/device, resume with `cecyTests/VisualStyleTests`, both `cecyUITests/VisualRefreshUITests` scenarios, and the existing largest-text onboarding test. Inspect light/dark, navigation, sheets and largest-text screenshots. Stop on infrastructure failure rather than retrying. Previously reported automation fixes still need a fresh complete focused pass. The historical file-protection failure and full-suite/device gates remain open.

### Remaining device review

Physically review glass reflections and legibility over scrolling content, landscape and iPad layouts, VoiceOver/Switch Control, and OS-level Reduce Transparency/Reduce Motion/Increase Contrast. iOS 17/18 fallback execution requires an older runtime; only newer runtimes are installed locally. Automated contrast checks cover solid color tokens, not the changing native glass compositor.
