import SwiftUI

struct HealthImportSettingsView: View {
    let session: TrackerSession
    @State private var months = 12
    @State private var selected: HealthFlowSample?
    @State private var showAccessHelp = false
    @AccessibilityFocusState private var reviewResultFocused: Bool
    private var review: HealthImportReview { session.healthImport }

    var body: some View {
        SettingsForm(title: "Apple Health") {
            Section {
                Label("Review before importing", systemImage: "heart.text.clipboard")
                Text("Read menstrual-flow samples and confirm which dates began a period. Nothing is sent to Apple Health.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Picker("History to review", selection: $months) {
                    Text("Last 3 months").tag(3)
                    Text("Last 6 months").tag(6)
                    Text("Last 12 months").tag(12)
                }.disabled(review.isBusy)
                if review.isAvailable {
                    Button(review.state == .empty || review.state == .failed ? "Check again" : "Review Apple Health samples") {
                        session.reviewAppleHealth(months: months)
                    }
                        .disabled(review.isBusy).accessibilityIdentifier("reviewAppleHealth")
                    if review.state == .empty {
                        Text("Review finished. No readable menstrual-flow records were returned.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("healthReviewResult")
                            .accessibilityFocused($reviewResultFocused)
                    }
                    Button("How to enable Health access") { showAccessHelp = true }
                        .accessibilityIdentifier("healthAccessHelp")
                } else {
                    Text("Apple Health isn’t available on this device. Local tracking works without it.")
                        .accessibilityIdentifier("healthUnavailable")
                }
                if review.isBusy {
                    ProgressView(review.state == .requesting ? "Checking Health access…" : "Reading samples…")
                        .accessibilityIdentifier("healthReviewProgress")
                }
                if review.state != .off {
                    Button("Stop and clear review", role: .cancel) { review.stop() }
                        .accessibilityIdentifier("stopHealthReview")
                }
            } footer: {
                Text("Optional and manual. No background sync. Only menstrual flow is requested—not sexual activity, measurements or other symptoms.")
            }
            if let message = review.message {
                Section { InlineError(message: message).accessibilityFocused($reviewResultFocused) }
            }
            if review.state == .empty {
                Section("No readable flow samples") {
                    Text("There may be no matching records, or read access may be limited or off. An empty result does not tell Cecy which. Local records haven’t changed.")
                    Text("If you already answered Apple’s permission prompt, it won’t appear again. Change Cecy’s read access in Health, then return here and tap Check again.")
                    Text("Only recorded menstrual flow can be imported—not predicted periods. Check that Health has records within the selected date range.")
                }.accessibilityIdentifier("healthEmpty")
            }
            if review.state == .review {
                Section {
                    ForEach(review.samples) { sample in
                        if let receipt = session.snapshot.healthImports.first(where: { $0.id == sample.id }) {
                            VStack(alignment: .leading, spacing: 6) {
                                sampleLabel(sample)
                                Text(receipt.sample == sample ? "Already imported" : "Source changed · local record unchanged")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text(session.snapshot.periods.contains(where: { $0.id == receipt.periodID })
                                     ? "Manage the accepted period in Calendar or History."
                                     : "The local period was deleted. This sample will not be imported again.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        } else {
                            Button { selected = sample } label: {
                                HStack {
                                    sampleLabel(sample)
                                    Spacer()
                                    Image(systemName: "chevron.right").accessibilityHidden(true)
                                }.frame(minHeight: 44)
                            }
                            .foregroundStyle(.primary)
                            .accessibilityIdentifier("healthSample_\(sample.id.uuidString)")
                        }
                    }
                } header: { Text("Review samples") } footer: {
                    Text("Only readable samples appear; older history may be outside your allowed access. A sample is not necessarily a period start. Confirm only dates you recognize as the first day. Adjacent samples are never combined automatically.")
                }
            }
            Section("Your control") {
                DisclosureGroup("Access, deletion and export") {
                    Text("Leaving this screen or stopping review discards unconfirmed samples. Cecy reads again only when you tap Review. To revoke permission, use Apple Health’s app-access settings.")
                    Text("Accepted starts become local records and affect cycle calculations. Later Health edits or deletions do not change them automatically. A missing sample can also mean access changed; it is never treated as a deletion.")
                    Text("Imported periods are included in your normal period export. Source app identifiers and sample metadata are not exported. Other export choices stay unchanged.")
                    Text("Deleting all Cecy data clears imports and their review history, not records in Apple Health. Those samples can be reviewed again afterward.")
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAccessHelp) { HealthAccessHelpView() }
        .sheet(item: $selected) { sample in
            if let today = session.today {
                HealthStartReviewView(session: session, sample: sample, today: today,
                                      timeZone: review.mappingTimeZone)
            }
        }
        .onChange(of: review.state) { _, state in
            if state != .review { selected = nil }
            reviewResultFocused = state == .empty || state == .failed
        }
        .onDisappear { review.stop() }
    }

    private func sampleLabel(_ sample: HealthFlowSample) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let day = try? sample.suggestedDay(fallbackTimeZone: review.mappingTimeZone) {
                Text(DayText.full(day))
            } else { Text("Date needs review") }
            Text("\(sample.flowDescription) · \(sample.sourceName)")
                .font(.subheadline).foregroundStyle(.secondary)
            if sample.markedCycleStart {
                Text("Source marked cycle start").font(.caption).foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

private struct HealthAccessHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsForm(title: "Health access") {
                Section {
                    Text("Apple Health uses permissions on this device. There’s no separate account to connect.")
                        .accessibilityIdentifier("healthAccessExplanation")
                }
                Section("Enable menstrual-flow reading") {
                    Text("1. Open the Health app and tap your profile picture.")
                    Text("2. Under Privacy, tap Apps or Apps and Services, then Cecy.")
                    Text("3. Turn on Menstruation (Menstrual Flow) under the data Cecy is allowed to read.")
                        .accessibilityIdentifier("healthReadPermissionStep")
                    Text("4. Return to Cecy and tap Check again (or Review Apple Health samples).")
                }
                Section("Still no samples?") {
                    Text("In Health, open Browse (or Search) → Cycle Tracking → Menstruation and check for recorded bleeding in your selected date range. Predicted dates aren’t records.")
                    Text("If Cecy isn’t listed in Health, return here and tap Review Apple Health samples first. If Health is restricted on your device, those restrictions may need to be changed.")
                    Text("Cecy cannot tell whether read access was denied. Reviewing never changes your existing records or writes to Health.")
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityIdentifier("closeHealthAccessHelp")
                }
            }
        }
    }
}

private struct HealthStartReviewView: View {
    @Environment(\.dismiss) private var dismiss
    let session: TrackerSession
    let sample: HealthFlowSample
    let today: LocalDay
    let timeZone: TimeZone
    @State private var startDate: Date
    @State private var confirmed = false
    @State private var error: String?
    @AccessibilityFocusState private var errorFocused: Bool

    init(session: TrackerSession, sample: HealthFlowSample, today: LocalDay, timeZone: TimeZone) {
        self.session = session
        self.sample = sample
        self.today = today
        self.timeZone = timeZone
        let suggested = (try? sample.suggestedDay(fallbackTimeZone: timeZone)) ?? today
        _startDate = State(initialValue: min(suggested, today).formattingDate)
    }

    private var validation: String? {
        do {
            let day = try LocalDay(date: startDate, timeZone: LocalDay.calendar.timeZone)
            _ = try HealthImportPolicy.prepare(sample: sample, confirmedStart: day, existing: session.snapshot,
                                              today: session.today ?? today, now: Date(), timeZone: timeZone)
            return nil
        } catch { return error.localizedDescription }
    }

    var body: some View {
        NavigationStack {
            SettingsForm(title: "Confirm a period start") {
                Section("Source observation") {
                    LabeledContent("Source", value: sample.sourceName)
                    LabeledContent("Flow", value: sample.flowDescription)
                    Text("From \(sample.start.formatted()) to \(sample.end.formatted()).")
                    Text("Sample times above use your device’s current time zone.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let identifier = sample.timeZoneIdentifier, TimeZone(identifier: identifier) != nil {
                        Text("Suggested date uses the source time zone: \(identifier).")
                    } else {
                        Text("Source time zone unavailable. Suggested date uses \(timeZone.identifier); check it if you were traveling.")
                    }
                    Text("This may be a daily or multi-day flow observation. It does not confirm when a period began or ended.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    if let sourceDay = try? sample.suggestedDay(fallbackTimeZone: timeZone), sourceDay > today {
                        Text("The source-zone date is \(DayText.full(sourceDay)), ahead of today here. Check the date on this device before confirming; the picker starts at today.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    DatePicker("Period start", selection: $startDate, in: ...today.formattingDate, displayedComponents: .date)
                    Toggle("I confirm this was a new period start", isOn: $confirmed)
                        .accessibilityIdentifier("confirmHealthStart")
                } footer: {
                    Text("Save a start only. No end date, whole-period flow or notes are inferred. You can edit this record later in Calendar or History.")
                }
                if let message = error ?? validation {
                    Section { InlineError(message: message).accessibilityFocused($errorFocused) }
                }
                Section {
                    Button("Save confirmed start") {
                        do {
                            let day = try LocalDay(date: startDate, timeZone: LocalDay.calendar.timeZone)
                            Task {
                                error = await session.withPredictionUpdate { session.importHealthStart(sample, confirmedStart: day) }
                                if error == nil { dismiss() } else { errorFocused = true }
                            }
                        } catch { self.error = "Check the selected date."; errorFocused = true }
                    }
                    .disabled(!confirmed || validation != nil || session.isSaving || !session.healthImport.contains(sample))
                    .accessibilityIdentifier("saveHealthStart")
                }
            }
            .environment(\.calendar, LocalDay.calendar)
            .environment(\.timeZone, LocalDay.calendar.timeZone)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
