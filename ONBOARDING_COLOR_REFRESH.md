# Onboarding Color & Engagement Refresh — Study

Branch: `feat/onboarding-color-refresh`
Status: Study / proposal (no code changes yet)

## 1. Current state

Flow (`OnboardingFlowView.Step`, 8 steps): welcome → about → history → cycle (period length) → cycleLength → preview → review → apple.

| Area | What exists today | Why it feels flat |
|---|---|---|
| Page shell (`OnboardingPage`) | Native grouped `Form`, warm-neutral `palette.background`, one 28 pt SF Symbol on a sage tile, rounded large title, linear `ProgressView` | Every step uses the same green tile on the same beige. Only the glyph changes. |
| Welcome | Three plain `Label` rows in a form section, "Get started" button | There's no hero moment, and it looks like a settings screen |
| About / lengths / history | Text field, chips, wheel picker, date button | Functional, but answers aren't celebrated and the wheels have no visual context |
| Preview | Three text labels plus a footer paragraph, then the estimate as `LabeledContent` | It describes the Today view in words instead of showing it |
| Review | `LabeledContent` rows and a disclosure group | Reads like a receipt |
| Apple page | Separate `OnboardingApplePage` on `systemBackground` (white/black), with a different background from every other step | Abrupt visual break. The privacy note also has a copy bug: *"are not restored by Apple sign-in"* is repeated. |
| Progress | Default tinted `ProgressView` (accent green) | Generic, with no sense of journey |
| Motion | `.id(step)` swaps the content with no transition | Steps "cut" instead of flowing |

Palette (`TrackerPalette`): background (warm neutral), surface, accent (deep green), sage, recorded (rose), recordedSurface, sexualActivity (red-coral), action (dark green). The follicular phase tile already uses `Color.orange.opacity(0.08)`.

## 2. Constraints to respect

From the existing design docs (`PHASE_0_FOUNDATIONS.md`, `PHASE_1_DESIGN.md` §457/§473, `UI_REFRESH.md`):

- **Keep the brand base:** warm neutral background, sage, and deep green. *"Do not introduce a pink default, branded illustration dependency, or decorative cycle wheel."* → Color should be added as accents on top of this base, not as a new pink theme. Rose is allowed as a semantic accent (it already means "period/recorded").
- **Accessibility:** Reduce Motion, Reduce Transparency, Increase Contrast, Dynamic Type up to AX sizes, VoiceOver focus on the heading (`onboardingHeading`), dark mode, iPad, and landscape. Color must never be the only indicator.
- **Glass belongs to actions and navigation, not content.** No `.glassEffect` on cards.
- **Keep native controls** (wheels, text fields, Sign in with Apple button) so the existing UI tests and accessibility keep working.
- **UI-test identifiers must survive:** `onboardingHeading`, `onboardingContinue`, `onboardingBack`, `onboardingPeriodLength*`, `onboardingCycleLength*`, `addOnboardingPeriod`, `onboardingLastStart*`, `continueWithApple`, `onboardingLocalProfileNote`, `starterEstimateNotice`, `setupStatus`, `creatingAccountMessage`.
- **Not medical / not gamified:** keep the "estimates are not medical advice" copy, and avoid streaks or confetti-style rewards for health data.

## 3. Proposal

### 3.1 Per-step color identity ("journey through the cycle")
Give each step a theme drawn from the cycle phases, so the onboarding previews the app's own color language:

| Step | Theme | Tint (light / dark) | Symbol |
|---|---|---|---|
| welcome | Sage / brand | accent on sage | `leaf.fill` (hero) |
| about | Warm apricot (follicular) | new `apricot` ≈ #C2662D / #F2A66B | `person.crop.circle.fill` |
| history | Rose (menstrual, existing `recorded`) | recorded / recordedSurface | `calendar` |
| cycle (period length) | Rose | recorded | `drop.fill` |
| cycleLength | Lavender (luteal) | new `lavender` ≈ #6A5AA8 / #B9AEF0 | `arrow.triangle.2.circlepath` |
| preview | Sunny (ovulation) | new `sun` ≈ #A0700F / #F5CD6B | `sun.max.fill` |
| review | Sage | accent | `checkmark.seal.fill` |
| apple | Sage | accent | `lock.shield.fill` |

Implementation: add `OnboardingTheme` (tint, surface, gradient stops) keyed by `Step`. Add the new colors to `TrackerPalette` as semantic tokens with light, dark, and high-contrast variants, each checked for ≥ 4.5:1 text contrast and ≥ 3:1 for glyphs. Wire them into `ContrastTests` / `AppBrandingTests`.

### 3.2 Hero header instead of a flat tile
Replace the 28 pt symbol-on-sage tile in `OnboardingPage` with an `OnboardingHero` view:
- A soft radial or mesh gradient "glow" behind the header in the step's tint (≤ 18% opacity over `palette.background`, so the base stays warm neutral). On iOS 18+ use `MeshGradient`, with a `RadialGradient` fallback on iOS 17.
- The symbol is larger (44–56 pt, `@ScaledMetric`, clamped at AX sizes), uses `.symbolRenderingMode(.palette)` or `.hierarchical`, and sits in a circular tinted badge.
- `symbolEffect(.bounce)` once on appear on iOS 17+, skipped when `accessibilityReduceMotion` is on.
- The background gradient extends under the progress bar and nav bar, so the page feels like one canvas.

### 3.3 Welcome as a real landing moment
- Full-bleed gradient (sage → apricot → rose, very soft) with the app icon or `LaunchIcon` in the center and "Understand your cycle." as the hero title.
- Convert the three `Label` rows into three colored feature cards, one per theme (calendar = rose, symptoms = apricot, patterns = lavender), each with a filled icon badge. They stagger in on appear, or appear instantly with Reduce Motion.
- A small privacy reassurance pill under the cards: "Stored on this device" with `lock.fill`.

### 3.4 Journey progress indicator
Replace the plain `ProgressView` with `OnboardingProgressBar`:
- A capsule track with a gradient fill that moves through the step tints. Optionally show segmented dots (one per step), colored once completed.
- Keep the same accessibility contract: label "Onboarding progress", value "Step N of M".
- Animate the fill with `.smooth`, or no animation with Reduce Motion.

### 3.5 Step transitions
- Swap `.id(step)` for a directional transition: `.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))`, reversed for Back. Track direction in `@State var forward: Bool`.
- Wrap `step = destination` in `withAnimation(reduceMotion ? nil : .smooth)`.
- Move VoiceOver focus to the heading after the transition (already done via `onAppear`, so verify it still fires).
- Add `sensoryFeedback(.selection, trigger: step)` for a light haptic on advance.

### 3.6 Tinted inputs and answers
- `SelectionChip` / `OnboardingCycleLengthField`: tint the selected chip with the step color instead of the generic accent, and pass the tint via an environment value (`\.onboardingTint`) so shared components don't need new parameters.
- `CycleLengthWheel`: show the big "28 days" number in the step tint. Under it, add a tiny visual such as a row of N small capsules (period length) or an arc fraction (cycle length) that grows with the value, making the choice tangible. This is decorative, so mark it `accessibilityHidden`.
- History: show the chosen date as a colored "date card" (rose surface, calendar badge, big day number) instead of a label plus text.

### 3.7 Preview shows instead of tells
- Render a mini, non-interactive Today card (a reduced `CyclePhaseRingView` with `ringOnly` and fixture-free data from `draft.overview`) or a 4-tile phase strip in the real phase colors, with "Your first estimate" as a colored highlight card.
- Keep the three explanatory lines as a short caption list beneath.

### 3.8 Review as a summary card
- One `TrackerCard`-style card with colored stat tiles: Cycle (lavender), Period (rose), Next start (sun), and Confidence as a pill.
- Each tile is tappable to edit. This replaces the "Edit answers" disclosure, but keep it accessible as buttons with labels.
- Keep the medical disclaimer as footnote text.

### 3.9 Unify the Apple page
- Use the same `OnboardingPage` shell (hero + gradient + palette background) instead of the separate `OnboardingApplePage` on `systemBackground`.
- A shield or lock hero, three short privacy bullets with icons, and the Sign in with Apple button pinned to the bottom (style stays `.black` / `.white` per Apple HIG).
- Fix the duplicated copy in `onboardingLocalProfileNote`.

### 3.10 "Creating your account" moment
- Replace the bare spinner with the hero gradient plus a gently pulsing `leaf.fill` symbol (`symbolEffect(.pulse)`, with a static symbol under Reduce Motion) and the existing message. Keep `setupStatus` / `creatingAccountMessage`.

## 4. Architecture

New files under `cecy/Features/Onboarding/`:
- `OnboardingTheme.swift`: `struct OnboardingTheme { tint, surface, glow: [Color], symbol }` and `extension OnboardingFlowView.Step { func theme(_ palette:) }`, plus `EnvironmentValues.onboardingTint`.
- `OnboardingHero.swift`: gradient background and animated symbol badge.
- `OnboardingProgressBar.swift`: journey progress.
- `OnboardingFeatureCard.swift`: welcome and preview cards.

Edited:
- `TrackerStyle.swift`: add `apricot`, `lavender`, and `sun` (+ surfaces) to `TrackerPalette`, with high-contrast variants.
- `OnboardingPage.swift`: take a `theme`, use the hero, and keep the `Form` for native controls but with the gradient behind it.
- `OnboardingFlowView.swift`: transitions, direction state, haptics, the new welcome/preview/review content, removal of `OnboardingApplePage`, and the copy fix.
- `CycleLengthWheel.swift`, `SelectionChip.swift`: read `onboardingTint`, with the default falling back to the current accent so other screens don't change.
- `Localizable.xcstrings`: new strings.

No domain or persistence changes, and `OnboardingDraft` / `OnboardingProgress` are untouched.

## 5. Validation plan
- Unit: contrast checks for the new palette tokens (light, dark, high contrast), and a theme mapping test (every `Step` has a theme).
- UI: the existing onboarding suites (`OnboardingUITests`, `DeviceFeedbackRoundFiveUITests`, `TodayDetailsAndWelcomeUITests`, `PhaseTwoUITests`) must pass unchanged. Add a smoke test that runs through onboarding with Reduce Motion enabled via launch argument.
- Manual: light/dark, AX5 Dynamic Type, iPhone SE through Pro Max, iPad split view, landscape, VoiceOver order, Increase Contrast, Reduce Transparency.

## 6. Suggested rollout (small PRs on this branch)
1. Palette tokens, `OnboardingTheme`, and tests.
2. `OnboardingHero` + `OnboardingProgressBar` in `OnboardingPage`, unify the Apple page, and the copy fix.
3. Transitions, haptics, and the Reduce Motion handling.
4. Welcome feature cards and the "creating account" moment.
5. Tinted chips/wheels, the history date card, the preview mini-Today, and the review summary card.

## 7. Open questions
- Is introducing apricot, lavender, and sun accents acceptable given the "no pink default" guidance? They're accents only, and the base stays sage/neutral.
- Should the per-step themes carry into the main app (phase tiles currently use rose/orange/sage), so the onboarding colors match what users later see on Today?
- Is the welcome illustration limited to SF Symbols and the app icon (no new illustration assets), per the "no branded illustration dependency" guidance?
